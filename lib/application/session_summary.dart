import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';

/// How a viewer supported the stream.
enum SupportKind { superChat, membership, gift, raid, support }

class SessionSupporter {
  const SessionSupporter({
    required this.platform,
    required this.name,
    required this.kind,
    this.amount,
    this.months,
    this.count,
  });

  final Platform platform;
  final String name;
  final SupportKind kind;

  /// The Super Chat amount as YouTube shows it ("$5.00").
  final String? amount;
  final int? months;

  /// Gifted subscriptions, or raid viewers.
  final int? count;
}

class SessionChatter {
  const SessionChatter(this.platform, this.name, this.messages);

  final Platform platform;
  final String name;
  final int messages;
}

/// What happened in the chat between starting and stopping it.
class SessionSummary {
  const SessionSummary({
    this.startedAt,
    this.endedAt,
    this.messagesByPlatform = const {},
    this.chatters = 0,
    this.topChatters = const [],
    this.supporters = const [],
  });

  final DateTime? startedAt;
  final DateTime? endedAt;
  final Map<Platform, int> messagesByPlatform;
  final int chatters;
  final List<SessionChatter> topChatters;
  final List<SessionSupporter> supporters;

  int get messages =>
      messagesByPlatform.values.fold(0, (total, count) => total + count);

  bool get isEmpty => messages == 0 && supporters.isEmpty;

  Duration duration(DateTime now) {
    final start = startedAt;
    if (start == null) return Duration.zero;
    return (endedAt ?? now).difference(start);
  }
}

/// Collects the session summary from the chat as it happens.
class SessionSummaryCollector {
  SessionSummaryCollector({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const topChatterCount = 5;

  final DateTime Function() _clock;
  DateTime? _startedAt;
  DateTime? _endedAt;
  final _messages = <Platform, int>{};
  final _chatters = <String, ({Platform platform, String name, int count})>{};
  final _supporters = <SessionSupporter>[];
  final _seenEvents = <String>{};

  bool get _running => _startedAt != null && _endedAt == null;

  /// A new chat session: the previous summary is replaced.
  void start() {
    _startedAt = _clock();
    _endedAt = null;
    _messages.clear();
    _chatters.clear();
    _supporters.clear();
    _seenEvents.clear();
  }

  /// The summary stays available until the next [start].
  void stop() {
    if (_running) _endedAt = _clock();
  }

  void handleMessage(ChatMessage message) {
    if (!_running) return;
    if (message.isMembershipEvent) {
      final gifts = message.membershipGiftCount;
      _supporters.add(SessionSupporter(
        platform: message.platform,
        name: message.author.name,
        kind: message.membershipEventKind == MembershipEventKind.gift ||
                (gifts != null && gifts > 0)
            ? SupportKind.gift
            : SupportKind.membership,
        months: message.membershipMonths,
        count: gifts,
      ));
      return;
    }
    if (message.isOwner) return;
    _messages.update(message.platform, (n) => n + 1, ifAbsent: () => 1);
    final identity = message.author.channelId.trim().isNotEmpty
        ? message.author.channelId
        : message.author.name;
    final key = '${message.platform.name}:${identity.trim().toLowerCase()}';
    final previous = _chatters[key];
    _chatters[key] = (
      platform: message.platform,
      name: message.author.name,
      count: (previous?.count ?? 0) + 1,
    );
    if (message.superChat case final superChat?) {
      _supporters.add(SessionSupporter(
        platform: message.platform,
        name: message.author.name,
        kind: SupportKind.superChat,
        amount: superChat.amount,
      ));
    }
  }

  void handleProviderEvent(ChatProviderEvent event) {
    if (!_running) return;
    final kind = switch (event.kind) {
      ChatProviderEventKind.raid => SupportKind.raid,
      ChatProviderEventKind.support => SupportKind.support,
      _ => null,
    };
    if (kind == null || event.authorName.trim().isEmpty) return;
    if (!_seenEvents.add('${event.platform.name}:${event.id}')) return;
    _supporters.add(SessionSupporter(
      platform: event.platform,
      name: event.authorName,
      kind: kind,
      count: event.count,
    ));
  }

  SessionSummary get summary {
    final chatters = _chatters.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return SessionSummary(
      startedAt: _startedAt,
      endedAt: _endedAt,
      messagesByPlatform: Map.unmodifiable(_messages),
      chatters: _chatters.length,
      topChatters: [
        for (final chatter in chatters.take(topChatterCount))
          SessionChatter(chatter.platform, chatter.name, chatter.count),
      ],
      supporters: List.unmodifiable(_supporters),
    );
  }
}
