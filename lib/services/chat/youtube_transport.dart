import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;

abstract interface class YouTubeChatTransport {
  Stream<yt.ChatItem> get messages;
  Stream<yt.LiveChatEvent> get events;
  Stream<yt.UpdatedMetadataState> get metadataStates;
  Stream<Exception> get errors;
  Stream<DateTime> get polls;
  String get liveId;
  Future<void> start();
  void stop();
}

typedef YouTubeChatTransportFactory = YouTubeChatTransport Function(
  yt.YoutubeId id,
);

class DartYouTubeChatTransport implements YouTubeChatTransport {
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
  Stream<Exception> get errors => _session.errors;
  @override
  Stream<DateTime> get polls => _session.chatPolls;
  @override
  String get liveId => _session.liveId;
  @override
  Future<void> start() => _session.start();
  @override
  void stop() => _session.stop();
}
