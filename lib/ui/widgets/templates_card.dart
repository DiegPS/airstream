import 'settings_controls.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:airstream/services/templates/template_archive.dart';
import 'package:airstream/services/templates/gallery/gallery_catalog.dart';
import 'template_fields.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/services/templates/template_starters.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _explore(String target) async {
  await Process.start('explorer', [target], mode: ProcessStartMode.detached);
}

class TemplatesCard extends ConsumerStatefulWidget {
  const TemplatesCard({super.key});
  @override
  ConsumerState<TemplatesCard> createState() => _TemplatesCardState();
}

class _TemplatesCardState extends ConsumerState<TemplatesCard> {
  TemplateLibrary? _library;
  StreamSubscription<TemplateChange>? _subscription;
  List<TemplateInfo> _items = [];
  bool _busy = false;
  String? _notice;
  int _generation = 0;
  Future<void> _refresh() async {
    final generation = ++_generation;
    try {
      final items = await _library!.list();
      if (mounted && generation == _generation) setState(() => _items = items);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _notice = AppLocalizations.of(context)!.templatesFailed);
      }
    }
  }

  Future<void> _action(Future<void> Function() run) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await run();
    } on FormatException catch (error) {
      if (mounted) setState(() => _notice = _reason(error.message));
    } catch (_) {
      if (mounted) {
        setState(() => _notice = AppLocalizations.of(context)!.templatesFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _url(String id) =>
      '${ref.read(overlayUrlProvider) ?? 'http://localhost:${ref.read(settingsProvider).overlayPort}'}/custom/$id/';
  Future<void> _new() async {
    final choice = await showDialog<(String, TemplateStarter)>(
        context: context, builder: (_) => const _NewTemplateDialog());
    if (choice == null) return;
    await _library!
        .createTemplate(choice.$1, templateStarterFiles(choice.$2, choice.$1));
    await _refresh();
  }

  Future<void> _addGallery(GalleryItem item, String language) async {
    await const TemplateArchive().installGallery(_library!, item, language);
    await _refresh();
  }

  Widget _gallery(AppLocalizations l, String? url, bool enabled) => Column(
        key: const Key('template-gallery'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 28),
          settingsLabel(l.templatesGallery),
          // Said once for the whole gallery, not under every item.
          if (url == null)
            Text(l.galleryPreviewUnavailable,
                key: const Key('gallery-preview-unavailable'),
                style: settingsHintStyle),
          for (final item in galleryCatalog.values)
            Container(
              key: Key('gallery-item-${item.id}'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(item.name(l), style: settingsItemTitleStyle),
                  const SizedBox(height: 2),
                  Text(item.description(l), style: settingsHintStyle),
                  const SizedBox(height: 4),
                  Text('${item.width}×${item.height}',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        key: Key('gallery-preview-${item.id}'),
                        onPressed: url == null || _busy
                            ? null
                            : () => _action(() =>
                                _explore('$url/gallery/${item.id}/?demo=1')),
                        child: Text(l.templatesPreview),
                      ),
                      TextButton(
                        key: Key('gallery-add-${item.id}'),
                        onPressed: enabled
                            ? () =>
                                _action(() => _addGallery(item, l.localeName))
                            : null,
                        child: Text(l.galleryAdd),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );

  Widget? _galleryUpdate(TemplateInfo info, AppLocalizations l, bool enabled) {
    final source = info.manifest.gallery;
    if (source == null) return null;
    final item = galleryCatalog[source.id];
    if (item == null || source.version >= item.version) return null;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.galleryNewVersion),
        TextButton(
          key: Key('gallery-add-again-${info.id}'),
          onPressed: enabled
              ? () => _action(() => _addGallery(item, l.localeName))
              : null,
          child: Text(l.galleryAddAgain),
        ),
      ],
    );
  }

  String _reason(String reason) {
    final l = AppLocalizations.of(context)!;
    return switch (reason) {
      'zip' => l.templateRejectZip,
      'count' => l.templateRejectCount,
      'total' => l.templateRejectTotal,
      'libraryTotal' => l.templateLibrarySizeLimit,
      'file' => l.templateRejectFile,
      'path' => l.templateRejectPath,
      'link' => l.templateRejectLink,
      'type' => l.templateRejectType,
      'layout' => l.templateRejectLayout,
      'index' => l.templateRejectIndex,
      'indexSize' => l.templateRejectIndexSize,
      _ => l.templateRejectSize,
    };
  }

  static const _zipGroup = XTypeGroup(label: 'ZIP', extensions: ['zip']);
  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: [_zipGroup]);
    if (file == null) return;
    final archive = await const TemplateArchive().validate(file.path);
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                key: const Key('template-import-dialog'),
                title: Text(archive.name),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.templateArchiveSummary(
                          archive.count, archive.bytes)),
                      if (archive.network)
                        Text(l.templatesInternet,
                            style: const TextStyle(color: Color(0xFFFFB15C)))
                      else
                        Text(l.templatePlatformImages),
                      const SizedBox(height: 12),
                      Text(l.templateTrust)
                    ]),
                actions: [
                  OutlinedButton(
                      style: dialogSecondaryStyle(),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.templatesCancel)),
                  ElevatedButton(
                      style: dialogPrimaryStyle(),
                      key: const Key('template-import-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.templateImport))
                ]));
    if (yes != true) return;
    await const TemplateArchive().import(_library!, archive);
    await _refresh();
    if (mounted) setState(() => _notice = l.templateArchiveDone);
  }

  Future<void> _menu(String action, TemplateInfo info) async {
    switch (action) {
      case 'export':
        final l = AppLocalizations.of(context)!;
        final target = await getSaveLocation(
            suggestedName: '${info.id}.zip', acceptedTypeGroups: [_zipGroup]);
        if (target == null) return;
        await const TemplateArchive().export(_library!, info.id, target.path);
        if (mounted) setState(() => _notice = l.templateArchiveDone);
      case 'duplicate':
        final l = AppLocalizations.of(context)!;
        await const TemplateArchive()
            .duplicate(_library!, info.id, l.templateCopyWord);
        await _refresh();

      case 'preview':
        await _explore('${_url(info.id)}?demo=1');
      case 'folder':
        final safe = await _library!.get(info.id);
        if (safe != null) await _explore(safe.folderPath);
      case 'edit':
        if (!mounted) return;
        await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _TemplateEditor(
                library: _library!, info: info, url: _url(info.id)));
      case 'delete':
        if (!mounted) return;
        final l = AppLocalizations.of(context)!;
        final yes = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text(l.templatesDelete),
                    content: Text(l.templatesDeleteConfirm(info.manifest.name)),
                    actions: [
                      OutlinedButton(
                          style: dialogSecondaryStyle(),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l.templatesCancel)),
                      OutlinedButton(
                          style: dialogSecondaryStyle(destructive: true),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l.templatesDelete))
                    ]));
        if (yes == true) {
          await _library!.deleteTemplate(info.id);
          await _refresh();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final library = ref.watch(templateLibraryProvider);
    ref.listen(templateLibraryProvider, (_, value) {
      final next = value.valueOrNull;
      if (next != null && next != _library) {
        _subscription?.cancel();
        _library = next;
        _subscription = next.changes
            .where((c) => c.kind != TemplateChangeKind.values)
            .listen((_) => unawaited(_refresh()));
        unawaited(_refresh());
      }
    });
    // A provider override may already have completed before the first build.
    if (_library == null && library.valueOrNull != null) {
      _library = library.requireValue;
      _subscription = _library!.changes
          .where((c) => c.kind != TemplateChangeKind.values)
          .listen((_) => unawaited(_refresh()));
      unawaited(_refresh());
    }
    final counts = ref.watch(templateCountsProvider).valueOrNull ?? {};
    final errors = ref.watch(templateErrorsProvider).valueOrNull ?? {};
    final enabled = _library != null && !_busy;
    final overlayUrl = ref.watch(overlayUrlProvider);
    return UiCard(
        title: l.templatesTitle,
        icon: Icons.dashboard_customize_outlined,
        description: l.templatesDescription,
        children: [
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  style: primarySettingsStyle(),
                  key: const Key('templates-new'),
                  onPressed: enabled ? () => _action(_new) : null,
                  child: Text(l.templatesNew))),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: OutlinedButton(
                    style: secondarySettingsStyle(),
                    key: const Key('templates-ai'),
                    onPressed: enabled
                        ? () => showDialog<void>(
                              context: context,
                              builder: (_) => _AiTemplateDialog(
                                  library: _library!, url: _url),
                            )
                        : null,
                    child: Text(l.templatesAi))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    style: secondarySettingsStyle(),
                    key: const Key('templates-import'),
                    onPressed: enabled ? () => _action(_import) : null,
                    child: Text(l.templateImport)))
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TextButton(
                key: const Key('templates-open-folder'),
                onPressed: enabled
                    ? () => _action(() async {
                          await _library!.ensureRoot();
                          await _explore(_library!.rootPath);
                        })
                    : null,
                child: Text(l.templatesOpenFolder)),
            if (counts.values.any((count) => count > 0))
              TextButton(
                  key: const Key('templates-test'),
                  onPressed: enabled
                      ? () {
                          final sent = ref
                                  .read(appControllerProvider)
                                  .templateServer
                                  ?.broadcastTemplateTest() ??
                              false;
                          setState(() => _notice = sent
                              ? l.templatesTestSent
                              : l.templatesTestEmpty);
                        }
                      : null,
                  child: Text(l.templatesTest))
          ]),
          if (library.isLoading)
            const LinearProgressIndicator(
                color: Color(0xFF53FC18), backgroundColor: Color(0xFF262626)),
          if (library.hasError) Text(l.templatesFailed),
          // Done / sent / copied in green; failures and "nothing to send"
          // stay orange, so success no longer reads as a warning.
          if (_notice != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_notice!,
                    key: const Key('templates-notice'),
                    style: TextStyle(
                        fontSize: 12,
                        color: {
                          l.templateArchiveDone,
                          l.templatesTestSent,
                          l.templatesCopied,
                        }.contains(_notice)
                            ? const Color(0xFF53FC18)
                            : const Color(0xFFFFB15C)))),
          if (_items.isEmpty && !library.isLoading)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l.templatesEmptyGuide,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12, height: 1.6))),
          _gallery(l, overlayUrl, enabled),
          for (final info in _items)
            Padding(
                key: Key('template-${info.id}'),
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Row(children: [
                        Expanded(
                            child: Text(info.manifest.name,
                                style: settingsItemTitleStyle)),
                        PopupMenuButton<String>(
                            key: Key('template-menu-${info.id}'),
                            enabled: enabled,
                            onSelected: (value) =>
                                _action(() => _menu(value, info)),
                            itemBuilder: (_) => [
                                  for (final e in {
                                    'preview': l.templatesPreview,
                                    'edit': l.templatesEdit,
                                    'folder': l.templatesOpenFolder,
                                    'export': l.templateExport,
                                    'duplicate': l.templateDuplicate,
                                    'delete': l.templatesDelete
                                  }.entries)
                                    PopupMenuItem(
                                        key:
                                            Key('template-${e.key}-${info.id}'),
                                        value: e.key,
                                        child: Text(e.value,
                                            style: e.key == 'delete'
                                                ? const TextStyle(
                                                    color: Color(0xFFFF6B6B))
                                                : null))
                                ])
                      ]),
                      Text(
                          '${info.id} · ${info.manifest.width}×${info.manifest.height}',
                          style: settingsHintStyle),
                      if (_galleryUpdate(info, l, enabled) case final update?)
                        update,
                      // A property of the template, not a button.
                      if (info.manifest.network)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: settingsStatus(
                              l.templatesInternet, const Color(0xFFFFB15C),
                              key: Key('template-internet-${info.id}')),
                        ),
                      for (final problem in info.problems)
                        Text(
                            switch (problem) {
                              'missingIndex' => l.templatesMissingIndex,
                              'invalidManifest' => l.templatesInvalidManifest,
                              'unsupportedSdk' => l.templatesUnsupportedSdk,
                              _ => l.templatesOversizedIndex
                            },
                            style: const TextStyle(color: Color(0xFFFFB15C))),
                      Text(l.templatesOpenCount(counts[info.id] ?? 0),
                          style: settingsHintStyle),
                      if (info.manifest.fields.isNotEmpty)
                        TemplateFields(
                            key: ValueKey('fields-${info.id}'),
                            library: _library!,
                            info: info),
                      if (errors[info.id] case final error?)
                        Row(children: [
                          Expanded(
                              child: Text(
                                  l.templatesError(
                                      error.source,
                                      error.line?.toString() ?? '?',
                                      error.message),
                                  style: const TextStyle(
                                      color: Color(0xFFFFB15C)))),
                          IconButton(
                              key: Key('template-error-clear-${info.id}'),
                              tooltip: l.clear,
                              onPressed: () => ref
                                  .read(appControllerProvider)
                                  .templateServer
                                  ?.clearTemplateError(info.id),
                              icon: const Icon(Icons.close, size: 16))
                        ]),
                      TextButton.icon(
                          key: Key('template-copy-${info.id}'),
                          onPressed: enabled
                              ? () => _action(() async {
                                    await Clipboard.setData(
                                        ClipboardData(text: _url(info.id)));
                                    if (mounted) {
                                      setState(
                                          () => _notice = l.templatesCopied);
                                    }
                                  })
                              : null,
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(l.templatesCopy)),
                    ])),
        ]);
  }
}

class _NewTemplateDialog extends StatefulWidget {
  const _NewTemplateDialog();
  @override
  State<_NewTemplateDialog> createState() => _NewTemplateDialogState();
}

class _NewTemplateDialogState extends State<_NewTemplateDialog> {
  final _name = TextEditingController();
  TemplateStarter _starter = TemplateStarter.blank;
  bool _invalid = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = [
      l.templatesBlank,
      l.templatesChat,
      l.templatesAlerts,
      l.templatesGoal
    ];
    final descriptions = [
      l.templatesBlankDescription,
      l.templatesChatDescription,
      l.templatesAlertsDescription,
      l.templatesGoalDescription
    ];
    return AlertDialog(
        key: const Key('template-new-dialog'),
        title: Text(l.templatesNew),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 14),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  settingsLabel(l.templatesName),
                  TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      key: const Key('template-new-name'),
                      controller: _name,
                      autofocus: true,
                      maxLength: 60,
                      // The "write a name" error goes as soon as one is typed.
                      onChanged: (value) {
                        if (_invalid && value.trim().isNotEmpty) {
                          setState(() => _invalid = false);
                        }
                      },
                      decoration: settingsInput(
                          error: _invalid ? l.templatesRequired : null)),
                  for (final starter in TemplateStarter.values)
                    ListTile(
                        key: Key('template-starter-${starter.name}'),
                        title: Text(labels[starter.index]),
                        subtitle: Text(descriptions[starter.index]),
                        leading: Icon(
                            _starter == starter
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _starter == starter
                                ? const Color(0xFF53FC18)
                                : Colors.white38),
                        onTap: () => setState(() => _starter = starter)),
                ]))),
        actions: [
          OutlinedButton(
              style: dialogSecondaryStyle(),
              onPressed: () => Navigator.pop(context),
              child: Text(l.templatesCancel)),
          ElevatedButton(
              style: dialogPrimaryStyle(),
              key: const Key('template-new-create'),
              onPressed: () {
                if (_name.text.trim().isEmpty) {
                  setState(() => _invalid = true);
                  return;
                }
                Navigator.pop(context, (_name.text.trim(), _starter));
              },
              child: Text(l.templatesCreate))
        ]);
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor(
      {required this.library, required this.info, required this.url});
  final TemplateLibrary library;
  final TemplateInfo info;
  final String url;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  static const _files = ['index.html', 'style.css', 'script.js'];
  static const _keys = ['html', 'css', 'js'];
  final _controllers = List.generate(3, (_) => TextEditingController());
  final _original = List<String?>.filled(3, null);
  final _blocked = List<bool>.filled(3, false);
  final _oversized = List<bool>.filled(3, false);
  bool _loading = true, _saving = false;
  String? _notice;
  bool get _dirty => List.generate(3,
          (i) => !_blocked[i] && _controllers[i].text != (_original[i] ?? ''))
      .any((v) => v);
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    for (var i = 0; i < 3; i++) {
      try {
        _original[i] =
            await widget.library.readTemplateFile(widget.info.id, _files[i]);
        if (!mounted) return;
        _controllers[i].text = _original[i] ?? '';
      } on FormatException catch (error) {
        _blocked[i] = true;
        _oversized[i] = error.message == 'size';
      } catch (_) {
        _blocked[i] = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_loading || _saving) return;
    setState(() => _saving = true);
    final l = AppLocalizations.of(context)!;
    try {
      for (var i = 0; i < 3; i++) {
        if (!_blocked[i] && _controllers[i].text != (_original[i] ?? '')) {
          final value = _controllers[i].text;
          await widget.library
              .writeTemplateFile(widget.info.id, _files[i], value);
          _original[i] = value;
        }
      }
      _notice = l.templatesSaved;
    } catch (_) {
      _notice = l.templatesFailed;
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _close() async {
    if (_saving) return;
    final l = AppLocalizations.of(context)!;
    if (_dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(title: Text(l.templatesUnsaved), actions: [
                OutlinedButton(
                    style: dialogSecondaryStyle(),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.templatesCancel)),
                OutlinedButton(
                    style: dialogSecondaryStyle(destructive: true),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.templatesDiscard))
              ]));
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).height < 360;
    ButtonStyle editorButtonStyle(ButtonStyle style) => compact
        ? style.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : style;
    final close = OutlinedButton(
      style: editorButtonStyle(secondarySettingsStyle()),
      onPressed: _saving ? null : _close,
      child: Text(l.templatesClose),
    );
    final save = ElevatedButton(
      style: editorButtonStyle(primarySettingsStyle()),
      key: const Key('template-editor-save'),
      onPressed: _loading || _saving ? null : _save,
      child: Text(l.templatesSave),
    );
    final editor = Padding(
      padding: compact ? const EdgeInsets.all(8) : const EdgeInsets.all(20),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(
              '${l.templatesEdit}: ${widget.info.manifest.name}',
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
            ),
          ),
          OutlinedButton(
            style: editorButtonStyle(secondarySettingsStyle()),
            onPressed: () async {
              try {
                await _explore('${widget.url}?demo=1');
              } catch (_) {
                if (mounted) setState(() => _notice = l.templatesFailed);
              }
            },
            child: Text(l.templatesPreview),
          ),
        ]),
        TabBar(tabs: [
          for (final label in ['HTML', 'CSS', 'JS'])
            Tab(text: label, height: compact ? 36 : null),
        ]),
        if (_loading || _saving)
          const LinearProgressIndicator(
              color: Color(0xFF53FC18), backgroundColor: Color(0xFF262626)),
        Expanded(
          child: TabBarView(children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 4 : 12),
                child: _blocked[i]
                    ? Center(
                        child: Text(_oversized[i]
                            ? l.templatesLarge
                            : l.templatesFailed))
                    : TextField(
                        key: Key('template-editor-${_keys[i]}'),
                        controller: _controllers[i],
                        enabled: !_loading && !_saving,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                            fontSize: 13),
                        decoration: settingsInput(),
                        onChanged: (_) => setState(() {}),
                      ),
              ),
          ]),
        ),
        // Preview opens the saved files, not the text being edited.
        if (_dirty)
          Text(l.templatesPreviewNeedsSave,
              key: const Key('template-editor-unsaved'),
              style: settingsHintStyle),
        // A stale "Saved" would be wrong once there are new edits.
        if (_notice != null && (!_dirty || _notice == l.templatesFailed))
          Text(_notice!,
              style: TextStyle(
                  fontSize: 12,
                  color: _notice == l.templatesFailed
                      ? const Color(0xFFFFB15C)
                      : const Color(0xFF53FC18))),
        if (compact)
          Row(children: [
            Expanded(child: close),
            const SizedBox(width: 8),
            Expanded(child: save),
          ])
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [close, const SizedBox(height: 8), save],
          ),
      ]),
    );
    const dialogKey = Key('template-editor');
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_close());
        },
        child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                  () => unawaited(_save())
            },
            child: DefaultTabController(
                length: 3,
                child: compact
                    ? Dialog.fullscreen(key: dialogKey, child: editor)
                    : Dialog(
                        key: dialogKey,
                        child: SizedBox(width: 960, height: 720, child: editor),
                      ))));
  }
}

class _AiTemplateDialog extends StatefulWidget {
  const _AiTemplateDialog({required this.library, required this.url});
  final TemplateLibrary library;
  final String Function(String) url;
  @override
  State<_AiTemplateDialog> createState() => _AiTemplateDialogState();
}

class _AiTemplateDialogState extends State<_AiTemplateDialog> {
  final _description = TextEditingController();
  bool _invalid = false, _busy = false;
  String? _notice;
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _run(bool copy) async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final description = _description.text.trim();
    if (copy && description.isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await widget.library.ensureRoot();
      if (copy) {
        final id = await widget.library.suggestedAgentId(description);
        await Clipboard.setData(ClipboardData(
            text: l.templatesAiInstruction(
                id, description, '${widget.url(id)}?demo=1')));
        if (mounted) setState(() => _notice = l.templatesAiCopied);
      } else {
        await _explore(widget.library.rootPath);
      }
    } catch (_) {
      if (mounted) setState(() => _notice = l.templatesFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('templates-ai-dialog'),
      title: Text(l.templatesAi),
      content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.templatesAiSteps),
                  const SizedBox(height: 20),
                  settingsLabel(l.templatesAiDescription),
                  TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      key: const Key('templates-ai-description'),
                      controller: _description,
                      autofocus: true,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      decoration: settingsInput(
                          error: _invalid
                              ? l.templatesAiDescriptionRequired
                              : null),
                      onChanged: (_) {
                        if (_invalid) setState(() => _invalid = false);
                      }),
                  if (_busy)
                    const LinearProgressIndicator(
                        color: Color(0xFF53FC18),
                        backgroundColor: Color(0xFF262626)),
                  if (_notice != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_notice!,
                            style: TextStyle(
                                fontSize: 12,
                                color: _notice == l.templatesFailed
                                    ? const Color(0xFFFFB15C)
                                    : const Color(0xFF53FC18)))),
                ],
              ))),
      actions: [
        OutlinedButton(
            style: dialogSecondaryStyle(),
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.templatesClose)),
        OutlinedButton(
            style: dialogSecondaryStyle(),
            key: const Key('templates-ai-open'),
            onPressed: _busy ? null : () => _run(false),
            child: Text(l.templatesOpenFolder)),
        ElevatedButton(
            style: dialogPrimaryStyle(),
            key: const Key('templates-ai-copy'),
            onPressed: _busy ? null : () => _run(true),
            child: Text(l.templatesAiCopy)),
      ],
    );
  }
}
