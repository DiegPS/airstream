import 'dart:io';
import 'dart:typed_data';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sound routes serve only fixed names and current validated settings',
      () async {
    final dir = Directory.systemTemp.createTempSync('airstream-routes-');
    final file = File('${dir.path}/raid.mp3')..writeAsBytesSync([1, 2, 3]);
    final server = OverlayServer();
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.dispose();
      dir.deleteSync(recursive: true);
    });
    SettingsModel settings(String path) => SettingsModel(alertTypeOptions: {
          'raid': {'sound': 'custom', 'soundPath': path},
        });
    await server.start(
        messages: const Stream<ChatMessage>.empty(),
        settings: settings(file.path),
        port: 0);
    Future<(HttpClientResponse, List<int>)> get(String path) async {
      final request = await client.getUrl(
          _RequestUri(Uri.parse('http://127.0.0.1:${server.port}'), path));
      final response = await request.close();
      return (
        response,
        await response.fold<List<int>>([], (a, b) => a..addAll(b))
      );
    }

    for (final name in ['chime', 'coin', 'fanfare']) {
      final (response, bytes) = await get('/sounds/$name.wav');
      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'audio/wav');
      expect(response.headers.value('x-content-type-options'), 'nosniff');
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    }
    for (final path in [
      '/sounds/custom/raid',
      '/sounds/custom/raid?path=C:/Windows/win.ini'
    ]) {
      final (response, bytes) = await get(path);
      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'audio/mpeg');
      expect(response.headers.value('cache-control'), 'no-store');
      expect(bytes, [1, 2, 3]);
    }
    for (final path in [
      '/sounds/custom/bits',
      '/sounds/custom/unknown',
      '/sounds/custom/raid/extra',
      '/sounds/x'
    ]) {
      expect((await get(path)).$1.statusCode, 404, reason: path);
    }
    // Dart normalizes dot segments before Shelf; these remain ordinary HTML pages.
    for (final path in [
      '/sounds/../alerts',
      '/sounds/custom/../../Windows/win.ini'
    ]) {
      final (response, bytes) = await get(path);
      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'text/html');
      expect(String.fromCharCodes(bytes), startsWith('<!DOCTYPE html>'));
    }
    file.deleteSync();
    expect((await get('/sounds/custom/raid')).$1.statusCode, 404);
    file.writeAsBytesSync(Uint8List(5 * 1024 * 1024 + 1));
    expect((await get('/sounds/custom/raid')).$1.statusCode, 404);
    final replacement = File('${dir.path}/replacement.ogg')
      ..writeAsBytesSync([4, 5]);
    server.setSettings(settings(replacement.path));
    final (updated, bytes) = await get('/sounds/custom/raid');
    expect(updated.headers.contentType?.mimeType, 'audio/ogg');
    expect(bytes, [4, 5]);
    final alerts = (await get('/alerts')).$1;
    final chat = (await get('/')).$1;
    expect(alerts.headers.value('content-security-policy'),
        contains("media-src 'self'"));
    expect(chat.headers.value('content-security-policy'),
        "default-src 'none'; img-src data: http: https:; connect-src ws: wss:; style-src 'unsafe-inline'; script-src 'unsafe-inline'");
  });
}

// Uri.parse removes dot segments before HttpClient sees them. Preserve the
// request target here so the traversal test actually reaches the server.
class _RequestUri implements Uri {
  _RequestUri(this.base, this.target);
  final Uri base;
  final String target;
  @override
  String get scheme => base.scheme;
  @override
  String get host => base.host;
  @override
  int get port => base.port;
  @override
  String get userInfo => '';
  @override
  String get path => target.split('?').first;
  @override
  String get query =>
      target.contains('?') ? target.split('?').skip(1).join('?') : '';
  @override
  bool get hasQuery => target.contains('?');
  @override
  bool get hasPort => true;
  @override
  bool get hasFragment => false;
  @override
  Uri removeFragment() => this;
  @override
  bool isScheme(String scheme) => base.isScheme(scheme);
  @override
  String toString() => '$base$target';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
