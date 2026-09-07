import 'dart:async';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
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
    _eventSubscription = _client.events.listen(_handleProviderEvent);
  }

  final twitch.TwitchChatClient _client;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _statuses = StreamController<(ServiceStatus, String?)>.broadcast();
  final _moderationEvents = StreamController<ChatModerationEvent>.broadcast();
  final _appEvents = StreamController<ChatProviderEvent>.broadcast();
  late final StreamSubscription<twitch.TwitchChatMessage> _messageSubscription;
  late final StreamSubscription<twitch.TwitchConnectionUpdate>
      _connectionSubscription;
  late final StreamSubscription<twitch.TwitchFailure> _failureSubscription;
  late final StreamSubscription<twitch.TwitchEvent> _eventSubscription;
  bool _disposed = false;

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<(ServiceStatus, String?)> get statusStream => _statuses.stream;
  Stream<ChatModerationEvent> get moderationEvents => _moderationEvents.stream;
  Stream<ChatProviderEvent> get appEvents => _appEvents.stream;
  Stream<twitch.TwitchEvent> get providerEvents => _client.events;

  Future<void> connect(String channelName) => _client.connect(channelName);

  Future<void> disconnect() => _client.disconnect();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _messageSubscription.cancel();
    await _connectionSubscription.cancel();
    await _failureSubscription.cancel();
    await _eventSubscription.cancel();
    await _client.dispose();
    await _messages.close();
    await _statuses.close();
    await _moderationEvents.close();
    await _appEvents.close();
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
          channelId: message.author.id ?? message.author.login,
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
        superChat: message.bits == null
            ? null
            : SuperChat(
                amount: '${message.bits} Bits',
                color: '#9146FF',
              ),
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
        reply: message.reply == null
            ? null
            : ChatReplyContext(
                messageId: message.reply!.parentMessageId,
                authorId: message.reply!.parentUserId ?? '',
                authorName: message.reply!.parentDisplayName ??
                    message.reply!.parentUserLogin ??
                    '',
                text: message.reply!.parentMessageBody ?? '',
              ),
        sharedSource: message.sharedChatSource == null
            ? null
            : ChatSharedSource(
                messageId: message.sharedChatSource!.messageId ?? '',
                channelId: message.sharedChatSource!.roomId ?? '',
                messageType: message.sharedChatSource!.messageType ?? '',
              ),
        isAction: message.isAction,
      ),
    );
  }

  static MessageItem _messagePart(twitch.TwitchMessagePart part) {
    if (part.isGif) {
      final gif = part.gif!;
      return MessageItem.emoji(
        EmojiItem(
          url: gif.url,
          alt: gif.alt,
          isAnimated: true,
        ),
      );
    }
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

  void _handleProviderEvent(twitch.TwitchEvent event) {
    if (_moderationEvents.isClosed) return;
    switch (event) {
      case twitch.TwitchClearMessageEvent(:final targetMessageId)
          when targetMessageId.isNotEmpty:
        _moderationEvents.add(
          ChatModerationEvent.message(
            platform: Platform.twitch,
            messageId: targetMessageId,
          ),
        );
      case twitch.TwitchClearChatEvent(clearsEntireRoom: true):
        _moderationEvents.add(
          const ChatModerationEvent.platform(platform: Platform.twitch),
        );
      case twitch.TwitchClearChatEvent(:final targetUserId)
          when targetUserId != null && targetUserId.isNotEmpty:
        _moderationEvents.add(
          ChatModerationEvent.author(
            platform: Platform.twitch,
            authorChannelId: targetUserId,
          ),
        );
      default:
        break;
    }
    final appEvent = _convertProviderEvent(event);
    if (appEvent != null && !_appEvents.isClosed) {
      _appEvents.add(appEvent);
    }
    if (event case twitch.TwitchUserNoticeEvent(:final notice)
        when _isVisibleSpecialNotice(notice.kind)) {
      _emitSpecialNotice(notice);
    }
  }

  ChatProviderEvent? _convertProviderEvent(twitch.TwitchEvent event) {
    if (event case twitch.TwitchUserNoticeEvent(:final notice)) {
      final kind = switch (notice.kind) {
        twitch.TwitchUserNoticeKind.raid => ChatProviderEventKind.raid,
        twitch.TwitchUserNoticeKind.unraid => ChatProviderEventKind.unraid,
        twitch.TwitchUserNoticeKind.modiversary =>
          ChatProviderEventKind.modiversary,
        twitch.TwitchUserNoticeKind.viewerMilestone =>
          ChatProviderEventKind.viewerMilestone,
        twitch.TwitchUserNoticeKind.sharedChatNotice =>
          ChatProviderEventKind.sharedChat,
        _ => ChatProviderEventKind.notice,
      };
      return ChatProviderEvent(
        platform: Platform.twitch,
        kind: kind,
        id: notice.message.id.isEmpty
            ? '${notice.messageType}:${notice.timestamp.microsecondsSinceEpoch}'
            : notice.message.id,
        timestamp: notice.timestamp,
        authorName: notice.senderName ?? notice.message.author.name,
        text: notice.systemMessage ?? notice.message.plainText,
        count: notice.viewerCount ?? notice.milestoneValue,
        data: Map<String, Object?>.unmodifiable(notice.parameters),
      );
    }
    if (event
        case twitch.TwitchNoticeEvent(
          :final messageId,
          :final message,
        )) {
      return ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.notice,
        id: messageId ?? 'notice:${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now().toUtc(),
        text: message,
        data: Map<String, Object?>.unmodifiable(event.frame.tags),
      );
    }
    return null;
  }

  static bool _isVisibleSpecialNotice(twitch.TwitchUserNoticeKind kind) =>
      const {
        twitch.TwitchUserNoticeKind.raid,
        twitch.TwitchUserNoticeKind.modiversary,
        twitch.TwitchUserNoticeKind.viewerMilestone,
      }.contains(kind);

  void _emitSpecialNotice(twitch.TwitchUserNotice notice) {
    if (_messages.isClosed) return;
    final author = notice.senderName ?? notice.message.author.name;
    final text = notice.systemMessage?.trim().isNotEmpty == true
        ? notice.systemMessage!.trim()
        : notice.message.plainText;
    _messages.add(ChatMessage(
      platform: Platform.twitch,
      id: notice.message.id.isEmpty
          ? '${notice.messageType}:${notice.timestamp.microsecondsSinceEpoch}'
          : notice.message.id,
      author: ChatAuthor(
        name: author.isEmpty ? 'Twitch' : author,
        channelId: notice.senderLogin ?? notice.message.author.login,
      ),
      items: [MessageItem.text(text)],
      timestamp: notice.timestamp,
    ));
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
