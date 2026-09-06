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
  })  : _secureStore = secureStore ?? const FlutterSecureSettingsStore(),
        _settingsRepository =
            settingsRepository ?? SharedPreferencesSettingsRepository(),
        super(const SettingsModel()) {
    ready = _load();
  }

  final SecureSettingsStore _secureStore;
  final SettingsRepository _settingsRepository;
  late final Future<void> ready;
  Future<void> _updateQueue = Future<void>.value();
  String? _persistedObsPassword;

  Future<void> _load() async {
    var source = await _settingsRepository.read();
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
    final next = settings.appLanguageCode == state.appLanguageCode
        ? settings
        : _localizeBuiltInTtsDefaults(settings);
    state = next;
    final operation = _updateQueue.then((_) => _persist(next));
    _updateQueue = operation.catchError((Object error, StackTrace stack) {
      // Keep later writes flowing even if one persistence operation fails.
      AppLogger.warning(
        'Settings persistence failed',
        error: error,
        stackTrace: stack,
      );
    });
    return operation;
  }

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
