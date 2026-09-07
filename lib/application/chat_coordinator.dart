import 'dart:async';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/pipeline/message_pipeline.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/twitch_service.dart';
import 'package:airstream/services/youtube_service.dart';
import 'package:airstream/settings/settings_model.dart';

abstract interface class YouTubeChatClient {
  Stream<ChatMessage> get messages;
  Stream<ChatModerationEvent> get moderationEvents;
  Stream<YoutubeLiveMetadata?> get metadataStream;
  Stream<(ServiceStatus, String?)> get statusStream;
  String get resolvedLiveId;
  YoutubeLiveMetadata? get currentMetadata;
  Future<void> connect({String handle, String liveId});
  Future<void> disconnect();
  Future<void> dispose();
}

abstract interface class ChannelChatClient {
  Stream<ChatMessage> get messages;
  Stream<(ServiceStatus, String?)> get statusStream;
  Future<void> connect(String channel);
  Future<void> disconnect();
  Future<void> dispose();
}

abstract interface class ModeratingChannelChatClient {
  Stream<ChatModerationEvent> get moderationEvents;
}

abstract interface class ProviderEventChatClient {
  Stream<ChatProviderEvent> get appEvents;
}

abstract interface class MetadataChannelChatClient {
  Stream<PlatformLiveMetadata?> get platformMetadataStream;
}

class YouTubeChatServiceAdapter
    implements YouTubeChatClient, ProviderEventChatClient {
  YouTubeChatServiceAdapter(this.service);

  final YouTubeService service;

  @override
  Stream<ChatMessage> get messages => service.messages;
  @override
  Stream<ChatModerationEvent> get moderationEvents => service.moderationEvents;
  @override
  Stream<ChatProviderEvent> get appEvents => service.appEvents;
  @override
  Stream<YoutubeLiveMetadata?> get metadataStream => service.metadataStream;
  @override
  Stream<(ServiceStatus, String?)> get statusStream => service.statusStream;
  @override
  String get resolvedLiveId => service.resolvedLiveId;
  @override
  YoutubeLiveMetadata? get currentMetadata => service.currentMetadata;
  @override
  Future<void> connect({String handle = '', String liveId = ''}) =>
      service.connect(handle: handle, liveId: liveId);
  @override
  Future<void> disconnect() => service.disconnect();
  @override
  Future<void> dispose() => service.dispose();
}

class KickChatServiceAdapter
    implements
        ChannelChatClient,
        ModeratingChannelChatClient,
        ProviderEventChatClient,
        MetadataChannelChatClient {
  KickChatServiceAdapter(this.service);

  final KickService service;

  @override
  Stream<ChatMessage> get messages => service.messages;
  @override
  Stream<(ServiceStatus, String?)> get statusStream => service.statusStream;
  @override
  Stream<ChatModerationEvent> get moderationEvents => service.moderationEvents;
  @override
  Stream<ChatProviderEvent> get appEvents => service.appEvents;
  @override
  Stream<PlatformLiveMetadata?> get platformMetadataStream =>
      service.metadataStream;
  @override
  Future<void> connect(String channel) => service.connect(channel);
  @override
  Future<void> disconnect() => service.disconnect();
  @override
  Future<void> dispose() => service.dispose();
}

class TwitchChatServiceAdapter
    implements
        ChannelChatClient,
        ModeratingChannelChatClient,
        ProviderEventChatClient {
  TwitchChatServiceAdapter(this.service);

  final TwitchService service;

  @override
  Stream<ChatMessage> get messages => service.messages;
  @override
  Stream<(ServiceStatus, String?)> get statusStream => service.statusStream;
  @override
  Stream<ChatModerationEvent> get moderationEvents => service.moderationEvents;
  @override
  Stream<ChatProviderEvent> get appEvents => service.appEvents;
  @override
  Future<void> connect(String channel) => service.connect(channel);
  @override
  Future<void> disconnect() => service.disconnect();
  @override
  Future<void> dispose() => service.dispose();
}

class ChatCoordinator {
  ChatCoordinator({
    required YouTubeChatClient youtube,
    required YouTubeChatClient youtubeHorizontal,
    required YouTubeChatClient youtubeVertical,
    required ChannelChatClient kick,
    required ChannelChatClient twitch,
    MessagePipeline? pipeline,
    String? Function(String value)? youtubeVideoIdFromUrl,
  })  : _youtube = youtube,
        _youtubeHorizontal = youtubeHorizontal,
        _youtubeVertical = youtubeVertical,
        _kick = kick,
        _twitch = twitch,
        _pipeline = pipeline ?? MessagePipeline(const SettingsModel()),
        _youtubeVideoIdFromUrl =
            youtubeVideoIdFromUrl ?? YouTubeService.videoIdFromUrl {
    _pipeline.addSource(_youtube.messages);
    _pipeline.addSource(_youtubeHorizontal.messages);
    _pipeline.addSource(_youtubeVertical.messages);
    _pipeline.addSource(_kick.messages);
    _pipeline.addSource(_twitch.messages);
    _pipelineSub = _pipeline.stream.listen((message) {
      if (!_listController.isClosed) {
        _listController.add(_pipeline.buffer);
      }
    });
    _statusSubscriptions.addAll([
      _youtube.statusStream.listen(
        (status) => _handleServiceStatus('youtube', status),
      ),
      _youtubeHorizontal.statusStream.listen(
        (status) => _handleServiceStatus('youtubeHorizontal', status),
      ),
      _youtubeVertical.statusStream.listen(
        (status) => _handleServiceStatus('youtubeVertical', status),
      ),
      _kick.statusStream.listen(
        (status) => _handleServiceStatus('kick', status),
      ),
      _twitch.statusStream.listen(
        (status) => _handleServiceStatus('twitch', status),
      ),
    ]);
    _metadataSubscriptions.addAll([
      _youtube.metadataStream.listen(
        (metadata) => _handleYoutubeMetadata('youtube', metadata),
      ),
      _youtubeHorizontal.metadataStream.listen(
        (metadata) => _handleYoutubeMetadata('youtubeHorizontal', metadata),
      ),
      _youtubeVertical.metadataStream.listen(
        (metadata) => _handleYoutubeMetadata('youtubeVertical', metadata),
      ),
    ]);
    _moderationSubscriptions.addAll([
      _youtube.moderationEvents.listen(_handleModeration),
      _youtubeHorizontal.moderationEvents.listen(_handleModeration),
      _youtubeVertical.moderationEvents.listen(_handleModeration),
    ]);
    if (_twitch case final ModeratingChannelChatClient twitch) {
      _moderationSubscriptions.add(
        twitch.moderationEvents.listen(_handleModeration),
      );
    }
    if (_kick case final ModeratingChannelChatClient kick) {
      _moderationSubscriptions.add(
        kick.moderationEvents.listen(_handleModeration),
      );
    }
    for (final service in [
      _youtube,
      _youtubeHorizontal,
      _youtubeVertical,
      _kick,
      _twitch,
    ]) {
      if (service case final ProviderEventChatClient source) {
        _providerEventSubscriptions.add(source.appEvents.listen((event) {
          if (!_providerEventController.isClosed) {
            _providerEventController.add(event);
          }
        }));
      }
      if (service case final MetadataChannelChatClient source) {
        _platformMetadataSubscriptions.add(
          source.platformMetadataStream.listen((metadata) {
            if (metadata == null) {
              // The only metadata-capable channel adapter is Kick today.
              _platformMetadata.remove(Platform.kick);
            } else {
              _platformMetadata[metadata.platform] = metadata;
            }
            if (!_platformMetadataController.isClosed) {
              _platformMetadataController
                  .add(Map.unmodifiable(_platformMetadata));
            }
          }),
        );
      }
    }
  }

  final YouTubeChatClient _youtube;
  final YouTubeChatClient _youtubeHorizontal;
  final YouTubeChatClient _youtubeVertical;
  final ChannelChatClient _kick;
  final ChannelChatClient _twitch;
  final MessagePipeline _pipeline;
  final String? Function(String value) _youtubeVideoIdFromUrl;
  final _listController = StreamController<List<ChatMessage>>.broadcast();
  final _statusController =
      StreamController<Map<String, (ServiceStatus, String?)>>.broadcast();
  final _youtubeBadgeController = StreamController<String?>.broadcast();
  final _youtubeMetadataController =
      StreamController<YoutubeLiveMetadataSummary>.broadcast();
  final _providerEventController =
      StreamController<ChatProviderEvent>.broadcast();
  final _moderationEventController =
      StreamController<ChatModerationEvent>.broadcast();
  final _platformMetadataController =
      StreamController<Map<Platform, PlatformLiveMetadata>>.broadcast();
  final _statusSubscriptions = <StreamSubscription<(ServiceStatus, String?)>>[];
  final _metadataSubscriptions = <StreamSubscription<YoutubeLiveMetadata?>>[];
  final _moderationSubscriptions = <StreamSubscription<ChatModerationEvent>>[];
  final _providerEventSubscriptions = <StreamSubscription<ChatProviderEvent>>[];
  final _platformMetadataSubscriptions =
      <StreamSubscription<PlatformLiveMetadata?>>[];
  final _platformMetadata = <Platform, PlatformLiveMetadata>{};
  StreamSubscription<ChatMessage>? _pipelineSub;
  final _platformStatus = <String, (ServiceStatus, String?)>{
    'youtube': (ServiceStatus.idle, null),
    'youtubeHorizontal': (ServiceStatus.idle, null),
    'youtubeVertical': (ServiceStatus.idle, null),
    'twitch': (ServiceStatus.idle, null),
    'kick': (ServiceStatus.idle, null),
  };
  String? _youtubeBadgeValue;
  final _youtubeMetadata = <String, YoutubeLiveMetadata?>{
    'youtube': null,
    'youtubeHorizontal': null,
    'youtubeVertical': null,
  };
  int _attemptGeneration = 0;
  SettingsModel? _lastSettings;
  bool? _lastConnectChats;
  bool _disposed = false;

  Stream<ChatMessage> get messages => _pipeline.stream;

  Stream<List<ChatMessage>> get messageListStream async* {
    yield List<ChatMessage>.from(_pipeline.buffer);
    yield* _listController.stream;
  }

  Stream<Map<String, (ServiceStatus, String?)>>
      get connectionStatusStream async* {
    yield Map.from(_platformStatus);
    yield* _statusController.stream;
  }

  Stream<String?> get youtubeBadgeValueStream async* {
    yield _youtubeBadgeValue;
    yield* _youtubeBadgeController.stream;
  }

  Stream<YoutubeLiveMetadataSummary> get youtubeMetadataStream async* {
    yield _metadataSummary;
    yield* _youtubeMetadataController.stream;
  }

  Stream<ChatProviderEvent> get providerEvents =>
      _providerEventController.stream;

  Stream<ChatModerationEvent> get moderationEvents =>
      _moderationEventController.stream;

  Stream<Map<Platform, PlatformLiveMetadata>>
      get platformMetadataStream async* {
    yield Map.unmodifiable(_platformMetadata);
    yield* _platformMetadataController.stream;
  }

  void applySettings(SettingsModel settings, {required bool connectChats}) {
    if (_disposed) return;
    final previous = _lastSettings;
    _lastSettings = settings;
    final visibleMessagesChanged = _pipeline.updateSettings(settings);
    if (visibleMessagesChanged && !_listController.isClosed) {
      _listController.add(_pipeline.buffer);
    }

    final connectionChanged = previous == null ||
        _lastConnectChats == null ||
        _lastConnectChats != connectChats;
    _lastConnectChats = connectChats;

    final horizontalId = _youtubeVideoIdFromUrl(settings.youtubeHorizontalUrl);
    final verticalId = _youtubeVideoIdFromUrl(settings.youtubeVerticalUrl);
    final hasYoutubeTarget = settings.youtubeEnabled &&
        (settings.youtubeDualStreamEnabled
            ? horizontalId != null &&
                verticalId != null &&
                horizontalId != verticalId
            : settings.youtubeHandle.isNotEmpty ||
                settings.youtubeLiveId.isNotEmpty);
    final hasTwitchTarget =
        settings.twitchEnabled && settings.twitchChannel.isNotEmpty;
    final hasKickTarget = settings.kickEnabled && settings.kickSlug.isNotEmpty;

    final youtubeChanged = connectionChanged ||
        previous.youtubeEnabled != settings.youtubeEnabled ||
        previous.youtubeDualStreamEnabled !=
            settings.youtubeDualStreamEnabled ||
        previous.youtubeHorizontalUrl != settings.youtubeHorizontalUrl ||
        previous.youtubeVerticalUrl != settings.youtubeVerticalUrl ||
        previous.youtubeHandle != settings.youtubeHandle ||
        previous.youtubeLiveId != settings.youtubeLiveId;
    final twitchChanged = connectionChanged ||
        previous.twitchEnabled != settings.twitchEnabled ||
        previous.twitchChannel != settings.twitchChannel;
    final kickChanged = connectionChanged ||
        previous.kickEnabled != settings.kickEnabled ||
        previous.kickSlug != settings.kickSlug;
    final generation = youtubeChanged || twitchChanged || kickChanged
        ? ++_attemptGeneration
        : _attemptGeneration;

    final shouldClear = connectChats &&
        ((youtubeChanged && hasYoutubeTarget) ||
            (twitchChanged && hasTwitchTarget) ||
            (kickChanged && hasKickTarget));
    if (shouldClear || !connectChats) _clearMessages();

    if (youtubeChanged) {
      _clearYoutubeMetadata();
      unawaited(_youtube.disconnect());
      unawaited(_youtubeHorizontal.disconnect());
      unawaited(_youtubeVertical.disconnect());
      _updateStatus('youtube', (ServiceStatus.idle, null));
      _updateStatus('youtubeHorizontal', (ServiceStatus.idle, null));
      _updateStatus('youtubeVertical', (ServiceStatus.idle, null));
      if (connectChats && hasYoutubeTarget) {
        if (settings.youtubeDualStreamEnabled) {
          _youtubeBadgeValue = '2 streams';
          _emitYoutubeBadgeValue();
          unawaited(_connectYoutubeStream(
            service: _youtubeHorizontal,
            statusKey: 'youtubeHorizontal',
            url: settings.youtubeHorizontalUrl,
            generation: generation,
          ));
          unawaited(_connectYoutubeStream(
            service: _youtubeVertical,
            statusKey: 'youtubeVertical',
            url: settings.youtubeVerticalUrl,
            generation: generation,
          ));
        } else {
          unawaited(_connectYoutube(settings, generation));
        }
      } else {
        _youtubeBadgeValue = null;
        _emitYoutubeBadgeValue();
        _updateStatus('youtube', (ServiceStatus.idle, null));
      }
    }

    if (twitchChanged) {
      if (connectChats && hasTwitchTarget) {
        unawaited(_connectChannel(
          service: _twitch,
          statusKey: 'twitch',
          channel: settings.twitchChannel,
          generation: generation,
        ));
      } else {
        unawaited(_twitch.disconnect());
        _updateStatus('twitch', (ServiceStatus.idle, null));
      }
    }

    if (kickChanged) {
      if (connectChats && hasKickTarget) {
        unawaited(_connectChannel(
          service: _kick,
          statusKey: 'kick',
          channel: settings.kickSlug,
          generation: generation,
        ));
      } else {
        unawaited(_kick.disconnect());
        _updateStatus('kick', (ServiceStatus.idle, null));
      }
    }
  }

  void retryConnections() {
    final settings = _lastSettings;
    if (settings == null || _lastConnectChats != true) return;
    final generation = ++_attemptGeneration;
    if (_isPlatformConfigured('youtube') &&
        _platformStatus['youtube']?.$1 == ServiceStatus.error) {
      unawaited(_connectYoutube(settings, generation));
    }
    for (final entry in [
      ('youtubeHorizontal', _youtubeHorizontal, settings.youtubeHorizontalUrl),
      ('youtubeVertical', _youtubeVertical, settings.youtubeVerticalUrl),
    ]) {
      if (_isPlatformConfigured(entry.$1) &&
          _platformStatus[entry.$1]?.$1 == ServiceStatus.error) {
        unawaited(_connectYoutubeStream(
          service: entry.$2,
          statusKey: entry.$1,
          url: entry.$3,
          generation: generation,
        ));
      }
    }
    for (final entry in [
      ('twitch', _twitch, settings.twitchChannel),
      ('kick', _kick, settings.kickSlug),
    ]) {
      if (_isPlatformConfigured(entry.$1) &&
          _platformStatus[entry.$1]?.$1 == ServiceStatus.error) {
        unawaited(_connectChannel(
          service: entry.$2,
          statusKey: entry.$1,
          channel: entry.$3,
          generation: generation,
        ));
      }
    }
  }

  void retryPlatform(String platform) {
    final settings = _lastSettings;
    if (settings == null ||
        _lastConnectChats != true ||
        !_isPlatformConfigured(platform)) {
      return;
    }
    final generation = ++_attemptGeneration;
    switch (platform) {
      case 'youtube':
        unawaited(_connectYoutube(settings, generation));
      case 'youtubeHorizontal':
        unawaited(_connectYoutubeStream(
          service: _youtubeHorizontal,
          statusKey: platform,
          url: settings.youtubeHorizontalUrl,
          generation: generation,
        ));
      case 'youtubeVertical':
        unawaited(_connectYoutubeStream(
          service: _youtubeVertical,
          statusKey: platform,
          url: settings.youtubeVerticalUrl,
          generation: generation,
        ));
      case 'twitch':
        unawaited(_connectChannel(
          service: _twitch,
          statusKey: platform,
          channel: settings.twitchChannel,
          generation: generation,
        ));
      case 'kick':
        unawaited(_connectChannel(
          service: _kick,
          statusKey: platform,
          channel: settings.kickSlug,
          generation: generation,
        ));
    }
  }

  Future<void> _connectYoutube(SettingsModel settings, int generation) async {
    _youtubeBadgeValue = null;
    _emitYoutubeBadgeValue();
    try {
      await _youtube.connect(
        handle: settings.youtubeHandle,
        liveId: settings.youtubeLiveId,
      );
      if (!_isCurrent(generation)) return;
      _youtubeBadgeValue = _youtube.resolvedLiveId.isNotEmpty
          ? _youtube.resolvedLiveId
          : settings.youtubeHandle.trim();
      _emitYoutubeBadgeValue();
    } catch (error, stack) {
      AppLogger.error(
        'YouTube connection failed',
        error: error,
        stackTrace: stack,
      );
      await _youtube.disconnect();
      if (!_isCurrent(generation)) return;
      _youtubeBadgeValue = null;
      _emitYoutubeBadgeValue();
      _updateStatus('youtube', (ServiceStatus.error, error.toString()));
    }
  }

  Future<void> _connectYoutubeStream({
    required YouTubeChatClient service,
    required String statusKey,
    required String url,
    required int generation,
  }) async {
    final videoId = _youtubeVideoIdFromUrl(url);
    if (videoId == null) {
      _updateStatus(
        statusKey,
        (ServiceStatus.error, 'A valid YouTube video URL is required.'),
      );
      return;
    }
    try {
      await service.connect(liveId: videoId);
    } catch (error, stack) {
      AppLogger.error(
        '$statusKey connection failed',
        error: error,
        stackTrace: stack,
      );
      await service.disconnect();
      if (_isCurrent(generation)) {
        _updateStatus(statusKey, (ServiceStatus.error, error.toString()));
      }
    }
  }

  Future<void> _connectChannel({
    required ChannelChatClient service,
    required String statusKey,
    required String channel,
    required int generation,
  }) async {
    try {
      await service.connect(channel);
    } catch (error, stack) {
      AppLogger.error(
        '$statusKey connection failed',
        error: error,
        stackTrace: stack,
      );
      await service.disconnect();
      if (_isCurrent(generation)) {
        _updateStatus(statusKey, (ServiceStatus.error, error.toString()));
      }
    }
  }

  bool _isCurrent(int generation) =>
      generation == _attemptGeneration && _lastConnectChats == true;

  void _handleServiceStatus(
    String platform,
    (ServiceStatus, String?) status,
  ) {
    if (!shouldAcceptServiceStatus(
      chatRequested: _lastConnectChats == true,
      platformConfigured: _isPlatformConfigured(platform),
      status: status.$1,
    )) {
      return;
    }
    _updateStatus(platform, status);
  }

  bool _isPlatformConfigured(String platform) {
    final settings = _lastSettings;
    if (settings == null) return false;
    return switch (platform) {
      'youtube' => settings.youtubeEnabled &&
          !settings.youtubeDualStreamEnabled &&
          (settings.youtubeHandle.trim().isNotEmpty ||
              settings.youtubeLiveId.trim().isNotEmpty),
      'youtubeHorizontal' => settings.youtubeEnabled &&
          settings.youtubeDualStreamEnabled &&
          _youtubeVideoIdFromUrl(settings.youtubeHorizontalUrl) != null,
      'youtubeVertical' => settings.youtubeEnabled &&
          settings.youtubeDualStreamEnabled &&
          _youtubeVideoIdFromUrl(settings.youtubeVerticalUrl) != null,
      'twitch' =>
        settings.twitchEnabled && settings.twitchChannel.trim().isNotEmpty,
      'kick' => settings.kickEnabled && settings.kickSlug.trim().isNotEmpty,
      _ => false,
    };
  }

  void _updateStatus(String platform, (ServiceStatus, String?) status) {
    _platformStatus[platform] = status;
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_platformStatus));
    }
  }

  void _clearMessages() {
    _pipeline.clear();
    if (!_listController.isClosed) _listController.add(const []);
  }

  void _emitYoutubeBadgeValue() {
    if (!_youtubeBadgeController.isClosed) {
      _youtubeBadgeController.add(_youtubeBadgeValue);
    }
  }

  YoutubeLiveMetadataSummary get _metadataSummary => YoutubeLiveMetadataSummary(
        primary: _youtubeMetadata['youtube'],
        horizontal: _youtubeMetadata['youtubeHorizontal'],
        vertical: _youtubeMetadata['youtubeVertical'],
      );

  void _handleYoutubeMetadata(
    String source,
    YoutubeLiveMetadata? metadata,
  ) {
    if (_disposed) return;
    _youtubeMetadata[source] = metadata;
    if (!_youtubeMetadataController.isClosed) {
      _youtubeMetadataController.add(_metadataSummary);
    }
  }

  void _clearYoutubeMetadata() {
    for (final key in _youtubeMetadata.keys) {
      _youtubeMetadata[key] = null;
    }
    if (!_youtubeMetadataController.isClosed) {
      _youtubeMetadataController.add(_metadataSummary);
    }
  }

  void _handleModeration(ChatModerationEvent event) {
    if (_disposed) return;
    if (!_moderationEventController.isClosed) {
      _moderationEventController.add(event);
    }
    if (!_pipeline.applyModeration(event)) return;
    if (!_listController.isClosed) {
      _listController.add(_pipeline.buffer);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_attemptGeneration;
    await _pipelineSub?.cancel();
    for (final subscription in _statusSubscriptions) {
      await subscription.cancel();
    }
    for (final subscription in _metadataSubscriptions) {
      await subscription.cancel();
    }
    for (final subscription in _moderationSubscriptions) {
      await subscription.cancel();
    }
    for (final subscription in _providerEventSubscriptions) {
      await subscription.cancel();
    }
    for (final subscription in _platformMetadataSubscriptions) {
      await subscription.cancel();
    }
    await _youtube.dispose();
    await _youtubeHorizontal.dispose();
    await _youtubeVertical.dispose();
    await _kick.dispose();
    await _twitch.dispose();
    _pipeline.dispose();
    await _listController.close();
    await _statusController.close();
    await _youtubeBadgeController.close();
    await _youtubeMetadataController.close();
    await _providerEventController.close();
    await _moderationEventController.close();
    await _platformMetadataController.close();
  }
}
