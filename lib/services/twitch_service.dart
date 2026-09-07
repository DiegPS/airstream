import 'dart:async';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;
import 'package:dart_twitch_chat/dart_twitch_chat.dart' as twitch;
import 'package:http/http.dart' as http;

export 'package:dart_twitch_chat/dart_twitch_chat.dart'
    show TwitchIrcEvent, TwitchIrcEventType, TwitchIrcParser, TwitchUserRoles;

/// Thin AirStream adapter over the standalone anonymous Twitch library.
class TwitchService {
  TwitchService({
    twitch.TwitchSocketFactory? socketFactory,
    http.Client? httpClient,
    Duration reconnectDelay = const Duration(seconds: 5),
    Duration connectionTimeout = const Duration(seconds: 10),
    Duration optionalApiTimeout = const Duration(seconds: 5),
    twitch.TwitchChatClient? client,
  }) : _client = client ??
            twitch.TwitchChatClient(
              socketFactory: socketFactory,
              httpClient: httpClient,
              reconnectDelay: reconnectDelay,
              connectionTimeout: connectionTimeout,
              optionalApiTimeout: optionalApiTimeout,
            ) {
    _messageSubscription = _client.messages.listen(_handleMessage);
    _connectionSubscription = _client.connections.listen(_handleConnection);
    _failureSubscription = _client.failures.listen(_handleFailure);
  }

  final twitch.TwitchChatClient _client;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _statuses = StreamController<(ServiceStatus, String?)>.broadcast();
  late final StreamSubscription<twitch.TwitchChatMessage> _messageSubscription;
  late final StreamSubscription<twitch.TwitchConnectionUpdate>
      _connectionSubscription;
  late final StreamSubscription<twitch.TwitchFailure> _failureSubscription;
  bool _disposed = false;

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<(ServiceStatus, String?)> get statusStream => _statuses.stream;

  Future<void> connect(String channelName) => _client.connect(channelName);

  Future<void> disconnect() => _client.disconnect();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _messageSubscription.cancel();
    await _connectionSubscription.cancel();
    await _failureSubscription.cancel();
    await _client.dispose();
    await _messages.close();
    await _statuses.close();
  }

  List<MessageItem> parseMessageForTesting({
    required String text,
    required String nativeEmotesTag,
    Map<String, String> thirdPartyUrls = const {},
  }) {
    return twitch.TwitchMessageParser.parseContent(
      text,
      nativeEmotesTag: nativeEmotesTag,
      thirdPartyEmotes: thirdPartyUrls.map(
        (code, url) => MapEntry(
          code,
          twitch.TwitchEmote(code: code, url: url),
        ),
      ),
    ).map(_messagePart).toList(growable: false);
  }

  void _handleMessage(twitch.TwitchChatMessage message) {
    if (_messages.isClosed) return;
    _messages.add(
      ChatMessage(
        platform: Platform.twitch,
        id: message.id,
        author: ChatAuthor(
          name: message.author.name,
          channelId: message.author.login,
          color: message.author.color,
          badges: message.author.badges
              .map(
                (badge) => AuthorBadge(
                  label: badge.label,
                  kind: badge.kind,
                ),
              )
              .toList(growable: false),
        ),
        items: message.parts.map(_messagePart).toList(growable: false),
        isModerator: message.author.isModerator,
        isMembership: message.author.isSubscriber,
        isMembershipEvent: message.isMembershipEvent,
        isOwner: message.author.isOwner,
        isVip: message.author.isVip,
        membershipEventKind: switch (message.membershipKind) {
          twitch.TwitchMembershipKind.subscription =>
            MembershipEventKind.subscription,
          twitch.TwitchMembershipKind.resubscription =>
            MembershipEventKind.resubscription,
          twitch.TwitchMembershipKind.gift => MembershipEventKind.gift,
          null => null,
        },
        membershipMonths: message.membershipMonths,
        timestamp: message.timestamp,
      ),
    );
  }

  static MessageItem _messagePart(twitch.TwitchMessagePart part) {
    if (!part.isEmote) return MessageItem.text(part.text);
    final emote = part.emote!;
    return MessageItem.emoji(
      EmojiItem(
        url: emote.url,
        alt: emote.code,
        isAnimated: emote.isAnimated,
      ),
    );
  }

  void _handleConnection(twitch.TwitchConnectionUpdate update) {
    if (_statuses.isClosed) return;
    final status = switch (update.state) {
      twitch.TwitchConnectionState.idle => ServiceStatus.idle,
      twitch.TwitchConnectionState.connecting => ServiceStatus.connecting,
      twitch.TwitchConnectionState.connected => ServiceStatus.connected,
      twitch.TwitchConnectionState.error => ServiceStatus.error,
    };
    _statuses.add((status, update.error?.toString()));
  }

  void _handleFailure(twitch.TwitchFailure failure) {
    if (failure.scope == twitch.TwitchFailureScope.emotes) {
      AppLogger.debug('Optional Twitch emotes unavailable: ${failure.error}');
      return;
    }
    AppLogger.warning(
      'Twitch connection failure',
      error: failure.error,
      stackTrace: failure.stackTrace,
    );
  }
}
