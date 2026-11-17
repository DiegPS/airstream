import 'dart:convert';
import 'gallery/gallery_catalog.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../overlay/overlay_routes.dart' show templateContentTypes;
import 'template_library.dart';

class TemplateArchiveLimits {
  const TemplateArchiveLimits(
      {this.zip = 100 * 1024 * 1024,
      this.total = 100 * 1024 * 1024,
      this.file = 50 * 1024 * 1024,
      this.count = 500});
  final int zip, total, file, count;
}

/// Immutable validated bytes: confirmation never rereads an untrusted zip.
class ValidatedTemplateArchive {
  ValidatedTemplateArchive._(this._files, this.name, this.baseId, this.network);
  final Map<String, Uint8List> _files;
  final String name, baseId;
  final bool network;
  int get count => _files.length;
  int get bytes => _files.values.fold(0, (n, b) => n + b.length);
}

class TemplateArchive {
  const TemplateArchive({this.limits = const TemplateArchiveLimits()});
  final TemplateArchiveLimits limits;
  Future<ValidatedTemplateArchive> validate(String path) {
    final limits = this.limits;
    return Isolate.run(() => _validate(path, limits));
  }

  Future<String> import(
      TemplateLibrary library, ValidatedTemplateArchive archive) async {
    await library.ensureRoot();
    final root = library.rootPath;
    return Isolate.run(() => _install(root, archive._files, archive.baseId));
  }

  Future<String> installGallery(
      TemplateLibrary library, GalleryItem item, String language) async {
    final files = {
      for (final entry in item.buildFiles(language).entries)
        entry.key: Uint8List.fromList(utf8.encode(entry.value)),
    };
    await library.ensureRoot();
    final root = library.rootPath;
    final id = item.id;
    return Isolate.run(() => _install(root, files, id));
  }

  Future<void> export(
      TemplateLibrary library, String id, String destination) async {
    final root = library.rootPath;
    final limits = this.limits;
    await Isolate.run(() {
      final files = _collect(root, id, limits);
      final archive = Archive();
      for (final e in files.entries) {
        archive.addFile(
            ArchiveFile(p.posix.join(id, e.key), e.value.length, e.value));
      }
      final bytes = ZipEncoder().encode(archive);
      if (bytes.length > limits.zip) throw const FormatException('zip');
      File(destination).writeAsBytesSync(bytes, flush: true);
    });
  }

  Future<String> duplicate(
      TemplateLibrary library, String id, String copyWord) async {
    final root = library.rootPath;
    final limits = this.limits;
    return Isolate.run(() {
      final files = _collect(root, id, limits);
      try {
        final raw = jsonDecode(utf8.decode(files['template.json']!));
        if (raw is Map<String, dynamic>) {
          raw['name'] = '${TemplateManifest(id, raw).name} ($copyWord)';
          files['template.json'] =
              Uint8List.fromList(utf8.encode(jsonEncode(raw)));
        }
      } catch (_) {/* Preserve invalid/missing manifests. */}
      _checkFiles(files, limits);
      return _install(
          root, files, '${id.substring(0, min(id.length, 35))}-copy');
    });
  }
}

bool _skip(String name) => name.split('/').any((s) =>
    const ['__MACOSX', '.DS_Store', 'Thumbs.db', 'desktop.ini'].contains(s));
void _path(String name, {int depth = 6}) {
  final segments = name.split('/');
  if (segments.length > depth ||
      segments.any(
          (s) => !RegExp(r'^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$').hasMatch(s))) {
    throw const FormatException('path');
  }
}

bool _allowed(String name) => templateContentTypes
    .containsKey(p.posix.extension(name).replaceFirst('.', '').toLowerCase());

ValidatedTemplateArchive _validate(String path, TemplateArchiveLimits limits) {
  try {
    final file = File(path);
    if (file.lengthSync() > limits.zip) throw const FormatException('zip');
    final bytes = _readBounded(file, limits.zip, 'zip');
    if (bytes.length > limits.zip) throw const FormatException('zip');
    // Read central headers only; in particular, do not decode symlink targets.
    final headers =
        ZipDirectory().headers(InputMemoryStream(bytes), verify: true).toList();
    final kept = <ZipFileHeader>[];
    var declared = 0, count = 0;
    for (final h in headers) {
      final name = h.filename;
      if (_skip(name)) continue;
      // Reject disagreement between local and central names as well as unsafe names.
      final data = ByteData.sublistView(bytes);
      final offset = h.localHeaderOffset;
      if (offset < 0 ||
          offset + 30 > bytes.length ||
          data.getUint32(offset, Endian.little) != 0x04034b50) {
        throw const FormatException('size');
      }
      final length = data.getUint16(offset + 26, Endian.little);
      if (offset + 30 + length > bytes.length) {
        throw const FormatException('size');
      }
      final localName =
          utf8.decode(bytes.sublist(offset + 30, offset + 30 + length));
      if (localName != name) throw const FormatException('path');
      final directory = name.endsWith('/');
      _path(directory ? name.substring(0, name.length - 1) : name, depth: 7);
      final mode = (h.externalFileAttributes >> 16) & 0xf000;
      if (mode == 0xa000 || (mode != 0 && mode != 0x8000 && mode != 0x4000)) {
        throw const FormatException('link');
      }
      if (directory) continue;
      if (++count > limits.count) throw const FormatException('count');
      if (!_allowed(name)) throw const FormatException('type');
      if (h.uncompressedSize < 0 || h.uncompressedSize > limits.file) {
        throw const FormatException('file');
      }
      declared += h.uncompressedSize;
      if (declared > limits.total) throw const FormatException('total');
      kept.add(h);
    }
    if (!kept.any((h) => p.posix.basename(h.filename) == 'index.html')) {
      throw const FormatException('index');
    }
    final atRoot = kept.any((h) => h.filename == 'index.html');
    String? top;
    if (!atRoot) {
      final tops = kept.map((h) => h.filename.split('/').first).toSet();
      if (tops.length != 1 || kept.any((h) => !h.filename.contains('/'))) {
        throw const FormatException('layout');
      }
      top = tops.single;
    }
    for (final h in headers) {
      if (_skip(h.filename)) continue;
      final name = h.filename.endsWith('/')
          ? h.filename.substring(0, h.filename.length - 1)
          : h.filename;
      if (top != null && name != top && !name.startsWith('$top/')) {
        throw const FormatException('layout');
      }
      if (top == null) _path(name);
    }
    final files = <String, Uint8List>{};
    var actual = 0;
    for (final h in kept) {
      final name =
          top == null ? h.filename : h.filename.substring(top.length + 1);
      _path(name);
      if (files.keys.any((k) => k.toLowerCase() == name.toLowerCase())) {
        throw const FormatException('path');
      }
      final output = _BoundedOutput(min(limits.file, limits.total - actual));
      final content = h.file!;
      content.throwOnError = true;
      content.decompress(output);
      final data = output.getBytes();
      if (data.length != h.uncompressedSize) {
        throw const FormatException('size');
      }
      actual += data.length;
      files[name] = data;
    }
    if (!files.containsKey('index.html')) throw const FormatException('index');
    Map raw = {};
    try {
      final v = jsonDecode(utf8.decode(files['template.json']!));
      if (v is Map) raw = v;
    } catch (_) {/* Defaults. */}
    final manifest =
        TemplateManifest(top ?? p.basenameWithoutExtension(path), raw);
    return ValidatedTemplateArchive._(files, manifest.name,
        templateId(top ?? manifest.name), manifest.network);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('size');
  }
}

/// All decompressor output paths check the real byte count before allocation.
class _BoundedOutput extends OutputMemoryStream {
  _BoundedOutput(this.limit);
  final int limit;
  void _check(int n) {
    if (length + n > limit) throw const FormatException('size');
  }

  @override
  void reserve(int total) {
    if (total > limit) throw const FormatException('size');
    super.reserve(total);
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }

  @override
  void writeRange(Uint8List bytes, int start, int end) {
    _check(end - start);
    super.writeRange(bytes, start, end);
  }
}

void _checkFiles(Map<String, Uint8List> files, TemplateArchiveLimits limits) {
  if (files.length > limits.count) throw const FormatException('count');
  var total = 0;
  for (final b in files.values) {
    if (b.length > limits.file) throw const FormatException('file');
    total += b.length;
  }
  if (total > limits.total) throw const FormatException('total');
}

Map<String, Uint8List> _collect(
    String root, String id, TemplateArchiveLimits limits) {
  if (!TemplateLibrary.validId(id)) throw const FormatException('path');
  final folder = Directory(p.join(root, id));
  if (FileSystemEntity.typeSync(folder.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const FormatException('link');
  }
  final real = folder.resolveSymbolicLinksSync();
  if (!p.isWithin(Directory(root).resolveSymbolicLinksSync(), real)) {
    throw const FormatException('path');
  }
  final files = <String, Uint8List>{};
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final relative = p.relative(entity.path, from: folder.path);
      final segments = p.split(relative);
      if (segments.any((s) => s.startsWith('.')) ||
          _skip(p.posix.joinAll(segments))) {
        continue;
      }
      final name = p.posix.joinAll(segments);
      _path(name);
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        walk(Directory(entity.path));
      } else if (type == FileSystemEntityType.file && _allowed(name)) {
        if (!p.isWithin(real, entity.resolveSymbolicLinksSync())) {
          throw const FormatException('path');
        }
        final file = File(entity.path);
        if (file.lengthSync() > limits.file) {
          throw const FormatException('file');
        }
        files[name] = _readBounded(
            file,
            min(limits.file,
                limits.total - files.values.fold(0, (n, b) => n + b.length)),
            'size');
        _checkFiles(files, limits);
      }
    }
  }

  walk(folder);
  if (!files.containsKey('index.html')) throw const FormatException('index');
  return files;
}

String _install(String root, Map<String, Uint8List> files, String base) {
  final temp = Directory(p.join(root,
      '.import-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}'));
  temp.createSync();
  try {
    for (final e in files.entries) {
      final file = File(p.join(temp.path, p.joinAll(e.key.split('/'))));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(e.value, flush: true);
    }
    var id = base, suffix = 2;
    while (true) {
      final path = p.join(root, id);
      if (FileSystemEntity.typeSync(path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        if (_renameWithRetry(temp, path)) return id;
        // Another install claimed this ID between lookup and rename.
      }
      final end = '-${suffix++}';
      id = '${base.substring(0, min(base.length, 40 - end.length))}$end';
    }
  } finally {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }
}

Uint8List _readBounded(File file, int limit, String reason) {
  final handle = file.openSync();
  final result = BytesBuilder(copy: false);
  try {
    while (true) {
      final chunk = handle.readSync(min(65536, limit - result.length + 1));
      if (chunk.isEmpty) break;
      if (result.length + chunk.length > limit) throw FormatException(reason);
      result.add(chunk);
    }
    return result.takeBytes();
  } finally {
    handle.closeSync();
  }
}

/// Renames [from] to [to]. Windows can briefly lock a folder whose files were
/// just written (antivirus, indexing), so a failed rename is retried while the
/// target is still free. Returns false when another install took [to].
bool _renameWithRetry(Directory from, String to) {
  for (var attempt = 1;; attempt++) {
    try {
      from.renameSync(to);
      return true;
    } on FileSystemException {
      if (FileSystemEntity.typeSync(to, followLinks: false) !=
          FileSystemEntityType.notFound) {
        return false;
      }
      if (attempt == 5) rethrow;
      sleep(Duration(milliseconds: 40 * attempt));
    }
  }
}
