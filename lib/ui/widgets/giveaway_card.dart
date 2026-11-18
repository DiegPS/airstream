import 'settings_controls.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:intl/intl.dart';
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
  int _drawCount = 1;

  Widget _history(
      AppLocalizations l, List<GiveawayRound> rounds, VoidCallback clear) {
    final format = DateFormat.yMd(l.localeName).add_Hms();
    String detail(GiveawayRound round) => [
          round.keyword,
          l.giveawayStartedAt(format.format(round.startedAt)),
          l.giveawayEndedAt(format.format(round.endedAt)),
          l.giveawayParticipants(round.entrantCount),
          if (round.winners.isEmpty) l.giveawayNoWinners,
          for (final winner in round.winners)
            '${winner.name} (${winner.platform.name})',
        ].join('\n');
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        key: const Key('giveaway-history'),
        title: Text(l.giveawayHistory),
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rounds.isEmpty) Text(l.giveawayHistoryEmpty),
          if (rounds.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: rounds.map(detail).join('\n\n'))),
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(l.copy),
                ),
                TextButton(
                    onPressed: clear, child: Text(l.giveawayClearHistory)),
              ],
            ),
            for (final round in rounds)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(detail(round)),
              ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(chatGiveawayProvider).valueOrNull;
    final history =
        ref.watch(settingsProvider.select((s) => s.giveawayHistory));
    final controller = ref.read(appControllerProvider);
    final winner = state?.winner;
    final url = ref.watch(overlayUrlProvider);
    final ready = ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
        OverlayServerPhase.ready;
    final pageUrl = ready && url != null ? '$url/giveaway' : null;
    Widget button(String key, String label, VoidCallback? action) => key ==
                'giveaway-close' ||
            key == 'giveaway-clear'
        ? OutlinedButton(
            key: Key(key),
            style: secondarySettingsStyle(destructive: key == 'giveaway-clear'),
            onPressed: action,
            child: Text(label))
        : SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                key: Key(key),
                style: primarySettingsStyle(),
                onPressed: action,
                child: Text(label)));
    return UiCard(
        key: const Key('giveaway-card'),
        title: l.giveawayTitle,
        description: l.giveawayDescription,
        icon: Icons.card_giftcard_rounded,
        children: [
          if (state == null) ...[
            settingsLabel(l.giveawayKeyword),
            TextField(
                key: const Key('giveaway-keyword'),
                controller: _keyword,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: settingsInput()),
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
              const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  if (state.phase == GiveawayPhase.open)
                    button('giveaway-close', l.giveawayClose,
                        controller.closeGiveaway),
                  Row(children: [
                    Expanded(child: Text(l.giveawayDrawCount)),
                    DropdownButton<int>(
                      key: const Key('giveaway-draw-count'),
                      value: _drawCount,
                      items: [
                        for (var count = 1; count <= 10; count++)
                          DropdownMenuItem(value: count, child: Text('$count')),
                      ],
                      onChanged: (count) {
                        if (count != null) setState(() => _drawCount = count);
                      },
                    ),
                  ]),
                  button(
                      winner == null ? 'giveaway-draw' : 'giveaway-redraw',
                      _drawCount > 1
                          ? l.giveawayDrawMany(_drawCount)
                          : winner == null
                              ? l.giveawayDraw
                              : l.giveawayRedraw,
                      state.entrantCount > state.winners.length
                          ? () {
                              if (_drawCount == 1) {
                                controller.drawGiveaway();
                              } else {
                                controller.drawGiveaways(_drawCount);
                              }
                            }
                          : null),
                  button('giveaway-clear', l.giveawayClear,
                      controller.clearGiveaway),
                ]),
          ],
          _history(l, history, controller.clearGiveawayHistory),
          const SizedBox(height: 12),
          if (pageUrl != null)
            PageUrlRow(
                url: pageUrl,
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: pageUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.giveawayUrlCopied)));
                }),
        ]);
  }
}
