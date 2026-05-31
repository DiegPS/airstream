import 'dart:async';
import 'dart:collection';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_model.dart';

/// Merges streams from YouTube, Twitch, and Kick, applies filtering rules,
/// and enforces the maxMessages buffer cap.
class MessagePipeline {
  final _controller = StreamController<ChatMessage>.broadcast();
  final _buffer = <ChatMessage>[];
  final _subscriptions = <StreamSubscription>[];
  final _seenIdKeys = <String>{};
  final _seenContentKeys = <String>{};
  final _seenOrder = Queue<({String idKey, String contentKey})>();
  final _blockedUsers = <String>{};
  final _blockedWordPatterns = <String>{};

  SettingsModel _settings;

  MessagePipeline(this._settings) {
    _rebuildFilterCache();
  }

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
    _rebuildFilterCache();
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
    final authorKeys = <String>{
      _normalizeUserKey(msg.author.name),
      _normalizeUserKey(msg.author.channelId),
    }..removeWhere((value) => value.isEmpty);

    if (authorKeys.any(_blockedUsers.contains)) {
      return true;
    }

    final normalizedText = _normalizeWordPattern(msg.plainText);
    if (normalizedText.isEmpty || _blockedWordPatterns.isEmpty) {
      return false;
    }

    final paddedText = ' $normalizedText ';
    for (final blockedWord in _blockedWordPatterns) {
      if (paddedText.contains(' $blockedWord ')) {
        return true;
      }
    }

    return false;
  }

  void _rebuildFilterCache() {
    _blockedUsers
      ..clear()
      ..addAll(_settings.blockedUsers
          .map(_normalizeUserKey)
          .where((value) => value.isNotEmpty));

    _blockedWordPatterns
      ..clear()
      ..addAll(_settings.blockedWords
          .map(_normalizeWordPattern)
          .where((value) => value.isNotEmpty));
  }

  static String _normalizeUserKey(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceFirst(RegExp(r'^@+'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    return normalized;
  }

  static String _normalizeWordPattern(String value) {
    final lowered = value.toLowerCase();
    final sanitized =
        lowered.replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ');
    return sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
