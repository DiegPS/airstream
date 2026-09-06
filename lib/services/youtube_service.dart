import 'dart:async';

import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;
import 'package:airstream/models/chat_media.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/chat/youtube_transport.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;

/// Wraps dart_youtube_chat.LiveChat and converts items to [ChatMessage].
class YouTubeService {
  static final RegExp _youtubeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  YouTubeService({
    this.streamOrientation,
    YouTubeChatTransportFactory? transportFactory,
    YouTubeMetadataTransportFactory? metadataTransportFactory,
    Duration connectionTimeout = const Duration(seconds: 15),
  })  : _transportFactory = transportFactory ?? DartYouTubeChatTransport.new,
        _metadataTransportFactory =
            metadataTransportFactory ?? DartYouTubeMetadataTransport.new,
        _connectionTimeout = connectionTimeout;

  final YoutubeStreamOrientation? streamOrientation;
  final YouTubeChatTransportFactory _transportFactory;
  final YouTubeMetadataTransportFactory _metadataTransportFactory;
  final Duration _connectionTimeout;

  YouTubeChatTransport? _chat;
  YouTubeMetadataTransport? _metadata;
  StreamSubscription? _sub;
  StreamSubscription? _eventSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _pollSub;
  StreamSubscription<yt.UpdatedMetadataBatch>? _metadataSub;
  StreamSubscription<Exception>? _metadataErrorSub;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _moderationController =
      StreamController<ChatModerationEvent>.broadcast();
  final _metadataController =
      StreamController<YoutubeLiveMetadata?>.broadcast();
  final _statusController =
      StreamController<(ServiceStatus, String?)>.broadcast();
  ServiceStatus _lastStatus = ServiceStatus.idle;
  YoutubeLiveMetadata? _currentMetadata;
  int _generation = 0;

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<ChatModerationEvent> get moderationEvents =>
      _moderationController.stream;
  Stream<YoutubeLiveMetadata?> get metadataStream async* {
    yield _currentMetadata;
    yield* _metadataController.stream;
  }

  Stream<(ServiceStatus, String?)> get statusStream => _statusController.stream;
  String get resolvedLiveId => _chat?.liveId ?? '';
  YoutubeLiveMetadata? get currentMetadata => _currentMetadata;

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

    final chat = _transportFactory(ytId);
    _chat = chat;
    _sub = chat.messages.listen(
      (item) {
        if (generation != _generation || _chat != chat) return;
        if (_lastStatus != ServiceStatus.connected) {
          _emit(ServiceStatus.connected, null);
        }
        try {
          final msg = _convertItem(item as yt.ChatItem);
          if (!_controller.isClosed) _controller.add(msg);
        } catch (error, stack) {
          AppLogger.warning(
            'YouTube returned a malformed chat item',
            error: error,
            stackTrace: stack,
          );
          _emit(ServiceStatus.error, 'Invalid YouTube chat response.');
        }
      },
      onError: (e) {
        if (generation == _generation && _chat == chat) {
          AppLogger.warning('YouTube message stream failed', error: e);
          _emit(ServiceStatus.error, e.toString());
        }
      },
    );
    _errorSub = chat.errors.listen(
      (e) {
        if (generation == _generation && _chat == chat) {
          AppLogger.warning('YouTube client reported an error', error: e);
          _emit(ServiceStatus.error, e.toString());
        }
      },
    );
    _eventSub = chat.events.listen((event) {
      if (generation != _generation || _chat != chat) return;
      try {
        final moderation = _convertModerationEvent(event as yt.LiveChatEvent);
        if (moderation != null && !_moderationController.isClosed) {
          _moderationController.add(moderation);
        }
      } catch (error, stack) {
        AppLogger.warning(
          'YouTube returned a malformed chat event',
          error: error,
          stackTrace: stack,
        );
      }
    });
    _pollSub = chat.polls.listen((_) {
      if (generation != _generation || _chat != chat) return;
      if (_lastStatus != ServiceStatus.connected) {
        _emit(ServiceStatus.connected, null);
      }
    });
    try {
      await chat.start().timeout(_connectionTimeout);
      if (generation != _generation || _chat != chat) {
        chat.stop();
        return;
      }
      _emit(ServiceStatus.connected, null);
      unawaited(_startMetadata(chat, generation));
    } catch (e, stack) {
      if (generation == _generation && _chat == chat) {
        await _closeCurrent();
        AppLogger.error(
          'YouTube connection failed',
          error: e,
          stackTrace: stack,
        );
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
    await _eventSub?.cancel();
    _eventSub = null;
    await _pollSub?.cancel();
    _pollSub = null;
    await _metadataSub?.cancel();
    _metadataSub = null;
    await _metadataErrorSub?.cancel();
    _metadataErrorSub = null;
    await _metadata?.stop();
    _metadata = null;
    _currentMetadata = null;
    _emitMetadata();
    _chat?.stop();
    _chat = null;
  }

  Future<void> _startMetadata(
    YouTubeChatTransport chat,
    int generation,
  ) async {
    final liveId = chat.liveId.trim();
    if (liveId.isEmpty || generation != _generation || _chat != chat) return;

    final transport = _metadataTransportFactory(yt.YoutubeId(liveId: liveId));
    _metadata = transport;
    _currentMetadata = YoutubeLiveMetadata(
      liveId: liveId,
      streamOrientation: streamOrientation,
    );
    _metadataSub = transport.batches.listen((batch) {
      if (generation != _generation || _metadata != transport) return;
      final viewership = batch.viewership;
      _currentMetadata = _currentMetadata!.merge(
        viewerCount: viewership?.originalViewCountValue,
        viewerCountText: viewership?.unlabeledViewCountValue.text,
        isLive: viewership?.isLive,
        title: batch.title?.text,
        dateText: batch.dateText?.text,
        description: batch.description?.text,
        updatedAt:
            batch.frameworkUpdates.entityBatchUpdate?.timestamp?.dateTime ??
                DateTime.now().toUtc(),
      );
      _emitMetadata();
    });
    _metadataErrorSub = transport.errors.listen((error) {
      if (generation == _generation && _metadata == transport) {
        AppLogger.warning('YouTube metadata polling failed', error: error);
      }
    });

    try {
      await transport.start().timeout(_connectionTimeout);
    } catch (error, stack) {
      if (generation == _generation && _metadata == transport) {
        AppLogger.warning(
          'YouTube metadata initialization failed',
          error: error,
          stackTrace: stack,
        );
        await transport.stop();
        if (_metadata == transport) _metadata = null;
      }
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
    await _moderationController.close();
    await _metadataController.close();
    await _statusController.close();
  }

  void _emit(ServiceStatus status, String? error) {
    _lastStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add((status, error));
    }
  }

  void _emitMetadata() {
    if (!_metadataController.isClosed) {
      _metadataController.add(_currentMetadata);
    }
  }

  ChatMessage _convertItem(yt.ChatItem item) {
    final items = item.message.map((m) {
      if (m.isEmoji) {
        final emoji = m.emoji!;
        return MessageItem.emoji(EmojiItem(
          url: _bestImageUrl(
            emoji.url,
            emoji.variants,
            logicalSize: 24,
          ),
          alt: emoji.emojiText,
          isCustom: emoji.isCustomEmoji,
        ));
      }
      return MessageItem.text(m.text);
    }).toList(growable: true);
    if (items.isEmpty && item.membershipText.trim().isNotEmpty) {
      items.add(MessageItem.text(item.membershipText.trim()));
    }

    SuperChat? superChat;
    if (item.superChat != null) {
      final sc = item.superChat!;
      superChat = SuperChat(
        amount: sc.amount,
        color: sc.color,
        stickerUrl: sc.sticker == null
            ? null
            : _bestImageUrl(
                sc.sticker!.url,
                sc.sticker!.variants,
                logicalSize: 128,
              ),
      );
    }

    final sourceBadges = item.author.badges.isNotEmpty
        ? item.author.badges
        : [if (item.author.badge != null) item.author.badge!];
    final badges = sourceBadges
        .map((badge) => AuthorBadge(
              imageUrl: _bestImageUrl(
                badge.thumbnail.url,
                badge.thumbnail.variants,
                logicalSize: 16,
              ),
              label: badge.label,
            ))
        .toList(growable: false);
    final badge = badges.isEmpty ? null : badges.first;

    return ChatMessage(
      platform: Platform.youtube,
      id: item.id,
      author: ChatAuthor(
        name: item.author.name,
        avatarUrl: item.author.thumbnail == null
            ? null
            : _bestImageUrl(
                item.author.thumbnail!.url,
                item.author.thumbnail!.variants,
                logicalSize: 44,
              ),
        channelId: item.author.channelId,
        badge: badge,
        badges: badges.length < 2 ? const [] : badges.skip(1).toList(),
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

  ChatModerationEvent? _convertModerationEvent(yt.LiveChatEvent event) {
    final payload = event.raw[event.actionType];
    if (payload is! Map<String, dynamic>) return null;
    switch (event.actionType) {
      case 'removeChatItemAction':
      case 'markChatItemAsDeletedAction':
        final messageId = payload['targetItemId'];
        if (messageId is String && messageId.trim().isNotEmpty) {
          return ChatModerationEvent.message(
            platform: Platform.youtube,
            messageId: messageId,
            youtubeStreamOrientation: streamOrientation,
          );
        }
        break;
      case 'markChatItemsByAuthorAsDeletedAction':
        final channelId = payload['externalChannelId'];
        if (channelId is String && channelId.trim().isNotEmpty) {
          return ChatModerationEvent.author(
            platform: Platform.youtube,
            authorChannelId: channelId,
            youtubeStreamOrientation: streamOrientation,
          );
        }
        break;
    }
    return null;
  }

  String _bestImageUrl(
    String fallback,
    List<yt.ImageVariant> variants, {
    required double logicalSize,
  }) {
    if (variants.isEmpty) return normalizeChatImageUrl(fallback);
    final image = yt.ImageItem(
      url: fallback,
      alt: '',
      variants: variants,
    ).bestFor(logicalSize, pixelRatio: 2);
    return normalizeChatImageUrl(image.url);
  }
}
