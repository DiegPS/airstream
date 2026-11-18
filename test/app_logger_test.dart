import 'dart:io';

import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/log_sanitizer.dart';
import 'package:airstream/services/rotating_log_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizes registered and structured secrets', () {
    LogSanitizer.registerSecret('secret-value');
    final safe = LogSanitizer.sanitize(
      'password=hunter2 token: abc123 Authorization: Bearer xyz secret-value',
    );
    expect(safe, isNot(contains('hunter2')));
    expect(safe, isNot(contains('abc123')));
    expect(safe, isNot(contains('xyz')));
    expect(safe, isNot(contains('secret-value')));
  });

  test('redacts webhook endpoint URLs and escaped JSON credentials', () {
    final safe = LogSanitizer.sanitize(
      r'https://discord.invalid/api/v10/webhooks/123/token?wait=true '
      r'https://local.invalid/api/webhooks https://local.invalid/webhooks/internal '
      r'{"rulesWebhookToken":"raw-webhook-token","obsPassword":"p\"ass\\word"} '
      r'https://example.invalid/ordinary',
    );
    for (final secret in [
      'discord.invalid',
      'local.invalid',
      'raw-webhook-token',
      r'p\"ass\\word'
    ]) {
      expect(safe, isNot(contains(secret)));
    }
    expect(safe, contains('https://example.invalid/ordinary'));
  });

  test('redacts truncated JSON credentials through the end of their line', () {
    final safe = LogSanitizer.sanitize([
      r'{"obsPassword":"first secret with spaces\',
      r'{"rulesWebhookToken":"second secret with \"quotes',
      'offset 42',
    ].join('\r\n'));
    expect(
        safe,
        [
          '{"obsPassword":<redacted>',
          '{"rulesWebhookToken":<redacted>',
          'offset 42',
        ].join('\r\n'));
  });

  test('rotates local log files without losing the newest entry', () async {
    final directory = await Directory.systemTemp.createTemp('airstream-logs-');
    addTearDown(() => directory.delete(recursive: true));
    final writer = RotatingLogWriter(
      directory: directory,
      maxBytes: 20,
      maxBackups: 2,
    );

    await writer.write('first-entry-long');
    await writer.write('second-entry-long');
    await writer.write('third-entry-long');

    expect(await writer.currentFile.readAsString(), contains('third-entry'));
    expect(await File('${writer.currentFile.path}.1').exists(), isTrue);
    expect(await File('${writer.currentFile.path}.2').exists(), isTrue);
  });

  test('AppLogger writes only sanitized values to disk', () async {
    final directory =
        await Directory.systemTemp.createTemp('airstream-app-log-');
    addTearDown(() => directory.delete(recursive: true));
    await AppLogger.initialize(directory: directory);
    AppLogger.registerSecret('obs-secret');
    AppLogger.error('connect password=obs-secret', error: 'token=raw-token');
    await AppLogger.flush();

    final contents = await File(
      '${directory.path}${Platform.pathSeparator}airstream.log',
    ).readAsString();
    expect(contents, isNot(contains('obs-secret')));
    expect(contents, isNot(contains('raw-token')));
    expect(contents, contains('<redacted>'));
  });
}
