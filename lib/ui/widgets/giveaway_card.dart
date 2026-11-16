import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class GiveawayCard extends ConsumerStatefulWidget {
  const GiveawayCard({super.key});
  @override
  ConsumerState<GiveawayCard> createState() => _GiveawayCardState();
}

class _GiveawayCardState extends ConsumerState<GiveawayCard> {
  final _keyword = TextEditingController();
  bool _membersOnly = false;
  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(chatGiveawayProvider).valueOrNull;
    final controller = ref.read(appControllerProvider);
    final winner = state?.winner;
    final url = ref.watch(overlayUrlProvider);
    final ready = ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
        OverlayServerPhase.ready;
    final pageUrl = ready && url != null ? '$url/giveaway' : null;
    Widget button(String key, String label, VoidCallback? action) =>
        ElevatedButton(key: Key(key), onPressed: action, child: Text(label));
    return UiCard(
        key: const Key('giveaway-card'),
        title: l.giveawayTitle,
        description: l.giveawayDescription,
        icon: Icons.card_giftcard_rounded,
        children: [
          if (state == null) ...[
            TextField(
                key: const Key('giveaway-keyword'),
                controller: _keyword,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                    labelText: l.giveawayKeyword, isDense: true)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text(l.giveawayMembersOnly,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12))),
              Switch(
                  value: _membersOnly,
                  onChanged: (value) => setState(() => _membersOnly = value))
            ]),
            button(
                'giveaway-start',
                l.giveawayStart,
                normalizeVoiceText(_keyword.text).isEmpty
                    ? null
                    : () => controller.startGiveaway(
                        keyword: _keyword.text, membersOnly: _membersOnly)),
          ] else ...[
            Text(state.keyword,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.giveawayParticipants(state.entrantCount),
                key: const Key('giveaway-count'),
                style: const TextStyle(color: Colors.white70)),
            if (state.phase == GiveawayPhase.closed)
              Text(l.giveawayClosed,
                  style: const TextStyle(color: Colors.white70)),
            if (winner != null) ...[
              const SizedBox(height: 10),
              Text(l.giveawayWinner,
                  style: const TextStyle(color: Colors.white70)),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (winner.platform) {
                          Platform.youtube => const Color(0xFFFF4444),
                          Platform.twitch => const Color(0xFFAD70FF),
                          Platform.kick => const Color(0xFF53FC18)
                        })),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(winner.name,
                        key: const Key('giveaway-winner'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Text(winner.platform.name,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (state.phase == GiveawayPhase.open)
                button('giveaway-close', l.giveawayClose,
                    controller.closeGiveaway),
              button(
                  winner == null ? 'giveaway-draw' : 'giveaway-redraw',
                  winner == null ? l.giveawayDraw : l.giveawayRedraw,
                  state.entrantCount > state.winners.length
                      ? () {
                          controller.drawGiveaway();
                        }
                      : null),
              button(
                  'giveaway-clear', l.giveawayClear, controller.clearGiveaway),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Text(
                    pageUrl == null
                        ? l.giveawayPageOff
                        : l.giveawayPageUrl(pageUrl),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11))),
            if (pageUrl != null)
              IconButton(
                  tooltip: l.copyUrl,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: pageUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.giveawayUrlCopied)));
                  }),
          ]),
        ]);
  }
}
