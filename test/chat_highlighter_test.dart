import 'package:airstream/models/chat_message.dart';
import 'package:airstream/pipeline/chat_highlighter.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(
  String text, {
  String author = 'viewer',
  bool owner = false,
  bool membershipEvent = false,
  bool first = false,
}) =>
    ChatMessage(
      platform: Platform.twitch,
      id: text,
      author: ChatAuthor(name: author, channelId: author),
      items: [MessageItem.text(text)],
      isOwner: owner,
      isFirstInSession: first,
      isMembershipEvent: membershipEvent,
      timestamp: DateTime.utc(2026, 11, 15),
    );

void main() {
  final highlighter = ChatHighlighter.fromSettings(const SettingsModel(
    twitchChannel: 'xqc',
    kickSlug: 'el-streamer',
    youtubeHandle: '@LofiGirl',
    highlightWords: ['pregunta', 'canción del día'],
  ));

  test('mentions of any of the streamer channels stand out', () {
    expect(highlighter.matches(_message('@xqc hola')), isTrue);
    expect(highlighter.matches(_message('XQC!!! que buen juego')), isTrue);
    expect(highlighter.matches(_message('saludos @el-streamer')), isTrue);
    expect(highlighter.matches(_message('te veo @LofiGirl')), isTrue);
    expect(highlighter.matches(_message('xqcfan123 dice hola')), isFalse);
  });

  test('highlight words match whole words and phrases in any case', () {
    expect(highlighter.matches(_message('Tengo una PREGUNTA')), isTrue);
    expect(highlighter.matches(_message('la canción del día!')), isTrue);
    expect(highlighter.matches(_message('preguntas varias')), isFalse);
    expect(highlighter.matches(_message('canción de ayer')), isFalse);
  });

  test('the streamer own messages and system events never stand out', () {
    expect(highlighter.matches(_message('pregunta', owner: true)), isFalse);
    expect(highlighter.matches(_message('@xqc', author: 'XQC')), isFalse);
    expect(
      highlighter.matches(_message('pregunta', membershipEvent: true)),
      isFalse,
    );
  });

  test('mentions can be turned off while words keep working', () {
    final wordsOnly = ChatHighlighter.fromSettings(const SettingsModel(
      twitchChannel: 'xqc',
      highlightMentions: false,
      highlightWords: ['pregunta'],
    ));
    expect(wordsOnly.matches(_message('@xqc hola')), isFalse);
    expect(wordsOnly.matches(_message('una pregunta')), isTrue);
  });

  test('a YouTube ID or URL is not taken as a name to mention', () {
    final names = ChatHighlighter.ownChannelNames(const SettingsModel(
      youtubeHandle: 'https://www.youtube.com/watch?v=jfKfPfyJRdk',
    ));
    expect(names, isEmpty);
  });

  test('mentions outrank keywords, which outrank first session messages', () {
    expect(highlighter.highlightKind(_message('xqc pregunta', first: true)),
        HighlightKind.mention);
    expect(highlighter.highlightKind(_message('pregunta', first: true)),
        HighlightKind.word);
    expect(highlighter.highlightKind(_message('hola', first: true)),
        HighlightKind.firstMessage);
    expect(highlighter.highlightKind(_message('hola')), isNull);
    final noFirst = ChatHighlighter.fromSettings(
      const SettingsModel(highlightFirstMessages: false),
    );
    expect(noFirst.highlightKind(_message('hola', first: true)), isNull);
  });

  test('legacy tones preserve the original trigger kinds', () {
    expect(SettingsModel.fromJson({'highlightSound': true}).highlightSounds, {
      HighlightKind.mention: 'chime',
      HighlightKind.word: 'chime',
      HighlightKind.firstMessage: 'none',
    });
    expect(SettingsModel.fromJson({'highlightSound': false}).highlightSounds,
        HighlightSounds.defaults);
    expect(
        SettingsModel.fromJson({
          'highlightSound': true,
          'highlightSounds': {
            'mention': '../wav',
            'word': 42,
            'other': 'chime'
          },
        }).highlightSounds,
        HighlightSounds.defaults);
  });

  test('highlight settings survive a save and reload', () {
    const settings = SettingsModel(
      highlightMentions: false,
      highlightWords: ['pregunta', 'sorteo'],
      highlightSounds: {
        HighlightKind.mention: 'coin',
        HighlightKind.word: '1234567890abcdef',
        HighlightKind.firstMessage: 'fanfare',
      },
    );
    final restored = SettingsModel.fromJsonString(settings.toJsonString());
    expect(restored.highlightMentions, isFalse);
    expect(restored.highlightWords, ['pregunta', 'sorteo']);
    expect(restored.highlightSounds, settings.highlightSounds);

    final corrupt = SettingsModel.fromJson({'highlightWords': 'not-a-list'});
    expect(corrupt.highlightWords, isEmpty);
    expect(corrupt.highlightMentions, isTrue);
  });
}
