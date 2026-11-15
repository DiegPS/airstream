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

    final view = pausedChatView(snapshot, live);

    // Message 1 was trimmed from the buffer; 4 and 5 wait below.
    expect(view.messages.map((m) => m.id), ['2', '3']);
    expect(view.newCount, 2);
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
