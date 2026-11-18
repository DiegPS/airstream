import 'package:airstream/application/app_providers.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/system_backup.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _accent = Color(0xFF53FC18);

/// Saves the current setup under a name and switches between setups.
class SettingsProfilesCard extends ConsumerStatefulWidget {
  const SettingsProfilesCard({super.key});

  @override
  ConsumerState<SettingsProfilesCard> createState() =>
      _SettingsProfilesCardState();
}

class _SettingsProfilesCardState extends ConsumerState<SettingsProfilesCard> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _notify(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1600),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final profiles = ref.watch(settingsProvider.select((s) => s.profiles));
    final notifier = ref.read(settingsProvider.notifier);
    final names = profiles.keys.toList()..sort();
    final canSave = _name.text.trim().isNotEmpty &&
        (profiles.containsKey(_name.text.trim()) ||
            profiles.length < SettingsProfiles.maxProfiles);

    return UiCard(
      key: const Key('profiles-card'),
      title: l.profilesTitle,
      icon: Icons.bookmarks_outlined,
      description: l.profilesDescription,
      children: [
        for (final name in names)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline_rounded,
                    size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                TextButton(
                  key: Key('profile-apply-$name'),
                  onPressed: () async {
                    final current = ref.read(settingsProvider);
                    await notifier.update(
                      SettingsProfiles.apply(current, profiles[name]!),
                    );
                    if (mounted) _notify(l.profileApplied(name));
                  },
                  child: Text(l.profileApply),
                ),
                IconButton(
                  key: Key('profile-delete-$name'),
                  tooltip: l.profileDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: Colors.white38,
                  onPressed: () => notifier.update(
                    SettingsProfiles.delete(ref.read(settingsProvider), name),
                  ),
                ),
              ],
            ),
          ),
        if (names.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.profilesEmpty,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('profile-name'),
                controller: _name,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.profileNameHint,
                  hintStyle:
                      const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              key: const Key('profile-save'),
              onPressed: canSave
                  ? () async {
                      final name = _name.text.trim();
                      await notifier.update(SettingsProfiles.save(
                        ref.read(settingsProvider),
                        name,
                      ));
                      _name.clear();
                      if (mounted) {
                        setState(() {});
                        _notify(l.profileSaved(name));
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF262626),
              ),
              child: Text(l.profileSave),
            ),
          ],
        ),
      ],
    );
  }
}

/// Exports, imports and resets the settings.
class SettingsBackupCard extends ConsumerStatefulWidget {
  const SettingsBackupCard({super.key});

  @override
  ConsumerState<SettingsBackupCard> createState() => _SettingsBackupCardState();
}

class _SettingsBackupCardState extends ConsumerState<SettingsBackupCard> {
  bool _busy = false;

  static const _jsonType = XTypeGroup(label: 'JSON', extensions: ['json']);

  XTypeGroup _backupType(AppLocalizations l, {bool import = false}) =>
      XTypeGroup(label: l.backupFileType, extensions: [
        'airstream-backup',
        if (import) 'zip',
      ]);

  Future<SystemBackup> _service() async {
    final (support, templates, media) = await (
      getApplicationSupportDirectory(),
      ref.read(templateLibraryProvider.future),
      ref.read(mediaLibraryProvider.future),
    ).wait;
    return SystemBackup(
      support: support,
      templates: templates,
      media: media,
    );
  }

  String _errorMessage(AppLocalizations l, Object error, String fallback) =>
      switch (error) {
        FormatException(message: 'version') => l.backupUnsupportedVersion,
        FormatException(message: 'path') => l.backupUnsafePath,
        FormatException(message: 'size') => l.backupSizeLimit,
        FormatException(message: 'media') => l.backupMediaInvalid,
        FormatException(message: 'rollback') => l.backupRollbackError,
        FormatException() => l.backupInvalid,
        _ => fallback,
      };

  Future<void> _runBackup(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _review(
    AppLocalizations l,
    ValidatedSystemBackup backup,
    Future<void> Function() restore,
  ) {
    var applying = false;
    final created = backup.createdAt.toLocal();
    final dates = MaterialLocalizations.of(context);
    final date = dates.formatMediumDate(created);
    final time = dates.formatTimeOfDay(TimeOfDay.fromDateTime(created));
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, refresh) => PopScope(
          canPop: !applying,
          child: AlertDialog(
            scrollable: true,
            title: Text(l.backupRestoreEverything),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.backupRestoreContents(backup.rules, backup.templates,
                    backup.media, '$date $time')),
                const SizedBox(height: 12),
                Text(l.backupRestoreReview),
                if (applying) const LinearProgressIndicator(),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    applying ? null : () => Navigator.pop(dialogContext, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                key: const Key('backup-restore-confirm'),
                onPressed: applying
                    ? null
                    : () async {
                        refresh(() => applying = true);
                        try {
                          await restore();
                        } finally {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        }
                      },
                child: Text(l.backupRestoreConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(settingsProvider.notifier);
    void notify(String text) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1800),
      ));

    Future<void> export() async {
      final location = await getSaveLocation(
        suggestedName: 'airstream-settings.json',
        acceptedTypeGroups: const [_jsonType],
      );
      if (location == null) return;
      try {
        await File(location.path).writeAsString(
          SettingsProfiles.export(ref.read(settingsProvider)),
        );
        if (context.mounted) notify(l.settingsExported);
      } catch (error, stack) {
        AppLogger.warning('Settings export failed',
            error: error, stackTrace: stack);
        if (context.mounted) notify(l.settingsExportFailed);
      }
    }

    Future<void> import() async {
      final file = await openFile(acceptedTypeGroups: const [_jsonType]);
      if (file == null) return;
      try {
        final imported = SettingsProfiles.import(
          await file.readAsString(),
          ref.read(settingsProvider),
        );
        await notifier.update(imported);
        if (context.mounted) notify(l.settingsImported);
      } catch (error, stack) {
        AppLogger.warning('Settings import failed',
            error: error, stackTrace: stack);
        if (context.mounted) notify(l.settingsImportFailed);
      }
    }

    Future<void> exportEverything() => _runBackup(() async {
          try {
            final location = await getSaveLocation(
              suggestedName: 'airstream.airstream-backup',
              acceptedTypeGroups: [_backupType(l)],
            );
            if (location == null || !mounted) return;
            final service = await _service();
            await notifier.ready;
            if (!mounted) return;
            final path = location.path;
            await service.exportCurrent(
              path.toLowerCase().endsWith('.airstream-backup')
                  ? path
                  : '$path.airstream-backup',
              () => ref.read(settingsProvider),
            );
            if (context.mounted) notify(l.backupExportDone);
          } catch (error, stack) {
            AppLogger.warning('Full backup export failed', stackTrace: stack);
            if (context.mounted) {
              notify(_errorMessage(l, error, l.backupExportError));
            }
          }
        });

    Future<void> restoreEverything() => _runBackup(() async {
          ValidatedSystemBackup? backup;
          try {
            final file = await openFile(
                acceptedTypeGroups: [_backupType(l, import: true)]);
            if (file == null || !mounted) return;
            final service = await _service();
            final validated = backup = await service.validate(file.path);
            if (!mounted) return;
            Object? failure;
            final applied = await _review(l, validated, () async {
              try {
                await service.restore(validated, notifier);
              } catch (error, stack) {
                AppLogger.warning('Full backup restore failed',
                    stackTrace: stack);
                failure = error;
              }
            });
            if (!context.mounted || applied != true) return;
            final error = failure;
            notify(error == null
                ? l.backupRestoreDone
                : _errorMessage(l, error, l.backupRestoreError));
          } catch (error, stack) {
            AppLogger.warning('Full backup validation failed',
                stackTrace: stack);
            if (context.mounted) {
              notify(_errorMessage(l, error, l.backupRestoreError));
            }
          } finally {
            await backup?.dispose();
          }
        });

    Future<void> reset() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF181818),
          title: Text(l.settingsResetTitle),
          content: Text(l.settingsResetConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const Key('settings-reset-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.settingsReset),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await notifier.update(
        SettingsProfiles.resetToDefaults(ref.read(settingsProvider)),
      );
      if (context.mounted) notify(l.settingsResetDone);
    }

    return UiCard(
      key: const Key('backup-card'),
      title: l.settingsBackupTitle,
      icon: Icons.save_alt_rounded,
      description: l.settingsBackupDescription,
      children: [
        if (_busy) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('settings-export'),
              onPressed: _busy ? null : export,
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: Text(l.settingsExport),
            ),
            OutlinedButton.icon(
              key: const Key('settings-import'),
              onPressed: _busy ? null : import,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(l.settingsImport),
            ),
            OutlinedButton.icon(
              key: const Key('backup-export-everything'),
              onPressed: _busy ? null : exportEverything,
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: Text(l.backupExportEverything),
            ),
            OutlinedButton.icon(
              key: const Key('backup-restore-everything'),
              onPressed: _busy ? null : restoreEverything,
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: Text(l.backupRestoreEverything),
            ),
            TextButton.icon(
              key: const Key('settings-reset'),
              onPressed: _busy ? null : reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text(l.settingsReset),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF8A80),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
