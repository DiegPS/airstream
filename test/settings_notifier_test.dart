import 'dart:async';
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

  test('subathon rules and state survive a settings save and reload', () async {
    final store = _MemorySecureSettingsStore();
    final first = SettingsNotifier(secureStore: store);
    await first.ready;
    final changed = first.state.copyWith(
        subathonPhase: 'running',
        subathonEndsAtMs: 123456789,
        subathonRemainingMs: 987,
        subathonSecondsPerSub: 7,
        subathonSecondsPer100Bits: 8,
        subathonSecondsPer100Kicks: 9,
        subathonStartMinutes: 10,
        subathonMaxRemainingMinutes: 11);
    await first.update(changed);
    final second = SettingsNotifier(secureStore: store);
    await second.ready;
    expect(second.state.toJson(), changed.toJson());
    first.dispose();
    second.dispose();
  });

  test('media library and alert references survive save and reload', () async {
    final store = _MemorySecureSettingsStore();
    final first = SettingsNotifier(secureStore: store);
    await first.ready;
    final changed = first.state.copyWith(mediaLibrary: {
      '1234567890abcdef': {
        'name': 'Picture.png',
        'kind': 'image',
        'ext': 'png',
        'bytes': 8,
        'addedAt': 1
      },
      'abcdef1234567890': {
        'name': 'Music.wav',
        'kind': 'audio',
        'ext': 'wav',
        'bytes': 12,
        'addedAt': 1
      },
    }, alertTypeOptions: {
      'raid': {
        'media': '1234567890abcdef',
        'mediaAudio': false,
        'sound': 'library',
        'soundMediaId': 'abcdef1234567890'
      }
    });
    await first.update(changed);
    final second = SettingsNotifier(secureStore: store);
    await second.ready;
    expect(second.state.mediaLibrary, changed.mediaLibrary);
    expect(second.state.alertTypeOptions, changed.alertTypeOptions);
    first.dispose();
    second.dispose();
  });

  test('goals survive a settings save and reload', () async {
    final store = _MemorySecureSettingsStore();
    final first = SettingsNotifier(secureStore: store);
    await first.ready;
    final goals = {
      'g': {'title': 'Support', 'type': 'subs', 'target': 100, 'current': 12}
    };
    await first.update(first.state.copyWith(goals: goals));
    final second = SettingsNotifier(secureStore: store);
    await second.ready;
    expect(second.state.goals, goals);
    first.dispose();
    second.dispose();
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

  test('a change made while settings load keeps every saved setting', () async {
    final saved = SettingsDocumentCodec.encode(const SettingsModel(
      twitchEnabled: true,
      twitchChannel: 'saved-channel',
      maxMessages: 321,
    ));
    final repository = _GatedSettingsRepository(saved);
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: repository,
    );

    // The UI shows defaults until loading finishes; the user edits one field.
    final pending = notifier.update(notifier.state.copyWith(fontSize: 20));
    repository.release();
    await pending;

    expect(notifier.state.fontSize, 20);
    expect(notifier.state.twitchChannel, 'saved-channel');
    expect(notifier.state.maxMessages, 321);
    final persisted = SettingsDocumentCodec.decode(repository.json!).settings;
    expect(persisted.fontSize, 20);
    expect(persisted.twitchChannel, 'saved-channel');
    expect(persisted.maxMessages, 321);
  });

  test('the first run follows the system language', () async {
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: _MemorySettingsRepository(),
      systemLanguageCode: () => 'es',
    );
    await notifier.ready;

    expect(notifier.state.appLanguageCode, 'es');
    expect(notifier.state.ttsLanguage, 'es');
    expect(notifier.state.ttsSeparatorText, 'dice');
  });

  test('saved settings keep their language whatever the system uses', () async {
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: _MemorySettingsRepository(
        SettingsDocumentCodec.encode(
          const SettingsModel(appLanguageCode: 'en'),
        ),
      ),
      systemLanguageCode: () => 'es',
    );
    await notifier.ready;

    expect(notifier.state.appLanguageCode, 'en');
  });

  test('an unsupported system language keeps English', () async {
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: _MemorySettingsRepository(),
      systemLanguageCode: () => 'fr',
    );
    await notifier.ready;

    expect(notifier.state.appLanguageCode, 'en');
  });

  test('a burst of changes only writes the latest settings', () async {
    final repository = _CountingSettingsRepository();
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: repository,
    );
    await notifier.ready;

    final writes = [
      for (var i = 0; i < 30; i++)
        notifier.update(notifier.state.copyWith(fontSize: 10.0 + i / 2)),
    ];
    await Future.wait(writes);

    expect(repository.writes, lessThanOrEqualTo(2));
    expect(
      SettingsDocumentCodec.decode(repository.json!).settings.fontSize,
      24.5,
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

/// A repository whose first read waits until [release] is called.
class _GatedSettingsRepository implements SettingsRepository {
  _GatedSettingsRepository(this.json);

  String? json;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<String?> read() async {
    await _gate.future;
    return json;
  }

  @override
  Future<void> write(String json) async {
    this.json = json;
  }
}

class _CountingSettingsRepository implements SettingsRepository {
  String? json;
  int writes = 0;

  @override
  Future<String?> read() async => json;

  @override
  Future<void> write(String json) async {
    writes++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    this.json = json;
  }
}
