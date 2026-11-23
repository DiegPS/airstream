import 'package:airstream/ui/widgets/settings_controls.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/application/rules/rule_sharing.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'rules_card.dart';

const _rulesJson = XTypeGroup(label: 'JSON', extensions: ['json']);
Future<void> exportRules(
    BuildContext context, List<Map<String, dynamic>> rules) async {
  try {
    final location = await getSaveLocation(
        suggestedName: 'airstream-rules.json',
        acceptedTypeGroups: const [_rulesJson]);
    if (location == null) return;
    await File(location.path).writeAsString(RuleSharing.export(rules));
  } catch (_) {
    if (context.mounted) ruleFeedback(context, 'exportFailed');
  }
}

Future<void> importRules(BuildContext context, WidgetRef ref) async {
  try {
    final file = await openFile(acceptedTypeGroups: const [_rulesJson]);
    if (file == null || !context.mounted) return;
    final existing = ref.read(settingsProvider);
    final review = await compute(readRulesImportFile,
        (file.path, existing.rules, existing.mediaLibrary.keys.toSet()));
    if (!context.mounted) return;
    await showDialog<void>(
        context: context, builder: (_) => RulesImportDialog(review: review));
  } on FormatException catch (error) {
    if (context.mounted) ruleFeedback(context, error.message);
  } catch (_) {
    if (context.mounted) ruleFeedback(context, 'importReadFailed');
  }
}

/// A top-level worker avoids capturing UI objects when spawning an isolate.
Future<RuleImportReview> readRulesImportFile(
    (String, List<Map<String, dynamic>>, Set<String>) input) async {
  final f = File(input.$1);
  if (await f.length() > 1024 * 1024) {
    throw const FormatException('fileTooLarge');
  }
  final bytes = await f
      .openRead(0, 1024 * 1024 + 1)
      .fold<List<int>>([], (a, b) => a..addAll(b));
  if (bytes.length > 1024 * 1024) {
    throw const FormatException('fileTooLarge');
  }
  String source;
  try {
    source = utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('malformedJson');
  }
  return RuleSharing.import(source, existing: input.$2, mediaIds: input.$3);
}

class RulesImportDialog extends ConsumerStatefulWidget {
  const RulesImportDialog({super.key, required this.review});
  final RuleImportReview review;
  @override
  ConsumerState<RulesImportDialog> createState() => _RulesImportDialogState();
}

class _RulesImportDialogState extends ConsumerState<RulesImportDialog> {
  // Saving blocks a second click; a failed save stays in the dialog in red
  // instead of escaping the button with no feedback.
  bool _saving = false;
  bool _failed = false;
  bool _published = false;
  late RuleImportReview _review = widget.review;

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final notifier = ref.read(settingsProvider.notifier);
    final addedIds = <Object?>{};
    RuleImportReview? revised;
    try {
      await notifier.updateLatest((current) {
        // A failed disk write can leave the new rules published in memory.
        if (_published) return current.copyWith();
        final checked = RuleSharing.import(RuleSharing.export(_review.rules),
            existing: current.rules,
            mediaIds: current.mediaLibrary.keys.toSet());
        if (checked.skipped > 0 ||
            checked.warnings.values
                .any((ww) => ww.any((w) => w.$1 == 'webhookCollision'))) {
          revised = RuleImportReview(checked.rules, checked.warnings,
              _review.skipped + checked.skipped);
          return current;
        }
        addedIds.addAll(checked.rules.map((rule) => rule['id']));
        return current.copyWith(rules: [...current.rules, ...checked.rules]);
      });
      if (!mounted) return;
      if (revised case final review?) {
        setState(() {
          _review = review;
          _saving = false;
        });
        return;
      }
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      _published = _published ||
          ref
              .read(settingsProvider)
              .rules
              .any((rule) => addedIds.contains(rule['id']));
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final l = AppLocalizations.of(context)!;
    final dialog = AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        key: const Key('rules-import-dialog'),
        title: Text(ruleText(l, 'importReview')),
        content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ruleText(l, 'importDisabled')),
                      Text(
                          '${ruleText(l, 'importSkipped')}: ${review.skipped}'),
                      for (final r in review.rules)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(r['name'] as String),
                            subtitle: Text([
                              ruleSummary(l, r),
                              for (final w in review.warnings[r['id']] ??
                                  <(String, String)>[])
                                '${ruleText(l, w.$1)} ${w.$2}'
                            ].join('\n'))),
                    ]))),
        actions: [
          if (_saving || _failed || review.rules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                ruleText(
                    l,
                    _saving
                        ? 'saving'
                        : _failed
                            ? 'importSaveFailed'
                            : 'nothingToImport'),
                key: _failed ? const Key('rules-import-failed') : null,
                style: _failed
                    ? settingsBodyStyle.copyWith(color: const Color(0xFFFF6B6B))
                    : settingsHintStyle,
              ),
            ),
          OutlinedButton(
              style: dialogSecondaryStyle(),
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(ruleText(l, 'cancel'))),
          ElevatedButton(
              style: dialogPrimaryStyle(),
              key: const Key('rules-import-confirm'),
              onPressed: review.rules.isEmpty || _saving ? null : _confirm,
              child: Text(ruleText(l, 'importRules')))
        ]);
    return PopScope(canPop: !_saving, child: dialog);
  }
}
