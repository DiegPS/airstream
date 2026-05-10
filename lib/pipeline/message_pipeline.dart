import 'dart:async';
import 'dart:collection';

import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/settings/settings_model.dart';

/// Merges streams from YouTube, Twitch, and Kick, applies filtering rules,
/// and enforces the maxMessages buffer cap.
class MessagePipeline {
  final _controller = StreamController<ChatMessage>.broadcast();
  final _buffer = <ChatMessage>[];
  final _subscriptions = <StreamSubscription>[];
  final _seenIdKeys = <String>{};
  final _seenContentKeys = <String>{};
  final _seenOrder = Queue<({String idKey, String contentKey})>();

  SettingsModel _settings;

  MessagePipeline(this._settings);

  /// The filtered, deduplicated output stream.
  Stream<ChatMessage> get stream => _controller.stream;

  /// Current buffered messages (up to settings.maxMessages).
  List<ChatMessage> get buffer => List.unmodifiable(_buffer);

  void clear() {
    _buffer.clear();
    _seenIdKeys.clear();
    _seenContentKeys.clear();
    _seenOrder.clear();
  }

  void updateSettings(SettingsModel settings) {
    _settings = settings;
    _trimSeenKeys();
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
    if (_isDuplicate(msg)) return;

    _rememberMessage(msg);

    _buffer.add(msg);
    while (_buffer.length > _settings.maxMessages) {
      _buffer.removeAt(0);
    }

    if (!_controller.isClosed) _controller.add(msg);
  }

  bool _isDuplicate(ChatMessage msg) {
    final idKey = msg.dedupeIdKey;
    if (idKey.isNotEmpty && _seenIdKeys.contains(idKey)) {
      return true;
    }
    return _seenContentKeys.contains(msg.dedupeContentKey);
  }

  void _rememberMessage(ChatMessage msg) {
    final idKey = msg.dedupeIdKey;
    final contentKey = msg.dedupeContentKey;

    if (idKey.isNotEmpty) {
      _seenIdKeys.add(idKey);
    }
    _seenContentKeys.add(contentKey);
    _seenOrder.add((idKey: idKey, contentKey: contentKey));
    _trimSeenKeys();
  }

  void _trimSeenKeys() {
    while (_seenOrder.length > _maxTrackedMessages) {
      final oldest = _seenOrder.removeFirst();
      if (oldest.idKey.isNotEmpty) {
        _seenIdKeys.remove(oldest.idKey);
      }
      _seenContentKeys.remove(oldest.contentKey);
    }
  }

  int get _maxTrackedMessages {
    final scaled = _settings.maxMessages * 20;
    if (scaled < 500) return 500;
    if (scaled > 5000) return 5000;
    return scaled;
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
