import 'package:airstream/models/chat_message.dart';
import 'dart:async';
import 'dart:convert';
import 'rule_model.dart';
import 'rule_events.dart';
import 'rule_evaluator.dart';

class RuleActionResult {
  const RuleActionResult(this.status, [this.reason]);
  final String status;
  final String? reason;
  static const done = RuleActionResult('done');
}

/// Feature targets provide read-only preflight and asynchronous execution.
abstract interface class RuleActionTarget {
  bool get streaming;
  String get currentScene;
  Map<String, int> get counters;
  String? skipReason(Map<String, dynamic> action, RuleEvent event);
  Future<RuleActionResult> execute(Map<String, dynamic> action, RuleRun run);
}

class RuleRun {
  RuleRun(
      {required this.id,
      required this.rule,
      required this.event,
      required this.startedAt,
      required this.generation,
      this.manual = false});
  final String id;
  final Map<String, dynamic> rule;
  final RuleEvent event;
  final DateTime startedAt;
  final int generation;
  final bool manual;
  String? previousScene;
  final List<RuleActionResult> results = [];
  String get ruleId => rule['id'] as String;
  String get ruleName => rule['name'] as String;
  String get triggerSummary => manual ? 'manual' : event.type;
  bool completed = false;
}

class RuleSimulation {
  const RuleSimulation(this.reason, this.actions, this.results);
  final String? reason;
  bool get matched => reason == null;
  final List<Map<String, dynamic>> actions;
  final List<RuleActionResult> results;
}

/// Rules core for the Rules tab. Call [updateSettings] whenever definitions or
/// the global switch change; [rules] contains the sanitized current definitions.
/// [history] and [historyStream] expose the newest 50 accepted runs (including
/// action progress). [tripped] and [trippedStream] expose the circuit breaker;
/// [resetBreaker] clears it without writing settings. [simulate] performs only
/// evaluation and preflight; [runNow] accepts a real manual run. [sampleEvent]
/// and [newRule] supply editor defaults. Never await actions from a chat listener.
class RuleEngine {
  RuleEngine({required this.target, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final RuleActionTarget target;
  final DateTime Function() _clock;
  List<Map<String, dynamic>> _rules = const [];
  List<Map<String, dynamic>> get rules => List.unmodifiable(_rules);
  bool _enabled = true, _disposed = false;
  bool get active =>
      !_disposed && _enabled && _rules.any((r) => r['enabled'] == true);
  String? _tripped;
  String? get tripped => _tripped;
  final _breaker = StreamController<String?>.broadcast();
  Stream<String?> get trippedStream => _breaker.stream;
  final _history = <RuleRun>[];
  List<RuleRun> get history => List.unmodifiable(_history);
  final _changes = StreamController<List<RuleRun>>.broadcast();
  Stream<List<RuleRun>> get historyStream => _changes.stream;
  final _generations = <String, int>{};
  final _queues = <String, List<RuleRun>>{};
  final _running = <String, RuleRun>{};
  final _waits = <RuleRun, ({Timer timer, Completer<void> completer})>{};
  final _cooldowns = <String, DateTime>{},
      _userCooldowns = <String, DateTime>{};
  final _seen = <String, Set<String>>{};
  final _starts = <DateTime>[];
  int _sequence = 0;
  void updateSettings(
      {required bool enabled, required List<Map<String, dynamic>> rules}) {
    final next = RuleSchema.sanitize(rules);
    for (final old in _rules) {
      final replacement = next.where((r) => r['id'] == old['id']).firstOrNull;
      if (!enabled ||
          replacement == null ||
          jsonEncode(old) != jsonEncode(replacement)) {
        _cancel(old['id'] as String);
      }
    }
    _enabled = enabled;
    _rules = next;
  }

  void _publish() {
    if (!_disposed) _changes.add(history);
  }

  void _cancel(String id) {
    _generations[id] = (_generations[id] ?? 0) + 1;
    final waiting = _queues.remove(id) ?? [];
    for (final run in waiting) {
      _finishCancelled(run);
    }
    final run = _running[id];
    if (run != null) {
      _finishCancelled(run);
      final w = _waits.remove(run);
      w?.timer.cancel();
      if (w != null && !w.completer.isCompleted) w.completer.complete();
    }
  }

  void _finishCancelled(RuleRun r) {
    while (r.results.length < (r.rule['actions'] as List).length) {
      r.results.add(const RuleActionResult('cancelled'));
    }
    r.completed = true;
    _publish();
  }

  bool _current(RuleRun r) =>
      !_disposed &&
      _enabled &&
      _tripped == null &&
      r.generation == (_generations[r.ruleId] ?? 0);
  RuleContext _context() => RuleContext(
      now: _clock(),
      streaming: target.streaming,
      enabled: _enabled,
      cooldowns: _cooldowns,
      userCooldowns: _userCooldowns);

  /// Returns a per-rule match/skip reason without waiting for any action.
  Map<String, String?> handle(RuleEvent event) {
    if (!active || _tripped != null) return const {};
    if (event.eventId.isNotEmpty) {
      final types = _seen.putIfAbsent(event.eventId, () => <String>{});
      if (!types.add(event.type)) return const {};
      if (_seen.length > 2000) _seen.remove(_seen.keys.first);
    }
    return {
      for (final rule in _rules) rule['id'] as String: _accept(rule, event)
    };
  }

  String? _accept(Map<String, dynamic> r, RuleEvent e, {bool manual = false}) {
    final reason = evaluateRule(r, e, _context(), manual: manual);
    if (reason != null) return reason;
    if (_tripped != null) return 'tripped';
    final id = r['id'] as String,
        queue = _queues.putIfAbsent(r['id'] as String, () => []);
    if (_running.containsKey(id) || queue.isNotEmpty) {
      if (r['overlap'] == 'skip') return 'overlapSkipped';
      if (queue.length >= 5) return 'queueFull';
    }
    if (_queues.values.fold<int>(0, (n, q) => n + q.length) >= 20) {
      return 'queueFull';
    }
    final now = _clock();
    _starts
        .removeWhere((t) => now.difference(t) >= const Duration(seconds: 60));
    if (_starts.length >= 30) {
      _tripped = 'runRateExceeded';
      for (final id in {..._queues.keys, ..._running.keys}) {
        _cancel(id);
      }
      _breaker.add(_tripped);
      return 'tripped';
    }
    _starts.add(now);
    _cooldowns[id] = now;
    _userCooldowns['$id:${e.userKey}'] = now;
    // Entries expire with their maximum possible cooldown, bounding long sessions.
    _userCooldowns.removeWhere((_, t) => now.difference(t).inSeconds > 3600);
    final run = RuleRun(
        id: 'run_${++_sequence}',
        rule: r,
        event: e,
        startedAt: now,
        generation: _generations[id] ?? 0,
        manual: manual);
    _history.insert(0, run);
    if (_history.length > 50) _history.removeLast();
    _publish();
    queue.add(run);
    if (!_running.containsKey(id)) {
      unawaited(Future<void>(() => _drain(id)));
    }
    return null;
  }

  Future<void> _drain(String id) async {
    if (_running.containsKey(id)) return;
    final queue = _queues[id];
    if (queue == null || queue.isEmpty) return;
    final run = queue.removeAt(0);
    _running[id] = run;
    for (final raw in run.rule['actions'] as List) {
      if (!_current(run)) break;
      final a = _resolve(Map<String, dynamic>.from(raw as Map), run.event);
      RuleActionResult result;
      final skip = a['type'] == 'obs.previousScene' && run.previousScene == null
          ? 'noPreviousScene'
          : target.skipReason(a, run.event);
      if (skip != null) {
        result = RuleActionResult('skipped', skip);
      } else if (a['type'] == 'wait') {
        final completer = Completer<void>();
        final timer =
            Timer(Duration(seconds: a['seconds'] as int), completer.complete);
        _waits[run] = (timer: timer, completer: completer);
        await completer.future;
        _waits.remove(run);
        if (!_current(run)) break;
        result = RuleActionResult.done;
      } else {
        if (a['type'] == 'obs.scene') run.previousScene ??= target.currentScene;
        try {
          final pending = target.execute(a, run);
          result = a['type'].toString().startsWith('obs.')
              ? await pending.timeout(const Duration(seconds: 5))
              : await pending;
        } on TimeoutException {
          result = RuleActionResult(
              a['type'].toString().startsWith('obs.') ? 'uncertain' : 'failed',
              'timeout');
        } catch (_) {
          result = const RuleActionResult('failed', 'targetError');
        }
      }
      if (!_current(run)) break;
      run.results.add(result);
      _publish();
    }
    if (!_current(run)) {
      _finishCancelled(run);
    } else {
      run.completed = true;
      _publish();
    }
    _running.remove(id);
    if (!_disposed) unawaited(_drain(id));
  }

  Map<String, dynamic> _resolve(Map<String, dynamic> a, RuleEvent e,
      {Map<String, int>? counters}) {
    final schema = RuleSchema.actions[a['type']] ?? const {};
    return {
      for (final entry in a.entries)
        entry.key: entry.value is String &&
                schema[entry.key] != null &&
                schema[entry.key]!.choices == null
            ? resolveRuleText(entry.value as String, e,
                counters ?? target.counters, schema[entry.key]!.max)
            : entry.value
    };
  }

  RuleSimulation simulate(Map<String, dynamic> rule, RuleEvent event) {
    final r = RuleSchema.sanitize([rule]).single;
    final reason = evaluateRule(r, event, _context());
    if (reason != null) return RuleSimulation(reason, const [], const []);
    var previous = false;
    final counters = {...target.counters};
    final actions = <Map<String, dynamic>>[], results = <RuleActionResult>[];
    for (final raw in r['actions'] as List) {
      final a = _resolve(Map<String, dynamic>.from(raw as Map), event,
          counters: counters);
      actions.add(a);
      final skip = a['type'] == 'obs.previousScene' && !previous
          ? 'noPreviousScene'
          : target.skipReason(a, event);
      if (a['type'] == 'obs.scene' && skip == null) previous = true;
      if (a['type'] == 'counter' && skip == null) {
        final name = a['name'] as String;
        counters[name] =
            ((a['op'] == 'add' ? counters[name] ?? 0 : 0) + (a['value'] as int))
                .clamp(-1000000000, 1000000000);
      }
      results.add(skip == null
          ? const RuleActionResult('wouldRun')
          : RuleActionResult('skipped', skip));
    }
    return RuleSimulation(null, actions, results);
  }

  String? runNow(String ruleId, RuleEvent sampleEvent) {
    if (_disposed) return 'disposed';
    if (_tripped != null) return 'tripped';
    final r = _rules.where((r) => r['id'] == ruleId).firstOrNull;
    return r == null ? 'invalidRule' : _accept(r, sampleEvent, manual: true);
  }

  void resetBreaker() {
    _tripped = null;
    _starts.clear();
    if (!_disposed) _breaker.add(null);
  }

  Map<String, dynamic> newRule(String type, {required String id}) =>
      RuleSchema.newRule(type, id: id);
  RuleEvent sampleEvent(String type) => RuleEvent(
      type: type,
      platform: type == 'support.superchat'
          ? 'youtube'
          : type == 'support.kicks'
              ? 'kick'
              : 'twitch',
      eventId: '',
      author: const RuleAuthor(
          name: 'Alex', id: 'sample', roles: ['member', 'moderator']),
      text: type == 'chat.command' ? '!hello welcome friends' : 'Hello stream!',
      amount: 5,
      presentationAmount: r'$5.00',
      currency: r'$',
      count: type == 'support.gift'
          ? 5
          : type == 'support.raid'
              ? 50
              : 500,
      months: 12,
      scene: 'Gameplay',
      goalId: 'goal',
      message: type.startsWith('chat.') || type.startsWith('support.')
          ? ChatMessage(
              platform: type == 'support.superchat'
                  ? Platform.youtube
                  : Platform.twitch,
              id: 'sample',
              author: const ChatAuthor(name: 'Alex', channelId: 'sample'),
              items: const [MessageItem.text('Hello stream!')],
              timestamp: _clock())
          : null);
  Future<void> dispose() async {
    for (final id in {..._queues.keys, ..._running.keys}) {
      _cancel(id);
    }
    _disposed = true;
    await _changes.close();
    await _breaker.close();
  }
}
