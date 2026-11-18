import 'settings_controls.dart';
import 'dart:async';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/settings/settings_input_normalizer.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class TemplateFields extends ConsumerStatefulWidget {
  const TemplateFields({super.key, required this.library, required this.info});
  final TemplateLibrary library;
  final TemplateInfo info;
  @override
  ConsumerState<TemplateFields> createState() => _TemplateFieldsState();
}

class _TemplateFieldsState extends ConsumerState<TemplateFields> {
  final _values = <String, Object?>{}, _pending = <String, Object?>{};
  final _controllers = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};
  final _invalid = <String>{};
  final _pageStorage = PageStorageBucket();
  StreamSubscription<TemplateChange>? _sub;
  Timer? _timer;
  Future<void> _writing = Future.value();
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _sub = widget.library.changes.listen((e) {
      if (e.id == widget.info.id) unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(TemplateFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTypes = {
      for (final field in oldWidget.info.manifest.fields) field.key: field.type
    };
    if (identical(oldWidget.info, widget.info)) return;
    for (final field in widget.info.manifest.fields) {
      final oldType = oldTypes[field.key];
      if (oldType == null || oldType == field.type) continue;
      _values.remove(field.key);
      _pending.remove(field.key);
      _invalid.remove(field.key);
      _controllers[field.key]?.text = '${field.defaultValue ?? ''}';
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    final info = widget.info;
    final values = await widget.library.editorValues(info);
    if (!mounted || !identical(info, widget.info)) return;
    setState(() {
      for (final entry in values.entries) {
        final key = entry.key;
        if ((_focus[key]?.hasFocus ?? false) || _pending.containsKey(key)) {
          continue;
        }
        final value = entry.value;
        _values[key] = value;
        _controllers[key]?.text = '${value ?? ''}';
        _invalid.remove(key);
      }
    });
  }

  void _change(TemplateField field, Object? value) {
    setState(() {
      _values[field.key] = field.sanitize(value);
      _pending[field.key] = _values[field.key];
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), _save);
  }

  void _save() {
    final patch = Map<String, Object?>.from(_pending);
    _pending.clear();
    _writing = _writing.then((_) async {
      try {
        final latest = await widget.library.resolvedValues(widget.info.id);
        await widget.library.writeValues(widget.info.id, {...latest, ...patch});
        if (mounted) setState(() => _failed = false);
      } catch (_) {
        if (mounted) setState(() => _failed = true);
      }
    });
  }

  Future<void> _reset() async {
    _timer?.cancel();
    _pending.clear();
    await _writing;
    try {
      await widget.library.writeValues(widget.info.id, {});
      for (final node in _focus.values) {
        node.unfocus();
      }
      await _load();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_pending.isNotEmpty) _save();
    _sub?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _field(TemplateField f) {
    final key = Key('template-field-${widget.info.id}-${f.key}');
    final value = f.resolveEditorValue(_values[f.key]);
    final l = AppLocalizations.of(context)!;
    if (f.type == 'boolean') {
      return SwitchListTile(
          key: key,
          title: Text(f.label),
          value: value == true,
          onChanged: (v) => _change(f, v));
    }
    if (f.type == 'select' || f.type == 'media') {
      final entries = <String, String>{};
      if (f.type == 'select') {
        final scoreLayout = widget.info.manifest.gallery?.id == 'scoreboard' &&
            f.key == 'layout';
        for (final option in (f.options['options'] as List).cast<String>()) {
          entries[option] = switch ((scoreLayout, option)) {
            (true, 'row') => l.galleryScoreboardRow,
            (true, 'column') => l.galleryScoreboardColumn,
            _ => option,
          };
        }
      } else {
        entries[''] = l.templateFieldNone;
        final kind = f.options['kind'];
        for (final e in ref.watch(settingsProvider).mediaLibrary.entries) {
          final entryKind = e.value['kind'];
          if (kind == 'any' ||
              kind == entryKind ||
              (kind == 'visual' &&
                  (entryKind == 'image' || entryKind == 'video'))) {
            entries[e.key] = e.value['name'] as String;
          }
        }
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.label),
        DropdownButton<String>(
            key: key,
            isExpanded: true,
            value: entries.containsKey(value)
                ? value as String
                : entries.keys.first,
            items: [
              for (final e in entries.entries)
                DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis))
            ],
            onChanged: (v) => _change(f, v))
      ]);
    }
    final min = (f.options['min'] as num?)?.toDouble();
    final max = (f.options['max'] as num?)?.toDouble();
    final step = (f.options['step'] as num?)?.toDouble() ?? 1;
    if (f.type == 'number' &&
        min != null &&
        max != null &&
        max > min &&
        (max - min) / step <= 200) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${f.label}: $value'),
        Slider(
            key: key,
            min: min,
            max: max,
            divisions: ((max - min) / step).ceil(),
            value: (value as num).toDouble().clamp(min, max),
            onChanged: (v) => _change(f, v))
      ]);
    }
    final controller = _controllers.putIfAbsent(
        f.key, () => TextEditingController(text: '${value ?? ''}'));
    final focus = _focus.putIfAbsent(
        f.key,
        () => FocusNode()
          ..addListener(() {
            if (!(_focus[f.key]?.hasFocus ?? true)) unawaited(_load());
          }));
    final color = f.type == 'color';
    final hex = value.toString().replaceFirst('#', '');
    final preview = color
        ? Color(int.parse(
            hex.length == 8
                ? '${hex.substring(6)}${hex.substring(0, 6)}'
                : 'ff$hex',
            radix: 16))
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      settingsLabel(f.label),
      TextField(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          key: key,
          controller: controller,
          focusNode: focus,
          maxLength: f.type == 'text' ? f.options['maxLength'] as int : null,
          keyboardType: f.type == 'number'
              ? const TextInputType.numberWithOptions(
                  decimal: true, signed: true)
              : TextInputType.text,
          decoration: settingsInput().copyWith(
              suffixIcon: preview == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(width: 20, height: 20, color: preview)),
              helperText:
                  _invalid.contains(f.key) ? l.templateFieldColorInvalid : null,
              helperStyle: const TextStyle(color: Color(0xFFFFB15C))),
          onChanged: (v) {
            if (color) {
              final text = v.trim();
              final valid =
                  RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(text);
              setState(() {
                if (valid) {
                  _invalid.remove(f.key);
                } else {
                  _invalid.add(f.key);
                }
              });
              if (!valid) return;
              _change(
                  f,
                  text.length == 7
                      ? SettingsInputNormalizer.hexColor(text,
                          fallback: '#ffffff')
                      : text.toLowerCase());
            } else if (f.type == 'number') {
              final n = num.tryParse(v);
              if (n != null && n.isFinite) _change(f, n);
            } else {
              _change(f, v);
            }
          })
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
        color: Colors.transparent,
        // The sidebar scroll offset and the tile's expansion flag use
        // different types. Keep the tile and its editable fields local.
        child: PageStorage(
            bucket: _pageStorage,
            child: ExpansionTile(
                key: Key('template-fields-${widget.info.id}'),
                tilePadding: EdgeInsets.zero,
                title: Text(l.templateCustomize),
                children: [
                  for (final f in widget.info.manifest.fields)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _field(f)),
                  if (_failed)
                    Text(l.templatesFailed,
                        style: const TextStyle(color: Color(0xFFFFB15C))),
                  TextButton(
                      key: Key('template-fields-reset-${widget.info.id}'),
                      onPressed: _reset,
                      child: Text(l.templateReset))
                ])));
  }
}
