import 'dart:async';

import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';

class RuleAuthor {
  const RuleAuthor({this.name = '', this.id = '', this.roles = const []});
  final String name, id;
  final List<String> roles;
}

bool isViewerRuleEvent(String type) =>
    type.startsWith('chat.') ||
    type == 'queue.joined' ||
    type.startsWith('support.');

class RuleEventOrigin {
  RuleEventOrigin({required this.viewer, required List<String> roles})
      : roles = List.unmodifiable(roles);

  final bool viewer;
  final List<String> roles;

  bool get isUnprivilegedViewer =>
      viewer && !roles.contains('owner') && !roles.contains('moderator');

  // Scope the cause to the run even if several rules overlap.
  static final _zoneKey = Object();
  static RuleEventOrigin? get current =>
      Zone.current[_zoneKey] as RuleEventOrigin?;

  T run<T>(T Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: this});
}

class RuleEvent {
  const RuleEvent(
      {required this.type,
      this.platform = '',
      this.eventId = '',
      this.author = const RuleAuthor(),
      this.text = '',
      this.amount,
      this.presentationAmount = '',
      this.currency = '',
      this.count = 0,
      this.note,
      this.position,
      this.winner,
      this.total,
      this.months = 0,
      this.scene = '',
      this.goalId = '',
      this.chainDepth = 0,
      RuleEventOrigin? origin,
      this.message,
      ChatMessage? moderationSource})
      : moderationSource = moderationSource ?? message,
        _origin = origin;

  final RuleEventOrigin? _origin;
  RuleEventOrigin get origin =>
      _origin ??
      RuleEventOrigin(viewer: isViewerRuleEvent(type), roles: author.roles);

  factory RuleEvent.pollEnded(ChatPoll poll, {String eventId = ''}) =>
      RuleEvent(
        type: 'poll.ended',
        eventId: eventId,
        winner: poll.winner,
        total: poll.total,
      );
  final String type,
      platform,
      eventId,
      text,
      currency,
      presentationAmount,
      scene,
      goalId;
  final RuleAuthor author;
  final num? amount;
  final int count, months, chainDepth;
  final String? note, winner;
  final int? position, total;
  final ChatMessage? message;
  final ChatMessage? moderationSource;
  String get command => text.trim().split(RegExp(r'\s+')).first.toLowerCase();
  String get args {
    final m = RegExp(r'^\s*\S+\s*(.*)$', dotAll: true).firstMatch(text);
    return m?[1] ?? '';
  }

  String get userKey =>
      '$platform:${author.id.isEmpty ? author.name.toLowerCase() : author.id}';
}

/// Parses presentation money without assuming that comma means thousands.
({num? amount, String currency}) parseRuleAmount(String text) {
  final m =
      RegExp(r'^\s*([^\d.,]*)([\d][\d., ]*)([^\d.,]*)\s*$').firstMatch(text);
  if (m == null) return (amount: null, currency: '');
  var n = m[2]!.trim().replaceAll(' ', '');
  final dot = n.lastIndexOf('.'), comma = n.lastIndexOf(',');
  if (dot >= 0 && comma >= 0) {
    final decimal = dot > comma ? '.' : ',';
    n = n.replaceAll(decimal == '.' ? ',' : '.', '').replaceAll(decimal, '.');
  } else if (comma >= 0) {
    n = n.length - comma - 1 == 3
        ? n.replaceAll(',', '')
        : n.replaceAll(',', '.');
  }
  return (amount: num.tryParse(n), currency: '${m[1]!.trim()}${m[3]!.trim()}');
}

int? parseRuleBits(String amount) {
  final digits = RegExp(r'^(\d+) Bits$').firstMatch(amount)?[1];
  return digits == null ? null : int.tryParse(digits) ?? 0;
}

/// Adapts pipeline messages and provider events to rule triggers.
class RuleEventAdapter {
  int _privateSupportSequence = 0;

  Iterable<RuleEvent> message(ChatMessage m,
      {bool supportOnly = false, int? twitchGiftCount}) sync* {
    final roles = [
      if (m.isOwner) 'owner',
      if (m.isModerator || m.isOwner) 'moderator',
      if (m.isVip) 'vip',
      if (m.isMembership) 'member'
    ];
    final a =
        RuleAuthor(name: m.author.name, id: m.author.channelId, roles: roles);
    final money = parseRuleAmount(m.superChat?.amount ?? '');
    final eventId = supportOnly && m.dedupeIdKey.isEmpty
        ? 'private-support:${++_privateSupportSequence}'
        : 'message:${m.dedupeKey}';
    RuleEvent event(String type, {int count = 0}) => RuleEvent(
        type: type,
        platform: m.platform.name,
        eventId: eventId,
        author: a,
        text: m.plainText,
        amount: money.amount,
        currency: money.currency,
        presentationAmount: m.superChat?.amount ?? '',
        count: count,
        months: m.membershipMonths ?? 0,
        message: m);
    if (twitchGiftCount != null) {
      yield event('support.gift', count: twitchGiftCount);
      return;
    }
    if (!supportOnly) {
      yield event('chat.message');
      if (RegExp(r'^![A-Za-z0-9_]{1,30}(?:\s|$)')
          .hasMatch(m.plainText.trim())) {
        yield event('chat.command');
      }
      if (!m.isMembershipEvent && m.isFirstInSession) {
        yield event('chat.firstMessage');
      }
    }
    if (m.superChat != null) {
      final bits = parseRuleBits(m.superChat!.amount);
      if (m.platform == Platform.twitch && bits != null) {
        yield event('support.bits', count: bits);
      } else if (m.platform == Platform.youtube) {
        yield event('support.superchat');
      }
    }
    if (m.membershipEventKind == MembershipEventKind.gift) {
      if (m.platform != Platform.twitch) {
        yield event('support.gift', count: m.membershipGiftCount ?? 1);
      }
    } else if (m.membershipEventKind != null ||
        (m.platform == Platform.youtube && m.isMembershipEvent)) {
      yield event('support.membership');
    }
  }

  RuleEvent? provider(ChatProviderEvent e) {
    final type = switch (e.kind) {
      ChatProviderEventKind.raid ||
      ChatProviderEventKind.host =>
        'support.raid',
      ChatProviderEventKind.support when e.platform == Platform.kick =>
        'support.kicks',
      _ => null
    };
    return type == null
        ? null
        : RuleEvent(
            type: type,
            platform: e.platform.name,
            eventId: 'provider:${e.platform.name}:${e.id}',
            author: RuleAuthor(name: e.authorName),
            text: e.text,
            moderationSource: type == 'support.kicks'
                ? ChatMessage(
                    id: e.id,
                    platform: e.platform,
                    author: ChatAuthor(
                      name: e.viewerName ?? e.authorName,
                      channelId: e.authorChannelId,
                    ),
                    items: [MessageItem.text(e.viewerText ?? e.text)],
                    timestamp: e.timestamp,
                  )
                : null,
            count: e.count ?? 0);
  }
}
