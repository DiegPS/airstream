import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'rules_card.dart';
import 'ui_card.dart';

class RuleButtonsCard extends ConsumerWidget {
  const RuleButtonsCard({super.key, this.engine});
  final RuleEngine? engine;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final rules = settings.rules
        .where((r) => r['enabled'] == true && r['trigger']['type'] == 'manual')
        .toList();
    if (rules.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return UiCard(
        title: ruleText(l, 'buttons'),
        icon: Icons.bolt_rounded,
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final rule in rules)
              OutlinedButton(
                  key: Key('rule-button-${rule['id']}'),
                  onPressed: () {
                    final target =
                        engine ?? ref.read(appControllerProvider).rules;
                    final reason = target.fireManual(rule['id'] as String);
                    if (reason != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ruleText(l, reason))));
                    }
                  },
                  child: Text(rule['name'] as String))
          ])
        ]);
  }
}
