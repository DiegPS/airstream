import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:airstream/services/templates/template_archive.dart';
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

  String _reason(String reason) {
    final l = AppLocalizations.of(context)!;
    return switch (reason) {
      'zip' => l.templateRejectZip,
      'count' => l.templateRejectCount,
      'total' => l.templateRejectTotal,
      'file' => l.templateRejectFile,
      'path' => l.templateRejectPath,
      'link' => l.templateRejectLink,
      'type' => l.templateRejectType,
      'layout' => l.templateRejectLayout,
      'index' => l.templateRejectIndex,
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
                            style: const TextStyle(color: Color(0xFFFFB15C))),
                      const SizedBox(height: 12),
                      Text(l.templateTrust)
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.templatesCancel)),
                  FilledButton(
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
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l.templatesCancel)),
                      FilledButton(
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
        _subscription = next.changes.listen((_) => unawaited(_refresh()));
        unawaited(_refresh());
      }
    });
    // A provider override may already have completed before the first build.
    if (_library == null && library.valueOrNull != null) {
      _library = library.requireValue;
      _subscription = _library!.changes.listen((_) => unawaited(_refresh()));
      unawaited(_refresh());
    }
    final counts = ref.watch(templateCountsProvider).valueOrNull ?? {};
    final errors = ref.watch(templateErrorsProvider).valueOrNull ?? {};
    final enabled = _library != null && !_busy;
    return UiCard(
        title: l.templatesTitle,
        icon: Icons.dashboard_customize_outlined,
        description: l.templatesDescription,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            TextButton(
                key: const Key('templates-import'),
                onPressed: enabled ? () => _action(_import) : null,
                child: Text(l.templateImport)),
            FilledButton.tonal(
                key: const Key('templates-ai'),
                onPressed: enabled
                    ? () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _AiTemplateDialog(library: _library!, url: _url),
                        )
                    : null,
                child: Text(l.templatesAi)),
            FilledButton(
                key: const Key('templates-new'),
                onPressed: enabled ? () => _action(_new) : null,
                child: Text(l.templatesNew)),
            TextButton(
                key: const Key('templates-open-folder'),
                onPressed: enabled
                    ? () => _action(() async {
                          await _library!.ensureRoot();
                          await _explore(_library!.rootPath);
                        })
                    : null,
                child: Text(l.templatesOpenFolder)),
            TextButton(
                key: const Key('templates-test'),
                onPressed: enabled
                    ? () {
                        final sent = ref
                                .read(appControllerProvider)
                                .templateServer
                                ?.broadcastTemplateTest() ??
                            false;
                        setState(() => _notice =
                            sent ? l.templatesTestSent : l.templatesTestEmpty);
                      }
                    : null,
                child: Text(l.templatesTest)),
          ]),
          if (library.isLoading) const LinearProgressIndicator(),
          if (library.hasError) Text(l.templatesFailed),
          if (_notice != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_notice!,
                    style: const TextStyle(color: Color(0xFFFFB15C)))),
          if (_items.isEmpty && !library.isLoading)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l.templatesEmpty)),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
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
                                        child: Text(e.value))
                                ])
                      ]),
                      Text(
                          '${info.id} · ${info.manifest.width}×${info.manifest.height}',
                          style: const TextStyle(color: Colors.white70)),
                      if (info.manifest.network)
                        Chip(
                            label: Text(l.templatesInternet),
                            labelStyle:
                                const TextStyle(color: Color(0xFFFFB15C))),
                      for (final problem in info.problems)
                        Text(
                            switch (problem) {
                              'missingIndex' => l.templatesMissingIndex,
                              'invalidManifest' => l.templatesInvalidManifest,
                              'unsupportedSdk' => l.templatesUnsupportedSdk,
                              _ => l.templatesOversizedIndex
                            },
                            style: const TextStyle(color: Color(0xFFFFB15C))),
                      Text(l.templatesOpenCount(counts[info.id] ?? 0)),
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  key: const Key('template-new-name'),
                  controller: _name,
                  autofocus: true,
                  maxLength: 60,
                  decoration: InputDecoration(
                      labelText: l.templatesName,
                      errorText: _invalid ? l.templatesRequired : null)),
              for (final starter in TemplateStarter.values)
                ListTile(
                    key: Key('template-starter-${starter.name}'),
                    title: Text(labels[starter.index]),
                    subtitle: Text(descriptions[starter.index]),
                    leading: Icon(_starter == starter
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                    onTap: () => setState(() => _starter = starter)),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.templatesCancel)),
          FilledButton(
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
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.templatesCancel)),
                FilledButton(
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
                child: Dialog(
                    key: const Key('template-editor'),
                    child: SizedBox(
                        width: 960,
                        height: 720,
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        '${l.templatesEdit}: ${widget.info.manifest.name}')),
                                TextButton(
                                    onPressed: () async {
                                      try {
                                        await _explore('${widget.url}?demo=1');
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() =>
                                              _notice = l.templatesFailed);
                                        }
                                      }
                                    },
                                    child: Text(l.templatesPreview))
                              ]),
                              const TabBar(tabs: [
                                Tab(text: 'HTML'),
                                Tab(text: 'CSS'),
                                Tab(text: 'JS')
                              ]),
                              if (_loading || _saving)
                                const LinearProgressIndicator(),
                              Expanded(
                                  child: TabBarView(children: [
                                for (var i = 0; i < 3; i++)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: _blocked[i]
                                          ? Center(
                                              child: Text(_oversized[i]
                                                  ? l.templatesLarge
                                                  : l.templatesFailed))
                                          : TextField(
                                              key: Key(
                                                  'template-editor-${_keys[i]}'),
                                              controller: _controllers[i],
                                              enabled: !_loading && !_saving,
                                              expands: true,
                                              minLines: null,
                                              maxLines: null,
                                              textAlignVertical:
                                                  TextAlignVertical.top,
                                              style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 14),
                                              decoration: const InputDecoration(
                                                  border: OutlineInputBorder()),
                                              onChanged: (_) =>
                                                  setState(() {})))
                              ])),
                              if (_notice != null) Text(_notice!),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                        onPressed: _saving ? null : _close,
                                        child: Text(l.templatesClose)),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                        key: const Key('template-editor-save'),
                                        onPressed:
                                            _loading || _saving ? null : _save,
                                        child: Text(l.templatesSave))
                                  ]),
                            ])))))));
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
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.templatesAiSteps),
              const SizedBox(height: 20),
              TextField(
                  key: const Key('templates-ai-description'),
                  controller: _description,
                  autofocus: true,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                      labelText: l.templatesAiDescription,
                      errorText: _invalid ? l.templatesRequired : null),
                  onChanged: (_) {
                    if (_invalid) setState(() => _invalid = false);
                  }),
              if (_busy) const LinearProgressIndicator(),
              if (_notice != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_notice!)),
            ],
          ))),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.templatesClose)),
        TextButton(
            key: const Key('templates-ai-open'),
            onPressed: _busy ? null : () => _run(false),
            child: Text(l.templatesOpenFolder)),
        FilledButton(
            key: const Key('templates-ai-copy'),
            onPressed: _busy ? null : () => _run(true),
            child: Text(l.templatesAiCopy)),
      ],
    );
  }
}
