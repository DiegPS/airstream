import 'package:airstream/application/rules/rules_webhook.dart';
import 'package:airstream/application/chat_queue.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:airstream/services/app_logger.dart';
import 'package:airstream/settings/media_library_entries.dart';
import 'package:airstream/settings/secure_settings_store.dart';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:airstream/settings/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── providers ────────────────────────────────────────────────────────────────

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsModel>(
  (ref) => SettingsNotifier(),
);

/// Completes only after persisted settings and secure values have loaded.
/// Service providers use this as a side-effect barrier during app startup.
final settingsInitializationProvider = FutureProvider<void>((ref) async {
  try {
    await ref.watch(settingsProvider.notifier).ready;
  } catch (error, stack) {
    AppLogger.error(
      'Settings initialization failed; using safe defaults',
      error: error,
      stackTrace: stack,
    );
  }
});

// ── SettingsNotifier ─────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<SettingsModel> {
  SettingsNotifier({
    SecureSettingsStore? secureStore,
    SettingsRepository? settingsRepository,
    String Function()? systemLanguageCode,
  })  : _systemLanguageCode = systemLanguageCode ??
            (() => PlatformDispatcher.instance.locale.languageCode),
        _secureStore = secureStore ?? const FlutterSecureSettingsStore(),
        _settingsRepository =
            settingsRepository ?? SharedPreferencesSettingsRepository(),
        super(const SettingsModel()) {
    ready = _load();
  }

  final String Function() _systemLanguageCode;
  final SecureSettingsStore _secureStore;
  final SettingsRepository _settingsRepository;
  late final Future<void> ready;
  bool _loaded = false;
  Future<void> _updateQueue = Future<void>.value();
  Future<void>? _restoreInProgress;
  // Null means secure storage could not be read. An empty string means
  // secure storage was read successfully and had no saved password.
  String? _persistedObsPassword;
  bool _readObsPasswordOnEdit = false;
  String? _unmigratedObsPassword;
  String? _obsPasswordToRetry;
  final _obsPasswordNotSaved = ValueNotifier(false);
  ValueListenable<bool> get obsPasswordNotSaved => _obsPasswordNotSaved;

  @override
  void dispose() {
    _obsPasswordNotSaved.dispose();
    super.dispose();
  }

  bool _publishingRestore = false;
  bool get publishingRestore => _publishingRestore;

  Future<void> _load() async {
    try {
      await _loadPersisted();
    } finally {
      _loaded = true;
    }
  }

  Future<void> _loadPersisted() async {
    final source = await _settingsRepository.read();
    if (!mounted) return;
    if (source == null) {
      // First run: speak the language Windows uses, when Airstream has it.
      final language = _systemLanguageCode();
      if (_supportedLanguages.contains(language)) {
        state = _localizeBuiltInDefaults(
          state.copyWith(appLanguageCode: language, ttsLanguage: language),
        );
      }
    }
    DecodedSettingsDocument? document;
    var recoveredFromBackup = false;
    if (source != null) {
      try {
        try {
          document = SettingsDocumentCodec.decode(source);
        } catch (error) {
          final repository = _settingsRepository;
          final backup = repository is RecoverableSettingsRepository
              ? await repository.readBackup()
              : null;
          if (backup == null || backup == source) rethrow;
          AppLogger.warning(_settingsDecodeMessage(
              'Primary settings are invalid; recovering the backup', error));
          document = SettingsDocumentCodec.decode(backup);
          recoveredFromBackup = true;
        }
      } catch (error) {
        AppLogger.error(_settingsDecodeMessage(
            'Persisted settings are invalid; using safe defaults', error));
      }
    }

    if (!mounted) return;
    if (document == null) {
      // Keep first-run initialization independent of the secure store. An
      // explicit password edit still checks the store before touching it.
      _readObsPasswordOnEdit = true;
      return;
    }
    final decoded = document.settings;
    final loaded = _localizeBuiltInDefaults(decoded);
    state = loaded;
    if (document.containsLegacyPassword && loaded.obsPassword.isNotEmpty) {
      _unmigratedObsPassword = loaded.obsPassword;
    }
    try {
      var password = await _secureStore.readObsPassword();
      _persistedObsPassword = password ?? '';
      if (password == null && loaded.obsPassword.isNotEmpty) {
        await _writeObsPassword(loaded.obsPassword);
        password = loaded.obsPassword;
      }
      _unmigratedObsPassword = null;
      if (!mounted) return;
      state = loaded.copyWith(obsPassword: password ?? '');
    } catch (error, stack) {
      // A future launch can retry a failed read or legacy migration, and an
      // explicit password edit in this session reads the store again first.
      _readObsPasswordOnEdit = _persistedObsPassword == null;
      if (mounted && _obsPasswordToRetry != null) {
        _obsPasswordNotSaved.value = true;
      }
      AppLogger.warning(
        'Could not load or migrate secure settings',
        error: error,
        stackTrace: stack,
      );
      return;
    }

    if (document.containsLegacyPassword ||
        document.requiresRewrite ||
        recoveredFromBackup ||
        loaded.ttsCommandPrefix != decoded.ttsCommandPrefix ||
        loaded.ttsSeparatorText != decoded.ttsSeparatorText) {
      try {
        await _settingsRepository.write(SettingsDocumentCodec.encode(state));
      } catch (error, stack) {
        AppLogger.warning('Could not rewrite persisted settings',
            error: error, stackTrace: stack);
      }
    }
  }

  static String _settingsDecodeMessage(String message, Object error) {
    final offset = error is FormatException ? error.offset : null;
    return offset == null ? message : '$message (offset $offset)';
  }

  /// Evaluates a change against the current settings once they are writable.
  Future<void> updateLatest(SettingsModel Function(SettingsModel) change) {
    if (!mounted) return Future<void>.value();
    final restore = _restoreInProgress;
    if (restore != null) return restore.then((_) => updateLatest(change));
    if (!_loaded) return ready.then((_) => updateLatest(change));
    final next = change(state);
    return identical(next, state) ? Future<void>.value() : update(next);
  }

  Future<void> update(SettingsModel settings) {
    final restore = _restoreInProgress;
    if (restore != null) {
      final base = state;
      return restore.then((_) => update(_rebase(base, settings, state)));
    }
    if (!_loaded) {
      // The change was made on top of the defaults shown while loading.
      // Persisting it as-is would overwrite every saved setting, so replay
      // only what changed on top of the loaded settings.
      final base = state;
      return ready.then((_) => update(_rebase(base, settings, state)));
    }
    settings = enableRulesWebhook(settings, settings.rulesWebhookEnabled);
    final next = settings.appLanguageCode == state.appLanguageCode
        ? settings
        : _localizeBuiltInDefaults(settings);
    return _publishAndPersist(next);
  }

  Future<void> _publishAndPersist(SettingsModel next) {
    final passwordChanged =
        (_persistedObsPassword != null || _readObsPasswordOnEdit) &&
            next.obsPassword != state.obsPassword;
    state = next;
    // Only the latest settings need to reach the disk: a slider produces a
    // change per frame, and writing each one would queue dozens of writes.
    final previousPending = _pendingPersist;
    final pending = _PendingPersist(next,
        passwordChanged ? next.obsPassword : previousPending?.obsPassword);
    _pendingPersist = pending;
    previousPending?.supersededBy(pending);
    final writeAfter = _updateQueue;
    _updateQueue = writeAfter.then((_) async {
      if (!identical(_pendingPersist, pending)) return;
      _pendingPersist = null;
      try {
        await _persist(pending.settings, pending.obsPassword);
        pending.complete();
      } catch (error, stack) {
        // Keep later writes flowing even if one persistence operation fails.
        AppLogger.warning(
          'Settings persistence failed',
          error: error,
          stackTrace: stack,
        );
        pending.fail(error, stack);
      }
    });
    return pending.future;
  }

  Future<void> saveQueueState(QueueState queue) async {
    if (!_loaded) await ready;
    final restore = _restoreInProgress;
    if (restore != null) await restore;
    if (mounted) await _publishAndPersist(state.copyWith(queueState: queue));
  }

  Future<void> renameMedia(String id, String input) async {
    await ready;
    final restore = _restoreInProgress;
    if (restore != null) await restore;
    final name = MediaLibraryEntries.displayName(input);
    if (name == null) throw const FormatException('name');
    final entry = state.mediaLibrary[id];
    if (entry == null) throw StateError('Media entry no longer exists.');
    await update(state.copyWith(mediaLibrary: {
      ...state.mediaLibrary,
      id: {...entry, 'name': name},
    }));
  }

  Future<void> importSettings(String source, {Directory? mediaDirectory}) =>
      restoreBackup((current, commit) {
        final SettingsModel imported;
        try {
          imported = SettingsProfiles.import(source, current,
              mediaDirectory: mediaDirectory);
        } on FormatException catch (error) {
          AppLogger.warning(
              _settingsDecodeMessage('Settings import failed', error));
          rethrow;
        }
        var next = imported;
        next = enableRulesWebhook(next, next.rulesWebhookEnabled);
        if (current.appLanguageCode != next.appLanguageCode) {
          next = _localizeBuiltInDefaults(next);
        }
        return commit(next);
      });

  /// Holds settings updates until the restore commits or rolls back. The
  /// caller commits only after it has staged and installed the file areas.
  Future<void> restoreBackup(
    Future<void> Function(
      SettingsModel current,
      Future<void> Function(SettingsModel) commit,
    ) restore,
  ) async {
    await ready;
    if (_restoreInProgress != null) {
      throw StateError('A backup restore is already in progress.');
    }
    final finished = Completer<void>();
    _restoreInProgress = finished.future;
    try {
      await _updateQueue;
      await restore(state, (next) async {
        // The backup leaves secure storage and the local webhook opt-in alone.
        await _writeSettings(next);
        if (mounted) {
          _publishingRestore = true;
          try {
            state = next;
          } catch (error, stack) {
            // Listener failures cannot undo a committed settings write.
            AppLogger.warning('Could not notify a listener after restore',
                error: error, stackTrace: stack);
          } finally {
            _publishingRestore = false;
          }
        }
      });
    } finally {
      _restoreInProgress = null;
      finished.complete();
    }
  }

  _PendingPersist? _pendingPersist;

  Future<void> _persist(SettingsModel settings, String? obsPassword) async {
    await ready;
    if (obsPassword != null) _obsPasswordToRetry = obsPassword;
    await _savePendingObsPassword();
    await _writeSettings(settings);
  }

  Future<void> retryObsPassword() {
    final restore = _restoreInProgress;
    if (restore != null) return restore.then((_) => retryObsPassword());
    return _updateQueue = _updateQueue.then((_) async {
      final hadLegacyPassword = _unmigratedObsPassword != null;
      await _savePendingObsPassword();
      if (mounted && hadLegacyPassword && _unmigratedObsPassword == null) {
        try {
          await _writeSettings(state);
        } catch (error, stack) {
          AppLogger.warning('Could not remove the legacy OBS credential',
              error: error, stackTrace: stack);
        }
      }
    });
  }

  Future<void> _savePendingObsPassword() async {
    final password = _obsPasswordToRetry;
    if (password == null) return;
    try {
      if (_readObsPasswordOnEdit) {
        _persistedObsPassword = await _secureStore.readObsPassword() ?? '';
        _readObsPasswordOnEdit = false;
      }
      if (password != _persistedObsPassword) {
        await _writeObsPassword(password);
      }
      _obsPasswordToRetry = null;
      _unmigratedObsPassword = null;
    } catch (error, stack) {
      AppLogger.warning('Could not save the OBS credential',
          error: error, stackTrace: stack);
    }
    if (mounted) _obsPasswordNotSaved.value = _obsPasswordToRetry != null;
  }

  Future<void> _writeObsPassword(String password) async {
    _obsPasswordToRetry = password;
    if (password.isEmpty) {
      await _secureStore.deleteObsPassword();
    } else {
      await _secureStore.writeObsPassword(password);
    }
    _persistedObsPassword = password;
    _obsPasswordToRetry = null;
  }

  Future<void> _writeSettings(SettingsModel settings) =>
      _settingsRepository.write(SettingsDocumentCodec.encode(settings,
          unmigratedObsPassword: _unmigratedObsPassword));

  /// Applies the fields that differ between [base] and [edited] to [target].
  static SettingsModel _rebase(
    SettingsModel base,
    SettingsModel edited,
    SettingsModel target,
  ) {
    final baseJson = base.toJson();
    final editedJson = edited.toJson();
    final merged = Map<String, dynamic>.from(target.toJson());
    for (final entry in editedJson.entries) {
      if (jsonEncode(entry.value) != jsonEncode(baseJson[entry.key])) {
        merged[entry.key] = entry.value;
      }
    }
    return SettingsModel.fromJson(merged).copyWith(
      obsPassword: edited.obsPassword != base.obsPassword
          ? edited.obsPassword
          : target.obsPassword,
    );
  }

  static const _supportedLanguages = {'en', 'es'};

  static SettingsModel _localizeBuiltInDefaults(SettingsModel settings) {
    final spanish = settings.appLanguageCode == 'es';
    final prefix = settings.ttsCommandPrefix.trim();
    final separator = settings.ttsSeparatorText.trim();
    final localizedPrefix =
        prefix.isEmpty || prefix == '!voz' || prefix == '!voice'
            ? '!v'
            : settings.ttsCommandPrefix;
    final localizedSeparator =
        separator.isEmpty || separator == 'dice' || separator == 'says'
            ? (spanish ? 'dice' : 'says')
            : settings.ttsSeparatorText;
    return settings.copyWith(
      queueOptions: settings.queueOptions.copyWith(
          command: settings.queueOptions.commandFor(settings.appLanguageCode)),
      ttsCommandPrefix: localizedPrefix,
      ttsSeparatorText: localizedSeparator,
    );
  }
}

/// A settings write waiting its turn. When a newer change replaces it, it
/// completes with the newer write, which also stores this change.
class _PendingPersist {
  _PendingPersist(this.settings, this.obsPassword);

  final SettingsModel settings;
  final String? obsPassword;
  final _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void supersededBy(_PendingPersist newer) {
    newer.future.then(
      (_) => complete(),
      onError: (Object error, StackTrace stack) => fail(error, stack),
    );
  }

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void fail(Object error, StackTrace stack) {
    if (!_completer.isCompleted) _completer.completeError(error, stack);
  }
}
