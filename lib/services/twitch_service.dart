import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:airchat_flutter/models/chat_message.dart';

const _ircUrl = 'wss://irc-ws.chat.twitch.tv/';
const _reconnectDelay = Duration(seconds: 5);

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

/// Anonymous Twitch IRC client — no OAuth, no avatars.
/// Connects as justinfan{random}, supports BTTV/FFZ/7TV global emotes.
class TwitchService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<ChatMessage>.broadcast();

  String _channel_ = '';
  bool _closed = false;
  final _emotes = <String, _ThirdPartyEmote>{};

  Stream<ChatMessage> get messages => _controller.stream;

  Future<void> connect(String channelName) async {
    await disconnect();
    _closed = false;
    _channel_ = channelName.toLowerCase().replaceAll('#', '');
    await _loadThirdPartyEmotes();
    await _dial();
    _readLoop().ignore();
  }

  Future<void> disconnect() async {
    _closed = true;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }

  // ── internals ────────────────────────────────────────────────────────────────

  Future<void> _dial() async {
    final nick = 'justinfan${Random().nextInt(80000) + 1000}';
    _channel = WebSocketChannel.connect(Uri.parse(_ircUrl));
    await _channel!.ready;
    _send('CAP REQ :twitch.tv/tags twitch.tv/commands');
    _send('PASS oauth:anonymous');
    _send('NICK $nick');
    _send('JOIN #$_channel_');
  }

  void _send(String line) => _channel?.sink.add('$line\r\n');

  Future<void> _readLoop() async {
    while (!_closed) {
      try {
        await for (final dynamic raw in _channel!.stream) {
          if (raw is String) _handleRaw(raw);
        }
      } catch (_) {}

      if (_closed) break;
      await Future<void>.delayed(_reconnectDelay);
      if (_closed) break;
      try {
        await _dial();
      } catch (_) {}
    }
  }

  void _handleRaw(String raw) {
    for (final line in raw.split('\r\n')) {
      if (line.isEmpty) continue;
      if (line.startsWith('PING')) {
        _send('PONG :tmi.twitch.tv');
        continue;
      }
      if (line.contains('PRIVMSG')) _handlePrivmsg(line);
    }
  }

  static final _privmsgRe = RegExp(
    r'^(?:@([^ ]+) )?:([^!]+)![^ ]+ PRIVMSG #\w+ :(.+)$',
  );

  void _handlePrivmsg(String line) {
    final m = _privmsgRe.firstMatch(line);
    if (m == null) return;

    final tagStr = m.group(1) ?? '';
    final username = m.group(2)!;
    final text = m.group(3)!;
    final tags = _parseTags(tagStr);

    final color = tags['color']?.isNotEmpty == true ? tags['color'] : null;
    final displayName = tags['display-name'] ?? username;
    final msgId = tags['id'] ?? '${DateTime.now().millisecondsSinceEpoch}';
    final isMod = tags['mod'] == '1';
    final isSub = tags['subscriber'] == '1';

    // Parse native Twitch emotes from tags
    // Format: emote_id:start-end,start-end/emote_id2:start-end
    final nativeEmotes = <int, String>{}; // start pos → CDN url
    final emotesTag = tags['emotes'] ?? '';
    if (emotesTag.isNotEmpty) {
      for (final entry in emotesTag.split('/')) {
        final parts = entry.split(':');
        if (parts.length != 2) continue;
        final emoteId = parts[0];
        final url =
            'https://static-cdn.jtvnw.net/emoticons/v2/$emoteId/default/dark/1.0';
        for (final range in parts[1].split(',')) {
          final bounds = range.split('-');
          if (bounds.length == 2) {
            final start = int.tryParse(bounds[0]);
            if (start != null) nativeEmotes[start] = url;
          }
        }
      }
    }

    final items = _buildItems(text, nativeEmotes);

    final badge = isSub ? const AuthorBadge(label: 'subscriber') : null;

    if (!_controller.isClosed) {
      _controller.add(ChatMessage(
        platform: Platform.twitch,
        id: msgId,
        author: ChatAuthor(
          name: displayName,
          channelId: username,
          color: color,
          badge: badge,
        ),
        items: items,
        isModerator: isMod,
        isMembership: isSub,
        timestamp: DateTime.now(),
      ));
    }
  }

  List<MessageItem> _buildItems(String text, Map<int, String> nativeEmotes) {
    if (nativeEmotes.isNotEmpty) {
      return _buildWithNativeEmotes(text, nativeEmotes);
    }
    // Word-by-word scan for third-party emotes
    return _buildWithThirdParty(text);
  }

  List<MessageItem> _buildWithNativeEmotes(
      String text, Map<int, String> positions) {
    final items = <MessageItem>[];
    // text is utf16 code units in IRC — we index by rune for correctness
    final chars = text.split(''); // simple, works for BMP
    int cursor = 0;

    final sortedStarts = positions.keys.toList()..sort();
    for (final start in sortedStarts) {
      final url = positions[start]!;
      // scan forward from start to find the emote token end
      int end = start;
      while (end < chars.length && chars[end] != ' ') {
        end++;
      }
      final emoteText = chars.sublist(start, end).join();

      if (start > cursor) {
        final between = chars.sublist(cursor, start).join();
        if (between.trim().isNotEmpty) {
          items.add(MessageItem.text(between));
        }
      }
      items.add(MessageItem.emoji(EmojiItem(url: url, alt: emoteText)));
      cursor = end;
    }

    if (cursor < chars.length) {
      final tail = chars.sublist(cursor).join();
      if (tail.trim().isNotEmpty) items.add(MessageItem.text(tail));
    }

    return items.isEmpty ? [MessageItem.text(text)] : items;
  }

  List<MessageItem> _buildWithThirdParty(String text) {
    final items = <MessageItem>[];
    final words = text.split(' ');
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final emote = _emotes[word];
      if (emote != null) {
        items.add(MessageItem.emoji(
            EmojiItem(url: emote.url, alt: word, isAnimated: emote.isAnimated)));
      } else {
        if (items.isNotEmpty && !items.last.isEmoji) {
          // Append to previous text item
          items[items.length - 1] =
              MessageItem.text('${items.last.text} $word');
        } else {
          items.add(MessageItem.text(word));
        }
      }
    }
    return items.isEmpty ? [MessageItem.text(text)] : items;
  }

  static Map<String, String> _parseTags(String tagStr) {
    final tags = <String, String>{};
    if (tagStr.isEmpty) return tags;
    for (final kv in tagStr.split(';')) {
      final eq = kv.indexOf('=');
      if (eq == -1) continue;
      tags[kv.substring(0, eq)] = kv.substring(eq + 1);
    }
    return tags;
  }

  Future<void> _loadThirdPartyEmotes() async {
    await Future.wait([
      _loadBttv(),
      _loadFfz(),
      _loadSevenTv(),
    ]);
  }

  Future<void> _loadBttv() async {
    try {
      final res = await http.get(Uri.parse(_bttvGlobalUrl));
      if (res.statusCode != 200) return;
      final list = jsonDecode(res.body) as List<dynamic>;
      for (final e in list) {
        final id = e['id'] as String;
        final code = e['code'] as String;
        final imageType = e['imageType'] as String? ?? 'png';
        final url = 'https://cdn.betterttv.net/emote/$id/1x';
        _emotes[code] =
            _ThirdPartyEmote(code, url, isAnimated: imageType == 'gif');
      }
    } catch (_) {}
  }

  Future<void> _loadFfz() async {
    try {
      final res = await http.get(Uri.parse(_ffzGlobalUrl));
      if (res.statusCode != 200) return;
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
    } catch (_) {}
  }

  Future<void> _loadSevenTv() async {
    try {
      final res = await http.get(Uri.parse(_sevenTvGlobalUrl));
      if (res.statusCode != 200) return;
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
              (f as Map<String, dynamic>)['name']
                  .toString()
                  .startsWith('1x') ==
              true,
          orElse: () => files.first,
        );
        final fileName = (file as Map<String, dynamic>)['name'] as String;
        final isAnimated = fileName.contains('gif') ||
            ((data['animated'] as bool?) ?? false);
        final url = 'https:$baseUrl/$fileName';
        _emotes[name] = _ThirdPartyEmote(name, url, isAnimated: isAnimated);
      }
    } catch (_) {}
  }
}
