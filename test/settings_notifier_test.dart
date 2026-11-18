import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/app_logger.dart';

import 'package:airstream/settings/secure_settings_store.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'chat_queue_test.dart' show queueMessage;
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

  test('queue options and live state reload, but portable exports omit state',
      () async {
    final store = _MemorySecureSettingsStore();
    final first =
        SettingsNotifier(secureStore: store, systemLanguageCode: () => 'es');
    await first.ready;
    expect(first.state.queueOptions.command, '!unirme');
    final english =
        SettingsNotifier(secureStore: store, systemLanguageCode: () => 'en');
    await english.ready;
    expect(english.state.queueOptions.command, '!join');
    english.dispose();

    const options = QueueOptions(
      command: '!turno',
      max: 30,
      role: QueueRole.member,
      nextCount: 2,
      priority: true,
      rejoin: false,
      moderatorCommands: true,
    );
    final queue = ChatQueueController()
      ..configure(options, 'es')
      ..setStatus(QueueStatus.open)
      ..handleMessage(queueMessage('Former', '!turno', member: true))
      ..handleMessage(queueMessage('Current', '!turno note', member: true))
      ..handleMessage(queueMessage('Waiting', '!turno other', member: true));
    final picked = queue.next(2);
    queue.done(picked.first.id);
    queue.setStatus(QueueStatus.paused);
    await first.update(first.state.copyWith(queueOptions: options));
    await first.saveQueueState(queue.current);
    final state = first.state;
    final second = SettingsNotifier(secureStore: store);
    await second.ready;
    expect(second.state.queueOptions.toJson(), options.toJson());
    expect(second.state.queueState.toJson(), state.queueState.toJson());

    final profile = SettingsProfiles.capture(second.state);
    expect(profile, isNot(contains('queueState')));
    expect(profile['queueOptions'], options.toJson());
    final file = SettingsProfiles.export(second.state);
    final payload = jsonDecode(file)['settings'] as Map;
    expect(payload, isNot(contains('queueState')));
    expect(payload['queueOptions'], options.toJson());
    final imported = SettingsProfiles.import(file, state);
    expect(imported.queueState, same(state.queueState));
    expect(
        SettingsProfiles.apply(state, {'queueState': {}}).queueState.toJson(),
        state.queueState.toJson());

    queue.clear();
    queue.restore(second.state.queueState);
    queue.setStatus(QueueStatus.open);
    queue.handleMessage(queueMessage('Former', '!turno', member: true));
    expect(queue.current.entries.single.name, 'Waiting');
    await queue.dispose();
    first.dispose();
    second.dispose();
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

  test('OBS password reads retry on each explicit edit until storage recovers',
      () async {
    final secure = _MemorySecureSettingsStore('original')..failReads = true;
    final notifier = SettingsNotifier(
      secureStore: secure,
      settingsRepository: _MemorySettingsRepository('{}'),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.update(notifier.state.copyWith(fontSize: 24));
    expect(secure.password, 'original');
    await notifier.update(notifier.state.copyWith(obsPassword: 'replacement'));
    expect(secure.password, 'original');
    await notifier.update(notifier.state.copyWith(obsPassword: 'second'));
    expect(secure.reads, 3);
    expect(secure.password, 'original');

    secure.failReads = false;
    await notifier.update(notifier.state.copyWith(obsPassword: 'final'));
    expect(secure.reads, 4);
    expect(secure.password, 'final');
    await notifier.update(notifier.state.copyWith(obsPassword: 'later'));
    expect(secure.reads, 4);
    expect(secure.password, 'later');
  });

  test('an unrelated save retries a password edit after a secure read fails',
      () async {
    final secure = _MemorySecureSettingsStore('original')..failReads = true;
    final repository = _MemorySettingsRepository('{}');
    final notifier =
        SettingsNotifier(secureStore: secure, settingsRepository: repository);
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.update(notifier.state.copyWith(obsPassword: 'replacement'));
    expect(notifier.state.obsPassword, 'replacement');
    expect(notifier.obsPasswordNotSaved.value, isTrue);
    expect(secure.password, 'original');
    expect(secure.reads, 2);

    secure.failReads = false;
    await notifier.update(notifier.state.copyWith(fontSize: 24));
    expect(secure.reads, 3);
    expect(notifier.obsPasswordNotSaved.value, isFalse);
    expect(secure.password, 'replacement');
    expect(notifier.state.obsPassword, 'replacement');
  });

  test('failed credential writes keep the edited password and retry on save',
      () async {
    final secure = _MemorySecureSettingsStore('original')..failWrites = true;
    final notifier = SettingsNotifier(
      secureStore: secure,
      settingsRepository: _MemorySettingsRepository('{}'),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.update(notifier.state.copyWith(obsPassword: 'new'));
    expect(notifier.obsPasswordNotSaved.value, isTrue);
    expect(notifier.state.obsPassword, 'new');
    expect(secure.password, 'original');
    secure.failWrites = false;
    await notifier.update(notifier.state.copyWith(fontSize: 22));
    expect(secure.password, 'new');
    expect(notifier.obsPasswordNotSaved.value, isFalse);
  });

  test('Retry saves the latest pending OBS credential without a settings edit',
      () async {
    final secure = _MemorySecureSettingsStore('original')..failWrites = true;
    final repository = _MemorySettingsRepository('{}');
    final notifier =
        SettingsNotifier(secureStore: secure, settingsRepository: repository);
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.update(notifier.state.copyWith(obsPassword: 'first'));
    final update = notifier
        .update(notifier.state.copyWith(obsPassword: 'latest', fontSize: 23));
    final retry = notifier.retryObsPassword();
    await Future.wait([update, retry]);
    expect(notifier.obsPasswordNotSaved.value, isTrue);
    expect(secure.password, 'original');
    expect(
        SettingsDocumentCodec.decode(repository.json!).settings.fontSize, 23);
    expect(repository.json, isNot(contains('latest')));

    secure.failWrites = false;
    await notifier.retryObsPassword();
    expect(secure.password, 'latest');
    expect(notifier.obsPasswordNotSaved.value, isFalse);
  });

  test('first-run settings only look up an OBS credential on a password edit',
      () async {
    final secure = _MemorySecureSettingsStore('original')..failReads = true;
    final notifier = SettingsNotifier(
      secureStore: secure,
      settingsRepository: _MemorySettingsRepository(),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.update(notifier.state.copyWith(fontSize: 24));
    expect(secure.reads, 0);
    await notifier.update(notifier.state.copyWith(obsPassword: 'replacement'));
    expect(secure.reads, 1);
    expect(secure.password, 'original');
  });

  test('a malformed settings import logs only the offset', () async {
    final directory = await Directory.systemTemp.createTemp('invalid-import-');
    addTearDown(() => directory.delete(recursive: true));
    await AppLogger.initialize(directory: directory);
    final notifier = SettingsNotifier(
      secureStore: _MemorySecureSettingsStore(),
      settingsRepository: _MemorySettingsRepository('{}'),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;

    const source = '{"note":"private-source","obsPassword":"truncated password';
    final offset = () {
      try {
        jsonDecode(source);
      } on FormatException catch (error) {
        return error.offset;
      }
      fail('Expected malformed JSON');
    }();
    await expectLater(notifier.importSettings(source), throwsFormatException);
    await AppLogger.flush();
    final log = await File(
      '${directory.path}${Platform.pathSeparator}airstream.log',
    ).readAsLines();
    expect(log.last, endsWith('WARN Settings import failed (offset $offset)'));
    expect(log.join('\n'), isNot(contains('private-source')));
    expect(log.join('\n'), isNot(contains('truncated password')));
  });

  test('invalid settings log the offset without source, including on recovery',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('invalid-settings-log-');
    addTearDown(() => directory.delete(recursive: true));
    await AppLogger.initialize(directory: directory);
    const source =
        '{"note":"https://local.invalid/private-source", "bad": NOT_SETTINGS}';
    for (final backup in [null, '{"fontSize":27}']) {
      final notifier = SettingsNotifier(
        secureStore: _MemorySecureSettingsStore(),
        settingsRepository: _RecoverableMemorySettingsRepository(
            primary: source, backup: backup),
      );
      addTearDown(notifier.dispose);
      await notifier.ready;
      if (backup != null) expect(notifier.state.fontSize, 27);
    }
    await AppLogger.flush();
    final log =
        await File('${directory.path}${Platform.pathSeparator}airstream.log')
            .readAsString();
    expect(
        log,
        contains(
            'Persisted settings are invalid; using safe defaults (offset '));
    expect(
        log,
        contains(
            'Primary settings are invalid; recovering the backup (offset '));
    expect(log, isNot(contains('private-source')));
    expect(log, isNot(contains('NOT_SETTINGS')));
    expect(log, isNot(contains('FormatException')));
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
    final secure = _MemorySecureSettingsStore()..failWrites = true;
    final notifier = SettingsNotifier(secureStore: secure);
    addTearDown(notifier.dispose);

    await notifier.ready;

    expect(notifier.state.obsPassword, 'recoverable-secret');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('AIRSTREAM_SETTINGS'),
      contains('recoverable-secret'),
    );
    await notifier.update(notifier.state.copyWith(fontSize: 22));
    expect(notifier.obsPasswordNotSaved.value, isTrue);
    expect(
        prefs.getString('AIRSTREAM_SETTINGS'), contains('recoverable-secret'));
    secure.failWrites = false;
    await notifier.update(notifier.state.copyWith(fontSize: 23));
    expect(secure.password, 'recoverable-secret');
    expect(prefs.getString('AIRSTREAM_SETTINGS'),
        isNot(contains('recoverable-secret')));
    expect(prefs.getString('AIRSTREAM_SETTINGS_BACKUP'), isNull);
  });

  test('an unrelated save preserves a legacy credential after a read failure',
      () async {
    final repository = _MemorySettingsRepository('{"obsPassword":"legacy"}');
    final secure = _MemorySecureSettingsStore()..failReads = true;
    final notifier =
        SettingsNotifier(settingsRepository: repository, secureStore: secure);
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.update(notifier.state.copyWith(fontSize: 22));
    expect(await repository.read(), contains('legacy'));
    expect(secure.reads, 1);
  });

  test('a failed startup rewrite still allows later settings to persist',
      () async {
    final repository = _MemorySettingsRepository('{"fontSize":21}')
      ..failWrites = true;
    final notifier = SettingsNotifier(
      settingsRepository: repository,
      secureStore: _MemorySecureSettingsStore('stored'),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    expect(notifier.state.fontSize, 21);
    expect(notifier.state.obsPassword, 'stored');
    repository.failWrites = false;
    await notifier.update(notifier.state.copyWith(fontSize: 22));
    expect(
        SettingsDocumentCodec.decode(repository.json!).settings.fontSize, 22);
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
  bool failWrites = false;

  @override
  Future<String?> read() async => json;

  @override
  Future<void> write(String json) async {
    if (failWrites) throw StateError('Settings repository unavailable');
    this.json = json;
  }
}

class _MemorySecureSettingsStore implements SecureSettingsStore {
  _MemorySecureSettingsStore([this.password]);

  String? password;
  bool failWrites = false;
  bool failReads = false;
  int reads = 0;
  Duration writeDelay = Duration.zero;

  @override
  Future<void> deleteObsPassword() async {
    password = null;
  }

  @override
  Future<String?> readObsPassword() async {
    reads++;
    if (failReads) throw StateError('Secure storage unavailable');
    return password;
  }

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
