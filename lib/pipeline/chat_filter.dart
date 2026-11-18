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

  static bool sameBlockLists(SettingsModel previous, SettingsModel next) =>
      listEquals(previous.blockedUsers, next.blockedUsers) &&
      listEquals(previous.blockedWords, next.blockedWords);

  bool blocksMessage(ChatMessage message) =>
      _blocks(message.author.name, message.author.channelId, message.plainText);

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

  bool _blocks(String name, String id, String text) {
    if (_users.isNotEmpty &&
        (_users.contains(normalizeUserKey(name)) ||
            _users.contains(normalizeUserKey(id)))) {
      return true;
    }
    if (_words.isEmpty || text.isEmpty) return false;
    final paddedText = ' ${WordMatching.normalize(text)} ';
    return _words.any((word) => paddedText.contains(' $word '));
  }

  static String normalizeUserKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^@+'), '')
      .replaceAll(RegExp(r'\s+'), '');
}
