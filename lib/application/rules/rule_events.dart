import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';

class RuleAuthor {
  const RuleAuthor({this.name = '', this.id = '', this.roles = const []});
  final String name, id;
  final List<String> roles;
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
      this.months = 0,
      this.scene = '',
      this.goalId = '',
      this.chainDepth = 0,
      this.message});
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
  final ChatMessage? message;
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

/// Session-local first-author tracking; event dedupe belongs to the engine.
class RuleEventAdapter {
  final _authors = <String>{};
  void startSession() => _authors.clear();
  Iterable<RuleEvent> message(ChatMessage m, {bool? firstInSession}) sync* {
    final roles = [
      if (m.isOwner) 'owner',
      if (m.isModerator || m.isOwner) 'moderator',
      if (m.isVip) 'vip',
      if (m.isMembership) 'member'
    ];
    final a =
        RuleAuthor(name: m.author.name, id: m.author.channelId, roles: roles);
    final money = parseRuleAmount(m.superChat?.amount ?? '');
    RuleEvent event(String type, {int count = 0}) => RuleEvent(
        type: type,
        platform: m.platform.name,
        eventId: 'message:${m.dedupeKey}',
        author: a,
        text: m.plainText,
        amount: money.amount,
        currency: money.currency,
        presentationAmount: m.superChat?.amount ?? '',
        count: count,
        months: m.membershipMonths ?? 0,
        message: m);
    yield event('chat.message');
    if (RegExp(r'^![A-Za-z0-9_]{1,30}(?:\s|$)').hasMatch(m.plainText.trim())) {
      yield event('chat.command');
    }
    if (_authors.add(
            '${m.platform.name}:${a.id.isEmpty ? a.name.toLowerCase() : a.id}') &&
        (firstInSession ?? true)) {
      yield event('chat.firstMessage');
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
      yield event('support.gift',
          count:
              m.platform == Platform.twitch ? 1 : (m.membershipGiftCount ?? 1));
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
            count: e.count ?? 0);
  }
}
