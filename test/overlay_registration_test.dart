import 'dart:async';
import 'dart:convert';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test(
      'fresh server replays empty poll, giveaway, goals, timer and queue snapshots',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final poll = _Socket(server)..register('poll');
    final giveaway = _Socket(server)..register('giveaway');
    final goals = _Socket(server)..register('goals');
    final timer = _Socket(server)..register('timer');
    final clock = _Socket(server)..register('clock');
    final widget = _Socket(server)..register('gallery', template: 'poll');
    final queue = _Socket(server)..register('gallery', template: 'queue-list');

    expect(poll.snapshot('poll')['data'], isNull);
    expect(giveaway.snapshot('giveaway')['data'], isNull);
    expect(goals.snapshot('goals')['data'], isEmpty);
    expect(timer.snapshot('timer')['data'], containsPair('phase', 'idle'));
    expect(clock.snapshot('clock')['data'], isA<Map>());
    expect(widget.snapshot('poll')['data'], isNull);
    expect(queue.snapshot('queue')['data'], containsPair('entries', isEmpty));
  });

  test(
      'test and replay require successful delivery to a registered alerts page',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final chat = _Socket(server)..register('chat');
    final unregistered = _Socket(server);
    server.broadcastProviderEvent(ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: 'raid',
        timestamp: DateTime.utc(2026),
        authorName: 'Viewer',
        count: 42));
    final recent = server.recentAlertsSnapshot.single;
    chat.sink.frames.clear();
    unregistered.sink.frames.clear();

    expect(server.broadcastTestAlert('bits'), isFalse);
    expect(server.replayRecentAlert('raid'), isFalse);
    expect(chat.sink.frames, isEmpty);
    expect(unregistered.sink.frames, isEmpty);

    final alerts = _Socket(server)..register('alerts');
    expect(server.broadcastTestAlert('bits'), isTrue);
    expect(server.replayRecentAlert('raid'), isTrue);
    final received =
        alerts.sink.frames.where((frame) => frame['type'] == 'alert').toList();
    expect(received, hasLength(2));
    expect(received.first['data']['id'], startsWith('test-bits-'));
    expect(received.last['data']['id'], 'raid');
    expect(received.last['data'], recent);
    expect(chat.sink.frames, isEmpty);
    expect(unregistered.sink.frames, isEmpty);

    alerts.sink.fail = true;
    expect(server.broadcastTestAlert('bits'), isFalse);
    expect(server.replayRecentAlert('raid'), isFalse);
  });
}

class _Socket implements WebSocketChannel {
  _Socket(OverlayServer server) {
    server.attachClient(this);
    addTearDown(_incoming.close);
  }

  final _incoming = StreamController<String>(sync: true);

  @override
  final _Sink sink = _Sink();

  @override
  Stream<String> get stream => _incoming.stream;

  void register(String view, {String? template}) {
    _incoming.add(jsonEncode({
      'type': 'register',
      'view': view,
      if (template != null) 'template': template,
    }));
    expect(sink.frames.singleWhere((frame) => frame['type'] == 'registered'),
        {'type': 'registered', 'view': view});
  }

  Map<String, dynamic> snapshot(String type) {
    final frame = sink.frames.singleWhere((frame) => frame['type'] == type);
    expect(frame['replay'], isTrue);
    return frame;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  final frames = <Map<String, dynamic>>[];
  bool fail = false;

  @override
  void add(dynamic event) {
    if (fail) throw StateError('Closed socket');
    frames.add(jsonDecode(event as String) as Map<String, dynamic>);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
