import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:airchat_flutter/models/chat_message.dart';

/// Serves the OBS overlay HTML page and broadcasts chat messages over WebSocket.
class OverlayServer {
  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  StreamSubscription? _msgSub;

  int _port = 8080;
  int get port => _port;

  String? _localIp;
  String? get localIp => _localIp;

  String get overlayUrl =>
      _localIp != null ? 'http://$_localIp:$_port' : 'http://localhost:$_port';

  Future<void> start({
    required Stream<ChatMessage> messages,
    int port = 8080,
  }) async {
    await stop();
    _port = port;
    _localIp = await NetworkInfo().getWifiIP();

    final wsHandler = webSocketHandler((WebSocketChannel ws, _) {
      _clients.add(ws);
      ws.stream.listen(null, onDone: () => _clients.remove(ws));
    });

    final handler = const Pipeline().addHandler((Request req) async {
      if (req.url.path == 'ws') {
        return wsHandler(req);
      }
      return Response.ok(
        _overlayHtml(),
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    } on SocketException {
      // Try localhost-only as fallback (avoids OS permission issues on some systems).
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _port);
    }
    _msgSub = messages.listen(_broadcast);
  }

  Future<void> stop() async {
    await _msgSub?.cancel();
    _msgSub = null;
    await _server?.close(force: true);
    _server = null;
    _clients.clear();
  }

  void _broadcast(ChatMessage msg) {
    if (_clients.isEmpty) return;
    final json = jsonEncode({
      'platform': msg.platform.name,
      'id': msg.id,
      'author': msg.author.name,
      'color': msg.author.color,
      'text': msg.plainText,
      'isSuperChat': msg.superChat != null,
      'superChatAmount': msg.superChat?.amount,
      'superChatColor': msg.superChat?.color,
      'isMembership': msg.isMembership,
      'isOwner': msg.isOwner,
      'isModerator': msg.isModerator,
      'timestamp': msg.timestamp.toIso8601String(),
    });
    for (final client in List.of(_clients)) {
      try {
        client.sink.add(json);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  static String _overlayHtml() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AirChat Overlay</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: transparent;
    font-family: 'Segoe UI', sans-serif;
    font-size: 14px;
    overflow: hidden;
    height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    padding: 8px;
  }
  #chat {
    display: flex;
    flex-direction: column;
    gap: 4px;
    max-height: 100vh;
    overflow: hidden;
  }
  .msg {
    display: flex;
    align-items: baseline;
    gap: 6px;
    padding: 4px 8px;
    border-radius: 8px;
    background: rgba(0,0,0,0.45);
    animation: fadeIn 0.2s ease;
    word-break: break-word;
    max-width: 100%;
  }
  .msg.superchat {
    border-left: 4px solid var(--sc-color, #FFD600);
    background: color-mix(in srgb, var(--sc-color, #FFD600) 20%, rgba(0,0,0,0.6));
  }
  .badge {
    font-size: 10px;
    padding: 1px 4px;
    border-radius: 3px;
    white-space: nowrap;
    font-weight: 600;
  }
  .badge.yt  { background: #FF0000; color: #fff; }
  .badge.twitch { background: #9147FF; color: #fff; }
  .badge.kick { background: #53FC18; color: #000; }
  .author { font-weight: 700; white-space: nowrap; }
  .text { color: #fff; }
  .sc-amount { font-weight: 700; font-size: 12px; color: #FFD600; white-space: nowrap; }
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(4px); }
    to   { opacity: 1; transform: translateY(0); }
  }
</style>
</head>
<body>
<div id="chat"></div>
<script>
const MAX = 50;
const chat = document.getElementById('chat');

function addMsg(data) {
  const div = document.createElement('div');
  div.className = 'msg' + (data.isSuperChat ? ' superchat' : '');
  if (data.isSuperChat && data.superChatColor) {
    div.style.setProperty('--sc-color', data.superChatColor);
  }

  const badge = document.createElement('span');
  badge.className = 'badge ' + data.platform;
  badge.textContent = data.platform === 'youtube' ? 'YT'
                    : data.platform === 'twitch' ? 'TW' : 'KK';
  div.appendChild(badge);

  const author = document.createElement('span');
  author.className = 'author';
  author.style.color = data.color || '#fff';
  author.textContent = data.author + ':';
  div.appendChild(author);

  if (data.isSuperChat && data.superChatAmount) {
    const sc = document.createElement('span');
    sc.className = 'sc-amount';
    sc.textContent = data.superChatAmount;
    div.appendChild(sc);
  }

  const text = document.createElement('span');
  text.className = 'text';
  text.textContent = data.text;
  div.appendChild(text);

  chat.appendChild(div);
  while (chat.children.length > MAX) chat.removeChild(chat.firstChild);
  div.scrollIntoView({ behavior: 'smooth' });
}

function connect() {
  const ws = new WebSocket('ws://' + location.host + '/ws');
  ws.onmessage = (e) => { try { addMsg(JSON.parse(e.data)); } catch(_) {} };
  ws.onclose = () => setTimeout(connect, 3000);
}
connect();
</script>
</body>
</html>''';
}
