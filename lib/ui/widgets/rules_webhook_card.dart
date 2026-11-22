import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/application/rules/rules_webhook.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'rules_card.dart';
import 'settings_controls.dart';
import 'ui_card.dart';

class RulesWebhookCard extends ConsumerStatefulWidget {
  const RulesWebhookCard({super.key, this.baseUrl});
  final String? baseUrl;
  @override
  ConsumerState<RulesWebhookCard> createState() => _RulesWebhookCardState();
}

class _RulesWebhookCardState extends ConsumerState<RulesWebhookCard> {
  bool reveal = false;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider), l = AppLocalizations.of(context)!;
    final baseUrl = widget.baseUrl ?? 'http://localhost:${s.overlayPort}';
    final notifier = ref.read(settingsProvider.notifier);
    return UiCard(
        title: ruleText(l, 'webhookTitle'),
        icon: Icons.link_rounded,
        children: [
          Material(
              color: Colors.transparent,
              child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ruleText(l, 'webhookEnable'),
                      style: settingsBodyStyle),
                  value: s.rulesWebhookEnabled,
                  onChanged: (v) => notifier.update(
                      enableRulesWebhook(ref.read(settingsProvider), v)))),
          Text(ruleText(l, 'webhookHelp'), style: settingsHintStyle),
          const SizedBox(height: 4),
          Text(ruleText(l, 'webhookSecretWarning'),
              style: const TextStyle(
                  color: Color(0xFFFFB15C), fontSize: 11, height: 1.3)),
          if (s.rulesWebhookEnabled) ...[
            const SizedBox(height: 8),
            Text(ruleText(l, 'webhookServerHelp'), style: settingsHintStyle),
            const SizedBox(height: 6),
            SelectableText(reveal ? s.rulesWebhookToken : '••••••••••••••••',
                key: const Key('rules-webhook-token'),
                style: const TextStyle(
                    color: Color(0xFFACCBFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace')),
            Wrap(spacing: 6, children: [
              TextButton(
                  onPressed: () => setState(() => reveal = !reveal),
                  child:
                      Text(ruleText(l, reveal ? 'hideToken' : 'revealToken'))),
              TextButton(
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: s.rulesWebhookToken)),
                  child: Text(ruleText(l, 'copyToken'))),
              TextButton(
                  key: const Key('rules-webhook-regenerate'),
                  onPressed: () async {
                    if (await ruleConfirm(
                        context, ruleText(l, 'regenerateConfirm'),
                        action: 'regenerate')) {
                      reveal = false;
                      await notifier.update(ref
                          .read(settingsProvider)
                          .copyWith(rulesWebhookToken: newRulesWebhookToken()));
                    }
                  },
                  child: Text(ruleText(l, 'regenerate')))
            ]),
            for (final r in s.rules)
              if (r['enabled'] == true &&
                  r['trigger']['type'] == 'manual' &&
                  (r['trigger']['webhook'] as String? ?? '').isNotEmpty)
                Material(
                    color: Colors.transparent,
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r['name'] as String),
                        subtitle: Text(
                            '$baseUrl/api/rules/${r['trigger']['webhook']}?token=••••••••',
                            overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                            key: Key('rule-webhook-copy-${r['id']}'),
                            tooltip: ruleText(l, 'copy'),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            onPressed: () => Clipboard.setData(ClipboardData(
                                text:
                                    '$baseUrl/api/rules/${r['trigger']['webhook']}?token=${s.rulesWebhookToken}')))))
          ]
        ]);
  }
}
