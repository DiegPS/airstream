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
  final l = AppLocalizations.of(context)!;
  try {
    final location = await getSaveLocation(
        suggestedName: 'airstream-rules.json',
        acceptedTypeGroups: const [_rulesJson]);
    if (location == null) return;
    await File(location.path).writeAsString(RuleSharing.export(rules));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ruleText(l, 'sharingFailed'))));
    }
  }
}

Future<void> importRules(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context)!;
  try {
    final file = await openFile(acceptedTypeGroups: const [_rulesJson]);
    if (file == null) return;
    final existing = ref.read(settingsProvider);
    final review = await compute(readRulesImportFile,
        (file.path, existing.rules, existing.mediaLibrary.keys.toSet()));
    if (!context.mounted) return;
    await showDialog<void>(
        context: context, builder: (_) => RulesImportDialog(review: review));
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ruleText(l, error.message))));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ruleText(l, 'sharingFailed'))));
    }
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

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
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
                      if (_saving) const LinearProgressIndicator(),
                      if (_failed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(ruleText(l, 'saveFailed'),
                              key: const Key('rules-import-failed'),
                              style: const TextStyle(
                                  color: Color(0xFFFF6B6B), fontSize: 12)),
                        ),
                    ]))),
        actions: [
          OutlinedButton(
              style: dialogSecondaryStyle(),
              onPressed: () => Navigator.pop(context),
              child: Text(ruleText(l, 'cancel'))),
          ElevatedButton(
              style: dialogPrimaryStyle(),
              key: const Key('rules-import-confirm'),
              onPressed: review.rules.isEmpty || _saving
                  ? null
                  : () async {
                      // Recheck collisions/capacity if settings changed while reviewing.
                      final s = ref.read(settingsProvider);
                      final checked = RuleSharing.import(
                          RuleSharing.export(review.rules),
                          existing: s.rules,
                          mediaIds: s.mediaLibrary.keys.toSet());
                      if (checked.skipped > 0 ||
                          checked.warnings.values.any((ww) =>
                              ww.any((w) => w.$1 == 'webhookCollision'))) {
                        Navigator.pop(context);
                        await showDialog<void>(
                            context: context,
                            builder: (_) => RulesImportDialog(review: checked));
                        return;
                      }
                      setState(() {
                        _saving = true;
                        _failed = false;
                      });
                      try {
                        await ref.read(settingsProvider.notifier).update(
                            s.copyWith(rules: [...s.rules, ...checked.rules]));
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            _saving = false;
                            _failed = true;
                          });
                        }
                        return;
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(ruleText(l, 'importRules')))
        ]);
  }
}
