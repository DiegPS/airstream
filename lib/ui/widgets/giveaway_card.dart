import 'settings_controls.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
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
            '${winner.name} (${winner.platform.displayName})',
        ].join('\n');
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        key: const Key('giveaway-history'),
        title: Text(l.giveawayHistory),
        tilePadding: EdgeInsets.zero,
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same look as the other empty states ("Nobody is waiting").
          if (rounds.isEmpty)
            Text(l.giveawayHistoryEmpty, style: settingsBodyStyle),
          if (rounds.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed: () => copyLiveText(
                      context, rounds.map(detail).join('\n\n'),
                      success: l.liveCopied),
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
                child: Text(detail(round), style: settingsBodyStyle),
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
    final snapshot = ref.watch(chatGiveawayProvider);
    final state = snapshot.valueOrNull;
    final canStart = normalizeVoiceText(_keyword.text).isNotEmpty;
    final history =
        ref.watch(settingsProvider.select((s) => s.giveawayHistory));
    final controller = ref.read(appControllerProvider);
    final winner = state?.winner;
    // Never offer (or promise in the button) more winners than there are
    // eligible people: the draw would silently pick fewer.
    final eligibleCount = state?.eligibleEntrants.take(10).length ?? 0;
    final maxDraw = eligibleCount == 0 ? 1 : eligibleCount;
    final drawCount = _drawCount.clamp(1, maxDraw);
    final drawLabel = winner == null
        ? (drawCount == 1 ? l.giveawayDraw : l.giveawayDrawMany(drawCount))
        : (drawCount == 1 ? l.giveawayRedraw : l.giveawayRedrawMany(drawCount));
    void draw() {
      if (drawCount == 1) {
        controller.drawGiveaway();
      } else {
        controller.drawGiveaways(drawCount);
      }
    }

    final url = ref.watch(overlayUrlProvider);
    final ready = ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
        OverlayServerPhase.ready;
    final pageUrl = ready && url != null ? '$url/giveaway' : null;
    Widget button(String key, String label, VoidCallback? action,
            {bool destructive = false, bool secondary = false}) =>
        secondary || destructive
            ? OutlinedButton(
                key: Key(key),
                style: secondarySettingsStyle(destructive: destructive),
                onPressed: action,
                child: Text(label))
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    key: Key(key),
                    style: primarySettingsStyle(),
                    onPressed: action,
                    child: Text(label)));
    Future<void> confirm(
        String title, String action, String key, VoidCallback perform) async {
      if (await confirmLiveAction(context,
              title: title, action: action, actionKey: Key(key)) &&
          context.mounted) {
        final latest = ref.read(chatGiveawayProvider).valueOrNull;
        if (latest?.keyword == state?.keyword &&
            latest?.phase == state?.phase &&
            latest?.drawId == state?.drawId) {
          perform();
        }
      }
    }

    return UiCard(
        key: const Key('giveaway-card'),
        title: l.giveawayTitle,
        description: l.giveawayDescription,
        icon: Icons.card_giftcard_rounded,
        children: [
          if (snapshot.hasError)
            Text(l.liveLoadFailed,
                style:
                    settingsBodyStyle.copyWith(color: const Color(0xFFFF6B6B)))
          else if (snapshot.isLoading && !snapshot.hasValue)
            Text(l.loading, style: settingsBodyStyle)
          else if (state == null) ...[
            settingsLabel(l.giveawayKeyword),
            TextField(
                key: const Key('giveaway-keyword'),
                controller: _keyword,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (canStart) {
                    controller.startGiveaway(
                        keyword: _keyword.text, membersOnly: _membersOnly);
                  }
                },
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
            if (!canStart)
              Text(l.giveawayKeywordRequired, style: settingsHintStyle),
            button(
                'giveaway-start',
                l.giveawayStart,
                canStart
                    ? () => controller.startGiveaway(
                        keyword: _keyword.text, membersOnly: _membersOnly)
                    : null),
          ] else ...[
            settingsStatus(
                state.phase == GiveawayPhase.open
                    ? l.giveawayOpen
                    : l.giveawayClosed,
                state.phase == GiveawayPhase.open
                    ? const Color(0xFF53FC18)
                    : const Color(0xFFFFB15C)),
            Text(
                state.phase == GiveawayPhase.open
                    ? l.giveawayJoinHint(state.keyword)
                    : state.keyword,
                style: settingsItemTitleStyle),
            const SizedBox(height: 8),
            Text(l.giveawayParticipants(state.entrantCount),
                key: const Key('giveaway-count'),
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
                Text(winner.platform.displayName,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              // A batch draw names several people; the big row shows only
              // the latest, so the whole round is listed below it.
              if (state.winners.length > 1) ...[
                const SizedBox(height: 10),
                Text(l.giveawayAllWinners(state.winners.length),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                for (final (i, each) in state.winners.indexed)
                  Text('${i + 1}. ${each.name} · ${each.platform.displayName}',
                      key: Key('giveaway-winner-$i'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ],
            const SizedBox(height: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  if (state.phase == GiveawayPhase.open)
                    button('giveaway-close', l.giveawayClose,
                        controller.closeGiveaway,
                        secondary: true),
                  Row(children: [
                    Expanded(child: Text(l.giveawayDrawCount)),
                    settingsDropdown<int>(
                      key: const Key('giveaway-draw-count'),
                      expanded: false,
                      value: drawCount,
                      items: [
                        for (var count = 1; count <= maxDraw; count++)
                          DropdownMenuItem(value: count, child: Text('$count')),
                      ],
                      onChanged: (count) {
                        if (count != null) setState(() => _drawCount = count);
                      },
                    ),
                  ]),
                  if (eligibleCount == 0)
                    Text(l.giveawayNoEligibleEntrants,
                        style: settingsHintStyle),
                  button(
                    winner == null ? 'giveaway-draw' : 'giveaway-redraw',
                    drawLabel,
                    eligibleCount == 0
                        ? null
                        : winner == null
                            ? draw
                            : () => confirm(l.giveawayRedrawConfirm, drawLabel,
                                'giveaway-redraw-confirm', draw),
                    destructive: winner != null,
                  ),
                  button(
                      'giveaway-clear',
                      l.giveawayClear,
                      () => confirm(l.giveawayClearConfirm, l.giveawayClear,
                          'giveaway-clear-confirm', controller.clearGiveaway),
                      destructive: true),
                ]),
          ],
          _history(l, history, controller.clearGiveawayHistory),
          const SizedBox(height: 12),
          if (pageUrl != null)
            PageUrlRow(
                url: pageUrl,
                onCopy: () => copyLiveText(context, pageUrl,
                    success: l.giveawayUrlCopied)),
        ]);
  }
}
