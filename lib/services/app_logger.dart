import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_sanitizer.dart';
import 'rotating_log_writer.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger(
    level: kDebugMode ? Level.debug : Level.warning,
    printer: SimplePrinter(colors: false, printTime: true),
  );

  static RotatingLogWriter? _fileWriter;

  static Future<void> initialize({Directory? directory}) async {
    try {
      final target = directory ??
          Directory(
              p.join((await getApplicationSupportDirectory()).path, 'logs'));
      _fileWriter = RotatingLogWriter(directory: target);
      await _fileWriter!.write(
        '${DateTime.now().toUtc().toIso8601String()} INFO session_started '
        'os=${Platform.operatingSystem} osVersion=${LogSanitizer.sanitize(Platform.operatingSystemVersion)} '
        'dart=${Platform.version.split(' ').first}',
      );
    } catch (error) {
      _logger.w('File logging unavailable',
          error: LogSanitizer.sanitize(error));
    }
  }

  static void registerSecret(String value) =>
      LogSanitizer.registerSecret(value);

  static Future<void> flush() => _fileWriter?.flush() ?? Future<void>.value();

  static void debug(String message) => _write('DEBUG', message);

  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _write('WARN', message, error: error, stackTrace: stackTrace);

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _write('ERROR', message, error: error, stackTrace: stackTrace);

  static void _write(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final safeMessage = LogSanitizer.sanitize(message);
    final safeError = error == null ? null : LogSanitizer.sanitize(error);
    final safeStack = stackTrace == null
        ? null
        : StackTrace.fromString(LogSanitizer.sanitize(stackTrace));
    switch (level) {
      case 'DEBUG':
        _logger.d(safeMessage, error: safeError, stackTrace: safeStack);
      case 'WARN':
        _logger.w(safeMessage, error: safeError, stackTrace: safeStack);
      default:
        _logger.e(safeMessage, error: safeError, stackTrace: safeStack);
    }
    final suffix = [
      if (safeError != null) 'error=$safeError',
      if (safeStack != null) safeStack.toString(),
    ].join(' ');
    unawaited(
      _fileWriter
              ?.write(
                '${DateTime.now().toUtc().toIso8601String()} $level $safeMessage${suffix.isEmpty ? '' : ' $suffix'}',
              )
              .catchError((_) {}) ??
          Future<void>.value(),
    );
  }
}
