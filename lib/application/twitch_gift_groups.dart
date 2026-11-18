import 'dart:async';

import 'package:airstream/models/chat_message.dart';

/// Coalesces Twitch's per-recipient notices for alerts and gift automation.
class TwitchGiftGroups {
  TwitchGiftGroups({this.window = defaultWindow});

  static const defaultWindow = Duration(seconds: 2);
  final Duration window;
  final _pending = <(String, String), _GiftGroup>{};

  static bool includes(ChatMessage message) =>
      message.platform == Platform.twitch &&
      message.membershipEventKind == MembershipEventKind.gift;

  void add(ChatMessage message, void Function(ChatMessage, int) onGroup) {
    final author = message.author;
    final key = (
      message.providerRoomId,
      author.channelId.isNotEmpty
          ? author.channelId
          : author.name.toLowerCase(),
    );
    final group = _pending.putIfAbsent(key, () => _GiftGroup(message));
    group.count++;
    group.timer?.cancel();
    group.timer = Timer(window, () {
      _pending.remove(key);
      onGroup(group.first, group.count);
    });
  }

  void clear() {
    for (final group in _pending.values) {
      group.timer?.cancel();
    }
    _pending.clear();
  }
}

class _GiftGroup {
  _GiftGroup(this.first);

  final ChatMessage first;
  int count = 0;
  Timer? timer;
}
