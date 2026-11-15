import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/chat_screen.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/legacy_image_cache_cleaner.dart';
import 'package:airstream/window/window_bounds.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Decoded avatars and emotes stay in memory up to this size (Flutter's
  // default is 100 MB). Long streams meet thousands of distinct viewers, and
  // evicted images are read back from the disk cache.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;
  await AppLogger.initialize();
  await LegacyImageCacheCleaner.cleanupOnce();
  final defaultFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.error(
      'Unhandled Flutter framework error: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (defaultFlutterErrorHandler != null) {
      defaultFlutterErrorHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(
      'Unhandled asynchronous application error',
      error: error,
      stackTrace: stack,
    );
    return false;
  };
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      await windowManager.ensureInitialized();
      await Window
          .initialize(); // flutter_acrylic — debe ir después de windowManager
      await Window.setEffect(
        effect: WindowEffect.transparent,
        color: const Color(0x00000000),
        dark: true,
      );
      await windowManager.setResizable(true);
      // AirStream always uses its own Flutter title bar on desktop.
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      final bounds = WindowBoundsKeeper();
      await bounds.restore();
      bounds.startTracking();
    } catch (error, stack) {
      AppLogger.error(
        'Desktop window initialization failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  runApp(
    ProviderScope(
      child: Platform.isWindows
          ? const ExcludeSemantics(child: AirstreamApp())
          : const AirstreamApp(),
    ),
  );
}

/// Built once: a theme rebuilt on every frame compares unequal (its switch
/// colors are closures), which rebuilds every Material widget in the app.
final _airstreamTheme = ThemeData(
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF53FC18),
    surface: Color(0xFF121212),
  ),
  scaffoldBackgroundColor: const Color(0xFF0D0D0D),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? null
          : states.contains(WidgetState.disabled)
              ? const Color(0xFF3A3A3A)
              : const Color(0xFF9A9A9A),
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? null
          : const Color(0xFF1E1E1E),
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? null
          : states.contains(WidgetState.disabled)
              ? const Color(0xFF2A2A2A)
              : const Color(0xFF4A4A4A),
    ),
  ),
  useMaterial3: true,
);

class AirstreamApp extends ConsumerWidget {
  const AirstreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the language matters here; other settings must not rebuild the
    // whole app.
    final languageCode =
        ref.watch(settingsProvider.select((s) => s.appLanguageCode));

    return MaterialApp(
      title: 'Airstream',
      debugShowCheckedModeBanner: false,
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: _airstreamTheme,
      home: const ChatScreen(),
    );
  }
}
