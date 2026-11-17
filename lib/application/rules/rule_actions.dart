import 'package:airstream/services/speech/voice_command.dart';
import 'rule_model.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/models/chat_message.dart';
import 'rule_engine.dart';
import 'rule_events.dart';

/// Local feature bridge. Settings writes are supplied by the Riverpod layer.
class RuleActions implements RuleActionTarget {
  RuleActions(
      {required this.settings,
      required this.writeSettings,
      required this.obs,
      required this.audio,
      required this.giveaway,
      required this.server,
      required this.feature,
      required this.draw});
  final SettingsModel Function() settings;
  final Future<void> Function(SettingsModel, int) writeSettings;
  final ObsCoordinator obs;
  final AudioCoordinator audio;
  final ChatGiveawayController giveaway;
  final OverlayServer? Function() server;
  final void Function(ChatMessage) feature;
  final void Function(int) draw;
  @override
  bool get streaming => obs.currentState.outputActive;
  @override
  String get currentScene => obs.currentState.currentScene;
  @override
  Map<String, int> get counters => settings().ruleCounters;
  @override
  String? skipReason(Map<String, dynamic> a, RuleEvent e) {
    final s = settings(), type = a['type'];
    if (const ['obs.source', 'obs.mute', 'sound.play', 'alert.show']
        .contains(type)) {
      return 'notAvailableYet';
    }
    if (type.toString().startsWith('obs.') &&
        (!s.obsEnabled || !obs.currentState.connected)) {
      return 'notConnected';
    }
    if (type == 'tts.say' && !audio.ruleTtsReady) return 'ttsOff';
    if (type == 'featured' && e.message == null) return 'noMessage';
    if (type == 'goal.adjust' && !s.goals.containsKey(a['goalId'])) {
      return 'goalNotFound';
    }
    if (type == 'subathon.adjust' &&
        !['running', 'paused'].contains(s.subathonPhase)) {
      return 'timerNotRunning';
    }
    if (type == 'template.trigger' && server() == null) return 'noReceiver';
    if (type == 'giveaway') {
      if (a['op'] == 'start' &&
          normalizeVoiceText(a['keyword'] as String).isEmpty) {
        return 'invalidKeyword';
      }
      final g = giveaway.current;
      if (a['op'] == 'start' && g?.phase == GiveawayPhase.open) {
        return 'alreadyOpen';
      }
      if (a['op'] == 'close' && g?.phase != GiveawayPhase.open) {
        return 'notOpen';
      }
      if (a['op'] == 'draw' &&
          (g == null ||
              !g.entrants.any(
                  (e) => !g.winners.any((w) => w.identity == e.identity)))) {
        return 'noEntrants';
      }
    }
    if (type == 'counter' &&
        !s.ruleCounters.containsKey(a['name']) &&
        s.ruleCounters.length >= RuleSchema.maxCounters) {
      return 'counterLimit';
    }
    return null;
  }

  @override
  Future<RuleActionResult> execute(Map<String, dynamic> a, RuleRun run) async {
    final skip = skipReason(a, run.event);
    if (skip != null) return RuleActionResult('skipped', skip);
    final s = settings(), depth = run.event.chainDepth + 1;
    switch (a['type']) {
      case 'obs.scene':
        await obs.ruleScene(a['scene'] as String);
      case 'obs.previousScene':
        await obs.ruleScene(run.previousScene!);
      case 'obs.recording':
        await obs.ruleRecording(a['state'] == 'start');
      case 'tts.say':
        audio.ruleSpeak(a['text'] as String);
      case 'featured':
        feature(run.event.message!);
      case 'template.trigger':
        if (!server()!.broadcastRuleTrigger(
            name: a['name'] as String,
            data: a['data'] as String,
            rule: run.ruleName)) {
          return const RuleActionResult('skipped', 'noReceiver');
        }
      case 'goal.adjust':
        final id = a['goalId'] as String, g = s.goals[id]!;
        await writeSettings(
            s.copyWith(goals: {
              ...s.goals,
              id: {
                ...g,
                'current': ((g['current'] as int) + (a['delta'] as int))
                    .clamp(0, 10000000)
              }
            }),
            depth);
      case 'subathon.adjust':
        await writeSettings(
            SubathonTimer.addSeconds(
                s, DateTime.now().millisecondsSinceEpoch, a['seconds'] as int),
            depth);
      case 'counter':
        final name = a['name'] as String,
            value = ((a['op'] == 'add' ? (s.ruleCounters[name] ?? 0) : 0) +
                    (a['value'] as int))
                .clamp(-1000000000, 1000000000);
        await writeSettings(
            s.copyWith(ruleCounters: {...s.ruleCounters, name: value}), depth);
      case 'giveaway':
        switch (a['op']) {
          case 'start':
            giveaway.start(
                keyword: a['keyword'] as String,
                membersOnly: a['membersOnly'] as bool);
          case 'close':
            giveaway.close();
          case 'draw':
            draw(depth);
        }
    }
    return RuleActionResult.done;
  }
}
