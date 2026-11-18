import 'dart:async';

import 'package:air_window_control/air_window_control.dart';
import 'package:airstream/window/global_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.airchat/air_window_control';
  const channel = MethodChannel(channelName);
  const codec = StandardMethodCodec();
  final calls = <MethodCall>[];

  void mockPlatform({bool Function(MethodCall call)? register}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'registerGlobalHotKey') {
        return register?.call(call) ?? true;
      }
      return null;
    });
  }

  Future<void> press(String id) async {
    final response = Completer<ByteData?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channelName,
      codec.encodeMethodCall(MethodCall('onEvent', {
        'eventName': 'globalHotKeyPressed',
        'id': id,
      })),
      response.complete,
    );
    await response.future;
  }

  setUp(calls.clear);
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('shortcuts are saved as text and shown readably', () {
    const shortcut = GlobalShortcut(
      {AirHotKeyModifier.shift, AirHotKeyModifier.control},
      AirHotKey.keyS,
    );
    expect(shortcut.encode(), 'control+shift+S');
    expect(shortcut.label, 'Ctrl + Shift + S');
    expect(GlobalShortcut.parse('control+shift+S'), shortcut);
    expect(GlobalShortcut.parse('alt+F9')!.label, 'Alt + F9');
    expect(GlobalShortcut.parse(''), isNull);
    expect(GlobalShortcut.parse('control+Nope'), isNull);
  });

  test('a shortcut needs Ctrl, Alt or Win', () {
    expect(
      const GlobalShortcut({AirHotKeyModifier.shift}, AirHotKey.keyA).isAllowed,
      isFalse,
    );
    expect(const GlobalShortcut({}, AirHotKey.f9).isAllowed, isFalse);
    expect(
      const GlobalShortcut({AirHotKeyModifier.alt}, AirHotKey.f9).isAllowed,
      isTrue,
    );
  });

  test('reads a key press into a shortcut', () {
    final shortcut = GlobalShortcut.fromKeyEvent(
      LogicalKeyboardKey.keyM,
      {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.altRight},
    );
    expect(shortcut!.encode(), 'control+alt+M');
    expect(
      GlobalShortcut.fromKeyEvent(
        LogicalKeyboardKey.controlLeft,
        {LogicalKeyboardKey.controlLeft},
      ),
      isNull,
      reason: 'a modifier alone is not a shortcut yet',
    );
  });

  test('registers assigned shortcuts, replaces changed ones and runs them',
      () async {
    mockPlatform();
    final pressed = <GlobalShortcutAction>[];
    final shortcuts = GlobalShortcutsNotifier(onPressed: pressed.add);
    addTearDown(shortcuts.dispose);

    await shortcuts.apply({
      GlobalShortcutAction.silenceTts: 'control+alt+M',
      GlobalShortcutAction.toggleTts: '',
    });
    expect(calls.map((c) => c.method), ['registerGlobalHotKey']);
    expect(calls.single.arguments, {
      'id': 'shortcut-silenceTts',
      'key': 'M',
      'modifiers': ['control', 'alt'],
    });

    calls.clear();
    await shortcuts.apply({
      GlobalShortcutAction.silenceTts: 'control+alt+M',
      GlobalShortcutAction.toggleTts: '',
    });
    expect(calls, isEmpty, reason: 'nothing changed');

    await press('shortcut-silenceTts');
    expect(pressed, [GlobalShortcutAction.silenceTts]);

    await shortcuts.apply({
      GlobalShortcutAction.silenceTts: '',
      GlobalShortcutAction.toggleTts: 'alt+F9',
    });
    expect(calls.map((c) => c.method),
        ['unregisterGlobalHotKey', 'registerGlobalHotKey']);
  });

  test('releases both old bindings before registering swapped shortcuts',
      () async {
    final held = <String, Object>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = call.arguments as Map;
      final id = args['id'] as String;
      if (call.method == 'unregisterGlobalHotKey') {
        held.remove(id);
        return null;
      }
      final binding = (args['key'], (args['modifiers'] as List).join('+'));
      if (held.containsValue(binding)) return false;
      held[id] = binding;
      return true;
    });
    final shortcuts = GlobalShortcutsNotifier(onPressed: (_) {});
    addTearDown(shortcuts.dispose);
    await shortcuts.apply({
      GlobalShortcutAction.silenceTts: 'control+M',
      GlobalShortcutAction.toggleTts: 'alt+F9',
    });
    calls.clear();
    await shortcuts.apply({
      GlobalShortcutAction.silenceTts: 'alt+F9',
      GlobalShortcutAction.toggleTts: 'control+M',
    });
    expect(shortcuts.state, isEmpty);
    expect(held, {
      'shortcut-silenceTts': ('F9', 'alt'),
      'shortcut-toggleTts': ('M', 'control'),
    });
    expect(calls.map((call) => call.method), [
      'unregisterGlobalHotKey',
      'unregisterGlobalHotKey',
      'registerGlobalHotKey',
      'registerGlobalHotKey',
    ]);
  });

  test('reports a shortcut another app owns', () async {
    mockPlatform(register: (_) => throw PlatformException(code: 'in_use'));
    final shortcuts = GlobalShortcutsNotifier(onPressed: (_) {});
    addTearDown(shortcuts.dispose);

    await shortcuts.apply({GlobalShortcutAction.toggleTts: 'control+alt+T'});
    expect(shortcuts.state, {GlobalShortcutAction.toggleTts});

    mockPlatform();
    await shortcuts.apply({GlobalShortcutAction.toggleTts: ''});
    expect(shortcuts.state, isEmpty);
  });
}
