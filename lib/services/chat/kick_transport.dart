import 'package:dart_kick_chat/dart_kick_chat.dart' as kick;

abstract interface class KickChatTransport {
  Stream<dynamic> get messages;
  Stream<dynamic> get errors;
  Future<void> joinBySlug(String slug);
  Future<void> close();
}

typedef KickChatTransportFactory = Future<KickChatTransport> Function();

class DartKickChatTransport implements KickChatTransport {
  DartKickChatTransport._(this._client);
  final kick.KickClient _client;

  static Future<KickChatTransport> connect() async =>
      DartKickChatTransport._(await kick.KickClient.connect());

  @override
  Stream<dynamic> get messages => _client.messages;
  @override
  Stream<dynamic> get errors => _client.errors;
  @override
  Future<void> joinBySlug(String slug) => _client.joinBySlug(slug);
  @override
  Future<void> close() => _client.close();
}
