import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/pipeline/word_matching.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter/foundation.dart' show listEquals;

class ChatFilter {
  ChatFilter(SettingsModel settings)
      : _users = settings.blockedUsers
            .map(normalizeUserKey)
            .where((value) => value.isNotEmpty)
            .toSet(),
        _words = settings.blockedWords
            .map(WordMatching.normalize)
            .where((value) => value.isNotEmpty)
            .toSet();

  final Set<String> _users;
  final Set<String> _words;

  Map<String, Object?> get templateFilters => {
        'users': _users.toList(),
        'words': _words.toList(),
      };

  static bool sameBlockLists(SettingsModel previous, SettingsModel next) =>
      listEquals(previous.blockedUsers, next.blockedUsers) &&
      listEquals(previous.blockedWords, next.blockedWords);

  bool blocksMessage(ChatMessage message) =>
      _blocks(message.author.name, message.author.channelId, message.plainText);

  ChatMessage redactReply(ChatMessage message) {
    final reply = message.reply;
    if (reply == null ||
        reply.text.isEmpty ||
        !_blocks(reply.authorName, reply.authorId, reply.text)) {
      return message;
    }
    return message.copyWith(reply: reply.withoutText());
  }

  bool blocksProviderEvent(ChatProviderEvent event) => _blocks(
        event.viewerName ?? event.authorName,
        event.authorChannelId,
        event.viewerText ??
            (switch (event.kind) {
              ChatProviderEventKind.reward ||
              ChatProviderEventKind.pinnedMessage ||
              ChatProviderEventKind.support =>
                event.text,
              _ => '',
            }),
      );

  bool _blocks(String name, String id, String text) =>
      blocksUser(name, id) || blocksText(text);

  bool blocksUser(String name, String id) =>
      _users.isNotEmpty &&
      (_users.contains(normalizeUserKey(name)) ||
          _users.contains(normalizeUserKey(id)));

  bool blocksText(String text) {
    if (_words.isEmpty || text.isEmpty) return false;
    final prepared = WordMatching.prepare(text);
    return _words.any((word) => WordMatching.containsPhrase(prepared, word));
  }

  static String normalizeUserKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^@+'), '')
      .replaceAll(RegExp(r'\s+'), '');
}
