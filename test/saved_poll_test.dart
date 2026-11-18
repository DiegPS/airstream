import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/application/saved_poll.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const template = {
    'name': '  Feedback  ',
    'question': '  Thoughts?  ',
    'mode': 'word',
    'options': [' Azul ', '', 'Rojo', 'Verde', 'Gris', 'Ignored'],
    'minutes': 5,
    'allowed': 'moderator',
    'hideResults': true,
    'allowChange': false,
    'command': ' !OPINA ',
  };

  test('preserves all setup fields and strips invalid and duplicate polls', () {
    final settings = SettingsModel.fromJson({
      'savedPolls': [
        null,
        {},
        {
          ...template,
          'name': 'Invalid',
          'options': ['cafe', 'Café']
        },
        {
          ...template,
          'name': 'Bad command',
          'mode': 'freeAnswer',
          'command': '!two words'
        },
        template,
        {...template, 'name': 'FEEDBACK'},
      ]
    });
    final poll = settings.savedPolls.single;
    expect(poll.name, 'Feedback');
    expect(poll.question, 'Thoughts?');
    expect(poll.options, ['Azul', '', 'Rojo', 'Verde', 'Gris']);
    expect(poll.mode, PollMode.word);
    expect(poll.minutes, 5);
    expect(poll.allowed, QueueRole.moderator);
    expect(poll.hideResults, true);
    expect(poll.allowChange, false);
    expect(poll.command, '!opina');
    expect(SettingsModel.fromJson(settings.toJson()).savedPolls.single.toJson(),
        poll.toJson());
  });

  test('keeps at most 20 unique valid setups', () {
    final loaded = SavedPoll.sanitize([
      for (var i = 0; i < 28; i++)
        {...template, 'name': 'Setup $i', 'minutes': 999},
    ]);
    expect(loaded, hasLength(20));
    expect(loaded.last.name, 'Setup 19');
    expect(loaded.last.minutes, isNull);
  });
}
