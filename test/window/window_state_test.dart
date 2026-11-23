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

  test('reserves Ctrl+Shift+C only while click-through is on', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'registerGlobalHotKey') return true;
      return null;
    });

    final notifier = WindowStateNotifier();
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    // Other apps keep the shortcut while click-through is off.
    expect(calls, isEmpty);

    await notifier.toggleClickThrough();
    expect(notifier.state.clickThrough, isTrue);
    expect(notifier.state.globalClickThroughHotKeyRegistered, isTrue);
    expect(calls.map((call) => call.method),
        ['registerGlobalHotKey', 'setClickThrough']);
    expect(calls.first.arguments, {
      'id': WindowStateNotifier.clickThroughHotKeyId,
      'key': 'C',
      'modifiers': containsAll(['control', 'shift']),
    });

    calls.clear();
    await sendNativeEvent({
      'eventName': 'globalHotKeyPressed',
      'id': WindowStateNotifier.clickThroughHotKeyId,
    });
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.clickThrough, isFalse);
    expect(calls.map((call) => call.method),
        ['setClickThrough', 'unregisterGlobalHotKey']);
    expect(calls.first.arguments, {'enabled': false});
  });

  test('keeps click-through off when another app owns the shortcut', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'registerGlobalHotKey') {
        throw PlatformException(code: 'hot_key_unavailable');
      }
      return null;
    });

    final notifier = WindowStateNotifier();
    addTearDown(notifier.dispose);

    await notifier.toggleClickThrough();

    expect(notifier.state.clickThrough, isFalse);
    expect(notifier.state.globalClickThroughHotKeyRegistered, isFalse);
    expect(
      notifier.state.globalClickThroughHotKeyError,
      'hot_key_unavailable',
    );
    expect(calls.where((call) => call.method == 'setClickThrough'), isEmpty);
  });

  test('a failed capture exclusion cannot retry after a newer choice',
      () async {
    final failed = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return calls.length == 1 ? await failed.future : true;
    });

    final notifier = WindowStateNotifier();
    addTearDown(notifier.dispose);
    final enabling = notifier.setExcludeFromCapture(true);
    await notifier.setExcludeFromCapture(false);
    failed.complete(false);
    await enabling;
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(calls.map((call) => call.arguments), [
      {'enabled': true},
      {'enabled': false},
    ]);
  });

  test('the shield turns off again when Windows refuses capture exclusion',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return false;
    });

    final notifier = WindowStateNotifier();
    addTearDown(notifier.dispose);
    await notifier.setExcludeFromCapture(true);
    expect(notifier.state.excludeFromCapture, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(calls, hasLength(2));
    expect(notifier.state.excludeFromCapture, isFalse);
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
