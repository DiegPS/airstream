import 'dart:async';

import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;
import 'package:airstream/models/chat_media.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/chat/youtube_transport.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;

/// Adapts a dart_youtube_chat live session to AirStream models.
class YouTubeService {
  YouTubeService({
    this.streamOrientation,
    YouTubeChatTransportFactory? transportFactory,
    Duration connectionTimeout = const Duration(seconds: 15),
  })  : _transportFactory = transportFactory ?? DartYouTubeChatTransport.new,
        _connectionTimeout = connectionTimeout;

  final YoutubeStreamOrientation? streamOrientation;
  final YouTubeChatTransportFactory _transportFactory;
  final Duration _connectionTimeout;

  YouTubeChatTransport? _chat;
  StreamSubscription<yt.ChatItem>? _sub;
  StreamSubscription<yt.LiveChatEvent>? _eventSub;
  StreamSubscription<Exception>? _chatErrorSub;
  StreamSubscription<Exception>? _metadataErrorSub;
  StreamSubscription<DateTime>? _pollSub;
  StreamSubscription<yt.UpdatedMetadataState>? _metadataSub;
  StreamSubscription<yt.YoutubeLiveLifecycle>? _lifecycleSub;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _moderationController =
      StreamController<ChatModerationEvent>.broadcast();
  final _appEventController = StreamController<ChatProviderEvent>.broadcast();
  final _metadataController =
      StreamController<YoutubeLiveMetadata?>.broadcast();
  final _statusController =
      StreamController<(ServiceStatus, String?)>.broadcast();
  ServiceStatus _lastStatus = ServiceStatus.idle;
  YoutubeLiveMetadata? _currentMetadata;
  final Set<String> _seenEventIds = <String>{};
  final List<String> _seenEventOrder = <String>[];
  int _generation = 0;
  bool _liveEnded = false;

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<ChatModerationEvent> get moderationEvents =>
      _moderationController.stream;
  Stream<ChatProviderEvent> get appEvents => _appEventController.stream;
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
    return yt.YoutubeId.tryParseVideoUrl(value)?.liveId;
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

    late final yt.YoutubeId ytId;
    try {
      ytId = _resolveYoutubeId(
        handle: handle,
        liveId: liveId,
        channelId: channelId,
      );
    } catch (error, stack) {
      AppLogger.warning(
        'YouTube identifier is invalid',
        error: error,
        stackTrace: stack,
      );
      _emit(ServiceStatus.error, error.toString());
      rethrow;
    }

    final chat = _transportFactory(ytId);
    _chat = chat;
    _sub = chat.messages.listen(
      (item) {
        if (generation != _generation || _chat != chat) return;
        if (!_liveEnded && _lastStatus != ServiceStatus.connected) {
          _emit(ServiceStatus.connected, null);
        }
        try {
          final msg = _convertItem(item);
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
    _chatErrorSub = chat.chatErrors.listen(
      (e) {
        if (generation == _generation && _chat == chat) {
          AppLogger.warning('YouTube chat reported an error', error: e);
          _emit(ServiceStatus.error, e.toString());
        }
      },
    );
    _metadataErrorSub = chat.metadataErrors.listen((e) {
      if (generation == _generation && _chat == chat) {
        AppLogger.warning(
          'YouTube metadata refresh failed; chat remains connected',
          error: e,
        );
      }
    });
    _eventSub = chat.events.listen((event) {
      if (generation != _generation || _chat != chat) return;
      try {
        final moderation = _convertModerationEvent(event);
        if (moderation != null && !_moderationController.isClosed) {
          _moderationController.add(moderation);
        }
        final membership = _convertMembershipEvent(event);
        if (membership != null && !_controller.isClosed) {
          _controller.add(membership);
        }
        final appEvent = _convertProviderEvent(event);
        if (appEvent != null && !_appEventController.isClosed) {
          _appEventController.add(appEvent);
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
      if (!_liveEnded && _lastStatus != ServiceStatus.connected) {
        _emit(ServiceStatus.connected, null);
      }
    });
    _metadataSub = chat.metadataStates.listen((state) {
      if (generation != _generation || _chat != chat) return;
      _currentMetadata = _convertMetadata(state, chat.liveId);
      _emitMetadata();
    });
    if (chat case final YouTubeLifecycleTransport lifecycle) {
      _lifecycleSub = lifecycle.lifecycle.listen((state) {
        if (generation != _generation || _chat != chat) return;
        _liveEnded = state == yt.YoutubeLiveLifecycle.ended;
        if (_liveEnded) {
          _emit(ServiceStatus.idle, null);
          if (!_appEventController.isClosed) {
            _appEventController.add(ChatProviderEvent(
              platform: Platform.youtube,
              kind: ChatProviderEventKind.streamOffline,
              id: 'stream-ended:${chat.liveId}',
              timestamp: DateTime.now().toUtc(),
            ));
          }
        }
      });
    }
    try {
      await chat.start().timeout(_connectionTimeout);
      if (generation != _generation || _chat != chat) {
        chat.stop();
        return;
      }
      _emit(ServiceStatus.connected, null);
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

  yt.YoutubeId _resolveYoutubeId({
    required String handle,
    required String liveId,
    required String channelId,
  }) {
    final explicitLiveId = liveId.trim();
    if (explicitLiveId.isNotEmpty) {
      return yt.YoutubeId(liveId: explicitLiveId);
    }

    final explicitChannelId = channelId.trim();
    if (explicitChannelId.isNotEmpty) {
      return yt.YoutubeId(channelId: explicitChannelId);
    }

    final value = handle.trim();
    if (value.isEmpty) return const yt.YoutubeId();
    final parsed = yt.YoutubeId.tryParse(value);
    if (parsed != null) return parsed;
    final uri = Uri.tryParse(value);
    if (uri?.hasScheme == true) {
      throw FormatException('Unsupported YouTube URL', value);
    }
    return yt.YoutubeId.parse('@${value.split('/').first}');
  }

  Future<void> disconnect() async {
    ++_generation;
    await _closeCurrent();
    _emit(ServiceStatus.idle, null);
  }

  Future<void> _closeCurrent() async {
    await _sub?.cancel();
    _sub = null;
    await _chatErrorSub?.cancel();
    _chatErrorSub = null;
    await _metadataErrorSub?.cancel();
    _metadataErrorSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    await _pollSub?.cancel();
    _pollSub = null;
    await _metadataSub?.cancel();
    _metadataSub = null;
    await _lifecycleSub?.cancel();
    _lifecycleSub = null;
    _currentMetadata = null;
    _liveEnded = false;
    _seenEventIds.clear();
    _seenEventOrder.clear();
    _emitMetadata();
    _chat?.stop();
    _chat = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
    await _moderationController.close();
    await _appEventController.close();
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
          url: normalizeChatImageUrl(
            emoji.bestFor(24, pixelRatio: 2).url,
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
                sc.sticker!,
                logicalSize: 128,
              ),
      );
    }

    final badges = item.author.allBadges
        .map((badge) => AuthorBadge(
              imageUrl: _bestImageUrl(
                badge.thumbnail,
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
                item.author.thumbnail!,
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
    switch (event.kind) {
      case yt.LiveChatEventKind.messageDeleted:
        if (event.targetItemId.trim().isNotEmpty) {
          return ChatModerationEvent.message(
            platform: Platform.youtube,
            messageId: event.targetItemId,
            youtubeStreamOrientation: streamOrientation,
          );
        }
      case yt.LiveChatEventKind.authorMessagesDeleted:
        if (event.authorChannelId.trim().isNotEmpty) {
          return ChatModerationEvent.author(
            platform: Platform.youtube,
            authorChannelId: event.authorChannelId,
            youtubeStreamOrientation: streamOrientation,
          );
        }
      default:
        return null;
    }
    return null;
  }

  ChatProviderEvent? _convertProviderEvent(yt.LiveChatEvent event) {
    final kind = switch (event.kind) {
      yt.LiveChatEventKind.bannerAdded => ChatProviderEventKind.pinnedMessage,
      yt.LiveChatEventKind.bannerRemoved =>
        ChatProviderEventKind.unpinnedMessage,
      yt.LiveChatEventKind.pollUpdated => ChatProviderEventKind.poll,
      yt.LiveChatEventKind.viewerNotice ||
      yt.LiveChatEventKind.tooltip ||
      yt.LiveChatEventKind.tickerAdded ||
      yt.LiveChatEventKind.tickerRemoved =>
        ChatProviderEventKind.notice,
      yt.LiveChatEventKind.chatItemReplaced ||
      yt.LiveChatEventKind.unknown =>
        ChatProviderEventKind.unknown,
      _ => null,
    };
    if (kind == null) return null;
    return ChatProviderEvent(
      platform: Platform.youtube,
      kind: kind,
      id: event.id.isNotEmpty
          ? event.id
          : '${event.actionType}:${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now().toUtc(),
      text: event.text,
      data: Map<String, Object?>.unmodifiable(event.raw),
    );
  }

  ChatMessage? _convertMembershipEvent(yt.LiveChatEvent event) {
    if (event.kind != yt.LiveChatEventKind.membershipGiftPurchased &&
        event.kind != yt.LiveChatEventKind.membershipGiftReceived) {
      return null;
    }
    final stableId = event.id.trim();
    final authorName = event.authorName.trim();
    final text = event.text.trim();
    final eventKey = stableId.isNotEmpty
        ? stableId
        : '${event.kind.name}:${event.authorChannelId}:${event.timestamp?.microsecondsSinceEpoch}:$text';
    if (!_rememberEvent(eventKey)) return null;
    return ChatMessage(
      platform: Platform.youtube,
      id: stableId.isEmpty
          ? 'youtube-membership-${event.timestamp?.microsecondsSinceEpoch ?? DateTime.now().microsecondsSinceEpoch}'
          : stableId,
      author: ChatAuthor(
        name: authorName.isEmpty ? 'YouTube' : authorName,
        avatarUrl: event.authorThumbnail == null
            ? null
            : _bestImageUrl(event.authorThumbnail!, logicalSize: 44),
        channelId: event.authorChannelId,
      ),
      items: text.isEmpty ? const [] : [MessageItem.text(text)],
      isMembership: true,
      isMembershipEvent: true,
      membershipEventKind: MembershipEventKind.gift,
      membershipGiftCount:
          event.giftMembershipCount > 0 ? event.giftMembershipCount : null,
      youtubeStreamOrientation: streamOrientation,
      timestamp: event.timestamp ?? DateTime.now(),
    );
  }

  bool _rememberEvent(String key) {
    if (!_seenEventIds.add(key)) return false;
    _seenEventOrder.add(key);
    const maximumRememberedEvents = 2000;
    if (_seenEventOrder.length > maximumRememberedEvents) {
      _seenEventIds.remove(_seenEventOrder.removeAt(0));
    }
    return true;
  }

  String _bestImageUrl(
    yt.ImageItem image, {
    required double logicalSize,
  }) {
    return normalizeChatImageUrl(
      image.bestFor(logicalSize, pixelRatio: 2).url,
    );
  }

  YoutubeLiveMetadata _convertMetadata(
    yt.UpdatedMetadataState state,
    String liveId,
  ) {
    final batch = state.lastBatch;
    return YoutubeLiveMetadata(
      liveId: liveId,
      streamOrientation: streamOrientation,
      viewerCount: state.viewership?.originalViewCountValue,
      viewerCountText: state.viewership?.unlabeledViewCountValue.text ?? '',
      isLive: state.viewership?.isLive,
      title: state.title?.text ?? '',
      dateText: state.dateText?.text ?? '',
      description: state.description?.text ?? '',
      updatedAt:
          batch?.frameworkUpdates.entityBatchUpdate?.timestamp?.dateTime ??
              DateTime.now().toUtc(),
    );
  }
}
