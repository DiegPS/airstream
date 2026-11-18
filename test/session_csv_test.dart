import 'dart:convert';

import 'package:airstream/application/session_csv.dart';
import 'package:airstream/application/session_summary.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final time = DateTime.utc(2026, 11, 17, 12, 34, 56);
  ChatMessage message(
    String id, {
    String name = 'Ana',
    String channelId = 'ana-id',
    Platform platform = Platform.youtube,
    String? amount,
    bool owner = false,
  }) =>
      ChatMessage(
        platform: platform,
        id: id,
        author: ChatAuthor(name: name, channelId: channelId),
        items: const [MessageItem.text('@hola, "qué tal"\nsegunda línea')],
        timestamp: time,
        isMembership: true,
        isModerator: true,
        isOwner: owner,
        superChat: amount == null ? null : SuperChat(amount: amount, color: ''),
      );

  test('chat CSV writes BOM, local time, exact columns and safely escaped text',
      () {
    final csv = SessionCsv.chat([
      message('1', name: '=Ána, "C"', channelId: '+id', amount: r'MX$10.25'),
      message('2',
          name: '-Pepe',
          channelId: '@other',
          platform: Platform.twitch,
          amount: '20 Bits'),
    ]);
    expect(csv.take(3), [0xef, 0xbb, 0xbf]);
    final local = time.toLocal().toIso8601String();
    expect(
        utf8.decode(csv),
        'time,platform,name,channel id,roles,message,amount,currency,kind\r\n'
        '$local,youtube,"\'=Ána, ""C""",\'+id,member | moderator,'
        '"\'@hola, ""qué tal""\nsegunda línea",10.25,MX\$,superchat\r\n'
        '$local,twitch,\'-Pepe,\'@other,member | moderator,'
        '"\'@hola, ""qué tal""\nsegunda línea",20,Bits,bits\r\n');
  });

  test('participants use the full session counters and per-currency totals',
      () {
    final collector = SessionSummaryCollector(clock: () => time)..start();
    final kickSupport = ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.support,
      id: 'kicks',
      timestamp: time,
      authorName: 'Ana',
      authorChannelId: 'ana-id',
      count: 20,
    );
    collector
      ..handleMessage(message('1', name: '@Ána', amount: r'MX$10.10'))
      ..handleMessage(message('2', name: '@Ána', amount: r'MX$0.20'))
      ..handleMessage(message('3', name: '@Ána', amount: 'EUR 1.25'))
      ..handleMessage(message('3', name: '@Ána', amount: 'EUR 1.25'))
      ..handleMessage(message('4', platform: Platform.kick))
      ..handleMessage(
          message('5', owner: true, name: 'Owner', channelId: 'owner'))
      ..handleProviderEvent(kickSupport)
      ..handleProviderEvent(kickSupport)
      ..handleProviderEvent(ChatProviderEvent(
        platform: Platform.kick,
        kind: ChatProviderEventKind.support,
        id: 'kicks-by-name',
        timestamp: time,
        authorName: 'Ana',
        count: 2,
      ))
      ..handleProviderEvent(ChatProviderEvent(
        platform: Platform.kick,
        kind: ChatProviderEventKind.support,
        id: 'support-only',
        timestamp: time,
        authorName: 'Beto, "B"',
        count: 40,
      ))
      ..stop()
      ..handleMessage(
          message('outside', name: 'Outside', channelId: 'outside'));

    final csv = SessionCsv.participants(collector.summary.participants);
    expect(csv.take(3), [0xef, 0xbb, 0xbf]);
    expect(
        utf8.decode(csv),
        'name,platform,channel id,messages,supports,totals by currency\r\n'
        '\'@Ána,youtube,ana-id,3,3,EUR 1.25 | MX\$ 10.3\r\n'
        'Ana,kick,ana-id,1,2,Kicks 22\r\n'
        '"Beto, ""B""",kick,,0,1,Kicks 40\r\n');
    collector.start();
    expect(collector.summary.participants, isEmpty);
  });
}
