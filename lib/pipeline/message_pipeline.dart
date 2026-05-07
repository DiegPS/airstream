import 'dart:async';

import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/settings/settings_model.dart';

/// Merges streams from YouTube, Twitch, and Kick, applies filtering rules,
/// and enforces the maxMessages buffer cap.
class MessagePipeline {
  final _controller = StreamController<ChatMessage>.broadcast();
  final _buffer = <ChatMessage>[];
  final _subscriptions = <StreamSubscription>[];

  SettingsModel _settings;

  MessagePipeline(this._settings);

  /// The filtered, deduplicated output stream.
  Stream<ChatMessage> get stream => _controller.stream;

  /// Current buffered messages (up to settings.maxMessages).
  List<ChatMessage> get buffer => List.unmodifiable(_buffer);

  void updateSettings(SettingsModel settings) {
    _settings = settings;
  }

  /// Adds a platform stream to the pipeline. Can be called multiple times.
  void addSource(Stream<ChatMessage> source) {
    _subscriptions.add(source.listen(_handleMessage, onError: (_) {}));
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _controller.close();
  }

  void _handleMessage(ChatMessage msg) {
    if (_shouldBlock(msg)) return;

    _buffer.add(msg);
    while (_buffer.length > _settings.maxMessages) {
      _buffer.removeAt(0);
    }

    if (!_controller.isClosed) _controller.add(msg);
  }

  bool _shouldBlock(ChatMessage msg) {
    final name = msg.author.name.toLowerCase();
    if (_settings.blockedUsers.any((u) => u.toLowerCase() == name)) return true;

    final text = msg.plainText.toLowerCase();
    if (_settings.blockedWords
        .any((w) => w.isNotEmpty && text.contains(w.toLowerCase()))) {
      return true;
    }

    return false;
  }
}
