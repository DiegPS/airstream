import 'package:airstream/models/chat_message.dart';
import 'package:airstream/ui/chat/paused_chat_view.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(String id, [String text = 'hi']) => ChatMessage(
      platform: Platform.twitch,
      id: id,
      author: const ChatAuthor(name: 'viewer', channelId: 'viewer'),
      items: [MessageItem.text(text)],
      timestamp: DateTime.utc(2026, 5, 9, 12),
    );

void main() {
  test('reading back keeps the same messages on screen', () {
    final snapshot = [_message('1'), _message('2'), _message('3')];
    final live = [_message('2'), _message('3'), _message('4'), _message('5')];

    final view = pausedChatView(snapshot, live, bufferFull: true);

    // Message 1 was trimmed from the full buffer but is still being read;
    // 4 and 5 wait below.
    expect(view.messages.map((m) => m.id), ['1', '2', '3']);
    expect(view.newCount, 2);
  });

  test('a fast chat never empties the paused view', () {
    final snapshot = [_message('1'), _message('2')];
    final live = [_message('7'), _message('8')];

    final view = pausedChatView(snapshot, live, bufferFull: true);

    expect(view.messages.map((m) => m.id), ['1', '2']);
    expect(view.newCount, 2);
  });

  test('moderated messages still leave the paused view', () {
    final snapshot = [_message('1'), _message('2'), _message('3')];
    // 2 was deleted by a moderator; the buffer is not full, nothing trimmed.
    final live = [_message('1'), _message('3')];

    expect(
        pausedChatView(snapshot, live).messages.map((m) => m.id), ['1', '3']);
    // With a full buffer, a gap in the middle is still a deletion.
    expect(
        pausedChatView(snapshot, live, bufferFull: true)
            .messages
            .map((m) => m.id),
        ['1', '3']);
  });

  test('reading back shows the latest version of each message', () {
    final view = pausedChatView(
      [_message('1', 'before')],
      [_message('1', 'after')],
    );

    expect(view.messages.single.plainText, 'after');
    expect(view.newCount, 0);
  });
}
