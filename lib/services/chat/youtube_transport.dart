import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;

abstract interface class YouTubeChatTransport {
  Stream<dynamic> get messages;
  Stream<dynamic> get errors;
  Stream<dynamic> get polls;
  String get liveId;
  Future<void> start();
  void stop();
}

typedef YouTubeChatTransportFactory = YouTubeChatTransport Function(
  yt.YoutubeId id,
);

class DartYouTubeChatTransport implements YouTubeChatTransport {
  DartYouTubeChatTransport(yt.YoutubeId id) : _chat = yt.LiveChat(id: id);

  final yt.LiveChat _chat;

  @override
  Stream<dynamic> get messages => _chat.messages;
  @override
  Stream<dynamic> get errors => _chat.errors;
  @override
  Stream<dynamic> get polls => _chat.polls;
  @override
  String get liveId => _chat.liveId;
  @override
  Future<void> start() => _chat.start();
  @override
  void stop() => _chat.stop();
}
