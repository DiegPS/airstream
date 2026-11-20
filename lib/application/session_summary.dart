import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/support_alert.dart';
import 'package:airstream/pipeline/chat_filter.dart';
import 'package:airstream/settings/alert_type_options.dart';

import 'rules/rule_events.dart';

/// How a viewer supported the stream.
enum SupportKind { superChat, membership, gift, raid, support }

typedef _SupportIdentity = (Platform, {String accountId, String fallbackName});

class SessionSupporter {
  const SessionSupporter({
    required this.platform,
    required this.name,
    required this.kind,
    required this.id,
    required this.at,
    this.channelId = '',
    this.type,
    this.currency,
    this.value,
    this.amount,
    this.months,
    this.count,
  });

  final Platform platform;
  final String name;
  final String channelId;
  // The legacy kind drives the in-app summary wording.
  final SupportKind kind;
  final String id;
  final DateTime at;
  final String? type, currency;
  final num? value;

  Map<String, Object?> toTemplateJson() => {
        'id': id,
        'platform': platform.name,
        'name': name,
        if (channelId.isNotEmpty) 'channelId': channelId,
        'type': type,
        'amount': amount,
        'currency': currency,
        'value': value,
        'months': months,
        'count': count,
        'at': at.toUtc().toIso8601String(),
      };

  /// The presentation amount supplied by the chat message.
  final String? amount;
  final int? months;

  /// Gifted subscriptions, bits, kicks, or raid viewers.
  final int? count;
}

class SessionParticipant {
  const SessionParticipant({
    required this.platform,
    required this.name,
    required this.channelId,
    required this.messages,
    required this.supports,
    required this.totals,
  });

  final Platform platform;
  final String name;
  final String channelId;
  final int messages;
  final int supports;
  final Map<String, num> totals;
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
    this.participants = const [],
  });

  final DateTime? startedAt;
  final DateTime? endedAt;
  final Map<Platform, int> messagesByPlatform;
  final int chatters;
  final List<SessionChatter> topChatters;
  final List<SessionSupporter> supporters;
  final List<SessionParticipant> participants;

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
  final _chatters = <String,
      ({Platform platform, String name, String channelId, int count})>{};
  final _supporters = <({
    SessionSupporter supporter,
    _SupportIdentity identity,
    bool inSummary
  })>[];
  final _kickAccountsByName = <String, String?>{};
  int _nextSupporter = 0;
  Map<String, Object?>? _templateSupports;
  ChatFilter? _publicFilter;
  final _seenEvents = <String>{};

  /// Bumps whenever the block list changes, so pages can tell a name
  /// removed by blocking from one that just dropped out of a ranking.
  int _filterRevision = 0;

  void applyBlockFilter(ChatFilter filter) {
    _publicFilter = filter;
    _filterRevision++;
    _templateSupports = null;
  }

  bool _isPublic(String name, String channelId) =>
      _publicFilter?.blocksUser(name, channelId) != true;

  bool get _running => _startedAt != null && _endedAt == null;

  /// A new chat session: the previous summary is replaced.
  void start() {
    _startedAt = _clock();
    _endedAt = null;
    _messages.clear();
    _chatters.clear();
    _supporters.clear();
    _kickAccountsByName.clear();
    _templateSupports = null;
    _seenEvents.clear();
  }

  /// The summary stays available until the next [start].
  void stop() {
    if (_running) _endedAt = _clock();
  }

  bool handleMessage(ChatMessage message, {int? twitchGiftCount}) {
    if (!_running) return false;
    _rememberKickAccount(
        message.platform, message.author.accountId, message.author.name);
    final kind = messageAlertKind(message);
    if (kind != null && !_seenEvents.add('message:${message.dedupeKey}')) {
      return false;
    }

    final identity = message.author.channelId.trim().isNotEmpty
        ? message.author.channelId
        : message.author.name;
    final key = _identity(message.platform, identity);
    final countsAsChat = !message.isOwner && !message.isMembershipEvent;
    if (countsAsChat) {
      _messages.update(message.platform, (n) => n + 1, ifAbsent: () => 1);
      final previous = _chatters[key];
      _chatters[key] = (
        platform: message.platform,
        name: message.author.name,
        channelId: message.author.channelId,
        count: (previous?.count ?? 0) + 1,
      );
    }
    if (kind == null) return countsAsChat;

    final type =
        supportAlertType(kind, message.platform, message.membershipEventKind);
    final amount = message.superChat?.amount;
    final money = type == 'superchat' ? parseRuleAmount(amount!) : null;
    final bits = type == 'bits' ? parseRuleBits(amount!) : null;
    final gifts = twitchGiftCount ?? message.membershipGiftCount;
    final legacy = message.isMembershipEvent
        ? (message.membershipEventKind == MembershipEventKind.gift ||
                (gifts != null && gifts > 0)
            ? SupportKind.gift
            : SupportKind.membership)
        : SupportKind.superChat;
    _supporters.add((
      supporter: SessionSupporter(
        id: _newSupportId(),
        at: message.timestamp,
        platform: message.platform,
        name: message.author.name,
        channelId: message.author.channelId,
        kind: legacy,
        type: type,
        amount: legacy == SupportKind.superChat ? amount : null,
        currency: money?.currency.isNotEmpty == true ? money!.currency : null,
        value: bits ?? (money?.amount?.isFinite == true ? money!.amount : null),
        months: message.membershipMonths,
        count: type == 'gift' ? (gifts ?? 1) : (bits ?? gifts),
      ),
      identity: _supportIdentity(
          message.platform, message.author.accountId, message.author.name),
      inSummary: countsAsChat || message.isMembershipEvent,
    ));
    if (type != null) _templateSupports = null;
    return countsAsChat || type != null;
  }

  bool handleProviderEvent(ChatProviderEvent event) {
    if (!_running || event.authorName.trim().isEmpty) return false;
    _rememberKickAccount(
        event.platform, event.authorAccountId, event.authorName);
    final legacy = switch (event.kind) {
      ChatProviderEventKind.raid => SupportKind.raid,
      ChatProviderEventKind.support => SupportKind.support,
      _ => null,
    };
    final kind = providerAlertKind(event);
    if (legacy == null && kind == null) return false;
    if (!_seenEvents.add('provider:${event.platform.name}:${event.id}')) {
      return false;
    }
    _supporters.add((
      supporter: SessionSupporter(
        id: _newSupportId(),
        at: event.timestamp,
        platform: event.platform,
        name: event.authorName,
        channelId: event.authorChannelId,
        kind: legacy ?? SupportKind.raid,
        type:
            kind == null ? null : supportAlertType(kind, event.platform, null),
        value: event.count,
        count: event.count,
      ),
      identity: _supportIdentity(
          event.platform, event.authorAccountId, event.authorName),
      inSummary: legacy != null,
    ));
    if (kind != null) _templateSupports = null;
    return kind != null;
  }

  String _newSupportId() =>
      'support-${_startedAt!.microsecondsSinceEpoch}-${++_nextSupporter}';

  static String _identity(Platform platform, String author) =>
      '${platform.name}:${author.trim().toLowerCase()}';

  static _SupportIdentity _supportIdentity(
      Platform platform, String accountId, String name) {
    final id = accountId.trim();
    return (
      platform,
      accountId: id,
      fallbackName: id.isEmpty ? name.trim().toLowerCase() : '',
    );
  }

  void _rememberKickAccount(Platform platform, String accountId, String name) {
    if (platform != Platform.kick) return;
    final id = accountId.trim();
    final key = name.trim().toLowerCase();
    if ((int.tryParse(id) ?? 0) <= 0 || key.isEmpty) return;
    if (!_kickAccountsByName.containsKey(key)) {
      _kickAccountsByName[key] = id;
      _templateSupports = null;
    } else if (_kickAccountsByName[key] case final previous?
        when previous != id) {
      _kickAccountsByName[key] = null;
      _templateSupports = null;
    }
  }

  _SupportIdentity _resolvedSupportIdentity(_SupportIdentity identity) {
    if (identity.$1 == Platform.kick && identity.accountId.isEmpty) {
      final id = _kickAccountsByName[identity.fallbackName];
      if (id != null) return (Platform.kick, accountId: id, fallbackName: '');
    }
    return identity;
  }

  /// Builds the template projection on demand, independent of the dialog.
  Map<String, Object?>? templateState({required bool live}) {
    final startedAt = _startedAt;
    if (startedAt == null) return null;
    final chatters = _chatters.values.indexed.toList()
      ..sort((a, b) {
        final count = b.$2.count.compareTo(a.$2.count);
        return count != 0 ? count : a.$1.compareTo(b.$1);
      });
    return {
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': _endedAt?.toUtc().toIso8601String(),
      'live': live,
      // Additive SDK v1 field: changes only when the block list changes.
      'filterRevision': _filterRevision,
      'messages':
          _messages.values.fold<int>(0, (total, count) => total + count),
      'chatters': _chatters.length,
      ...(_templateSupports ??= _buildTemplateSupports()),
      'topChatters': [
        for (final (index, chatter) in chatters
            .where((entry) => _isPublic(entry.$2.name, entry.$2.channelId))
            .take(10))
          {
            'platform': chatter.platform.name,
            'name': chatter.name,
            'messages': chatter.count,
            'sessionIndex': index,
          },
      ],
    };
  }

  Map<String, Object?> _buildTemplateSupports() {
    final supports = [
      for (final (index, entry) in _supporters.indexed)
        if (entry.supporter.type != null)
          (
            index: index,
            supporter: entry.supporter,
            identity: _resolvedSupportIdentity(entry.identity),
          ),
    ]..sort((a, b) {
        final time = a.supporter.at.compareTo(b.supporter.at);
        return time != 0 ? time : a.index.compareTo(b.index);
      });

    final latest = <String, SessionSupporter?>{
      for (final type in alertTypeIds) type: null,
    };
    final rankings = <String, Map<_SupportIdentity, _SupportTotal>>{
      'gift': {},
      'bits': {},
      'kicks': {},
    };
    final currencies = <String, Map<_SupportIdentity, _SupportTotal>>{};
    final superchatCounts = <String, int>{};
    final publicSupports = <SessionSupporter>[];

    for (final entry in supports) {
      final supporter = entry.supporter;
      final type = supporter.type!;
      final isPublic = _isPublic(supporter.name, supporter.channelId);
      if (isPublic) {
        latest[type] = supporter;
        publicSupports.add(supporter);
      }
      final currency = supporter.currency;
      if (type == 'superchat' && currency != null) {
        superchatCounts.update(currency, (count) => count + 1,
            ifAbsent: () => 1);
      }
      final value = type == 'gift' ? supporter.count : supporter.value;
      if (!isPublic || value == null) continue;
      final totals = type == 'superchat' && currency != null
          ? currencies.putIfAbsent(currency, () => {})
          : rankings[type];
      if (totals == null) continue;
      final total = totals.putIfAbsent(
          entry.identity, () => _SupportTotal(supporter, entry.index));
      total.value += value;
      if (entry.index < total.sessionIndex) total.sessionIndex = entry.index;
    }

    return {
      'supporterCount': supports.map((entry) => entry.identity).toSet().length,
      'superchatCounts': superchatCounts,
      'supporters': [
        for (final supporter in publicSupports.reversed.take(50))
          supporter.toTemplateJson()
      ],
      'latest': {
        for (final entry in latest.entries)
          entry.key: entry.value?.toTemplateJson(),
      },
      'top': {
        for (final entry in rankings.entries) entry.key: _rank(entry.value),
        'superchat': {
          for (final entry in currencies.entries) entry.key: _rank(entry.value),
        },
      },
    };
  }

  static List<Map<String, Object?>> _rank(
      Map<_SupportIdentity, _SupportTotal> totals) {
    final ranked = totals.values.toList()
      ..sort((a, b) {
        final value = b.value.compareTo(a.value);
        if (value != 0) return value;
        final time = a.first.at.compareTo(b.first.at);
        return time != 0 ? time : a.index.compareTo(b.index);
      });
    return [
      for (final total in ranked.take(5))
        {
          'platform': total.first.platform.name,
          'name': total.first.name,
          'value': total.value,
          'sessionIndex': total.sessionIndex,
        },
    ];
  }

  List<SessionParticipant> _exportParticipants() {
    final participants = <String, _ParticipantTotal>{};
    // Name-only provider events can use a chatter's identity when unambiguous.
    final keysByName = <String, String?>{};
    for (final entry in _chatters.entries) {
      final chatter = entry.value;
      participants[entry.key] = _ParticipantTotal(
        chatter.platform,
        chatter.name,
        chatter.channelId,
        chatter.count,
      );
      final nameKey = _identity(chatter.platform, chatter.name);
      keysByName[nameKey] = keysByName.containsKey(nameKey) ? null : entry.key;
    }
    for (final entry in _supporters) {
      if (!entry.inSummary) continue;
      final support = entry.supporter;
      final nameKey = _identity(support.platform, support.name);
      final key = support.channelId.isNotEmpty
          ? _identity(support.platform, support.channelId)
          : keysByName[nameKey] ?? nameKey;
      final participant = participants.putIfAbsent(
          key,
          () => _ParticipantTotal(
              support.platform, support.name, support.channelId, 0));
      participant.supports++;
      final unit = support.currency ??
          switch (support.type) {
            'bits' => 'Bits',
            'kicks' => 'Kicks',
            _ => null,
          };
      final value = support.value;
      if (unit != null && value != null) {
        participant.totals
            .update(unit, (total) => total + value, ifAbsent: () => value);
      }
    }
    return List.unmodifiable(
        participants.values.map((participant) => SessionParticipant(
              platform: participant.platform,
              name: participant.name,
              channelId: participant.channelId,
              messages: participant.messages,
              supports: participant.supports,
              totals: Map.unmodifiable(participant.totals),
            )));
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
      participants: _exportParticipants(),
      supporters: List.unmodifiable(_supporters
          .where((entry) => entry.inSummary)
          .map((entry) => entry.supporter)),
    );
  }
}

class _ParticipantTotal {
  _ParticipantTotal(this.platform, this.name, this.channelId, this.messages);

  final Platform platform;
  final String name;
  final String channelId;
  final int messages;
  int supports = 0;
  final totals = <String, num>{};
}

class _SupportTotal {
  _SupportTotal(this.first, this.index) : sessionIndex = index;
  final SessionSupporter first;
  final int index;
  // Keep this identity if a subsequent event has an earlier timestamp.
  int sessionIndex;
  num value = 0;
}
