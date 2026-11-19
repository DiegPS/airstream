import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/media_library_entries.dart';

final mediaLibraryProvider =
    FutureProvider<MediaLibrary>((ref) async => MediaLibrary(
          Directory(
              p.join((await getApplicationSupportDirectory()).path, 'media')),
          () => ref.read(settingsProvider).mediaLibrary,
        ));

class MediaLibrary {
  MediaLibrary(this.directory, this.entries);
  final Directory directory;
  final Map<String, Map<String, dynamic>> Function() entries;
  static const totalLimit = 500 * 1024 * 1024;
  final _pending = <String, Map<String, dynamic>>{};
  int get usedBytes => MediaLibraryEntries.sanitize({..._pending, ...entries()})
      .values
      .fold(0, (n, e) => n + (e['bytes'] as int));
  Future<void> _tail = Future.value();
  Future<String> validate(String path) async {
    final kind = await inspect(File(path));
    if (!['image', 'video', 'audio'].contains(kind)) return kind;
    if (usedBytes + await File(path).length() > totalLimit) return 'total';
    return kind;
  }

  /// Checks a standalone file without consulting the current library quota.
  static Future<String> inspect(File file, {int? maxBytes}) async {
    final path = file.path;
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    final kind = MediaLibraryEntries.types[ext]?.$1;
    if (kind == null) return 'type';
    try {
      if (await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.file) {
        return 'type';
      }
      final size = await file.length();
      if (size > (maxBytes ?? MediaLibraryEntries.limit(kind))) return 'size';
      final handle = await file.open();
      late List<int> b;
      try {
        b = await handle.read(12);
      } finally {
        await handle.close();
      }
      bool at(int offset, List<int> magic) =>
          b.length >= offset + magic.length &&
          List.generate(magic.length, (i) => b[offset + i] == magic[i])
              .every((v) => v);
      bool ascii(int offset, String s) => at(offset, s.codeUnits);
      final valid = switch (ext) {
        'png' => at(0, [137, 80, 78, 71, 13, 10, 26, 10]),
        'jpg' || 'jpeg' => at(0, [255, 216, 255]),
        'gif' => ascii(0, 'GIF87a') || ascii(0, 'GIF89a'),
        'webp' => ascii(0, 'RIFF') && ascii(8, 'WEBP'),
        'mp4' => ascii(4, 'ftyp'),
        'webm' => at(0, [0x1a, 0x45, 0xdf, 0xa3]),
        'wav' => ascii(0, 'RIFF') && ascii(8, 'WAVE'),
        'mp3' => ascii(0, 'ID3') ||
            (b.length >= 2 && b[0] == 255 && b[1] & 0xe0 == 0xe0),
        'ogg' => ascii(0, 'OggS'),
        _ => false,
      };
      return valid ? kind : 'type';
    } on FileSystemException {
      return 'type';
    }
  }

  void clearPendingImports() => _pending.clear();

  /// Serializes library mutations with full backup snapshots and restores.
  Future<T> withStableFiles<T>(Future<T> Function() work) {
    final operation = _tail.then((_) => work());
    _tail = operation.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return operation;
  }

  Future<MapEntry<String, Map<String, dynamic>>> import(
    String path, {
    Future<void> Function(MapEntry<String, Map<String, dynamic>>)? onImported,
  }) =>
      withStableFiles(() async {
        final kind = await validate(path);
        if (!['image', 'video', 'audio'].contains(kind)) {
          throw FormatException(kind);
        }
        await directory.create(recursive: true);
        if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw const FormatException('type');
        }
        final random = Random.secure();
        String id;
        do {
          id = List.generate(8,
                  (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
              .join();
        } while (entries().containsKey(id) ||
            _pending.containsKey(id) ||
            await FileSystemEntity.type(
                    p.join(directory.path,
                        '$id.${p.extension(path).substring(1).toLowerCase()}'),
                    followLinks: false) !=
                FileSystemEntityType.notFound);
        final ext = p.extension(path).substring(1).toLowerCase();
        final name = p.basename(path);
        final dest = File(p.join(directory.path, '$id.$ext'));
        late final Map<String, dynamic> metadata;
        try {
          await File(path).copy(dest.path);
          final check = await validate(dest.path);
          if (check != kind) throw FormatException(check);
          metadata = <String, dynamic>{
            'name': String.fromCharCodes(name.runes.take(80)),
            'kind': kind,
            'ext': ext,
            'bytes': await dest.length(),
            'addedAt': DateTime.now().millisecondsSinceEpoch
          };
        } catch (_) {
          if (await dest.exists()) await dest.delete();
          rethrow;
        }
        _pending[id] = metadata;
        final entry = MapEntry(id, metadata);
        if (onImported != null) {
          await onImported(entry);
          _pending.remove(id);
        }
        return entry;
      });

  Future<File?> fileFor(MapEntry<String, Map<String, dynamic>> entry) async {
    if (!MediaLibraryEntries.sanitize({entry.key: entry.value})
        .containsKey(entry.key)) {
      return null;
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return null;
    }
    final file =
        File(p.join(directory.path, '${entry.key}.${entry.value['ext']}'));
    return await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.file
        ? file
        : null;
  }

  Future<void> delete(String id, {Future<void> Function()? onDeleted}) =>
      withStableFiles(() async {
        final entry = MediaLibraryEntries.sanitize(entries())[id];
        if (entry == null) return;
        final file = await fileFor(MapEntry(id, entry));
        if (file != null) await file.delete();
        _pending.remove(id);
        await onDeleted?.call();
      });
}
