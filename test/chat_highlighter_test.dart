import 'package:airstream/models/chat_message.dart';
import 'package:airstream/pipeline/chat_highlighter.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(
  String text, {
  String author = 'viewer',
  bool owner = false,
  bool membershipEvent = false,
}) =>
    ChatMessage(
      platform: Platform.twitch,
      id: text,
      author: ChatAuthor(name: author, channelId: author),
      items: [MessageItem.text(text)],
      isOwner: owner,
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

  test('highlight settings survive a save and reload', () {
    const settings = SettingsModel(
      highlightMentions: false,
      highlightWords: ['pregunta', 'sorteo'],
      highlightSound: true,
    );
    final restored = SettingsModel.fromJsonString(settings.toJsonString());
    expect(restored.highlightMentions, isFalse);
    expect(restored.highlightWords, ['pregunta', 'sorteo']);
    expect(restored.highlightSound, isTrue);

    final corrupt = SettingsModel.fromJson({'highlightWords': 'not-a-list'});
    expect(corrupt.highlightWords, isEmpty);
    expect(corrupt.highlightMentions, isTrue);
  });
}
