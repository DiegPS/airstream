import 'dart:convert';
import 'dart:typed_data';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/support_alert.dart';

import 'rules/rule_events.dart';
import 'session_summary.dart';

abstract final class SessionCsv {
  static Uint8List chat(Iterable<ChatMessage> messages,
          {String separator = ','}) =>
      _encode(separator, [
        [
          'time',
          'platform',
          'name',
          'channel id',
          'roles',
          'message',
          'amount',
          'currency',
          'kind',
        ],
        ...messages.map(_chatRow),
      ]);

  static List<Object?> _chatRow(ChatMessage message) {
    final kind = messageAlertKind(message);
    final amount = message.superChat?.amount;
    final money = kind == 'superchat' ? parseRuleAmount(amount!) : null;
    final bits = kind == 'bits' ? parseRuleBits(amount!) : null;
    return [
      message.timestamp.toLocal().toIso8601String(),
      message.platform.name,
      message.author.name,
      message.author.channelId,
      [
        if (message.isMembership) 'member',
        if (message.isModerator) 'moderator',
        if (message.isVip) 'vip',
        if (message.isOwner) 'owner',
        if (message.isVerified) 'verified',
      ].join(' | '),
      message.plainText,
      money?.amount ?? bits ?? amount,
      kind == 'bits' ? 'Bits' : money?.currency,
      (kind == null
              ? null
              : supportAlertType(
                  kind, message.platform, message.membershipEventKind)) ??
          kind ??
          'chat',
    ];
  }

  static Uint8List participants(Iterable<SessionParticipant> participants,
          {String separator = ','}) =>
      _encode(separator, [
        [
          'name',
          'platform',
          'channel id',
          'messages',
          'supports',
          'totals by currency'
        ],
        for (final participant in participants)
          [
            participant.name,
            participant.platform.name,
            participant.channelId,
            participant.messages,
            participant.supports,
            (participant.totals.keys.toList()..sort())
                .map((unit) =>
                    '$unit ${_formatTotal(participant.totals[unit]!)}')
                .join(' | '),
          ],
      ]);

  static String _formatTotal(num value) => value is int
      ? value.toString()
      : num.parse(value.toStringAsPrecision(15)).toString();

  static Uint8List _encode(String separator, Iterable<List<Object?>> rows) {
    final csv = StringBuffer('\uFEFF');
    for (final row in rows) {
      csv
        ..write(row.map((cell) => _escape(cell, separator)).join(separator))
        ..write('\r\n');
    }
    return Uint8List.fromList(utf8.encode(csv.toString()));
  }

  static final _formulaStart = RegExp(r'^\s*[=+\-@]');
  static final _lineOrQuote = RegExp(r'["\r\n]');

  static String _escape(Object? value, String separator) {
    var cell = value?.toString() ?? '';
    if (_formulaStart.hasMatch(cell)) cell = "'$cell";
    return _lineOrQuote.hasMatch(cell) || cell.contains(separator)
        ? '"${cell.replaceAll('"', '""')}"'
        : cell;
  }
}
