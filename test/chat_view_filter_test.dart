import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_view_filter.dart';
import 'package:airstream/pipeline/chat_highlighter.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(
  String id,
  Platform platform, {
  bool member = false,
  bool moderator = false,
  bool owner = false,
  String text = 'hola',
}) =>
    ChatMessage(
      platform: platform,
      id: id,
      author: ChatAuthor(name: id, channelId: id),
      items: [MessageItem.text(text)],
      isMembership: member,
      isModerator: moderator,
      isOwner: owner,
      timestamp: DateTime.utc(2026, 11, 15),
    );

void main() {
  final highlighter = ChatHighlighter(ownNames: ['xqc'], words: []);
  final messages = [
    _message('yt', Platform.youtube, member: true),
    _message('tw', Platform.twitch, moderator: true),
    _message('kk', Platform.kick, text: '@xqc hola'),
    _message('owner', Platform.twitch, owner: true),
  ];
  List<String> ids(ChatViewFilter filter) =>
      filter.apply(messages, highlighter).map((m) => m.id).toList();

  test('no filter shows every message', () {
    const filter = ChatViewFilter();
    expect(filter.isActive, isFalse);
    expect(identical(filter.apply(messages, highlighter), messages), isTrue);
  });

  test('hidden platforms are left out', () {
    final filter = const ChatViewFilter().togglePlatform(Platform.twitch);
    expect(filter.isActive, isTrue);
    expect(ids(filter), ['yt', 'kk']);
    expect(filter.togglePlatform(Platform.twitch).isActive, isFalse);
  });

  test('roles keep members, moderators or highlighted messages', () {
    const filter = ChatViewFilter();
    expect(ids(filter.withRole(ChatViewRole.members)), ['yt']);
    expect(ids(filter.withRole(ChatViewRole.moderators)), ['tw', 'owner']);
    expect(ids(filter.withRole(ChatViewRole.highlighted)), ['kk']);
  });

  test('platforms and roles combine', () {
    final filter = const ChatViewFilter()
        .withRole(ChatViewRole.moderators)
        .togglePlatform(Platform.twitch);
    expect(ids(filter), isEmpty);
  });
}
