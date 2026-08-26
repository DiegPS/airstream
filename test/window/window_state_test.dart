import 'dart:async';

import 'package:airstream/window/window_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.airchat/air_window_control';
  const channel = MethodChannel(channelName);
  const codec = StandardMethodCodec();
  final calls = <MethodCall>[];

  Future<void> sendNativeEvent(Map<String, Object> event) async {
    final response = Completer<ByteData?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channelName,
      codec.encodeMethodCall(MethodCall('onEvent', event)),
      response.complete,
    );
    await response.future;
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('registers Ctrl+Shift+C and handles its native event', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'registerGlobalHotKey') return true;
      return null;
    });

    final notifier = WindowStateNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.globalClickThroughHotKeyRegistered, isTrue);
    expect(calls.first.method, 'registerGlobalHotKey');
    expect(calls.first.arguments, {
      'id': WindowStateNotifier.clickThroughHotKeyId,
      'key': 'C',
      'modifiers': containsAll(['control', 'shift']),
    });

    await sendNativeEvent({
      'eventName': 'globalHotKeyPressed',
      'id': WindowStateNotifier.clickThroughHotKeyId,
    });
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.clickThrough, isTrue);
    expect(
      calls.where((call) => call.method == 'setClickThrough').single.arguments,
      {'enabled': true},
    );
  });

  test('reports a global shortcut conflict without changing window state',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'registerGlobalHotKey') {
        throw PlatformException(code: 'hot_key_unavailable');
      }
      return null;
    });

    final notifier = WindowStateNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.globalClickThroughHotKeyRegistered, isFalse);
    expect(
      notifier.state.globalClickThroughHotKeyError,
      'hot_key_unavailable',
    );
    expect(notifier.state.clickThrough, isFalse);

    await notifier.toggleClickThrough();
    expect(notifier.state.clickThrough, isFalse);
  });

  test('serializes rapid toggles instead of applying the same state twice',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'registerGlobalHotKey') return true;
      return null;
    });

    final notifier = WindowStateNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    await Future.wait([
      notifier.toggleClickThrough(),
      notifier.toggleClickThrough(),
    ]);

    expect(notifier.state.clickThrough, isFalse);
    expect(
      calls
          .where((call) => call.method == 'setClickThrough')
          .map((call) => call.arguments),
      [
        {'enabled': true},
        {'enabled': false},
      ],
    );
  });
}
