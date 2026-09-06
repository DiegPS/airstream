import 'dart:async';

import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;

abstract interface class YouTubeChatTransport {
  Stream<dynamic> get messages;
  Stream<dynamic> get events;
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
  Stream<dynamic> get events => _chat.events;
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

abstract interface class YouTubeMetadataTransport {
  Stream<yt.UpdatedMetadataBatch> get batches;
  Stream<Exception> get errors;
  Future<void> start();
  Future<void> stop();
}

typedef YouTubeMetadataTransportFactory = YouTubeMetadataTransport Function(
  yt.YoutubeId id,
);

class DartYouTubeMetadataTransport implements YouTubeMetadataTransport {
  DartYouTubeMetadataTransport(this._id);

  final yt.YoutubeId _id;
  final _batchController =
      StreamController<yt.UpdatedMetadataBatch>.broadcast();
  final _errorController = StreamController<Exception>.broadcast();

  yt.YoutubeHttpClient? _client;
  yt.UpdatedMetadata? _metadata;
  StreamSubscription<yt.UpdatedMetadataBatch>? _batchSubscription;
  StreamSubscription<Exception>? _errorSubscription;
  bool _closed = false;

  @override
  Stream<yt.UpdatedMetadataBatch> get batches => _batchController.stream;

  @override
  Stream<Exception> get errors => _errorController.stream;

  @override
  Future<void> start() async {
    if (_closed) throw StateError('YouTube metadata transport is closed');
    final client = yt.YoutubeHttpClient();
    _client = client;
    final options = await client.fetchLivePage(_id);
    if (_closed) {
      client.close();
      return;
    }

    final metadata = yt.UpdatedMetadata(options: options, client: client);
    _metadata = metadata;
    _batchSubscription = metadata.batches.listen((batch) {
      if (!_batchController.isClosed) _batchController.add(batch);
    });
    _errorSubscription = metadata.errors.listen((error) {
      if (!_errorController.isClosed) _errorController.add(error);
    });
    metadata.start();
  }

  @override
  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    _metadata?.stop();
    _metadata = null;
    await _batchSubscription?.cancel();
    await _errorSubscription?.cancel();
    _batchSubscription = null;
    _errorSubscription = null;
    _client?.close();
    _client = null;
    await _batchController.close();
    await _errorController.close();
  }
}
