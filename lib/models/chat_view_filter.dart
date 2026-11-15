import 'package:airstream/models/chat_message.dart';
import 'package:airstream/pipeline/chat_highlighter.dart';

/// Which messages Airstream's chat window shows. The OBS overlay always
/// shows every message.
enum ChatViewRole { all, members, moderators, highlighted }

class ChatViewFilter {
  const ChatViewFilter({
    this.hiddenPlatforms = const {},
    this.role = ChatViewRole.all,
  });

  final Set<Platform> hiddenPlatforms;
  final ChatViewRole role;

  bool get isActive => hiddenPlatforms.isNotEmpty || role != ChatViewRole.all;

  ChatViewFilter togglePlatform(Platform platform) => ChatViewFilter(
        hiddenPlatforms: hiddenPlatforms.contains(platform)
            ? ({...hiddenPlatforms}..remove(platform))
            : {...hiddenPlatforms, platform},
        role: role,
      );

  ChatViewFilter withRole(ChatViewRole role) =>
      ChatViewFilter(hiddenPlatforms: hiddenPlatforms, role: role);

  bool accepts(ChatMessage message, ChatHighlighter highlighter) {
    if (hiddenPlatforms.contains(message.platform)) return false;
    return switch (role) {
      ChatViewRole.all => true,
      ChatViewRole.members => message.isMembership || message.isMembershipEvent,
      ChatViewRole.moderators => message.isModerator || message.isOwner,
      ChatViewRole.highlighted => highlighter.matches(message),
    };
  }

  /// The messages of [messages] this filter shows, keeping their order.
  List<ChatMessage> apply(
    List<ChatMessage> messages,
    ChatHighlighter highlighter,
  ) =>
      isActive
          ? [
              for (final message in messages)
                if (accepts(message, highlighter)) message,
            ]
          : messages;
}
