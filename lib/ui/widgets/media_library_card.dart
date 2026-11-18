import 'package:airstream/settings/alert_type_options.dart';
import 'settings_controls.dart';
import 'dart:io';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/settings/media_library_entries.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class MediaLibraryCard extends ConsumerStatefulWidget {
  const MediaLibraryCard({super.key});
  @override
  ConsumerState<MediaLibraryCard> createState() => _MediaLibraryCardState();
}

class _MediaLibraryCardState extends ConsumerState<MediaLibraryCard> {
  bool _busy = false;
  final _errors = <String>[];
  String _reason(AppLocalizations l, String reason) => switch (reason) {
        'size' => l.mediaRejectSize,
        'total' => l.mediaRejectTotal,
        _ => l.mediaRejectType,
      };
  Future<void> _add() async {
    setState(() {
      _busy = true;
      _errors.clear();
    });
    final l = AppLocalizations.of(context)!;
    try {
      final files = await openFiles(acceptedTypeGroups: [
        XTypeGroup(
            label: l.mediaImage,
            extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp']),
        XTypeGroup(label: l.mediaVideo, extensions: const ['mp4', 'webm']),
        XTypeGroup(
            label: l.mediaAudio, extensions: const ['wav', 'mp3', 'ogg']),
      ]);
      final library = await ref.read(mediaLibraryProvider.future);
      for (final file in files) {
        try {
          final entry = await library.import(file.path);
          final s = ref.read(settingsProvider);
          await ref.read(settingsProvider.notifier).update(s.copyWith(
              mediaLibrary: {...s.mediaLibrary, entry.key: entry.value}));
        } on FormatException catch (e) {
          _errors.add('${file.name}: ${_reason(l, e.message)}');
        } on FileSystemException {
          _errors.add('${file.name}: ${l.mediaRejectType}');
        }
      }
    } catch (_) {
      _errors.add(l.mediaRejectType);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id) async {
    setState(() => _busy = true);
    try {
      await (await ref.read(mediaLibraryProvider.future)).delete(id);
      final s = ref.read(settingsProvider);
      final options = AlertTypeOptions.sanitize(s.alertTypeOptions);
      void detach(Map<String, dynamic> v) {
        if (v['media'] == id) {
          v.remove('media');
          v.remove('mediaAudio');
        }
        if (v['soundMediaId'] == id) {
          v.remove('soundMediaId');
          if (v['sound'] == 'library') v.remove('sound');
        }
      }

      for (final option in options.values) {
        detach(option);
        for (final tier in AlertTypeOptions.tiers(option)) {
          detach(tier);
        }
      }
      await ref.read(settingsProvider.notifier).update(s.copyWith(
          mediaLibrary: {...s.mediaLibrary}..remove(id),
          alertTypeOptions: AlertTypeOptions.sanitize(options)));
    } catch (_) {
      if (mounted) _errors.add(AppLocalizations.of(context)!.mediaRejectType);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries =
        MediaLibraryEntries.sanitize(ref.watch(settingsProvider).mediaLibrary);
    final service = ref.watch(mediaLibraryProvider).valueOrNull;
    final used = entries.values.fold<int>(0, (n, e) => n + (e['bytes'] as int));
    return UiCard(
        title: l.mediaLibraryTitle,
        icon: Icons.perm_media_outlined,
        children: [
          Text(l.mediaUsage('${(used / 1048576).toStringAsFixed(1)} MB'),
              key: const Key('media-usage'),
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  style: primarySettingsStyle(),
                  key: const Key('media-add'),
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add),
                  label: Text(l.mediaAdd))),
          for (final error in _errors)
            Text(error, style: const TextStyle(color: Color(0xFFFFB15C))),
          for (final e in entries.entries)
            Padding(
                key: Key('media-item-${e.key}'),
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: [
                  SizedBox(
                      width: 40,
                      height: 40,
                      child: e.value['kind'] == 'image' && service != null
                          ? FutureBuilder<File?>(
                              future: service.fileFor(e),
                              builder: (context, snapshot) =>
                                  snapshot.data == null
                                      ? const Icon(Icons.image_outlined)
                                      : Image.file(snapshot.data!,
                                          cacheWidth: 96,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, error, stack) =>
                                              const Icon(Icons.image_outlined)))
                          : Icon(e.value['kind'] == 'video'
                              ? Icons.videocam_outlined
                              : Icons.audio_file_outlined)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(e.value['name'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white)),
                        Text(
                            '${(e.value['bytes'] / 1048576).toStringAsFixed(1)} MB · ${switch (e.value['kind']) {
                              'image' => l.mediaImage,
                              'video' => l.mediaVideo,
                              _ => l.mediaAudio
                            }}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ])),
                  IconButton(
                      key: Key('media-delete-${e.key}'),
                      tooltip: l.mediaDelete,
                      color: const Color(0xFFFF6B6B),
                      onPressed: _busy ? null : () => _delete(e.key),
                      icon: const Icon(Icons.delete_outline, size: 18)),
                ])),
        ]);
  }
}
