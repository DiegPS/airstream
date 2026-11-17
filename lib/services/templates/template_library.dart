import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'agent_guide.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String _text(Object? v, int max, [String fallback = '']) =>
    v is String ? String.fromCharCodes(v.trim().runes.take(max)) : fallback;
num? _number(Object? v) => v is num && v.isFinite ? v : null;

class TemplateField {
  TemplateField(this.key, this.label, this.type, this.options);
  final String key, label, type;
  final Map<String, dynamic> options;
  Object? get defaultValue => sanitize(options['default']);
  Object? sanitize(Object? value) {
    switch (type) {
      case 'text':
        return _text(value, options['maxLength'] as int);
      case 'color':
        return value is String &&
                RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value)
            ? value.toLowerCase()
            : '#ffffff';
      case 'number':
        var n = _number(value) ?? 0;
        if (options['min'] != null && n < options['min']) {
          n = options['min'] as num;
        }
        if (options['max'] != null && n > options['max']) {
          n = options['max'] as num;
        }
        return n;
      case 'boolean':
        return value is bool ? value : false;
      case 'select':
        return (options['options'] as List).contains(value)
            ? value
            : (options['options'] as List).first;
      case 'media':
        return value is String && RegExp(r'^[0-9a-f]{16}$').hasMatch(value)
            ? value
            : '';
    }
    return null;
  }
}

typedef TemplateGalleryVersion = ({String id, int version});

TemplateGalleryVersion? _galleryVersion(Object? raw) {
  if (raw case {'id': final String id, 'version': final int version}
      when RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(id) &&
          version >= 1 &&
          version <= 1000) {
    return (id: id, version: version);
  }
  return null;
}

class TemplateManifest {
  TemplateManifest(String id, Map raw)
      : name = _text(raw['name'], 60, id),
        description = _text(raw['description'], 200),
        author = _text(raw['author'], 60),
        sdk = raw['sdk'] is int ? raw['sdk'] as int : 1,
        width =
            raw['width'] is int ? (raw['width'] as int).clamp(100, 3840) : 800,
        height = raw['height'] is int
            ? (raw['height'] as int).clamp(100, 2160)
            : 600,
        network = raw['network'] == true,
        gallery = _galleryVersion(raw['gallery']) {
    final entries = raw['fields'];
    if (entries is! List) return;
    final keys = <String>{};
    for (final f in entries.take(40)) {
      if (f is! Map ||
          f['key'] is! String ||
          !RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,31}$')
              .hasMatch(f['key'] as String) ||
          keys.contains(f['key'])) {
        continue;
      }
      final type = f['type'];
      if (!['text', 'color', 'number', 'boolean', 'select', 'media']
          .contains(type)) {
        continue;
      }
      final o = <String, dynamic>{'default': f['default']};
      if (type == 'text') {
        o['maxLength'] =
            f['maxLength'] is int ? (f['maxLength'] as int).clamp(1, 500) : 200;
      }
      if (type == 'number') {
        for (final k in ['min', 'max', 'step']) {
          if (_number(f[k]) != null) o[k] = f[k];
        }
        if (o['min'] != null && o['max'] != null && o['min'] > o['max'] ||
            o['step'] != null && o['step'] <= 0) {
          continue;
        }
      }
      if (type == 'select') {
        final list = f['options'];
        if (list is! List ||
            list.isEmpty ||
            list.length > 30 ||
            list.any((v) => v is! String || v.runes.length > 60)) {
          continue;
        }
        o['options'] = List<String>.from(list);
      }
      if (type == 'media') {
        if (!['image', 'video', 'audio', 'visual', 'any']
            .contains(f['kind'] ?? 'any')) {
          continue;
        }
        o['kind'] = f['kind'] ?? 'any';
      }
      keys.add(f['key'] as String);
      fields.add(TemplateField(f['key'] as String,
          _text(f['label'], 60, f['key'] as String), type as String, o));
    }
  }
  final String name, description, author;
  final int sdk, width, height;
  final bool network;
  final TemplateGalleryVersion? gallery;
  final fields = <TemplateField>[];
  Map<String, Object?> values(Map raw) => {
        for (final f in fields)
          f.key:
              raw.containsKey(f.key) ? f.sanitize(raw[f.key]) : f.defaultValue
      };
}

class TemplateInfo {
  TemplateInfo(this.id, this.manifest, this.problems, this.folderPath);
  final String id, folderPath;
  final TemplateManifest manifest;
  final List<String> problems;
  bool get usable =>
      !problems.contains('missingIndex') &&
      !problems.contains('oversizedIndex');
}

class TemplateChangeKind {
  const TemplateChangeKind._(this.name);
  final String name;
  static const files = TemplateChangeKind._("files");
  static const values = TemplateChangeKind._("values");
  static const list = TemplateChangeKind._("list");
}

class TemplateChange {
  const TemplateChange(this.id, this.kind);
  final String id;
  final TemplateChangeKind kind;
}

class TemplateLibrary {
  TemplateLibrary(this.root);
  final Directory root;
  String get rootPath => root.path;
  static bool validId(String id) =>
      RegExp(r'^[a-z0-9][a-z0-9-]{0,39}$').hasMatch(id);
  static Future<Directory> defaultRoot() async => Directory(p.join(
      (await getApplicationDocumentsDirectory()).path,
      'Airstream',
      'Templates'));
  final _changes = StreamController<TemplateChange>.broadcast();
  Stream<TemplateChange> get changes => _changes.stream;
  final _cache = <String,
      ({
    DateTime modified,
    int size,
    TemplateManifest manifest,
    List<String> problems
  })>{};
  final _timers = <String, Timer>{};
  final _pending = <String, TemplateChangeKind>{};
  StreamSubscription<FileSystemEvent>? _watch;
  Future<bool> exists() => root.exists();
  Future<void> ensureRoot() async {
    await root.create(recursive: true);
    await writeAgentGuide();
    await watch();
  }

  Future<void>? _guideWrite;
  Future<void> writeAgentGuide() {
    final pending = _guideWrite;
    if (pending != null) return pending;
    return _guideWrite = writeGeneratedAgentGuide(root).whenComplete(() {
      _guideWrite = null;
    });
  }

  Future<String> suggestedAgentId(String description) async {
    final base = templateId(
        description.trim().split(RegExp(r'\s+')).take(6).join(' '),
        fallback: 'my-template');
    var id = base;
    var suffix = 2;
    while (await FileSystemEntity.type(p.join(root.path, id),
            followLinks: false) !=
        FileSystemEntityType.notFound) {
      final ending = '-${suffix++}';
      id =
          '${base.substring(0, base.length.clamp(0, 40 - ending.length))}$ending';
    }
    return id;
  }

  Future<void> watch() async {
    if (_watch != null || !await exists()) return;
    // Another caller may have started it while awaiting exists.
    if (_watch != null) {
      return;
    }
    try {
      _watch = root.watch(recursive: true).listen(_event, onError: (Object _) {
        unawaited(stopWatching());
      }, onDone: () {
        unawaited(stopWatching());
      });
    } on FileSystemException {/* Restart only on explicit request. */}
  }

  void _event(FileSystemEvent event) {
    _queueEvent(event, event.path);
    if (event is FileSystemMoveEvent && event.destination != null) {
      _queueEvent(event, event.destination!);
    }
  }

  void _queueEvent(FileSystemEvent event, String eventPath) {
    final parts = p.split(p.relative(eventPath, from: root.path));
    if (parts.isEmpty ||
        parts.any((s) =>
            s.startsWith('.') ||
            s.endsWith('~') ||
            s.endsWith('.tmp') ||
            s.endsWith('.swp')) ||
        !validId(parts.first)) {
      return;
    }
    if (parts.length == 1 && event is FileSystemModifyEvent) return;
    final id = parts.first;
    final kind = parts.length == 1
        ? TemplateChangeKind.list
        : parts.last == 'values.json'
            ? TemplateChangeKind.values
            : TemplateChangeKind.files;
    final old = _pending[id];
    _pending[id] =
        old == TemplateChangeKind.list || kind == TemplateChangeKind.list
            ? TemplateChangeKind.list
            : old == TemplateChangeKind.files
                ? old!
                : kind;
    _timers.remove(id)?.cancel();
    _timers[id] = Timer(const Duration(milliseconds: 250), () {
      _timers.remove(id);
      final k = _pending.remove(id)!;
      _changes.add(TemplateChange(id, k));
    });
  }

  Future<void> stopWatching() async {
    final sub = _watch;
    _watch = null;
    await sub?.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pending.clear();
  }

  Future<List<TemplateInfo>> list() async {
    if (!await exists()) return [];
    final result = <TemplateInfo>[];
    await for (final entity in root.list(followLinks: false)) {
      final info = await get(p.basename(entity.path));
      if (info != null) result.add(info);
    }
    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  /// The manifest as last validated by [get]. A page load asks for many
  /// assets right after its index, which always revalidates through [get].
  Future<TemplateManifest?> manifestFor(String id) async =>
      _cache[id]?.manifest ?? (await get(id))?.manifest;

  Future<TemplateInfo?> get(String id) async {
    if (!validId(id)) return null;
    final folder = Directory(p.join(root.path, id));
    if (await FileSystemEntity.type(folder.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return null;
    }
    // Reject junctions resolving beyond the library too.
    final realRoot = await root.resolveSymbolicLinks();
    if (!_inside(realRoot, await folder.resolveSymbolicLinks())) return null;
    final file = await safeFile(id, 'template.json');
    final stat = await file?.stat();
    var cached = _cache[id];
    if (cached == null ||
        cached.modified != (stat?.modified ?? DateTime(0)) ||
        cached.size != (stat?.size ?? -1)) {
      final problems = <String>[];
      Map raw = {};
      if (file != null) {
        try {
          final parsed = await _json(file, 65536);
          if (parsed is! Map) {
            problems.add('invalidManifest');
          } else {
            raw = parsed;
          }
        } catch (_) {
          problems.add('invalidManifest');
        }
      }
      final manifest = TemplateManifest(id, raw);
      if (raw.containsKey('sdk') && raw['sdk'] != 1) {
        problems.add('unsupportedSdk');
      }
      cached = (
        modified: stat?.modified ?? DateTime(0),
        size: stat?.size ?? -1,
        manifest: manifest,
        problems: problems
      );
      _cache[id] = cached;
    }
    final problems = [...cached.problems];
    final index = await safeFile(id, 'index.html');
    if (index == null) {
      problems.add('missingIndex');
    } else if (await index.length() > 2 * 1024 * 1024) {
      problems.add('oversizedIndex');
    }
    return TemplateInfo(id, cached.manifest, problems, folder.path);
  }

  Future<File?> safeFile(String id, String relative) async {
    if (!validId(id)) return null;
    final folder = Directory(p.join(root.path, id));
    final file = File(p.join(folder.path, relative));
    try {
      if (await FileSystemEntity.type(folder.path, followLinks: false) !=
              FileSystemEntityType.directory ||
          await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file) {
        return null;
      }
      final realFolder = await folder.resolveSymbolicLinks();
      if (!_inside(await root.resolveSymbolicLinks(), realFolder) ||
          !_inside(realFolder, await file.resolveSymbolicLinks())) {
        return null;
      }
      return file;
    } on FileSystemException {
      return null;
    }
  }

  static bool _inside(String parent, String child) {
    if (Platform.isWindows) {
      parent = parent.toLowerCase();
      child = child.toLowerCase();
    }
    return p.isWithin(parent, child);
  }

  Future<dynamic> _json(File f, int max) async {
    if (await f.length() > max) throw const FormatException('size');
    return jsonDecode(await f.readAsString());
  }

  Future<Map<String, Object?>> resolvedValues(String id) async {
    final info = await get(id);
    if (info == null) return {};
    Map raw = {};
    final file = await safeFile(id, 'values.json');
    if (file != null) {
      try {
        final v = await _json(file, 65536);
        if (v is Map) raw = v;
      } catch (_) {/* Use defaults. */}
    }
    return info.manifest.values(raw);
  }

  int _writeSequence = 0;

  Future<void> writeValues(String id, Map values) async {
    final info = await get(id);
    if (info == null) throw ArgumentError.value(id, 'id');
    final target = File(p.join(info.folderPath, 'values.json'));
    final temp = File(p.join(info.folderPath,
        '.values-${DateTime.now().microsecondsSinceEpoch}-${++_writeSequence}.tmp'));
    final encoded = jsonEncode(info.manifest.values(values));
    if (utf8.encode(encoded).length > 65536) {
      throw ArgumentError('Template values exceed 64 KB');
    }
    try {
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(target.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  static const editorLimit = 512 * 1024;
  static const editableFiles = {'index.html', 'style.css', 'script.js'};
  Future<String> _folder(String id) async {
    if (!validId(id)) throw ArgumentError.value(id);
    final folder = Directory(p.join(root.path, id));
    if (await FileSystemEntity.type(folder.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw ArgumentError.value(id);
    }
    final realRoot = await root.resolveSymbolicLinks();
    final real = await folder.resolveSymbolicLinks();
    if (!p.equals(
        Platform.isWindows ? p.dirname(real).toLowerCase() : p.dirname(real),
        Platform.isWindows ? realRoot.toLowerCase() : realRoot)) {
      throw ArgumentError.value(id);
    }
    return folder.path;
  }

  Future<void> deleteTemplate(String id) async {
    final path = await _folder(id);
    await Directory(path).delete(recursive: true);
    _cache.remove(id);
    _changes.add(TemplateChange(id, TemplateChangeKind.list));
  }

  Future<String> createTemplate(String name, Map<String, String> files) async {
    if (name.trim().isEmpty ||
        name.runes.length > 60 ||
        files.keys
            .any((k) => !{...editableFiles, 'template.json'}.contains(k))) {
      throw ArgumentError('Invalid template');
    }
    await ensureRoot();
    final base = templateId(name);
    var id = base;
    var suffix = 2;
    while (await FileSystemEntity.type(p.join(root.path, id),
            followLinks: false) !=
        FileSystemEntityType.notFound) {
      final ending = '-${suffix++}';
      id =
          '${base.substring(0, base.length.clamp(0, 40 - ending.length))}$ending';
    }
    await Directory(p.join(root.path, id)).create();
    try {
      for (final entry in files.entries) {
        await _writeFile(id, entry.key, entry.value);
      }
    } catch (_) {
      await deleteTemplate(id);
      rethrow;
    }
    _changes.add(TemplateChange(id, TemplateChangeKind.list));
    return id;
  }

  Future<String?> readTemplateFile(String id, String name) async {
    if (!editableFiles.contains(name)) throw ArgumentError.value(name);
    await _folder(id);
    final type = await FileSystemEntity.type(p.join(root.path, id, name),
        followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    final file = await safeFile(id, name);
    if (file == null) throw const FileSystemException('Unsafe template file');
    if (await file.length() > editorLimit) throw const FormatException('size');
    final handle = await file.open();
    try {
      final bytes = await handle.read(editorLimit + 1);
      if (bytes.length > editorLimit) throw const FormatException('size');
      return utf8.decode(bytes);
    } finally {
      await handle.close();
    }
  }

  Future<void> writeTemplateFile(
      String id, String name, String contents) async {
    if (!editableFiles.contains(name)) throw ArgumentError.value(name);
    final file = await safeFile(id, name);
    if (file != null && await file.length() > editorLimit) {
      throw const FormatException('size');
    }
    await _writeFile(id, name, contents);
  }

  Future<void> _writeFile(String id, String name, String contents) async {
    if (utf8.encode(contents).length > editorLimit) {
      throw const FormatException('size');
    }
    final folder = await _folder(id);
    final target = p.join(folder, name);
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        (type != FileSystemEntityType.file ||
            await safeFile(id, name) == null)) {
      throw const FileSystemException('Unsafe template file');
    }
    final temp = File(p.join(folder,
        '.edit-${DateTime.now().microsecondsSinceEpoch}-${++_writeSequence}.tmp'));
    try {
      await temp.create(exclusive: true);
      await temp.writeAsString(contents, flush: true);
      await _folder(id);
      await temp.rename(target);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> dispose() async {
    await stopWatching();
    await _changes.close();
    _cache.clear();
  }
}

String templateId(String name, {String fallback = 'template'}) {
  const groups = {
    'a': 'àáâãäåāăąǎǟǡǻȁȃȧḁạảấầẩẫậắằẳẵặ',
    'b': 'ḃḅḇ',
    'c': 'çćĉċčḉ',
    'd': 'ďḋḍḏḑḓ',
    'e': 'èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệ',
    'f': 'ḟ',
    'g': 'ĝğġģǧǵḡ',
    'h': 'ĥȟḣḥḧḩḫẖ',
    'i': 'ìíîïĩīĭįǐȉȋḭḯỉị',
    'j': 'ĵǰ',
    'k': 'ķǩḱḳḵ',
    'l': 'ĺļľḷḹḻḽ',
    'm': 'ḿṁṃ',
    'n': 'ñńņňǹṅṇṉṋ',
    'o': 'òóôõöōŏőơǒǫǭȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợø',
    'p': 'ṕṗ',
    'r': 'ŕŗřȑȓṙṛṝṟ',
    's': 'śŝşšșṡṣṥṧṩ',
    't': 'ţťțṫṭṯṱẗ',
    'u': 'ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữự',
    'v': 'ṽṿ',
    'w': 'ŵẁẃẅẇẉẘ',
    'x': 'ẋẍ',
    'y': 'ýÿŷȳẏẙỳỵỷỹ',
    'z': 'źżžẑẓẕ',
  };
  var value = name.toLowerCase();
  for (final e in groups.entries) {
    for (final rune in e.value.runes) {
      value = value.replaceAll(String.fromCharCode(rune), e.key);
    }
  }
  value = value
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (value.length > 40) {
    value = value.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  }
  return value.isEmpty ? fallback : value;
}
