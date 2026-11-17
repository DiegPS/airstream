import 'package:obs_websocket/obs_websocket.dart' show ObsRequestException;
import 'rule_sound_player.dart';
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
      required this.draw,
      RuleSoundPlayer? sounds})
      : sounds = sounds ?? RuleSoundPlayer(settings: settings);
  final RuleSoundPlayer sounds;
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
    if (type == 'alert.show' && (server()?.viewCounts['alerts'] ?? 0) == 0) {
      return 'noAlertsPage';
    }
    if (type == 'sound.play' &&
        a['source'] == 'library' &&
        s.mediaLibrary[a['mediaId']]?['kind'] != 'audio') {
      return 'notFound';
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
    try {
      switch (a['type']) {
        case 'obs.scene':
          await obs.ruleScene(a['scene'] as String, chainDepth: depth);
        case 'obs.previousScene':
          await obs.ruleScene(run.previousScene!, chainDepth: depth);
        case 'obs.recording':
          await obs.ruleRecording(a['state'] == 'start');
        case 'obs.source':
          await obs.ruleSource(a['scene'] as String, a['source'] as String,
              a['visible'] as String);
        case 'obs.mute':
          await obs.ruleMute(a['input'] as String, a['state'] as String);
        case 'sound.play':
          if (!await sounds.play(a)) {
            return const RuleActionResult('skipped', 'notFound');
          }
        case 'alert.show':
          if (!server()!.broadcastRuleAlert(
              title: a['title'] as String,
              text: a['text'] as String,
              mediaId: a['mediaId'] as String,
              seconds: a['seconds'] as int)) {
            return const RuleActionResult('skipped', 'noAlertsPage');
          }
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
              SubathonTimer.addSeconds(s, DateTime.now().millisecondsSinceEpoch,
                  a['seconds'] as int),
              depth);
        case 'counter':
          final name = a['name'] as String,
              value = ((a['op'] == 'add' ? (s.ruleCounters[name] ?? 0) : 0) +
                      (a['value'] as int))
                  .clamp(-1000000000, 1000000000);
          await writeSettings(
              s.copyWith(ruleCounters: {...s.ruleCounters, name: value}),
              depth);
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
    } on ObsRequestException catch (e) {
      if (e.code == 600 || e.code == 601) {
        return const RuleActionResult('failed', 'notFound');
      }
      rethrow;
    }
    return RuleActionResult.done;
  }
}
