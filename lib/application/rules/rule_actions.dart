import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:obs_websocket/obs_websocket.dart' show ObsRequestException;
import 'rule_sound_player.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'rule_model.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/services/obs_service.dart'
    show ObsNotBrowserSourceException, ObsNotTextSourceException;
import 'package:airstream/models/chat_message.dart';
import 'rule_engine.dart';
import 'rule_evaluator.dart';
import 'rule_events.dart';
import 'rule_validation.dart';

/// Local feature bridge. Settings writes are supplied by the Riverpod layer.
class RuleActions implements RuleActionTarget {
  RuleActions(
      {required this.settings,
      required this.writeSettings,
      required this.obs,
      required this.audio,
      required this.giveaway,
      required this.queue,
      required this.server,
      required this.feature,
      required this.draw,
      this.clock,
      DateTime Function()? now,
      RuleSoundPlayer? sounds,
      http.Client? httpClient})
      : sounds = sounds ?? RuleSoundPlayer(settings: settings),
        _now = now ?? DateTime.now,
        _httpClient = httpClient;
  final RuleSoundPlayer sounds;
  final http.Client? _httpClient;
  final DateTime Function() _now;
  final SettingsModel Function() settings;
  final Future<void> Function(SettingsModel, int) writeSettings;
  final ObsCoordinator obs;
  final AudioCoordinator audio;
  final ChatGiveawayController giveaway;
  final ChatQueueController queue;
  final OverlayServer? Function() server;
  final FeaturedMessageDelivery Function(ChatMessage) feature;
  final void Function(int, int) draw;
  final Future<void> Function(String op, int seconds, int depth)? clock;
  @override
  bool get streaming => obs.currentState.outputActive;
  @override
  String get currentScene => obs.currentState.currentScene;
  @override
  Map<String, int> get counters => settings().ruleCounters;
  @override
  String? skipReason(Map<String, dynamic> a, RuleEvent e) =>
      _skipReason(a, e, settings(), _now().millisecondsSinceEpoch);

  String? _skipReason(
      Map<String, dynamic> a, RuleEvent e, SettingsModel s, int now) {
    final type = a['type'];
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
    if (type == 'obs.stream' &&
        (a['state'] == 'start') == obs.currentState.outputActive) {
      return 'streamAlready';
    }
    if (type == 'http.request' && httpRuleUri(a['url']) == null) return 'noUrl';
    if (type == 'tts.say' && !audio.ruleTtsReady) return 'ttsOff';
    if (type == 'featured' && e.message == null) return 'noMessage';
    if (type == 'goal.adjust' && !s.goals.containsKey(a['goalId'])) {
      return 'goalNotFound';
    }
    if (type == 'subathon.adjust' &&
        s.subathonPhase != 'paused' &&
        SubathonTimer.remaining(s, now) == 0) {
      return 'timerNotRunning';
    }
    // Adding time at the cap, or 0 seconds, leaves the subathon as it was.
    if (type == 'subathon.adjust' &&
        identical(SubathonTimer.addSeconds(s, now, a['seconds'] as int? ?? 0),
            SubathonTimer.normalize(s, now))) {
      return 'subathonUnchanged';
    }
    if (type == 'clock') {
      // An operation the timer cannot take (adding time while idle or ended,
      // starting it while running) must not be reported as done.
      final current = s.clock.expire(now);
      final next = current.perform(a['op'] as String? ?? 'start', now,
          seconds: a['seconds'] as int? ?? 0);
      if (identical(next, current)) return 'clockUnchanged';
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
      if (a['op'] == 'draw' && (g == null || g.eligibleEntrants.isEmpty)) {
        return 'noEntrants';
      }
    }
    final queueReason = switch (type) {
      'queue.open' when queue.status == QueueStatus.open => 'queueAlreadyOpen',
      'queue.pause' when queue.status == QueueStatus.paused =>
        'queueAlreadyPaused',
      'queue.close' when queue.status == QueueStatus.closed =>
        'queueAlreadyClosed',
      'queue.next' when !queue.hasEntries => 'queueEmpty',
      'queue.next' when queue.playingFull => 'queuePlayingFull',
      _ => null,
    };
    if (queueReason != null) return queueReason;
    if (type == 'counter' &&
        !s.ruleCounters.containsKey(a['name']) &&
        s.ruleCounters.length >= RuleSchema.maxCounters) {
      return 'counterLimit';
    }
    return null;
  }

  @override
  Future<RuleActionResult> execute(Map<String, dynamic> a, RuleRun run) async {
    if (blocksStreamControl(a, run.rule, run.event)) {
      return const RuleActionResult('skipped', 'publicStreamControl');
    }
    final s = settings(), now = _now().millisecondsSinceEpoch;
    final skip = _skipReason(a, run.event, s, now);
    if (skip != null) return RuleActionResult('skipped', skip);
    final depth = run.event.chainDepth + 1;
    try {
      switch (a['type']) {
        case 'obs.scene':
          await obs.ruleScene(a['scene'] as String, chainDepth: depth);
        case 'obs.previousScene':
          await obs.ruleScene(run.previousScene!, chainDepth: depth);
        case 'obs.recording':
          await obs.ruleRecording(a['state'] == 'start', chainDepth: depth);
        case 'obs.source':
          await obs.ruleSource(a['scene'] as String, a['source'] as String,
              a['visible'] as String);
        case 'obs.mute':
          await obs.ruleMute(a['input'] as String, a['state'] as String);
        case 'obs.text':
          await obs.ruleText(a['source'] as String, a['text'] as String);
        case 'obs.filter':
          await obs.ruleFilter(a['source'] as String, a['filter'] as String,
              a['state'] as String);
        case 'obs.stream':
          await obs.ruleStream(a['state'] == 'start', chainDepth: depth);
        case 'obs.replay':
          await obs.ruleReplay(a['op'] as String);
        case 'obs.media':
          await obs.ruleMedia(a['source'] as String, a['op'] as String);
        case 'obs.volume':
          await obs.ruleVolume(
              a['input'] as String, a['mode'] == 'change', a['db'] as int);
        case 'obs.refresh':
          await obs.ruleRefresh(a['source'] as String);
        case 'http.request':
          return await _request(a, run.event);
        case 'sound.play':
          if (!await sounds.play(a)) {
            return const RuleActionResult('skipped', 'notFound');
          }
        case 'alert.show':
          if (!server()!.broadcastRuleAlert(
              title: a['title'] as String,
              text: a['text'] as String,
              mediaId: a['mediaId'] as String,
              seconds: a['seconds'] as int,
              source: run.event.moderationSource)) {
            return const RuleActionResult('skipped', 'noAlertsPage');
          }
        case 'tts.say':
          audio.ruleSpeak(a['text'] as String,
              source: run.event.moderationSource);
        case 'featured':
          final delivery = feature(run.event.message!);
          if (delivery.status == FeaturedMessageStatus.noReceiver) {
            return const RuleActionResult('skipped', 'noReceiver');
          }
          return switch (await delivery.completed) {
            FeaturedMessageStatus.noReceiver =>
              const RuleActionResult('skipped', 'noReceiver'),
            FeaturedMessageStatus.disconnected =>
              const RuleActionResult('failed', 'noReceiver'),
            FeaturedMessageStatus.removed =>
              const RuleActionResult('cancelled'),
            FeaturedMessageStatus.sent ||
            FeaturedMessageStatus.rendered =>
              RuleActionResult.done,
          };
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
              SubathonTimer.addSeconds(s, now, a['seconds'] as int), depth);
        case 'clock':
          final operate = clock;
          if (operate == null) throw StateError('Clock unavailable');
          await operate(a['op'] as String, a['seconds'] as int? ?? 0, depth);
        case 'counter':
          final name = a['name'] as String,
              value = ((a['op'] == 'add' ? (s.ruleCounters[name] ?? 0) : 0) +
                      (a['value'] as int))
                  .clamp(-1000000000, 1000000000);
          await writeSettings(
              s.copyWith(ruleCounters: {...s.ruleCounters, name: value}),
              depth);
        case 'queue.open':
          queue.setStatus(QueueStatus.open);
        case 'queue.close':
          queue.setStatus(QueueStatus.closed);
        case 'queue.pause':
          queue.setStatus(QueueStatus.paused);
        case 'queue.next':
          queue.next(a['count'] as int,
              random: a['random'] == true, depth: depth);
        case 'giveaway':
          switch (a['op']) {
            case 'start':
              giveaway.start(
                  keyword: a['keyword'] as String,
                  membersOnly: a['membersOnly'] as bool);
            case 'close':
              giveaway.close();
            case 'draw':
              draw(a['count'] as int? ?? 1, depth);
          }
      }
    } on ObsNotTextSourceException {
      return const RuleActionResult('failed', 'notTextSource');
    } on ObsNotBrowserSourceException {
      return const RuleActionResult('failed', 'notBrowserSource');
    } on ObsRequestException catch (e) {
      if (e.code == 600 || e.code == 601) {
        return const RuleActionResult('failed', 'notFound');
      }
      if (a['type'] == 'obs.replay') {
        if (a['op'] == 'save' && e.code == 501) {
          return const RuleActionResult('failed', 'replayOff');
        }
        if ((a['op'] == 'start' && e.code == 500) ||
            (a['op'] == 'stop' && e.code == 501)) {
          return const RuleActionResult('skipped', 'replayAlready');
        }
      }
      if (a['type'] == 'obs.stream' &&
          e.code == (a['state'] == 'start' ? 500 : 501)) {
        return const RuleActionResult('skipped', 'streamAlready');
      }
      rethrow;
    }
    return RuleActionResult.done;
  }

  Future<RuleActionResult> _request(
      Map<String, dynamic> action, RuleEvent event) async {
    final client = _httpClient ?? http.Client();
    try {
      final post = action['method'] == 'post';
      final request =
          http.Request(post ? 'POST' : 'GET', httpRuleUri(action['url'])!)
            ..headers['User-Agent'] = 'Airstream';
      if (post) {
        request.headers['Content-Type'] =
            action['contentType'] == 'json' ? 'application/json' : 'text/plain';
        request.bodyBytes =
            utf8.encode(resolveHttpRuleBody(action, event, counters));
      }
      Future<int> send() async {
        final response = await client.send(request);
        await response.stream.drain<void>();
        return response.statusCode;
      }

      final status = await send().timeout(const Duration(seconds: 5));
      return status >= 200 && status < 300
          ? RuleActionResult.done
          : const RuleActionResult('failed', 'httpStatus');
    } catch (_) {
      // Client exceptions can contain the full URL.
      return const RuleActionResult('failed', 'httpError');
    } finally {
      if (_httpClient == null) client.close();
    }
  }
}
