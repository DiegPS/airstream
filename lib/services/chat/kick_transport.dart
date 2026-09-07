import 'dart:async';

import 'package:dart_kick_chat/dart_kick_chat.dart' as kick;

abstract interface class KickChatTransport {
  Stream<kick.ChatMessage> get messages;
  Stream<kick.KickEvent> get events;
  Stream<Exception> get errors;
  Future<void> joinBySlug(String slug);
  Future<void> close();
}

abstract interface class KickMetadataTransport {
  Stream<kick.KickChannel> get metadata;
}

abstract interface class KickConnectionTransport {
  Stream<kick.KickConnectionUpdate> get connections;
  kick.KickConnectionState get connectionState;
}

abstract interface class KickEnrichmentTransport {
  Stream<kick.KickProfileUpdate> get profileUpdates;
  Stream<Exception> get enrichmentErrors;
}

typedef KickChatTransportFactory = Future<KickChatTransport> Function();

class DartKickChatTransport
    implements
        KickChatTransport,
        KickMetadataTransport,
        KickConnectionTransport,
        KickEnrichmentTransport {
  DartKickChatTransport._(this._client, this._monitor) {
    _clientErrorSubscription = _client.errors.listen(_forwardError);
    _metadataErrorSubscription = _monitor.errors.listen(_forwardError);
  }
  final kick.KickClient _client;
  final kick.KickChannelMonitor _monitor;
  final _errors = StreamController<Exception>.broadcast();
  late final StreamSubscription<Exception> _clientErrorSubscription;
  late final StreamSubscription<Exception> _metadataErrorSubscription;

  static Future<KickChatTransport> connect() async => DartKickChatTransport._(
        await kick.KickClient.connect(),
        kick.KickChannelMonitor(),
      );

  @override
  Stream<kick.ChatMessage> get messages => _client.messages;
  @override
  Stream<kick.KickEvent> get events => _client.events;
  @override
  Stream<Exception> get errors => _errors.stream;
  @override
  Stream<kick.KickChannel> get metadata => _monitor.states;
  @override
  Stream<kick.KickConnectionUpdate> get connections => _client.connections;
  @override
  Stream<kick.KickProfileUpdate> get profileUpdates => _client.profileUpdates;
  @override
  Stream<Exception> get enrichmentErrors => _client.enrichmentErrors;
  @override
  kick.KickConnectionState get connectionState => _client.connectionState;
  @override
  Future<void> joinBySlug(String slug) async {
    await _client.joinBySlug(slug);
    unawaited(_monitor.start(slug).then<void>((_) {}, onError: (_) {}));
  }

  @override
  Future<void> close() async {
    await _clientErrorSubscription.cancel();
    await _metadataErrorSubscription.cancel();
    await _monitor.close();
    await _client.close();
    await _errors.close();
  }

  void _forwardError(Exception error) {
    if (!_errors.isClosed) _errors.add(error);
  }
}
