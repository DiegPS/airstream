import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;

const _ircUrl = 'wss://irc-ws.chat.twitch.tv/';
const _reconnectDelay = Duration(seconds: 5);
const _optionalApiTimeout = Duration(seconds: 5);

/// Third-party emote APIs
const _bttvGlobalUrl = 'https://api.betterttv.net/3/cached/emotes/global';
const _ffzGlobalUrl = 'https://api.frankerfacez.com/v1/set/global';
const _sevenTvGlobalUrl = 'https://7tv.io/v3/emote-sets/global';

class _ThirdPartyEmote {
  final String code;
  final String url;
  final bool isAnimated;
  const _ThirdPartyEmote(this.code, this.url, {this.isAnimated = false});
}

class _NativeEmoteRange {
  const _NativeEmoteRange({
    required this.start,
    required this.end,
    required this.url,
  });

  final int start;
  final int end;
  final String url;
}

enum TwitchIrcEventType { message, membership }

class TwitchIrcEvent {
  const TwitchIrcEvent({
    required this.type,
    required this.tags,
    required this.username,
    required this.text,
  });

  final TwitchIrcEventType type;
  final Map<String, String> tags;
  final String username;
  final String text;
}

/// Parses the IRC framing separately from rendering so roles and USERNOTICE
/// events can be regression-tested without opening a Twitch connection.
class TwitchIrcParser {
  static const _membershipNoticeIds = {
    'sub',
    'resub',
    'subgift',
    'anonsubgift',
  };

  static TwitchIrcEvent? parse(String line) {
    var rest = line.trim();
    if (rest.isEmpty) return null;
    var tags = const <String, String>{};
    if (rest.startsWith('@')) {
      final end = rest.indexOf(' ');
      if (end < 0) return null;
      tags = parseTags(rest.substring(1, end));
      rest = rest.substring(end + 1);
    }

    var prefix = '';
    if (rest.startsWith(':')) {
      final end = rest.indexOf(' ');
      if (end < 0) return null;
      prefix = rest.substring(1, end);
      rest = rest.substring(end + 1);
    }

    final commandEnd = rest.indexOf(' ');
    final command = commandEnd < 0 ? rest : rest.substring(0, commandEnd);
    rest = commandEnd < 0 ? '' : rest.substring(commandEnd + 1);
    final trailingAt = rest.indexOf(' :');
    final text = trailingAt < 0 ? '' : rest.substring(trailingAt + 2);
    final username = prefix.split('!').first;

    if (command == 'PRIVMSG') {
      return TwitchIrcEvent(
        type: TwitchIrcEventType.message,
        tags: tags,
        username: username,
        text: text,
      );
    }
    if (command == 'USERNOTICE' &&
        _membershipNoticeIds.contains(tags['msg-id'])) {
      return TwitchIrcEvent(
        type: TwitchIrcEventType.membership,
        tags: tags,
        username: tags['login']?.isNotEmpty == true ? tags['login']! : username,
        text: text,
      );
    }
    return null;
  }

  static Map<String, String> parseTags(String source) {
    final tags = <String, String>{};
    for (final entry in source.split(';')) {
      final separator = entry.indexOf('=');
      if (separator < 0) continue;
      tags[entry.substring(0, separator)] =
          _unescape(entry.substring(separator + 1));
    }
    return tags;
  }

  static String _unescape(String value) {
    final result = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      if (char != '\\' || index + 1 >= value.length) {
        result.write(char);
        continue;
      }
      final escaped = value[++index];
      result.write(switch (escaped) {
        's' => ' ',
        ':' => ';',
        'r' => '\r',
        'n' => '\n',
        '\\' => '\\',
        _ => escaped,
      });
    }
    return result.toString();
  }
}

class TwitchUserRoles {
  const TwitchUserRoles({
    required this.badges,
    required this.isOwner,
    required this.isModerator,
    required this.isSubscriber,
    required this.isVip,
  });

  factory TwitchUserRoles.fromTags(
    Map<String, String> tags, {
    bool membershipEvent = false,
  }) {
    final badges = <String, String>{};
    for (final badge in (tags['badges'] ?? '').split(',')) {
      final separator = badge.indexOf('/');
      if (separator <= 0) continue;
      badges[badge.substring(0, separator).toLowerCase()] =
          badge.substring(separator + 1);
    }
    return TwitchUserRoles(
      badges: badges,
      isOwner: badges.containsKey('broadcaster'),
      isModerator: tags['mod'] == '1' || badges.containsKey('moderator'),
      isSubscriber: tags['subscriber'] == '1' ||
          badges.containsKey('subscriber') ||
          badges.containsKey('founder') ||
          membershipEvent,
      isVip: badges.containsKey('vip'),
    );
  }

  final Map<String, String> badges;
  final bool isOwner;
  final bool isModerator;
  final bool isSubscriber;
  final bool isVip;
}

/// Anonymous Twitch IRC client — no OAuth, no avatars.
/// Connects as justinfan{random}, supports BTTV/FFZ/7TV global emotes.
class TwitchService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _statusController =
      StreamController<(ServiceStatus, String?)>.broadcast();

  String _channel_ = '';
  bool _closed = false;
  int _generation = 0;
  final _emotes = <String, _ThirdPartyEmote>{};

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<(ServiceStatus, String?)> get statusStream => _statusController.stream;

  Future<void> connect(String channelName) async {
    await disconnect();
    final generation = ++_generation;
    _closed = false;
    _channel_ = channelName.toLowerCase().replaceAll('#', '');
    _emotes.clear();
    _emit(ServiceStatus.connecting, null);
    try {
      await _dial(generation);
      if (!_isCurrent(generation)) return;
      _emit(ServiceStatus.connected, null);
    } catch (error, stack) {
      if (!_isCurrent(generation)) return;
      AppLogger.error(
        'Twitch connection failed',
        error: error,
        stackTrace: stack,
      );
      _emit(ServiceStatus.error, error.toString());
      rethrow;
    }
    unawaited(_loadThirdPartyEmotes(generation));
    _readLoop(generation).ignore();
  }

  Future<void> disconnect() async {
    _generation++;
    _closed = true;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _emit(ServiceStatus.idle, null);
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
    await _statusController.close();
  }

  // ── internals ────────────────────────────────────────────────────────────────

  Future<void> _dial(int generation) async {
    final nick = 'justinfan${Random().nextInt(80000) + 1000}';
    final channel = WebSocketChannel.connect(Uri.parse(_ircUrl));
    try {
      await channel.ready;
    } catch (_) {
      // The failed channel is not installed; close it before propagating.
      await channel.sink.close();
      rethrow;
    }
    if (!_isCurrent(generation)) {
      await channel.sink.close();
      return;
    }
    _channel = channel;
    channel.sink.add('CAP REQ :twitch.tv/tags twitch.tv/commands\r\n');
    channel.sink.add('PASS oauth:anonymous\r\n');
    channel.sink.add('NICK $nick\r\n');
    channel.sink.add('JOIN #$_channel_\r\n');
  }

  void _send(String line) => _channel?.sink.add('$line\r\n');

  Future<void> _readLoop(int generation) async {
    while (_isCurrent(generation)) {
      final channel = _channel;
      if (channel == null) return;
      try {
        await for (final dynamic raw in channel.stream) {
          if (!_isCurrent(generation)) return;
          if (raw is String) _handleRaw(raw);
        }
        if (_isCurrent(generation)) {
          throw StateError('Twitch connection closed.');
        }
      } catch (error, stack) {
        if (!_isCurrent(generation)) return;
        AppLogger.warning(
          'Twitch connection lost',
          error: error,
          stackTrace: stack,
        );
        _emit(ServiceStatus.error, error.toString());
      }

      if (identical(_channel, channel)) {
        _channel = null;
        try {
          await channel.sink.close();
        } catch (_) {
          // The server already closed this socket; local cleanup is complete.
        }
      }

      if (!_isCurrent(generation)) return;
      await Future<void>.delayed(_reconnectDelay);
      if (!_isCurrent(generation)) return;
      _emit(ServiceStatus.connecting, null);
      try {
        await _dial(generation);
        if (!_isCurrent(generation)) return;
        _emit(ServiceStatus.connected, null);
      } catch (error, stack) {
        if (!_isCurrent(generation)) return;
        AppLogger.warning(
          'Twitch reconnection failed',
          error: error,
          stackTrace: stack,
        );
        _emit(ServiceStatus.error, error.toString());
      }
    }
  }

  bool _isCurrent(int generation) => !_closed && generation == _generation;

  void _emit(ServiceStatus status, String? error) {
    if (!_statusController.isClosed) {
      _statusController.add((status, error));
    }
  }

  void _handleRaw(String raw) {
    for (final line in raw.split('\r\n')) {
      if (line.isEmpty) continue;
      if (line.startsWith('PING')) {
        _send('PONG :tmi.twitch.tv');
        continue;
      }
      final event = TwitchIrcParser.parse(line);
      if (event != null) _handleChatEvent(event);
    }
  }

  void _handleChatEvent(TwitchIrcEvent event) {
    final username = event.username;
    final text = event.text;
    final tags = event.tags;

    final color = tags['color']?.isNotEmpty == true ? tags['color'] : null;
    final displayName = tags['display-name'] ?? username;
    final msgId = tags['id'] ?? '${DateTime.now().millisecondsSinceEpoch}';
    final roles = TwitchUserRoles.fromTags(
      tags,
      membershipEvent: event.type == TwitchIrcEventType.membership,
    );

    // Parse native Twitch emotes from tags
    // Format: emote_id:start-end,start-end/emote_id2:start-end
    final nativeEmotes = _parseNativeEmotes(tags['emotes'] ?? '');

    final items = _buildItems(text, nativeEmotes);

    final badges = roles.badges.entries
        .map((entry) => AuthorBadge(
              label: _badgeLabel(entry.key, entry.value),
              kind: entry.key,
            ))
        .toList(growable: false);
    final noticeId = tags['msg-id'];
    final eventKind = switch (noticeId) {
      'sub' => MembershipEventKind.subscription,
      'resub' => MembershipEventKind.resubscription,
      'subgift' || 'anonsubgift' => MembershipEventKind.gift,
      _ => null,
    };
    final months = int.tryParse(tags['msg-param-cumulative-months'] ?? '');

    if (!_controller.isClosed) {
      _controller.add(ChatMessage(
        platform: Platform.twitch,
        id: msgId,
        author: ChatAuthor(
          name: displayName,
          channelId: username,
          color: color,
          badges: badges,
        ),
        items: items,
        isModerator: roles.isModerator,
        isMembership: roles.isSubscriber,
        isMembershipEvent: event.type == TwitchIrcEventType.membership,
        isOwner: roles.isOwner,
        isVip: roles.isVip,
        membershipEventKind: eventKind,
        membershipMonths: months,
        timestamp: DateTime.now(),
      ));
    }
  }

  List<MessageItem> _buildItems(
    String text,
    List<_NativeEmoteRange> nativeEmotes,
  ) {
    if (text.isEmpty) return const [];
    return _buildWithAllEmotes(text, nativeEmotes);
  }

  @visibleForTesting
  List<MessageItem> parseMessageForTesting({
    required String text,
    required String nativeEmotesTag,
    Map<String, String> thirdPartyUrls = const {},
  }) {
    final thirdParty = thirdPartyUrls.map(
      (code, url) => MapEntry(code, _ThirdPartyEmote(code, url)),
    );
    return _buildWithAllEmotes(
      text,
      _parseNativeEmotes(nativeEmotesTag),
      thirdParty: thirdParty,
    );
  }

  static List<_NativeEmoteRange> _parseNativeEmotes(String source) {
    final ranges = <_NativeEmoteRange>[];
    for (final entry in source.split('/')) {
      final parts = entry.split(':');
      if (parts.length != 2 || parts[0].isEmpty) continue;
      final url =
          'https://static-cdn.jtvnw.net/emoticons/v2/${parts[0]}/default/dark/1.0';
      for (final sourceRange in parts[1].split(',')) {
        final bounds = sourceRange.split('-');
        if (bounds.length != 2) continue;
        final start = int.tryParse(bounds[0]);
        final end = int.tryParse(bounds[1]);
        if (start != null && end != null && start >= 0 && end >= start) {
          ranges.add(_NativeEmoteRange(start: start, end: end, url: url));
        }
      }
    }
    return ranges;
  }

  List<MessageItem> _buildWithAllEmotes(
      String text, List<_NativeEmoteRange> ranges,
      {Map<String, _ThirdPartyEmote>? thirdParty}) {
    final availableThirdParty = thirdParty ?? _emotes;
    final items = <MessageItem>[];
    final codePoints = text.runes.toList(growable: false);
    final sorted = ranges.toList()..sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;

    for (final range in sorted) {
      if (range.start < cursor ||
          range.start >= codePoints.length ||
          range.end >= codePoints.length) {
        continue;
      }
      _appendThirdParty(
        items,
        String.fromCharCodes(codePoints.sublist(cursor, range.start)),
        availableThirdParty,
      );
      final emoteText =
          String.fromCharCodes(codePoints.sublist(range.start, range.end + 1));
      items.add(
        MessageItem.emoji(EmojiItem(url: range.url, alt: emoteText)),
      );
      cursor = range.end + 1;
    }

    _appendThirdParty(
      items,
      String.fromCharCodes(codePoints.sublist(cursor)),
      availableThirdParty,
    );

    return items.isEmpty ? [MessageItem.text(text)] : items;
  }

  void _appendThirdParty(
    List<MessageItem> items,
    String text,
    Map<String, _ThirdPartyEmote> thirdParty,
  ) {
    if (text.isEmpty) return;
    var cursor = 0;
    for (final match in RegExp(r'\S+').allMatches(text)) {
      _appendText(items, text.substring(cursor, match.start));
      final token = match.group(0)!;
      final emote = thirdParty[token];
      if (emote != null) {
        items.add(
          MessageItem.emoji(
            EmojiItem(
              url: emote.url,
              alt: token,
              isAnimated: emote.isAnimated,
            ),
          ),
        );
      } else {
        _appendText(items, token);
      }
      cursor = match.end;
    }
    _appendText(items, text.substring(cursor));
  }

  static void _appendText(List<MessageItem> items, String text) {
    if (text.isEmpty) return;
    if (items.isNotEmpty && !items.last.isEmoji) {
      items[items.length - 1] = MessageItem.text('${items.last.text}$text');
    } else {
      items.add(MessageItem.text(text));
    }
  }

  static String _badgeLabel(String kind, String version) {
    final name = kind
        .split(RegExp('[-_]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    if (kind == 'bits' && version.isNotEmpty) return '$name $version';
    return name;
  }

  Future<void> _loadThirdPartyEmotes(int generation) async {
    await Future.wait([
      _loadBttv(generation),
      _loadFfz(generation),
      _loadSevenTv(generation),
    ]);
  }

  Future<void> _loadBttv(int generation) async {
    try {
      final res = await http
          .get(Uri.parse(_bttvGlobalUrl))
          .timeout(_optionalApiTimeout);
      if (res.statusCode != 200 || !_isCurrent(generation)) return;
      final list = jsonDecode(res.body) as List<dynamic>;
      for (final e in list) {
        final id = e['id'] as String;
        final code = e['code'] as String;
        final imageType = e['imageType'] as String? ?? 'png';
        final url = 'https://cdn.betterttv.net/emote/$id/1x';
        _emotes[code] =
            _ThirdPartyEmote(code, url, isAnimated: imageType == 'gif');
      }
    } catch (error) {
      AppLogger.debug('BetterTTV emotes unavailable: $error');
    }
  }

  Future<void> _loadFfz(int generation) async {
    try {
      final res =
          await http.get(Uri.parse(_ffzGlobalUrl)).timeout(_optionalApiTimeout);
      if (res.statusCode != 200 || !_isCurrent(generation)) return;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final sets = json['sets'] as Map<String, dynamic>? ?? {};
      for (final set in sets.values) {
        final emoticons =
            (set as Map<String, dynamic>)['emoticons'] as List<dynamic>? ?? [];
        for (final e in emoticons) {
          final code = e['name'] as String;
          final urls = e['urls'] as Map<String, dynamic>? ?? {};
          final url = urls['1'] as String? ?? '';
          if (url.isNotEmpty) {
            _emotes[code] = _ThirdPartyEmote(code, 'https:$url');
          }
        }
      }
    } catch (error) {
      AppLogger.debug('FrankerFaceZ emotes unavailable: $error');
    }
  }

  Future<void> _loadSevenTv(int generation) async {
    try {
      final res = await http
          .get(Uri.parse(_sevenTvGlobalUrl))
          .timeout(_optionalApiTimeout);
      if (res.statusCode != 200 || !_isCurrent(generation)) return;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final emotes = json['emotes'] as List<dynamic>? ?? [];
      for (final e in emotes) {
        final name = e['name'] as String;
        final data = e['data'] as Map<String, dynamic>? ?? {};
        final host = data['host'] as Map<String, dynamic>? ?? {};
        final baseUrl = host['url'] as String? ?? '';
        final files = host['files'] as List<dynamic>? ?? [];
        if (baseUrl.isEmpty || files.isEmpty) continue;
        // Prefer 1x WebP
        final file = files.firstWhere(
          (f) =>
              (f as Map<String, dynamic>)['name'].toString().startsWith('1x') ==
              true,
          orElse: () => files.first,
        );
        final fileName = (file as Map<String, dynamic>)['name'] as String;
        final isAnimated =
            fileName.contains('gif') || ((data['animated'] as bool?) ?? false);
        final url = 'https:$baseUrl/$fileName';
        _emotes[name] = _ThirdPartyEmote(name, url, isAnimated: isAnimated);
      }
    } catch (error) {
      AppLogger.debug('7TV emotes unavailable: $error');
    }
  }
}
