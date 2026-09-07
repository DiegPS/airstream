import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;

abstract interface class YouTubeChatTransport {
  Stream<yt.ChatItem> get messages;
  Stream<yt.LiveChatEvent> get events;
  Stream<yt.UpdatedMetadataState> get metadataStates;
  Stream<Exception> get chatErrors;
  Stream<Exception> get metadataErrors;
  Stream<DateTime> get polls;
  String get liveId;
  Future<void> start();
  void stop();
}

abstract interface class YouTubeLifecycleTransport {
  Stream<yt.YoutubeLiveLifecycle> get lifecycle;
}

typedef YouTubeChatTransportFactory = YouTubeChatTransport Function(
  yt.YoutubeId id,
);

class DartYouTubeChatTransport
    implements YouTubeChatTransport, YouTubeLifecycleTransport {
  DartYouTubeChatTransport(yt.YoutubeId id)
      : _session = yt.YoutubeLiveSession(id: id);

  final yt.YoutubeLiveSession _session;

  @override
  Stream<yt.ChatItem> get messages => _session.messages;
  @override
  Stream<yt.LiveChatEvent> get events => _session.events;
  @override
  Stream<yt.UpdatedMetadataState> get metadataStates => _session.metadataStates;
  @override
  Stream<Exception> get chatErrors => _session.chatErrors;
  @override
  Stream<Exception> get metadataErrors => _session.metadataErrors;
  @override
  Stream<DateTime> get polls => _session.chatPolls;
  @override
  Stream<yt.YoutubeLiveLifecycle> get lifecycle => _session.lifecycle;
  @override
  String get liveId => _session.liveId;
  @override
  Future<void> start() => _session.start();
  @override
  void stop() => _session.stop();
}
