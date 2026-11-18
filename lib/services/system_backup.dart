import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../settings/settings_document.dart';
import '../settings/settings_model.dart';
import '../settings/settings_notifier.dart';
import '../settings/settings_profiles.dart';
import 'app_logger.dart';
import 'media_library.dart';
import 'templates/template_archive.dart';
import 'templates/template_library.dart';

const _extension = '.airstream-backup';
const _format = 'airstream-backup';
const _settingsName = 'settings.json';
const _manifestName = 'manifest.json';
const _templateLimit = 100 * 1024 * 1024;
const _limits = TemplateArchiveLimits(
  zip: 660 * 1024 * 1024,
  total: 650 * 1024 * 1024,
  count: 5000,
);

class ValidatedSystemBackup {
  ValidatedSystemBackup._(this._staging, this._settings, this.createdAt,
      this.rules, this.templates, this.media, this.networkTemplateNames);

  final Directory _staging;
  final String _settings;
  final DateTime createdAt;
  final int rules, templates, media;
  final List<String> networkTemplateNames;

  List<String> rulesMissingHttpUrls(SettingsModel current) =>
      SettingsProfiles.rulesMissingHttpUrls(SettingsProfiles.keepLocalHttpUrls(
          SettingsDocumentCodec.decode(_settings).settings, current));

  Future<void> dispose() => _cleanup(_staging);
}

class SystemBackup {
  const SystemBackup({
    required this.support,
    required this.templates,
    required this.media,
    this.limits = _limits,
    this.appVersion = _buildVersion,
  });

  static const _buildVersion = String.fromEnvironment('FLUTTER_BUILD_NAME');

  final Directory support;
  final TemplateLibrary templates;
  final MediaLibrary media;
  final TemplateArchiveLimits limits;
  final String appVersion;

  Future<void> exportCurrent(
          String destination, SettingsModel Function() read) =>
      media.withStableFiles(() => export(destination, read()));

  Future<void> export(String destination, SettingsModel settings) =>
      _writeBackup(destination, SettingsProfiles.export(settings));

  Future<void> _writeBackup(String destination, String settings) {
    final templatePath = templates.rootPath;
    final mediaPath = media.directory.path;
    final limits = this.limits;
    final version = appVersion;
    final document = _scrubSettings(settings);
    return Isolate.run(() => _export(
        destination, document, templatePath, mediaPath, limits, version));
  }

  Future<ValidatedSystemBackup> validate(String path) async {
    await support.create(recursive: true);
    final staging = await support.createTemp('.backup-validation-');
    final limits = this.limits;
    try {
      return await Isolate.run(() => _validate(path, staging, limits));
    } catch (_) {
      await _cleanup(staging);
      rethrow;
    }
  }

  Future<void> restore(
          ValidatedSystemBackup backup, SettingsNotifier notifier) =>
      media.withStableFiles(
          () => notifier.restoreBackup((current, commit) async {
                if (!await backup._staging.exists()) {
                  throw const FormatException('invalid');
                }
                final next = SettingsProfiles.applyImportedSettings(
                    SettingsDocumentCodec.decode(backup._settings).settings,
                    current);
                await _safetyBackup(current);
                final oldIds = await _templateIds(templates.root);
                final newIds = await _templateIds(
                    Directory(p.join(backup._staging.path, 'templates')));
                final swaps = <_DirectorySwap>[];
                var keepRollback = false;
                bool? resumeWatching;
                var committed = false;
                try {
                  final templateSwap = await _DirectorySwap.prepare(
                      templates.root, backup._staging, 'templates');
                  swaps.add(templateSwap);
                  // Keep the guide and loose files in the template root.
                  if (await templates.root.exists()) {
                    await for (final entry
                        in templates.root.list(followLinks: false)) {
                      if (entry is Directory &&
                          TemplateLibrary.validId(p.basename(entry.path))) {
                        continue;
                      }
                      await _copyTree(entry, templateSwap.candidate);
                    }
                  }
                  swaps.add(await _DirectorySwap.prepare(
                      media.directory, backup._staging, 'media'));
                  resumeWatching = await templates.pauseForRestore();
                  for (final swap in swaps) {
                    await swap.install();
                  }
                  await commit(next);
                  committed = true;
                  media.clearPendingImports();
                } catch (_) {
                  Object? rollbackError;
                  for (final swap in swaps.reversed) {
                    try {
                      await swap.rollback();
                    } catch (error) {
                      rollbackError ??= error;
                    }
                  }
                  if (rollbackError != null) {
                    keepRollback = true;
                    AppLogger.warning(
                        'Backup rollback failed; original directories retained',
                        error: rollbackError);
                    throw const FormatException('rollback');
                  }
                  rethrow;
                } finally {
                  if (!keepRollback) {
                    for (final swap in swaps) {
                      await _cleanup(swap.workspace);
                    }
                  }
                  if (resumeWatching != null) {
                    try {
                      await templates.refreshAfterRestore(
                        committed ? {...oldIds, ...newIds} : {},
                        resumeWatching: resumeWatching,
                      );
                    } catch (_) {
                      AppLogger.warning(
                          'Could not refresh the template library after restore');
                    }
                  }
                }
              }));

  Future<void> _safetyBackup(SettingsModel current) async {
    final safety = Directory(p.join(support.path, 'safety-backups'));
    await safety.create(recursive: true);
    final previous = await safety
        .list(followLinks: false)
        .where((entry) =>
            entry is File &&
            RegExp(r'^safety-[0-9]{20}\.airstream-backup$')
                .hasMatch(p.basename(entry.path)))
        .cast<File>()
        .toList();
    previous.sort((a, b) => b.path.compareTo(a.path));
    final now = DateTime.now().microsecondsSinceEpoch;
    final last = previous.isEmpty
        ? 0
        : int.parse(p.basename(previous.first.path).substring(7, 27));
    final stamp = (now > last ? now : last + 1).toString().padLeft(20, '0');
    await _writeBackup(
      p.join(safety.path, 'safety-$stamp$_extension'),
      SettingsProfiles.export(current),
    );
    for (final old in previous.skip(2)) {
      await old.delete();
    }
  }
}

/// Removes credentials, including copies in saved profiles.
String _scrubSettings(String source) {
  Object? scrub(Object? value, {bool profileNames = false}) => switch (value) {
        Map() => {
            for (final entry in value.entries)
              if (profileNames ||
                  (entry.key != 'obsPassword' &&
                      entry.key != 'rulesWebhookToken'))
                entry.key: !profileNames &&
                        entry.key == 'url' &&
                        value['type'] == 'http.request'
                    ? ''
                    : scrub(entry.value,
                        profileNames: !profileNames && entry.key == 'profiles'),
          },
        List() => value.map(scrub).toList(),
        _ => value,
      };
  return jsonEncode(scrub(jsonDecode(source)));
}

final _reserved = RegExp(r'^(con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])(?:\.|$)',
    caseSensitive: false);
final _unsafe = RegExp(r'[\\:<>|?*"\x00-\x1f]');

class _ArchivePaths {
  final _paths = <String, ({String name, bool directory})>{};
  final _explicit = <String>{};

  String add(String raw, {required bool directory}) {
    final name =
        directory && raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    final parts = name.split('/');
    if (name.length > 1024 ||
        parts.length > 32 ||
        parts.any((part) =>
            part.isEmpty ||
            part.length > 255 ||
            part.endsWith('.') ||
            part.endsWith(' ') ||
            _unsafe.hasMatch(part) ||
            _reserved.hasMatch(part))) {
      throw const FormatException('path');
    }
    var prefix = '';
    for (var i = 0; i < parts.length; i++) {
      prefix = prefix.isEmpty ? parts[i] : '$prefix/${parts[i]}';
      final key = prefix.toLowerCase();
      final value =
          (name: prefix, directory: i < parts.length - 1 || directory);
      if (_paths.putIfAbsent(key, () => value) != value) {
        throw const FormatException('path');
      }
    }
    if (!_explicit.add(name)) throw const FormatException('path');
    return name;
  }
}

class _Budget {
  _Budget(this.limits);
  final TemplateArchiveLimits limits;
  var total = 0, count = 0, template = 0, media = 0;

  void add(String name, int size) {
    total += size;
    if (name.startsWith('templates/')) template += size;
    if (name.startsWith('media/')) media += size;
    if (++count > limits.count ||
        size < 0 ||
        size > limits.file ||
        total > limits.total ||
        template > _templateLimit ||
        media > MediaLibrary.totalLimit) {
      throw const FormatException('size');
    }
  }
}

String _mediaName(MapEntry<String, Map<String, dynamic>> entry) =>
    'media/${entry.key}.${entry.value['ext']}';

String _nativePath(Directory root, String name) =>
    p.join(root.path, p.joinAll(name.split('/')));

Future<ValidatedSystemBackup> _validate(
    String path, Directory staging, TemplateArchiveLimits limits) async {
  if (File(path).lengthSync() > limits.zip) throw const FormatException('size');
  final input = InputFileStream(path);
  try {
    if (input.length > limits.zip) throw const FormatException('size');
    final paths = _ArchivePaths();
    final budget = _Budget(limits);
    final stored = <String>{};
    final ids = <String>{};
    for (final header in ZipDirectory().headers(input, verify: true)) {
      final directory = header.filename.endsWith('/');
      final name = paths.add(header.filename, directory: directory);
      budget.add(name, header.uncompressedSize);
      final parts = name.split('/');
      final mode = (header.externalFileAttributes >> 16) & 0xf000;
      if (mode != 0 && mode != (directory ? 0x4000 : 0x8000)) {
        throw const FormatException('path');
      }
      final local = input.subset(position: header.localHeaderOffset);
      if (local.length < 30 || local.readUint32() != 0x04034b50) {
        throw const FormatException('invalid');
      }
      local.skip(2);
      final localFlags = local.readUint16();
      final localMethod = local.readUint16();
      local.skip(16);
      final nameLength = local.readUint16();
      local.skip(2);
      if (nameLength > local.length ||
          utf8.decode(local.readBytes(nameLength).toUint8List()) !=
              header.filename) {
        throw const FormatException('path');
      }
      final data = header.file!;
      if (data.filename != header.filename) throw const FormatException('path');
      if (directory && header.uncompressedSize != 0) {
        throw const FormatException('invalid');
      }
      if (parts.first == 'templates' &&
          parts.length >= 2 &&
          TemplateLibrary.validId(parts[1]) &&
          (directory || parts.length >= 3)) {
        ids.add(parts[1]);
      } else if (directory ||
          !(name == _manifestName ||
              name == _settingsName ||
              (parts.length == 2 &&
                  parts.first == 'media' &&
                  RegExp(r'^[0-9a-f]{16}\.[a-z0-9]+$').hasMatch(parts.last)))) {
        continue;
      }

      if (directory) {
        Directory(_nativePath(staging, name)).createSync(recursive: true);
        continue;
      }
      if ((header.generalPurposeBitFlag | localFlags) & 1 != 0 ||
          localMethod != header.compressionMethod ||
          (header.compressionMethod != 0 && header.compressionMethod != 8)) {
        throw const FormatException('invalid');
      }
      final target = File(_nativePath(staging, name));
      target.parent.createSync(recursive: true);
      final output = OutputFileStream(target.path, bufferSize: 65536);
      try {
        // The verified ZIP reader enforces the declared size during
        // decompression and checks the resulting length and CRC.
        data
          ..verify = true
          ..throwOnError = true
          ..decompress(output);
        if (output.length != header.uncompressedSize) {
          throw const FormatException('invalid');
        }
      } finally {
        output.closeSync();
      }
      stored.add(name);
    }

    if (!stored.containsAll([_manifestName, _settingsName])) {
      throw const FormatException('invalid');
    }
    final manifest = jsonDecode(
        File(p.join(staging.path, _manifestName)).readAsStringSync());
    if (manifest is! Map || manifest['format'] != _format) {
      throw const FormatException('invalid');
    }
    if (manifest['version'] is! int || manifest['version'] != 1) {
      throw const FormatException('version');
    }
    final timestamp = manifest['createdAt'];
    final createdAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
    final counts = manifest['counts'];
    final source = _scrubSettings(
        File(p.join(staging.path, _settingsName)).readAsStringSync());
    final decoded = SettingsDocumentCodec.decode(source);
    if (decoded.requiresRewrite ||
        createdAt == null ||
        counts is! Map ||
        counts['rules'] is! int ||
        counts['rules'] != decoded.settings.rules.length ||
        counts['templates'] is! int ||
        counts['templates'] != ids.length ||
        counts['media'] is! int ||
        counts['media'] != decoded.settings.mediaLibrary.length) {
      throw const FormatException('invalid');
    }
    final entries = decoded.settings.mediaLibrary.entries;
    final expectedMedia = entries.map(_mediaName).toSet();
    for (final name in stored.where((name) => name.startsWith('media/'))) {
      if (!expectedMedia.contains(name)) {
        File(_nativePath(staging, name)).deleteSync();
      }
    }
    for (final entry in entries) {
      final asset = File(_nativePath(staging, _mediaName(entry)));
      if (!asset.existsSync() ||
          asset.lengthSync() != entry.value['bytes'] ||
          await MediaLibrary.inspect(asset) != entry.value['kind']) {
        throw const FormatException('media');
      }
    }
    final library =
        TemplateLibrary(Directory(p.join(staging.path, 'templates')));
    final networkTemplateNames = <String>[];
    try {
      for (final id in ids.toList()..sort()) {
        final manifest = await library.manifestFor(id);
        if (manifest != null && manifest.network) {
          networkTemplateNames.add(manifest.name);
        }
      }
    } finally {
      await library.dispose();
    }
    return ValidatedSystemBackup._(
        staging,
        source,
        createdAt,
        decoded.settings.rules.length,
        ids.length,
        entries.length,
        List.unmodifiable(networkTemplateNames));
  } on ArchiveException {
    throw const FormatException('invalid');
  } finally {
    input.closeSync();
  }
}

Future<void> _export(String destination, String settings, String templatePath,
    String mediaPath, TemplateArchiveLimits limits, String appVersion) async {
  final model = SettingsDocumentCodec.decode(settings).settings;
  final templateRoot = Directory(templatePath);
  final mediaRoot = Directory(mediaPath);
  final ids = await _templateIds(templateRoot);
  final target = File(destination);
  final destinationFolder = await target.parent.resolveSymbolicLinks();
  for (final library in [templateRoot, mediaRoot]) {
    if (!await library.exists()) continue;
    final root = await library.resolveSymbolicLinks();
    if (p.equals(root, destinationFolder) ||
        p.isWithin(root, destinationFolder)) {
      throw const FormatException('path');
    }
  }
  final workspace = await target.parent.createTemp('.airstream-export-');
  try {
    final output = File(p.join(workspace.path, 'backup.zip'));
    final stream = OutputFileStream(output.path);
    final encoder = ZipFileEncoder()
      ..createWithStream(stream, level: ZipFileEncoder.store);
    try {
      final budget = _Budget(limits);
      final paths = _ArchivePaths();
      void add(ArchiveFile entry) {
        paths.add(entry.name, directory: entry.isDirectory);
        budget.add(entry.name, entry.size);
        encoder.addArchiveFile(entry);
      }

      Future<void> addFile(String name, File file) async {
        paths.add(name, directory: false);
        budget.add(name, await file.length());
        encoder.addFileSync(file, name);
      }

      Future<void> addTemplate(Directory folder, String name) async {
        add(ArchiveFile.directory(name));
        await for (final entity in folder.list(followLinks: false)) {
          final child = '$name/${p.basename(entity.path)}';
          if (!await _inside(folder, entity)) {
            throw const FormatException('path');
          }
          if (entity is Directory) {
            await addTemplate(entity, child);
          } else if (entity is File) {
            await addFile(child, entity);
          } else {
            throw const FormatException('path');
          }
        }
      }

      final backedUpMedia = <String, Map<String, dynamic>>{};
      for (final entry in model.mediaLibrary.entries) {
        final name = _mediaName(entry);
        final asset = File(p.join(mediaPath, p.posix.basename(name)));
        if (await FileSystemEntity.type(asset.path, followLinks: false) ==
            FileSystemEntityType.notFound) {
          continue;
        }
        if (await MediaLibrary.inspect(asset) != entry.value['kind'] ||
            await FileSystemEntity.type(mediaPath, followLinks: false) !=
                FileSystemEntityType.directory ||
            !await _inside(mediaRoot, asset) ||
            await asset.length() != entry.value['bytes']) {
          throw const FormatException('media');
        }
        await addFile(name, asset);
        backedUpMedia[entry.key] = entry.value;
      }

      add(ArchiveFile.string(
          _manifestName,
          jsonEncode({
            'format': _format,
            'version': 1,
            if (appVersion.isNotEmpty) 'appVersion': appVersion,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'counts': {
              'rules': model.rules.length,
              'templates': ids.length,
              'media': backedUpMedia.length,
            },
          })));
      final document = jsonDecode(settings) as Map<String, dynamic>;
      (document['settings'] as Map)['mediaLibrary'] = backedUpMedia;
      add(ArchiveFile.string(_settingsName, jsonEncode(document)));
      for (final id in ids) {
        final folder = Directory(p.join(templatePath, id));
        if (!await _inside(templateRoot, folder)) {
          throw const FormatException('path');
        }
        await addTemplate(folder, 'templates/$id');
      }
      encoder.closeSync();
    } finally {
      stream.closeSync();
    }
    if (await output.length() > limits.zip) throw const FormatException('size');
    await output.rename(target.path);
  } finally {
    await _cleanup(workspace);
  }
}

Future<Set<String>> _templateIds(Directory root) async {
  final type = await FileSystemEntity.type(root.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return {};
  if (type != FileSystemEntityType.directory) {
    throw const FormatException('path');
  }
  return {
    await for (final entry in root.list(followLinks: false))
      if (entry is Directory && TemplateLibrary.validId(p.basename(entry.path)))
        p.basename(entry.path),
  };
}

Future<bool> _inside(Directory parent, FileSystemEntity child) async =>
    p.isWithin(await parent.resolveSymbolicLinks(),
        await child.resolveSymbolicLinks());

Future<void> _copyTree(FileSystemEntity entry, Directory parent) async {
  final dest = p.join(parent.path, p.basename(entry.path));
  if (entry is File && await _inside(entry.parent, entry)) {
    await entry.copy(dest);
  } else if (entry is Directory && await _inside(entry.parent, entry)) {
    final folder = await Directory(dest).create();
    await for (final child in entry.list(followLinks: false)) {
      await _copyTree(child, folder);
    }
  } else {
    throw const FormatException('path');
  }
}

Future<void> _cleanup(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException {
    AppLogger.warning('Could not clean up backup workspace');
  }
}

class _DirectorySwap {
  _DirectorySwap(this.target, this.workspace)
      : candidate = Directory(p.join(workspace.path, 'new')),
        original = Directory(p.join(workspace.path, 'original'));

  final Directory target, workspace, candidate, original;
  bool _savedOriginal = false, _installed = false;

  static Future<_DirectorySwap> prepare(
      Directory target, Directory staging, String area) async {
    await target.parent.create(recursive: true);
    final swap = _DirectorySwap(
        target, await target.parent.createTemp('.airstream-restore-'));
    try {
      await swap.candidate.create();
      final source = Directory(p.join(staging.path, area));
      if (await source.exists()) {
        await for (final entry in source.list(followLinks: false)) {
          await _copyTree(entry, swap.candidate);
        }
      }
      return swap;
    } catch (_) {
      await _cleanup(swap.workspace);
      rethrow;
    }
  }

  Future<void> install() async {
    switch (await FileSystemEntity.type(target.path, followLinks: false)) {
      case FileSystemEntityType.directory:
        await _rename(target, original.path);
        _savedOriginal = true;
      case FileSystemEntityType.notFound:
        break;
      default:
        throw const FormatException('path');
    }
    await _rename(candidate, target.path);
    _installed = true;
  }

  Future<void> rollback() async {
    if (_installed) await _rename(target, candidate.path);
    if (_savedOriginal) await _rename(original, target.path);
  }

  static Future<void> _rename(Directory from, String destination) async {
    for (var attempt = 1;; attempt++) {
      try {
        await from.rename(destination);
        return;
      } on FileSystemException {
        if (attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 40 * attempt));
      }
    }
  }
}
