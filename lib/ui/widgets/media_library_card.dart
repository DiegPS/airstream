import 'dart:async';
import 'dart:io';

import 'package:airstream/services/app_logger.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'settings_controls.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/native_audio_playback_service.dart';
import 'package:airstream/services/windows_video_thumbnail.dart';
import 'package:airstream/settings/media_library_entries.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

final mediaPreviewAudioProvider =
    Provider<NativeAudioPlaybackService Function()>(
        (_) => NativeAudioPlaybackService.new);

class MediaLibraryCard extends ConsumerStatefulWidget {
  const MediaLibraryCard({super.key});
  @override
  ConsumerState<MediaLibraryCard> createState() => _MediaLibraryCardState();
}

class _MediaLibraryCardState extends ConsumerState<MediaLibraryCard> {
  bool _busy = false;
  String _query = '';

  /// Thumbnail lookups, kept across rebuilds (each search keystroke rebuilds
  /// the list). Keyed by id and extension, which identify the stored file.
  final _thumbnails = <String, Future<File?>>{};
  Future<File?> _thumbnail(
          MediaLibrary service, MapEntry<String, Map<String, dynamic>> e) =>
      _thumbnails.putIfAbsent(
          '${e.key}.${e.value['ext']}', () => service.fileFor(e));
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
          await library.import(file.path, onImported: (entry) {
            final s = ref.read(settingsProvider);
            return ref.read(settingsProvider.notifier).update(s.copyWith(
                mediaLibrary: {...s.mediaLibrary, entry.key: entry.value}));
          });
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
      final library = await ref.read(mediaLibraryProvider.future);
      await library.delete(id, onDeleted: () => _removeReferences(id));
    } catch (_) {
      if (mounted) _errors.add(AppLocalizations.of(context)!.mediaRejectType);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeReferences(String id) async {
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
        highlightSounds: {...s.highlightSounds}
          ..removeWhere((_, source) => source == id),
        alertTypeOptions: AlertTypeOptions.sanitize(options)));
  }

  Future<void> _rename(MapEntry<String, Map<String, dynamic>> entry) async {
    final l = AppLocalizations.of(context)!;
    final form = GlobalKey<FormState>();
    var name = entry.value['name'] as String;
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          if (form.currentState!.validate()) Navigator.pop(dialogContext, name);
        }

        return AlertDialog(
          title: Text(l.mediaRename),
          content: SizedBox(
            width: 300,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  settingsLabel(l.mediaDisplayName),
                  TextFormField(
                    key: const Key('media-rename-name'),
                    initialValue: name,
                    autofocus: true,
                    maxLength: 80,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: settingsInput(),
                    onChanged: (value) => name = value,
                    onFieldSubmitted: (_) => submit(),
                    validator: (value) =>
                        MediaLibraryEntries.displayName(value ?? '') == null
                            ? l.mediaRenameInvalid
                            : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: secondarySettingsStyle(),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              key: const Key('media-rename-save'),
              style: primarySettingsStyle(),
              onPressed: submit,
              child: Text(l.ruleLabel('ksave')),
            ),
          ],
        );
      },
    );
    if (!mounted || renamed == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(settingsProvider.notifier).renameMedia(entry.key, renamed);
    } catch (_) {
      _errors.add(l.mediaRenameFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(
    MediaLibrary library,
    MapEntry<String, Map<String, dynamic>> entry,
  ) async {
    final kind = entry.value['kind'];
    final player =
        kind == 'audio' ? ref.read(mediaPreviewAudioProvider)() : null;
    final volume = ref.read(settingsProvider).alertSoundVolume / 100;
    final file = library.fileFor(entry);
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return AlertDialog(
            title: Text(entry.value['name'] as String),
            scrollable: true,
            content: FutureBuilder(
              future: file,
              builder: (_, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                final asset = snapshot.data;
                if (asset == null) return Text(l.mediaPreviewUnavailable);
                if (player != null) {
                  return _AudioPreview(
                      player: player, file: asset, volume: volume);
                }
                return SizedBox(
                  width: 256,
                  height: 160,
                  child: kind == 'video'
                      ? _VideoPreview(file: asset)
                      : Image.file(
                          asset,
                          cacheWidth: 512,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Text(l.mediaPreviewUnavailable),
                        ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(MaterialLocalizations.of(context).closeButtonLabel),
              ),
            ],
          );
        },
      );
    } finally {
      try {
        await player?.dispose();
      } catch (_) {
        AppLogger.warning('Could not close the media audio preview');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries =
        MediaLibraryEntries.sanitize(ref.watch(settingsProvider).mediaLibrary);
    final service = ref.watch(mediaLibraryProvider).valueOrNull;
    final matches = MediaLibraryEntries.search(entries, _query).toList();
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
          // Searching an empty library is pointless; the box appears with
          // the first file. Same height as every other settings field.
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('media-search'),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (value) => setState(() => _query = value),
              decoration: settingsInput(hint: l.mediaSearch).copyWith(
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 16, color: Colors.white38),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 0),
              ),
            ),
          ],
          if (_query.trim().isNotEmpty && matches.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l.mediaNoMatches),
            ),
          for (final e in matches)
            Padding(
                key: Key('media-item-${e.key}'),
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: [
                  SizedBox(
                      width: 40,
                      height: 40,
                      child: e.value['kind'] == 'image' && service != null
                          ? FutureBuilder<File?>(
                              future: _thumbnail(service, e),
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
                    key: Key('media-preview-${e.key}'),
                    tooltip: l.mediaPreview,
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy || service == null
                        ? null
                        : () => _preview(service, e),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                  ),
                  IconButton(
                    key: Key('media-rename-${e.key}'),
                    tooltip: l.mediaRename,
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : () => _rename(e),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    key: Key('media-delete-${e.key}'),
                    tooltip: l.mediaDelete,
                    visualDensity: VisualDensity.compact,
                    color: const Color(0xFFFF6B6B),
                    onPressed: _busy ? null : () => _delete(e.key),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ])),
        ]);
  }
}

class _AudioPreview extends StatefulWidget {
  const _AudioPreview(
      {required this.player, required this.file, required this.volume});
  final NativeAudioPlaybackService player;
  final File file;
  final double volume;

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  var _playing = false;
  var _failed = false;

  Future<void> _play() async {
    setState(() {
      _playing = true;
      _failed = false;
    });
    try {
      await widget.player.playFile(widget.file,
          volume: widget.volume, timeout: const Duration(minutes: 2));
    } on TimeoutException {
      // The preview ends after two minutes.
    } catch (_) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _stop() async {
    try {
      await widget.player.stop();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton.icon(
        key: const Key('media-audio-preview-toggle'),
        onPressed: _playing ? _stop : _play,
        icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
        label: Text(_playing ? l.mediaPreviewStop : l.mediaPreviewPlay),
      ),
      if (_failed) Text(l.mediaPreviewUnavailable),
    ]);
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.file});
  final File file;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final _thumbnail = videoThumbnail(widget.file);

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _thumbnail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          final unavailable =
              Text(AppLocalizations.of(context)!.mediaPreviewUnavailable);
          return bytes == null
              ? Center(child: unavailable)
              : Image.memory(bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => unavailable);
        },
      );
}
