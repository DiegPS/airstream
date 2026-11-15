import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:airstream/services/app_logger.dart';
import 'package:airstream/settings/secure_settings_store.dart';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_repository.dart';
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
  String? _persistedObsPassword;

  Future<void> _load() async {
    try {
      await _loadPersisted();
    } finally {
      _loaded = true;
    }
  }

  Future<void> _loadPersisted() async {
    var source = await _settingsRepository.read();
    if (source == null) {
      // First run: speak the language Windows uses, when Airstream has it.
      final language = _systemLanguageCode();
      if (_supportedLanguages.contains(language)) {
        state = _localizeBuiltInTtsDefaults(
          state.copyWith(appLanguageCode: language, ttsLanguage: language),
        );
      }
    }
    if (source != null) {
      try {
        DecodedSettingsDocument document;
        var recoveredFromBackup = false;
        try {
          document = SettingsDocumentCodec.decode(source);
        } catch (primaryError, primaryStack) {
          final repository = _settingsRepository;
          final backup = repository is RecoverableSettingsRepository
              ? await repository.readBackup()
              : null;
          if (backup == null || backup == source) rethrow;
          AppLogger.warning(
            'Primary settings are invalid; recovering the backup',
            error: primaryError,
            stackTrace: primaryStack,
          );
          source = backup;
          document = SettingsDocumentCodec.decode(backup);
          recoveredFromBackup = true;
        }
        final decodedSettings = document.settings;
        final loaded = _localizeBuiltInTtsDefaults(decodedSettings);
        final localizedDefaultsChanged =
            loaded.ttsCommandPrefix != decodedSettings.ttsCommandPrefix ||
                loaded.ttsSeparatorText != decodedSettings.ttsSeparatorText;
        state = loaded;

        try {
          var password = await _secureStore.readObsPassword();
          if (password == null && loaded.obsPassword.isNotEmpty) {
            await _secureStore.writeObsPassword(loaded.obsPassword);
            password = loaded.obsPassword;
          }
          _persistedObsPassword = password ?? '';
          state = loaded.copyWith(obsPassword: password ?? '');

          if (document.containsLegacyPassword ||
              document.requiresRewrite ||
              recoveredFromBackup ||
              localizedDefaultsChanged) {
            await _settingsRepository
                .write(SettingsDocumentCodec.encode(state));
          }
        } catch (error, stack) {
          // Keep the legacy value and its persisted copy if secure storage is
          // temporarily unavailable. A future launch can retry the migration.
          AppLogger.warning(
            'Secure settings unavailable; preserving recoverable settings',
            error: error,
            stackTrace: stack,
          );
          state = loaded;
        }
      } catch (error, stack) {
        AppLogger.error(
          'Persisted settings are invalid; using safe defaults',
          error: error,
          stackTrace: stack,
        );
      }
    }
  }

  Future<void> update(SettingsModel settings) {
    if (!_loaded) {
      // The change was made on top of the defaults shown while loading.
      // Persisting it as-is would overwrite every saved setting, so replay
      // only what changed on top of the loaded settings.
      final base = state;
      return ready.then((_) => update(_rebase(base, settings, state)));
    }
    final next = settings.appLanguageCode == state.appLanguageCode
        ? settings
        : _localizeBuiltInTtsDefaults(settings);
    state = next;
    // Only the latest settings need to reach the disk: a slider produces a
    // change per frame, and writing each one would queue dozens of writes.
    final previousPending = _pendingPersist;
    final pending = _PendingPersist(next);
    _pendingPersist = pending;
    previousPending?.supersededBy(pending);
    final writeAfter = _updateQueue;
    _updateQueue = writeAfter.then((_) async {
      if (!identical(_pendingPersist, pending)) return;
      _pendingPersist = null;
      try {
        await _persist(pending.settings);
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

  _PendingPersist? _pendingPersist;

  Future<void> _persist(SettingsModel settings) async {
    await ready;
    if (settings.obsPassword != _persistedObsPassword) {
      if (settings.obsPassword.isEmpty) {
        await _secureStore.deleteObsPassword();
      } else {
        await _secureStore.writeObsPassword(settings.obsPassword);
      }
      _persistedObsPassword = settings.obsPassword;
    }
    await _settingsRepository.write(SettingsDocumentCodec.encode(settings));
  }

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

  static SettingsModel _localizeBuiltInTtsDefaults(SettingsModel settings) {
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
      ttsCommandPrefix: localizedPrefix,
      ttsSeparatorText: localizedSeparator,
    );
  }
}

/// A settings write waiting its turn. When a newer change replaces it, it
/// completes with the newer write, which also stores this change.
class _PendingPersist {
  _PendingPersist(this.settings);

  final SettingsModel settings;
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
