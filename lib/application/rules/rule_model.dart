/// Declarative schema shared by persistence, evaluation and the rules editor.
library;

class RuleField {
  const RuleField.text(
      {this.max = 200, this.min = 0, this.pattern, this.fallback = ''})
      : choices = null,
        numeric = false;
  const RuleField.number(this.min, this.max, {this.fallback = 0})
      : choices = null,
        pattern = null,
        numeric = true;
  const RuleField.choice(this.choices, this.fallback)
      : min = 0,
        max = 200,
        pattern = null,
        numeric = false;
  const RuleField.boolean()
      : min = 0,
        max = 0,
        choices = null,
        pattern = null,
        numeric = false,
        fallback = false;
  final int min, max;
  final String? pattern;
  final List<String>? choices;
  final bool numeric;
  final Object fallback;
}

abstract final class RuleSchema {
  static const maxRules = 50, maxActions = 20, maxCounters = 50;
  static const idPattern = r'^[a-z0-9_-]{1,40}$';
  static const goalPattern = r'^[a-zA-Z0-9_-]{1,64}$';
  static const platforms = ['youtube', 'twitch', 'kick'];
  static const roles = ['everyone', 'member', 'moderator', 'vip', 'owner'];
  static const triggers = <String, Map<String, RuleField>>{
    'chat.message': {
      'match':
          RuleField.choice(['contains', 'startsWith', 'equals'], 'contains'),
      'text': RuleField.text(min: 1, max: 100, fallback: 'hello')
    },
    'chat.command': {
      'command': RuleField.text(
          max: 31, pattern: r'^![A-Za-z0-9_]{1,30}$', fallback: '!hello')
    },
    'chat.firstMessage': {},
    'support.superchat': {
      'minAmount': RuleField.number(0, 1000000000),
      'currency': RuleField.text(max: 8)
    },
    'support.bits': {'min': RuleField.number(0, 1000000000)},
    'support.membership': {'minMonths': RuleField.number(0, 1200)},
    'support.gift': {'min': RuleField.number(0, 10000)},
    'support.raid': {'min': RuleField.number(0, 10000000)},
    'support.kicks': {'min': RuleField.number(0, 1000000000)},
    'goal.reached': {'goalId': RuleField.text(pattern: goalPattern)},
    'giveaway.winner': {},
    'poll.ended': {},
    'queue.joined': {},
    'queue.next': {},
    'subathon.ended': {},
    'obs.streamStarted': {},
    'obs.streamStopped': {},
    'obs.recordingStarted': {},
    'obs.recordingStopped': {},
    'obs.sceneChanged': {'scene': RuleField.text(max: 100)},
    'interval': {'minutes': RuleField.number(5, 240, fallback: 5)},
    'manual': {
      'webhook': RuleField.text(max: 40, pattern: r'^[a-z0-9-]{1,40}$')
    },
  };
  static const actions = <String, Map<String, RuleField>>{
    'wait': {'seconds': RuleField.number(1, 600, fallback: 1)},
    'obs.scene': {'scene': RuleField.text(min: 1, max: 100, fallback: 'Scene')},
    'obs.previousScene': {},
    'obs.recording': {
      'state': RuleField.choice(['start', 'stop'], 'start')
    },
    'obs.source': {
      'scene': RuleField.text(max: 100),
      'source': RuleField.text(min: 1, fallback: 'Source'),
      'visible': RuleField.choice(['show', 'hide', 'toggle'], 'show')
    },
    'obs.mute': {
      'input': RuleField.text(min: 1, fallback: 'Mic'),
      'state': RuleField.choice(['mute', 'unmute', 'toggle'], 'mute')
    },
    'obs.text': {
      'source': RuleField.text(min: 1, max: 100, fallback: 'Text'),
      'text': RuleField.text(max: 500, fallback: '{counter.count}')
    },
    'obs.filter': {
      'source': RuleField.text(min: 1, max: 100, fallback: 'Camera'),
      'filter': RuleField.text(min: 1, max: 100, fallback: 'Filter'),
      'state': RuleField.choice(['enable', 'disable', 'toggle'], 'enable')
    },
    'tts.say': {
      'text': RuleField.text(min: 1, max: 300, fallback: 'Hello {user}')
    },
    'sound.play': {
      'source': RuleField.choice(['builtin', 'library'], 'builtin'),
      'name': RuleField.choice(['chime', 'coin', 'fanfare'], 'chime'),
      'mediaId': RuleField.text(max: 16, pattern: r'^[a-fA-F0-9]{16}$')
    },
    'alert.show': {
      'title': RuleField.text(max: 60),
      'text': RuleField.text(),
      'mediaId': RuleField.text(max: 16, pattern: r'^[a-fA-F0-9]{16}$'),
      'seconds': RuleField.number(2, 30, fallback: 5)
    },
    'featured': {},
    'template.trigger': {
      'name': RuleField.text(
          max: 40,
          min: 1,
          pattern: r'^[A-Za-z0-9_-]{1,40}$',
          fallback: 'celebrate'),
      'data': RuleField.text()
    },
    'goal.adjust': {
      'goalId': RuleField.text(min: 1, pattern: goalPattern, fallback: 'goal'),
      'delta': RuleField.number(-100000, 100000)
    },
    'subathon.adjust': {'seconds': RuleField.number(-36000, 36000)},
    'giveaway': {
      'op': RuleField.choice(['start', 'close', 'draw'], 'start'),
      'keyword': RuleField.text(),
      'membersOnly': RuleField.boolean()
    },
    'queue.open': {},
    'queue.close': {},
    'queue.pause': {},
    'queue.next': {
      'count': RuleField.number(1, 10, fallback: 1),
      'random': RuleField.boolean()
    },
    'counter': {
      'name': RuleField.text(
          max: 30, min: 1, pattern: r'^[a-z0-9_]{1,30}$', fallback: 'count'),
      'op': RuleField.choice(['add', 'set'], 'add'),
      'value': RuleField.number(-1000000, 1000000)
    },
  };
  static String text(Object? value, int max) => String.fromCharCodes(
      (value is String ? value.trim() : '').runes.take(max));
  static int integer(Object? value, int min, int max, [int fallback = 0]) =>
      value is num && value.isFinite ? value.round().clamp(min, max) : fallback;
  static Map<String, int> counters(Object? raw) => raw is! Map
      ? {}
      : {
          for (final e in raw.entries
              .where((e) =>
                  e.key is String &&
                  RegExp(r'^[a-z0-9_]{1,30}$').hasMatch(e.key))
              .take(maxCounters))
            e.key as String: integer(e.value, -1000000000, 1000000000),
        };
  static List<Map<String, dynamic>> sanitize(Object? raw) {
    if (raw is! List) return [];
    final ids = <String>{};
    final names = <String>{};
    return [
      for (final item in raw.take(maxRules))
        _uniqueWebhook(_rule(item, ids), names)
    ];
  }

  static Map<String, dynamic> _uniqueWebhook(
      Map<String, dynamic> rule, Set<String> names) {
    final t = rule['trigger'] as Map;
    final name = t['webhook'];
    if (t['type'] == 'manual' &&
        name is String &&
        name.isNotEmpty &&
        !names.add(name)) {
      t['webhook'] = '';
    }
    return rule;
  }

  static Map<String, dynamic> _rule(Object? raw, Set<String> ids) {
    final m = raw is Map ? raw : const {};
    var invalid = m['invalid'] == true;
    String id(Object? v, String fallback) {
      final s = text(v, 40);
      if (!RegExp(idPattern).hasMatch(s) ||
          (v is String && v.trim().length > 40)) {
        invalid = true;
        return fallback;
      }
      return s;
    }

    final ruleId = id(m['id'], 'invalid_${ids.length}');
    if (!ids.add(ruleId)) invalid = true;
    Map<String, dynamic> params(
        Object? v, Map<String, Map<String, RuleField>> table) {
      final map = v is Map ? v : const {};
      final type = text(map['type'], 200), fields = table[type];
      if (fields == null) {
        invalid = true;
        return {'type': type};
      }
      final result = <String, dynamic>{'type': type};
      for (final e in fields.entries) {
        final f = e.value, value = map[e.key];
        if (f.numeric) {
          if (value is! num || !value.isFinite) invalid = true;
          result[e.key] = e.key == 'minAmount' && value is num && value.isFinite
              ? value.clamp(f.min, f.max)
              : integer(value, f.min, f.max, f.fallback as int);
        } else if (f.fallback is bool) {
          result[e.key] = value is bool ? value : false;
        } else if (f.choices != null) {
          if (!f.choices!.contains(value)) invalid = true;
          result[e.key] = f.choices!.contains(value) ? value : f.fallback;
        } else {
          if (value is String &&
              value.trim().isNotEmpty &&
              f.pattern != null &&
              !RegExp(f.pattern!).hasMatch(value.trim())) {
            invalid = true;
          }
          var s = text(value, f.max);
          if (e.key == 'command') s = s.toLowerCase();
          if (s.length < f.min ||
              (s.isNotEmpty &&
                  f.pattern != null &&
                  !RegExp(f.pattern!).hasMatch(s))) {
            invalid = true;
          }
          result[e.key] = s;
        }
      }
      if (type == 'sound.play' &&
          result['source'] == 'library' &&
          result['mediaId'] == '') {
        invalid = true;
      }
      if (type == 'giveaway' &&
          result['op'] == 'start' &&
          result['keyword'] == '') {
        invalid = true;
      }
      return result;
    }

    final trigger = params(m['trigger'], triggers);
    final list = m['actions'];
    if (list is! List) invalid = true;
    final actionIds = <String>{};
    final aa = <Map<String, dynamic>>[];
    if (list is List) {
      for (final a in list.take(maxActions)) {
        final v = params(a, actions),
            aid = id(a is Map ? a['id'] : null, 'invalid_${aa.length}');
        if (!actionIds.add(aid)) invalid = true;
        aa.add({'id': aid, ...v});
      }
    }
    final c = m['conditions'] is Map ? m['conditions'] as Map : const {};
    List<String> subset(String k, List<String> allowed) => c[k] is List
        ? (c[k] as List)
            .whereType<String>()
            .where(allowed.contains)
            .toSet()
            .toList()
        : [];
    return {
      'id': ruleId,
      'name': text(m['name'], 60),
      'enabled': !invalid && m['enabled'] == true,
      'invalid': invalid,
      'trigger': trigger,
      'conditions': {
        'platforms': subset('platforms', platforms),
        'roles': subset('roles', roles),
        'onlyWhileStreaming': c['onlyWhileStreaming'] == true
      },
      'actions': aa,
      'cooldownSeconds': integer(m['cooldownSeconds'], 0, 3600),
      'userCooldownSeconds': integer(m['userCooldownSeconds'], 0, 3600),
      'overlap': m['overlap'] == 'skip' ? 'skip' : 'queue'
    };
  }

  /// Creates an editable, disabled rule with valid default parameters.
  static Map<String, dynamic> newRule(String triggerType,
      {required String id}) {
    final fields = triggers[triggerType];
    return sanitize([
      {
        'id': id,
        'name': 'New rule',
        'enabled': false,
        'trigger': {
          'type': triggerType,
          if (fields != null)
            for (final e in fields.entries) e.key: e.value.fallback
        },
        'actions': <Object>[],
        'cooldownSeconds': triggerType.startsWith('chat.') ? 30 : 0
      }
    ]).single;
  }
}
