import 'dart:async';

import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;

/// Wraps dart_youtube_chat.LiveChat and converts items to [ChatMessage].
class YouTubeService {
  static final RegExp _youtubeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  YouTubeService({this.streamOrientation});

  final YoutubeStreamOrientation? streamOrientation;

  yt.LiveChat? _chat;
  StreamSubscription? _sub;
  StreamSubscription? _errorSub;
  StreamSubscription? _pollSub;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _statusController =
      StreamController<(ServiceStatus, String?)>.broadcast();
  ServiceStatus _lastStatus = ServiceStatus.idle;
  int _generation = 0;

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<(ServiceStatus, String?)> get statusStream => _statusController.stream;
  String get resolvedLiveId => _chat?.liveId ?? '';

  /// Returns the video ID only for an explicit YouTube video/live URL.
  /// Channel URLs and handles deliberately return null because they are
  /// ambiguous when two simultaneous broadcasts exist.
  static String? videoIdFromUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (host != 'youtube.com' &&
        host != 'm.youtube.com' &&
        host != 'youtu.be') {
      return null;
    }
    String? candidate;
    if (host == 'youtu.be') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      candidate = segments.isEmpty ? null : segments.first;
    } else {
      candidate = uri.queryParameters['v']?.trim();
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if ((candidate == null || candidate.isEmpty) &&
          segments.length >= 2 &&
          (segments.first == 'live' || segments.first == 'shorts')) {
        candidate = segments[1];
      }
    }
    return candidate != null && _youtubeVideoIdPattern.hasMatch(candidate)
        ? candidate
        : null;
  }

  Future<void> connect({
    String handle = '',
    String liveId = '',
    String channelId = '',
  }) async {
    final generation = ++_generation;
    await _closeCurrent();
    if (generation != _generation) return;
    _emit(ServiceStatus.connecting, null);

    final normalized = _normalizeYoutubeId(
      handle: handle,
      liveId: liveId,
      channelId: channelId,
    );

    final ytId = yt.YoutubeId(
      handle: normalized.handle,
      liveId: normalized.liveId,
      channelId: normalized.channelId,
    );

    final chat = yt.LiveChat(id: ytId);
    _chat = chat;
    _sub = chat.messages.listen(
      (item) {
        if (generation != _generation || _chat != chat) return;
        if (_lastStatus != ServiceStatus.connected) {
          _emit(ServiceStatus.connected, null);
        }
        final msg = _convertItem(item);
        if (msg != null && !_controller.isClosed) _controller.add(msg);
      },
      onError: (e) {
        if (generation == _generation && _chat == chat) {
          _emit(ServiceStatus.error, e.toString());
        }
      },
    );
    _errorSub = chat.errors.listen(
      (e) {
        if (generation == _generation && _chat == chat) {
          _emit(ServiceStatus.error, e.toString());
        }
      },
    );
    _pollSub = chat.polls.listen((_) {
      if (generation != _generation || _chat != chat) return;
      if (_lastStatus != ServiceStatus.connected) {
        _emit(ServiceStatus.connected, null);
      }
    });
    try {
      await chat.start();
      if (generation != _generation || _chat != chat) {
        chat.stop();
        return;
      }
      _emit(ServiceStatus.connected, null);
    } catch (e) {
      if (generation == _generation && _chat == chat) {
        _emit(ServiceStatus.error, e.toString());
        rethrow;
      }
    }
  }

  ({String handle, String liveId, String channelId}) _normalizeYoutubeId({
    required String handle,
    required String liveId,
    required String channelId,
  }) {
    final explicitLiveId = liveId.trim();
    if (explicitLiveId.isNotEmpty) {
      return (handle: '', liveId: explicitLiveId, channelId: '');
    }

    final explicitChannelId = channelId.trim();
    if (explicitChannelId.isNotEmpty) {
      return (handle: '', liveId: '', channelId: explicitChannelId);
    }

    var value = handle.trim();
    if (value.isEmpty) return (handle: '', liveId: '', channelId: '');

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      final videoId = uri.queryParameters['v']?.trim();
      if (videoId != null && videoId.isNotEmpty) {
        return (handle: '', liveId: videoId, channelId: '');
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (host == 'youtu.be' && segments.isNotEmpty) {
        return (handle: '', liveId: segments.first, channelId: '');
      }
      if (segments.length >= 2 && segments.first == 'channel') {
        return (handle: '', liveId: '', channelId: segments[1]);
      }
      if (segments.length >= 2 && segments.first == 'live') {
        return (handle: '', liveId: segments[1], channelId: '');
      }
      if (segments.isNotEmpty && segments.first.startsWith('@')) {
        return (handle: segments.first, liveId: '', channelId: '');
      }
    }

    value = value
        .replaceFirst(RegExp(r'^https?://(www\.)?youtube\.com/'), '')
        .replaceFirst(RegExp(r'^https?://youtu\.be/'), '');
    if (value.startsWith('watch?')) {
      final parsed = Uri.tryParse('https://youtube.com/$value');
      final videoId = parsed?.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return (handle: '', liveId: videoId, channelId: '');
      }
    }
    final pathValue = value.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (pathValue.startsWith('channel/')) {
      final parts = pathValue.split('/');
      if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
        return (handle: '', liveId: '', channelId: parts[1].trim());
      }
    }
    if (_looksLikeChannelId(value)) {
      return (handle: '', liveId: '', channelId: value);
    }
    if (_youtubeVideoIdPattern.hasMatch(value)) {
      return (handle: '', liveId: value, channelId: '');
    }
    if (value.startsWith('@')) {
      return (handle: value.split('/').first, liveId: '', channelId: '');
    }

    return (handle: '@${value.split('/').first}', liveId: '', channelId: '');
  }

  bool _looksLikeChannelId(String value) =>
      RegExp(r'^UC[a-zA-Z0-9_-]{20,}$').hasMatch(value);

  Future<void> disconnect() async {
    ++_generation;
    await _closeCurrent();
    _emit(ServiceStatus.idle, null);
  }

  Future<void> _closeCurrent() async {
    await _sub?.cancel();
    _sub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    await _pollSub?.cancel();
    _pollSub = null;
    _chat?.stop();
    _chat = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
    await _statusController.close();
  }

  void _emit(ServiceStatus status, String? error) {
    _lastStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add((status, error));
    }
  }

  ChatMessage? _convertItem(yt.ChatItem item) {
    final items = item.message.map((m) {
      if (m.isEmoji) {
        return MessageItem.emoji(EmojiItem(
          url: m.emoji!.url,
          alt: m.emoji!.emojiText,
        ));
      }
      return MessageItem.text(m.text);
    }).toList();

    SuperChat? superChat;
    if (item.superChat != null) {
      final sc = item.superChat!;
      superChat = SuperChat(
        amount: sc.amount,
        color: sc.color,
        stickerUrl: sc.sticker?.url,
      );
    }

    AuthorBadge? badge;
    if (item.author.badge != null) {
      badge = AuthorBadge(
        imageUrl: item.author.badge!.thumbnail.url,
        label: item.author.badge!.label,
      );
    }

    return ChatMessage(
      platform: Platform.youtube,
      id: item.id,
      author: ChatAuthor(
        name: item.author.name,
        avatarUrl: item.author.thumbnail?.url,
        channelId: item.author.channelId,
        badge: badge,
      ),
      items: items,
      superChat: superChat,
      isMembership: item.isMembership,
      isMembershipEvent: item.isMembershipEvent,
      isOwner: item.isOwner,
      isModerator: item.isModerator,
      isVerified: item.isVerified,
      youtubeStreamOrientation: streamOrientation,
      timestamp: item.timestamp,
    );
  }
}
