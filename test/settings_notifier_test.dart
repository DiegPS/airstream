import 'dart:convert';

import 'package:airstream/settings/secure_settings_store.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('migrates the legacy OBS password and removes its plaintext copy',
      () async {
    SharedPreferences.setMockInitialValues({
      'AIRSTREAM_SETTINGS': jsonEncode({
        'obsHost': 'studio.local:4455',
        'obsPassword': 'legacy-secret',
      }),
    });
    final secureStore = _MemorySecureSettingsStore();
    final notifier = SettingsNotifier(secureStore: secureStore);

    await notifier.ready;

    expect(notifier.state.obsPassword, 'legacy-secret');
    expect(secureStore.password, 'legacy-secret');
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString('AIRSTREAM_SETTINGS')!;
    expect(persisted, isNot(contains('legacy-secret')));
    expect(jsonDecode(persisted), isNot(contains('obsPassword')));
  });

  test('secure storage wins over a stale legacy password', () async {
    SharedPreferences.setMockInitialValues({
      'AIRSTREAM_SETTINGS': jsonEncode({
        'obsPassword': 'stale-secret',
      }),
    });
    final secureStore = _MemorySecureSettingsStore('secure-secret');
    final notifier = SettingsNotifier(secureStore: secureStore);

    await notifier.ready;

    expect(notifier.state.obsPassword, 'secure-secret');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('AIRSTREAM_SETTINGS'),
      isNot(contains('stale-secret')),
    );
  });

  test('updates and deletes the OBS password through secure storage', () async {
    final secureStore = _MemorySecureSettingsStore();
    final notifier = SettingsNotifier(secureStore: secureStore);
    await notifier.ready;

    await notifier.update(
      notifier.state.copyWith(obsPassword: 'new-secret'),
    );
    expect(secureStore.password, 'new-secret');

    await notifier.update(notifier.state.copyWith(obsPassword: ''));
    expect(secureStore.password, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('AIRSTREAM_SETTINGS'),
      isNot(contains('new-secret')),
    );
  });

  test('updates state immediately while persistence remains asynchronous',
      () async {
    final secureStore = _MemorySecureSettingsStore()
      ..writeDelay = const Duration(milliseconds: 30);
    final notifier = SettingsNotifier(secureStore: secureStore);
    await notifier.ready;

    final persistence = notifier.update(
      notifier.state.copyWith(obsPassword: 'immediate-secret'),
    );

    expect(notifier.state.obsPassword, 'immediate-secret');
    expect(secureStore.password, isNull);
    await persistence;
    expect(secureStore.password, 'immediate-secret');
  });

  test('does not erase legacy data when secure migration fails', () async {
    SharedPreferences.setMockInitialValues({
      'AIRSTREAM_SETTINGS': jsonEncode({
        'obsPassword': 'recoverable-secret',
      }),
    });
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore()..failWrites = true,
    );

    await notifier.ready;

    expect(notifier.state.obsPassword, 'recoverable-secret');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('AIRSTREAM_SETTINGS'),
      contains('recoverable-secret'),
    );
  });
}

class _MemorySecureSettingsStore implements SecureSettingsStore {
  _MemorySecureSettingsStore([this.password]);

  String? password;
  bool failWrites = false;
  Duration writeDelay = Duration.zero;

  @override
  Future<void> deleteObsPassword() async {
    password = null;
  }

  @override
  Future<String?> readObsPassword() async => password;

  @override
  Future<void> writeObsPassword(String password) async {
    if (writeDelay > Duration.zero) {
      await Future<void>.delayed(writeDelay);
    }
    if (failWrites) {
      throw StateError('Secure storage unavailable');
    }
    this.password = password;
  }
}
