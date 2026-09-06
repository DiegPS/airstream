import 'dart:convert';

import 'package:airstream/settings/secure_settings_store.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_repository.dart';
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
    final document = jsonDecode(persisted) as Map<String, dynamic>;
    expect(document['schemaVersion'], currentSettingsSchemaVersion);
    expect(document['settings'], isNot(contains('obsPassword')));
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

  test('migrates old Spanish TTS defaults in an English configuration',
      () async {
    SharedPreferences.setMockInitialValues({
      'AIRSTREAM_SETTINGS': jsonEncode({
        'appLanguageCode': 'en',
        'ttsCommandPrefix': '!voz',
        'ttsSeparatorText': 'dice',
      }),
    });
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
    );

    await notifier.ready;

    expect(notifier.state.ttsCommandPrefix, '!v');
    expect(notifier.state.ttsSeparatorText, 'says');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('AIRSTREAM_SETTINGS'), contains('!v'));
    expect(prefs.getString('AIRSTREAM_SETTINGS'), contains('says'));
  });

  test('keeps !v and translates the separator when the app language changes',
      () async {
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
    );
    await notifier.ready;

    await notifier.update(notifier.state.copyWith(
      appLanguageCode: 'en',
      ttsCommandPrefix: '!v',
      ttsSeparatorText: 'says',
    ));
    await notifier.update(notifier.state.copyWith(appLanguageCode: 'es'));

    expect(notifier.state.ttsCommandPrefix, '!v');
    expect(notifier.state.ttsSeparatorText, 'dice');

    await notifier.update(notifier.state.copyWith(
      appLanguageCode: 'en',
      ttsCommandPrefix: '!custom',
      ttsSeparatorText: 'announces',
    ));
    expect(notifier.state.ttsCommandPrefix, '!custom');
    expect(notifier.state.ttsSeparatorText, 'announces');
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

  test('loads and persists through an injected settings repository', () async {
    final repository = _MemorySettingsRepository(
      jsonEncode({'appLanguageCode': 'es'}),
    );
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: repository,
    );

    await notifier.ready;
    expect(notifier.state.appLanguageCode, 'es');

    await notifier.update(notifier.state.copyWith(appLanguageCode: 'en'));

    final document = jsonDecode(repository.json!) as Map<String, dynamic>;
    expect(document['settings'], containsPair('appLanguageCode', 'en'));
  });

  test('recovers valid settings from backup when primary is corrupt', () async {
    final repository = _RecoverableMemorySettingsRepository(
      primary: '{broken',
      backup: SettingsDocumentCodec.encode(
        const SettingsModel(appLanguageCode: 'es'),
      ),
    );
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: repository,
    );

    await notifier.ready;

    expect(notifier.state.appLanguageCode, 'es');
    expect(
      SettingsDocumentCodec.decode(repository.primary!)
          .settings
          .appLanguageCode,
      'es',
    );
  });
}

class _RecoverableMemorySettingsRepository
    implements RecoverableSettingsRepository {
  _RecoverableMemorySettingsRepository({this.primary, this.backup});
  String? primary;
  String? backup;

  @override
  Future<String?> read() async => primary;

  @override
  Future<String?> readBackup() async => backup;

  @override
  Future<void> write(String json) async {
    backup = primary;
    primary = json;
  }
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository([this.json]);

  String? json;

  @override
  Future<String?> read() async => json;

  @override
  Future<void> write(String json) async {
    this.json = json;
  }
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
