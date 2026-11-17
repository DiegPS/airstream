import 'rule_model.dart';

/// Disabled starting points; callers assign fresh IDs before persistence.
abstract final class RuleRecipes {
  static List<Map<String, dynamic>> get all => [
        _recipe(1, 'support.raid', {}, [
          {'type': 'obs.scene', 'scene': 'Raid'},
          {'type': 'wait', 'seconds': 15},
          {'type': 'obs.previousScene'},
        ]),
        _recipe(
            2,
            'chat.command',
            {'command': '!redes'},
            [
              {'type': 'template.trigger', 'name': 'redes', 'data': ''},
              {'type': 'tts.say', 'text': 'Sígueme en …'},
            ],
            cooldown: 60),
        _recipe(3, 'support.superchat', {
          'minAmount': 5,
          'currency': r'$'
        }, [
          {'type': 'tts.say', 'text': '{user} dice: {message}'},
        ]),
        _recipe(4, 'interval', {
          'minutes': 20
        }, [
          {'type': 'template.trigger', 'name': 'recordatorio', 'data': ''},
        ]),
        _recipe(5, 'goal.reached', {
          'goalId': ''
        }, [
          {'type': 'obs.scene', 'scene': 'Celebración'},
          {'type': 'wait', 'seconds': 10},
          {'type': 'obs.previousScene'},
        ]),
        _recipe(
            6,
            'chat.command',
            {'command': '!muerte'},
            [
              {'type': 'counter', 'name': 'muertes', 'op': 'add', 'value': 1},
              {
                'type': 'template.trigger',
                'name': 'muertes',
                'data': '{counter.muertes}'
              },
            ],
            roles: ['moderator'],
            cooldown: 30),
      ];
  static Map<String, dynamic> _recipe(int n, String type,
      Map<String, dynamic> params, List<Map<String, dynamic>> actions,
      {int cooldown = 0, List<String> roles = const []}) {
    final base = RuleSchema.newRule(type, id: 'recipe_$n');
    return RuleSchema.sanitize([
      {
        ...base,
        'trigger': {...base['trigger'] as Map, ...params},
        'conditions': {...base['conditions'] as Map, 'roles': roles},
        'actions': [
          for (var i = 0; i < actions.length; i++) {'id': 'a_$i', ...actions[i]}
        ],
        'cooldownSeconds': cooldown,
      }
    ]).single;
  }
}
