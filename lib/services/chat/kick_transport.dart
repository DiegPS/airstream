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

  /// Failures of the periodic channel-metadata lookup. They never affect the
  /// chat connection, so they are kept apart from [KickChatTransport.errors].
  Stream<Exception> get metadataErrors;
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
  DartKickChatTransport._(this._client, this._monitor);
  final kick.KickClient _client;
  final kick.KickChannelMonitor _monitor;

  static Future<KickChatTransport> connect() async => DartKickChatTransport._(
        await kick.KickClient.connect(),
        kick.KickChannelMonitor(),
      );

  @override
  Stream<kick.ChatMessage> get messages => _client.messages;
  @override
  Stream<kick.KickEvent> get events => _client.events;
  @override
  Stream<Exception> get errors => _client.errors;
  @override
  Stream<kick.KickChannel> get metadata => _monitor.states;
  @override
  Stream<Exception> get metadataErrors => _monitor.errors;
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
    await _monitor.close();
    await _client.close();
  }
}
