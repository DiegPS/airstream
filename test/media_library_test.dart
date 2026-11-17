import 'dart:io';
import 'dart:convert';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/settings/media_library_entries.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/services/overlay/overlay_payload_encoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

void main() {
  late Directory temp;
  late MediaLibrary library;
  late Map<String, Map<String, dynamic>> entries;
  const magic = <String, List<int>>{
    'png': [137, 80, 78, 71, 13, 10, 26, 10],
    'jpg': [255, 216, 255],
    'jpeg': [255, 216, 255],
    'gif': [71, 73, 70, 56, 57, 97],
    'webp': [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80],
    'mp4': [0, 0, 0, 20, 102, 116, 121, 112],
    'webm': [26, 69, 223, 163],
    'wav': [82, 73, 70, 70, 0, 0, 0, 0, 87, 65, 86, 69],
    'mp3': [73, 68, 51],
    'ogg': [79, 103, 103, 83],
  };
  Future<File> source(String ext) => File(p.join(temp.path, 'original.$ext'))
      .writeAsBytes(magic[ext.toLowerCase()]!);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('airstream-media-');
    entries = {};
    library =
        MediaLibrary(Directory(p.join(temp.path, 'media')), () => entries);
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  for (final ext in magic.keys) {
    test('accepts $ext magic and case insensitive extension', () async {
      final f = await source(ext.toUpperCase());
      expect(
          await library.validate(f.path), MediaLibraryEntries.types[ext]!.$1);
    });
  }
  test('accepts MPEG frame sync', () async {
    final f =
        await File(p.join(temp.path, 'frame.mp3')).writeAsBytes([255, 251, 0]);
    expect(await library.validate(f.path), 'audio');
  });
  test('rejects unsupported extensions and renamed executable', () async {
    final f =
        await File(p.join(temp.path, 'bad.exe')).writeAsBytes(magic['png']!);
    expect(await library.validate(f.path), 'type');
    final fake =
        await File(p.join(temp.path, 'bad.png')).writeAsBytes([77, 90, 0]);
    expect(await library.validate(fake.path), 'type');
    await expectLater(library.import(fake.path), throwsFormatException);
    expect(await library.directory.exists(), false);
  });
  for (final ext in ['png', 'mp4', 'wav']) {
    test('rejects oversize $ext using sparse length', () async {
      final f = await source(ext);
      final h = await f.open(mode: FileMode.append);
      await h.truncate(
          MediaLibraryEntries.limit(MediaLibraryEntries.types[ext]!.$1) + 1);
      await h.close();
      expect(await library.validate(f.path), 'size');
    });
  }
  test('total limit uses metadata without large files', () async {
    for (var i = 0; i < 10; i++) {
      entries[i.toRadixString(16).padLeft(16, '0')] = {
        'name': 'v.mp4',
        'kind': 'video',
        'ext': 'mp4',
        'bytes': 50 * 1024 * 1024,
        'addedAt': 1
      };
    }
    expect(await library.validate((await source('png')).path), 'total');
  });
  test(
      'import copies once, survives original removal, delete tolerates missing',
      () async {
    final original = await source('png');
    final e = await library.import(original.path);
    entries[e.key] = e.value;
    expect(e.key, matches(r'^[0-9a-f]{16}$'));
    expect(e.value['name'], 'original.png');
    await original.delete();
    expect(await (await library.fileFor(e))!.readAsBytes(), magic['png']);
    await library.delete(e.key);
    expect(await library.fileFor(e), isNull);
    await library.delete(e.key);
  });
  test('fileFor refuses missing files directories and links', () async {
    final e = await library.import((await source('png')).path);
    entries[e.key] = e.value;
    final f = (await library.fileFor(e))!;
    await f.delete();
    expect(await library.fileFor(e), isNull);
    final dir = await Directory(f.path).create();
    expect(await library.fileFor(e), isNull);
    await dir.delete();
    // Windows junctions do not require the symbolic-link privilege.
    final target = await Directory(p.join(temp.path, 'target')).create();
    if (Platform.isWindows) {
      final r =
          await Process.run('cmd', ['/c', 'mklink', '/J', f.path, target.path]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    } else {
      await Link(f.path).create(target.path);
    }
    expect(await library.fileFor(e), isNull);
    await Link(f.path).delete();
  });
  test('route serves only registered ids with types ranges and fresh bytes',
      () async {
    final e = await library.import((await source('png')).path);
    entries[e.key] = e.value;
    final handler = buildOverlayRoutes((_) => Response.notFound(''),
        mediaLibrary: () async => library);
    Future<Response> get(String url, [String? range]) async =>
        await handler(Request('GET', Uri.parse('http://localhost/$url'),
            headers: range == null ? {} : {'range': range}));
    final r = await get('media/${e.key}');
    expect(r.statusCode, 200);
    expect(r.headers['content-type'], 'image/png');
    expect(r.headers['x-content-type-options'], 'nosniff');
    expect(r.headers['cache-control'], 'private, max-age=86400');
    expect(r.headers['accept-ranges'], 'bytes');
    expect(await r.read().expand((b) => b).toList(), magic['png']);
    final partial = await get('media/${e.key}', 'bytes=0-3');
    expect(partial.statusCode, 206);
    expect(partial.headers['content-range'], 'bytes 0-3/8');
    expect(
        await partial.read().expand((b) => b).toList(), magic['png']!.take(4));
    expect((await get('media/${e.key}', 'bytes=4-')).statusCode, 206);
    for (final range in [
      'bytes=999999-',
      'bytes=4-2',
      'bytes=-4',
      'nonsense',
      'bytes=0-1,3-4'
    ]) {
      expect((await get('media/${e.key}', range)).statusCode, 416);
    }
    for (final path in [
      'media/0000000000000000',
      'media/x/y',
      'media/${e.key}.png'
    ]) {
      expect((await get(path)).statusCode, 404, reason: path);
    }
    // Dart normalizes dot segments before Shelf constructs the request.
    for (final path in ['media/../alerts', 'media/%2e%2e/alerts']) {
      final normalized = await get(path);
      expect(normalized.headers['content-type'], 'text/html; charset=utf-8');
      expect(await normalized.readAsString(), startsWith('<!DOCTYPE html>'));
    }
    final f = (await library.fileFor(e))!;
    await f.writeAsBytes([1, 2, 3]);
    expect(await (await get('media/${e.key}')).read().expand((b) => b).toList(),
        [1, 2, 3]);
  });
  test('settings persist sanitize and profiles reset retain local library',
      () async {
    final e = await library.import((await source('png')).path);
    entries[e.key] = e.value;
    final settings = SettingsModel(mediaLibrary: entries);
    final loaded =
        SettingsModel.fromJson(jsonDecode(jsonEncode(settings.toJson())));
    expect(loaded.mediaLibrary, entries);
    expect(SettingsProfiles.capture(settings), isNot(contains('mediaLibrary')));
    expect(SettingsProfiles.apply(settings, {'mediaLibrary': {}}).mediaLibrary,
        entries);
    expect(SettingsProfiles.resetToDefaults(settings).mediaLibrary, entries);
    expect(
        MediaLibraryEntries.sanitize({
          'bad': e.value,
          e.key: {'name': 'bad', 'kind': 'exe'}
        }),
        isEmpty);
    expect(
        MediaLibraryEntries.sanitize({
          e.key: {...e.value, 'ext': 'exe'}
        }),
        isEmpty);
  });
  test('options sanitize references and page payload exposes no paths',
      () async {
    final image = await library.import((await source('png')).path);
    entries[image.key] = image.value;
    final audio = await library.import((await source('wav')).path);
    entries[audio.key] = audio.value;
    final s = SettingsModel(mediaLibrary: entries, alertTypeOptions: {
      'raid': {
        'media': image.key,
        'mediaAudio': true,
        'sound': 'library',
        'soundMediaId': audio.key,
        'soundPath': temp.path
      }
    });
    final o = AlertTypeOptions.of(s, 'raid');
    expect(o.media, image.key);
    expect(o.mediaAudio, true);
    expect(o.soundMediaId, audio.key);
    final payload = jsonEncode(OverlayPayloadEncoder.settings(s));
    expect(payload, contains(image.key));
    expect(payload, contains(audio.key));
    expect(payload, isNot(contains(temp.path)));
    expect(payload, isNot(contains('soundPath')));
    expect(AlertTypeOptions.of(s.copyWith(mediaLibrary: {}), 'raid').media, '');
    expect(AlertTypeOptions.of(s.copyWith(mediaLibrary: {}), 'raid').sound, '');
    expect(
        AlertTypeOptions.sanitize({
          'raid': {'media': '../bad', 'mediaAudio': 'yes', 'soundMediaId': 3}
        }),
        isEmpty);
  });
}
