import 'package:airstream/application/app_providers.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class RecentAlertsCard extends ConsumerWidget {
  const RecentAlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final alerts = ref.watch(recentAlertsProvider).valueOrNull ?? const [];
    final queue = ref.watch(alertQueueStatusProvider).valueOrNull;
    final alertsOpen = (queue?.pages ?? 0) > 0;
    final featuredOpen =
        (ref.watch(overlayViewCountsProvider).valueOrNull?['featured'] ?? 0) >
            0;
    final paused = queue?.paused ?? false;
    final controller = ref.read(appControllerProvider);
    void control(AlertQueueOperation op) => controller.controlAlertQueue(op);
    return UiCard(
      key: const Key('recent-alerts-card'),
      title: l.recentAlertsTitle,
      icon: Icons.history_rounded,
      description: l.recentAlertsDescription,
      children: [
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: paused ? l.alertQueueResume : l.alertQueuePause,
              onPressed: alertsOpen
                  ? () => control(paused
                      ? AlertQueueOperation.resume
                      : AlertQueueOperation.pause)
                  : null,
              icon:
                  Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            ),
            IconButton(
              tooltip: l.alertQueueSkip,
              onPressed: alertsOpen && queue?.active == true
                  ? () => control(AlertQueueOperation.skip)
                  : null,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: l.alertQueueClear,
              onPressed: alertsOpen && (queue?.pending ?? 0) > 0
                  ? () => control(AlertQueueOperation.clear)
                  : null,
              icon: const Icon(Icons.playlist_remove_rounded),
            ),
            Tooltip(
              message: l.alertQueueWaitingHint,
              child: Text(l.alertQueueWaiting(queue?.pending ?? 0)),
            ),
          ],
        ),
        if (!alertsOpen) Text(l.alertQueueNoPage),
        if (alertsOpen || featuredOpen)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.removeFeaturedMessage,
              child: Text(l.featuredRemove),
            ),
          ),
        const SizedBox(height: 8),
        if (alerts.isEmpty)
          Text(l.recentAlertsEmpty,
              style: const TextStyle(color: Colors.white70))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: alerts.length.clamp(0, 30),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final id = alert['id'] as String;
                final time =
                    DateTime.tryParse('${alert['timestamp']}')?.toLocal();
                final clock = time == null
                    ? ''
                    : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (alert['platform']) {
                            'youtube' => const Color(0xFFFF4E45),
                            'twitch' => const Color(0xFF9146FF),
                            _ => const Color(0xFF53FC18),
                          },
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            (alert['author'] as String?)?.isNotEmpty == true
                                ? alert['author'] as String
                                : l.recentAlertsAnonymousViewer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text(_summary(alert, l),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    )),
                    const SizedBox(width: 6),
                    Text(clock,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    IconButton(
                      key: Key('recent-alert-replay-$id'),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      tooltip: l.recentAlertsReplay,
                      onPressed: () {
                        final shown = ref
                            .read(appControllerProvider)
                            .replayRecentAlert(id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(shown
                              ? l.recentAlertsReplayed
                              : l.openAlertsOverlayFirst),
                        ));
                      },
                    ),
                  ]),
                );
              },
            ),
          ),
      ],
    );
  }

  String _summary(Map<String, Object?> alert, AppLocalizations l) {
    if (alert['kind'] == 'custom') return alert['title'] as String? ?? '';
    final months = (alert['months'] as num?)?.toInt() ?? 0;
    final count = (alert['count'] as num?)?.toInt();
    return switch (alert['alertType']) {
      'superchat' || 'bits' => '${alert['amount'] ?? ''}',
      'membership' => l.recentAlertsMember,
      'subscription' =>
        months > 1 ? l.recentAlertsMonths(months) : l.recentAlertsSubscription,
      'gift' =>
        l.recentAlertsGifted((alert['giftCount'] as num?)?.toInt() ?? 1),
      'raid' when alert['kind'] == 'host' =>
        count == null ? l.recentAlertsHost : l.recentAlertsHostViewers(count),
      'raid' =>
        count == null ? l.recentAlertsRaid : l.recentAlertsRaidViewers(count),
      'kicks' => l.recentAlertsKicks(count ?? 0),
      _ => '',
    };
  }
}
