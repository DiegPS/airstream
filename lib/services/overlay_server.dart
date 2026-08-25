import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Serves the OBS overlay HTML page and broadcasts chat messages over WebSocket.
class OverlayServer {
  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  final _clientCountController = StreamController<int>.broadcast();
  StreamSubscription? _msgSub;
  SettingsModel _settings = const SettingsModel();

  int _port = 8080;
  int _networkLookupGeneration = 0;
  int _lifecycleGeneration = 0;
  int get port => _port;

  String? _localIp;
  String? get localIp => _localIp;
  int get clientCount => _clients.length;
  Stream<int> get clientCountStream async* {
    yield _clients.length;
    yield* _clientCountController.stream;
  }

  String get overlayUrl =>
      _localIp != null ? 'http://$_localIp:$_port' : 'http://localhost:$_port';

  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port = 8080,
  }) async {
    await stop();
    final lifecycleGeneration = ++_lifecycleGeneration;
    _settings = settings;
    _port = port;
    _localIp = null;
    final lookupGeneration = ++_networkLookupGeneration;
    unawaited(NetworkInfo().getWifiIP().then((address) {
      if (lookupGeneration == _networkLookupGeneration) {
        _localIp = address;
      }
    }).catchError((_) {}));

    final wsHandler = webSocketHandler((WebSocketChannel ws, _) {
      _clients.add(ws);
      _emitClientCount();
      _sendSettingsToClient(ws);
      ws.stream.listen(null, onDone: () {
        _clients.remove(ws);
        _emitClientCount();
      });
    });

    final handler = const Pipeline().addHandler((Request req) async {
      if (req.url.path == 'ws') {
        return wsHandler(req);
      }
      if (req.url.path == 'alerts') {
        return _htmlResponse(_alertsHtml());
      }
      if (req.url.path == 'captions') {
        return _htmlResponse(_captionsHtml());
      }
      return _htmlResponse(_overlayHtml());
    });

    late final HttpServer server;
    try {
      server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    } on SocketException {
      server =
          await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _port);
    }
    if (lifecycleGeneration != _lifecycleGeneration) {
      await server.close(force: true);
      return;
    }
    _server = server;
    _msgSub = messages.listen(_broadcastMessage);
  }

  static Response _htmlResponse(String html) => Response.ok(
        html,
        headers: const {
          'content-type': 'text/html; charset=utf-8',
          'cache-control': 'no-store',
          'referrer-policy': 'no-referrer',
          'x-content-type-options': 'nosniff',
          'content-security-policy':
              "default-src 'none'; img-src data: http: https:; connect-src ws: wss:; style-src 'unsafe-inline'; script-src 'unsafe-inline'",
        },
      );

  void setSettings(SettingsModel settings) {
    _settings = settings;
    _broadcastSettings();
  }

  bool reloadClients() {
    if (_clients.isEmpty) return false;
    _broadcastEnvelope({'type': 'reload'});
    return true;
  }

  bool broadcastTestAlert(String kind) {
    if (_clients.isEmpty) return false;
    final now = DateTime.now().toIso8601String();
    final spanish = _settings.appLanguageCode == 'es';
    final donorName = spanish ? 'Donante de prueba' : 'Test donor';
    final memberName = spanish ? 'Miembro de prueba' : 'Test member';
    const donorAvatar = null;
    const memberAvatar = null;
    final data = switch (kind) {
      'superchat-empty' => {
          'platform': 'youtube',
          'kind': 'superchat',
          'id': 'test-superchat-empty-$now',
          'author': donorName,
          'authorAvatarUrl': donorAvatar,
          'authorChannelId': 'test-donor',
          'badgeImageUrl': null,
          'badgeLabel': null,
          'message': '',
          'amount': r'MX$100.00',
          'color': '#E91E63',
          'stickerUrl': null,
          'timestamp': now,
        },
      'membership' => {
          'platform': 'youtube',
          'kind': 'membership',
          'id': 'test-membership-$now',
          'author': memberName,
          'authorAvatarUrl': memberAvatar,
          'authorChannelId': 'test-member',
          'badgeImageUrl': null,
          'badgeLabel': spanish ? 'Nuevo miembro' : 'New member',
          'message': spanish
              ? '¡Te damos la bienvenida a la membresía del canal!'
              : 'Welcome to the channel membership!',
          'amount': null,
          'color': '#0F9D58',
          'stickerUrl': null,
          'timestamp': now,
        },
      _ => {
          'platform': 'youtube',
          'kind': 'superchat',
          'id': 'test-superchat-$now',
          'author': donorName,
          'authorAvatarUrl': donorAvatar,
          'authorChannelId': 'test-donor',
          'badgeImageUrl': null,
          'badgeLabel': null,
          'message': spanish
              ? 'Este es un mensaje de prueba de Super Chat.'
              : 'This is a test Super Chat message.',
          'amount': r'MX$50.00',
          'color': '#FFD600',
          'stickerUrl': null,
          'timestamp': now,
        },
    };
    _broadcastEnvelope({'type': 'alert', 'data': data});
    return true;
  }

  void broadcastCaption(String text) {
    final caption = text.trim();
    if (caption.isEmpty) return;
    _broadcastEnvelope({
      'type': 'caption',
      'data': {'text': caption}
    });
  }

  Future<void> stop() async {
    _lifecycleGeneration++;
    _networkLookupGeneration++;
    await _msgSub?.cancel();
    _msgSub = null;
    await _server?.close(force: true);
    _server = null;
    _clients.clear();
    _emitClientCount();
  }

  Future<void> dispose() async {
    await stop();
    await _clientCountController.close();
  }

  void _broadcastMessage(ChatMessage msg) {
    _broadcastEnvelope({
      'type': 'message',
      'data': _messagePayload(msg),
    });
    _broadcastAlert(msg);
  }

  Map<String, dynamic> _messagePayload(ChatMessage msg) => {
        'platform': msg.platform.name,
        'id': msg.id,
        'author': msg.author.name,
        'authorAvatarUrl': msg.author.avatarUrl,
        'authorChannelId': msg.author.channelId,
        'badgeImageUrl': msg.author.badge?.imageUrl,
        'badgeLabel': msg.author.badge?.label,
        'color': msg.author.color,
        'text': msg.plainText,
        'items': msg.items
            .map((item) => item.isEmoji
                ? {
                    'kind': 'emoji',
                    'url': item.emoji!.url,
                    'alt': item.emoji!.alt,
                    'isAnimated': item.emoji!.isAnimated,
                  }
                : {
                    'kind': 'text',
                    'text': item.text,
                  })
            .toList(),
        'isSuperChat': msg.superChat != null,
        'superChatAmount': msg.superChat?.amount,
        'superChatColor': msg.superChat?.color,
        'superChatStickerUrl': msg.superChat?.stickerUrl,
        'isMembership': msg.isMembership,
        'isMembershipEvent': msg.isMembershipEvent,
        'isOwner': msg.isOwner,
        'isModerator': msg.isModerator,
        'isVerified': msg.isVerified,
        'timestamp': msg.timestamp.toIso8601String(),
      };

  void _broadcastAlert(ChatMessage msg) {
    if (msg.platform != Platform.youtube) return;
    final kind = msg.superChat != null
        ? 'superchat'
        : msg.isMembershipEvent
            ? 'membership'
            : null;
    if (kind == null) return;

    _broadcastEnvelope({
      'type': 'alert',
      'data': {
        'platform': msg.platform.name,
        'kind': kind,
        'id': msg.id,
        'author': msg.author.name,
        'authorAvatarUrl': msg.author.avatarUrl,
        'authorChannelId': msg.author.channelId,
        'badgeImageUrl': msg.author.badge?.imageUrl,
        'badgeLabel': msg.author.badge?.label,
        'message': msg.plainText.trim(),
        'amount': msg.superChat?.amount,
        'color': msg.superChat?.color,
        'stickerUrl': msg.superChat?.stickerUrl,
        'timestamp': msg.timestamp.toIso8601String(),
      },
    });
  }

  void _broadcastSettings() {
    _broadcastEnvelope({
      'type': 'settings',
      'data': _overlaySettingsPayload(),
    });
  }

  void _sendSettingsToClient(WebSocketChannel client) {
    try {
      client.sink.add(jsonEncode({
        'type': 'settings',
        'data': _overlaySettingsPayload(),
      }));
    } catch (_) {
      _clients.remove(client);
    }
  }

  void _broadcastEnvelope(Map<String, dynamic> envelope) {
    if (_clients.isEmpty) return;
    final json = jsonEncode(envelope);
    for (final client in List.of(_clients)) {
      try {
        client.sink.add(json);
      } catch (_) {
        _clients.remove(client);
        _emitClientCount();
      }
    }
  }

  void _emitClientCount() {
    if (!_clientCountController.isClosed) {
      _clientCountController.add(_clients.length);
    }
  }

  Map<String, dynamic> _overlaySettingsPayload() => {
        'appLanguageCode': _settings.appLanguageCode,
        'chromaMode': _settings.overlayChromaMode,
        'chromaColor': _settings.overlayChromaColor,
        'showGrid': _settings.overlayShowGrid,
        'hideScrollbar': _settings.overlayHideScrollbar,
        'fontSize': _settings.overlayFontSize,
        'bgOpacity': _settings.overlayBgOpacity,
        'messageOpacity': _settings.overlayMessageOpacity,
        'showAvatars': _settings.overlayShowAvatars,
        'showPlatformIcons': _settings.overlayShowPlatformIcons,
        'showBadges': _settings.overlayShowBadges,
        'showTimestamp': _settings.overlayShowTimestamp,
        'textStroke': _settings.overlayTextStroke,
        'textStrokeColor': _settings.overlayTextStrokeColor,
        'lineHeight': _settings.overlayLineHeight,
        'messageGap': _settings.overlayMessageGap,
        'fontWeight': _settings.overlayFontWeight,
        'borderRadius': _settings.overlayBorderRadius,
        'textShadow': _settings.overlayTextShadow,
        'showBubble': _settings.overlayShowBubble,
        'superChatBarEnabled': _settings.overlaySuperChatBarEnabled,
        'superChatBarColor': _settings.overlaySuperChatBarColor,
        'superChatBarWidth': _settings.overlaySuperChatBarWidth,
        'maxMessages': _settings.overlayMaxMessages,
        'messageTtlSeconds': _settings.overlayMessageTtlSeconds,
        'animation': _settings.overlayAnimation,
        'animationDuration': _settings.overlayAnimationDuration,
        'textAlign': _settings.overlayTextAlign,
        'twitchBubbleAccent': _settings.overlayTwitchBubbleAccent,
        'kickBubbleAccent': _settings.overlayKickBubbleAccent,
        'threeDEnabled': _settings.overlayThreeDEnabled,
        'perspective': _settings.overlayPerspective,
        'rotateX': _settings.overlayRotateX,
        'rotateY': _settings.overlayRotateY,
        'rotateZ': _settings.overlayRotateZ,
        'skewX': _settings.overlaySkewX,
        'scale': _settings.overlayScale,
        'alertFontSize': _settings.alertFontSize,
        'alertDisplaySeconds': _settings.alertDisplaySeconds,
        'alertShowAvatars': _settings.alertShowAvatars,
      };

  static String _alertsHtml() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Alerts</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: transparent;
    overflow: hidden;
    height: 100vh;
    font-family: 'Segoe UI', sans-serif;
  }
  #root { height: 100%; }
  .alert-stage {
    height: 100%;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 48px;
  }
  .alert-card {
    min-width: 360px;
    max-width: min(760px, 90vw);
    display: flex;
    align-items: center;
    gap: 18px;
    padding: 22px 28px;
    border-radius: 18px;
    color: #fff;
    background: rgba(10, 10, 10, 0.82);
    border: 1px solid rgba(255, 255, 255, 0.18);
    box-shadow: 0 20px 70px rgba(0, 0, 0, 0.45);
    animation: alert-in 0.45s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
  .alert-avatar {
    width: 76px;
    height: 76px;
    flex: 0 0 auto;
    border-radius: 50%;
    object-fit: cover;
    border: 3px solid rgba(255, 255, 255, 0.3);
    background: rgba(255, 255, 255, 0.12);
  }
  .alert-avatar-fallback {
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff;
    font-weight: 800;
    user-select: none;
  }
  .alert-copy {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .alert-kicker {
    font-size: 0.55em;
    font-weight: 800;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    opacity: 0.82;
  }
  .alert-title {
    font-size: 1em;
    font-weight: 800;
    line-height: 1.1;
    overflow-wrap: anywhere;
  }
  .alert-message {
    margin-top: 2px;
    font-size: 0.68em;
    line-height: 1.32;
    opacity: 0.94;
    overflow-wrap: anywhere;
  }
  .alert-sticker {
    max-width: 118px;
    max-height: 118px;
    border-radius: 8px;
  }
  @keyframes alert-in {
    from { opacity: 0; transform: translateY(24px) scale(0.94); }
    to { opacity: 1; transform: translateY(0) scale(1); }
  }
</style>
</head>
<body>
<div id="root"></div>
<script>
const DEFAULT_SETTINGS = {
  appLanguageCode: 'en',
  alertFontSize: 28,
  alertDisplaySeconds: 7,
  alertShowAvatars: true,
};

function normalizeUrl(url) {
  if (!url || typeof url !== 'string') return '';
  if (url.startsWith('//')) return 'https:' + url;
  return url;
}

function platformLabel(platform) {
  switch (platform) {
    case 'youtube': return 'YouTube';
    case 'twitch': return 'Twitch';
    case 'kick': return 'Kick';
    default: return 'Chat';
  }
}

function alertAccent(alert) {
  if (alert.kind === 'superchat') return alert.color || '#FFD600';
  if (alert.platform === 'kick') return '#53FC18';
  if (alert.platform === 'twitch') return '#9146FF';
  return '#FF4E45';
}

const UI_STRINGS = {
  en: {
    someone: 'Someone',
    sent: 'sent',
    superChat: 'a Super Chat',
    becameMember: 'became a member',
    membership: 'Membership',
  },
  es: {
    someone: 'Alguien',
    sent: 'envió',
    superChat: 'un Super Chat',
    becameMember: 'se convirtió en miembro',
    membership: 'Membresía',
  },
};

function initials(name) {
  const parts = String(name || '?').trim().split(' ').filter(Boolean);
  return (parts.length > 1 ? parts[0][0] + parts[parts.length - 1][0] : (parts[0] || '?').slice(0, 2)).toUpperCase();
}

function createImage(className, url, alt, onError) {
  const image = document.createElement('img');
  image.className = className;
  image.src = url;
  image.alt = alt || '';
  image.referrerPolicy = 'no-referrer';
  image.addEventListener('error', () => {
    if (onError) onError(image);
    else image.remove();
  }, { once: true });
  return image;
}

function renderAlert(alert) {
  const strings = UI_STRINGS[settings.appLanguageCode] || UI_STRINGS.en;
  const accent = alertAccent(alert);
  const author = String(alert.author || strings.someone);
  const message = String(alert.message || '').trim();
  const title = alert.kind === 'superchat'
    ? author + ' ' + strings.sent + ' ' + (alert.amount || strings.superChat)
    : author + ' ' + strings.becameMember;
  const kicker = alert.kind === 'superchat'
    ? platformLabel(alert.platform) + ' Super Chat'
    : platformLabel(alert.platform) + ' ' + strings.membership;
  const avatarUrl = normalizeUrl(alert.authorAvatarUrl);
  const stickerUrl = normalizeUrl(alert.stickerUrl);

  const card = document.createElement('div');
  card.className = 'alert-card';
  card.style.borderBottom = '5px solid ' + accent;

  if (settings.alertShowAvatars) {
    if (avatarUrl) {
      card.appendChild(createImage('alert-avatar', avatarUrl, author, (image) => {
        const fallback = document.createElement('div');
        fallback.className = 'alert-avatar alert-avatar-fallback';
        fallback.textContent = initials(author);
        image.replaceWith(fallback);
      }));
    } else {
      const fallback = document.createElement('div');
      fallback.className = 'alert-avatar alert-avatar-fallback';
      fallback.textContent = initials(author);
      card.appendChild(fallback);
    }
  }

  const copy = document.createElement('div');
  copy.className = 'alert-copy';
  const kickerNode = document.createElement('div');
  kickerNode.className = 'alert-kicker';
  kickerNode.style.color = accent;
  kickerNode.textContent = kicker;
  const titleNode = document.createElement('div');
  titleNode.className = 'alert-title';
  titleNode.textContent = title;
  copy.append(kickerNode, titleNode);
  if (message) {
    const messageNode = document.createElement('div');
    messageNode.className = 'alert-message';
    messageNode.textContent = message;
    copy.appendChild(messageNode);
  }
  card.appendChild(copy);
  if (stickerUrl) card.appendChild(createImage('alert-sticker', stickerUrl, ''));
  stage.replaceChildren(card);
}

const root = document.getElementById('root');
const stage = document.createElement('div');
stage.className = 'alert-stage';
root.appendChild(stage);
let settings = { ...DEFAULT_SETTINGS };
let queue = [];
let active = null;
let hideTimer = 0;
let retryTimer = 0;
let socket = null;
let shuttingDown = false;

function applySettings(next) {
  settings = { ...settings, ...next };
  document.documentElement.lang = settings.appLanguageCode || 'en';
  stage.style.fontSize = String(settings.alertFontSize || DEFAULT_SETTINGS.alertFontSize) + 'px';
  if (active) renderAlert(active);
}

function showNext() {
  if (active || queue.length === 0) return;
  active = queue.shift();
  renderAlert(active);
  const seconds = Math.max(1, Number(settings.alertDisplaySeconds) || DEFAULT_SETTINGS.alertDisplaySeconds);
  hideTimer = window.setTimeout(() => {
    active = null;
    stage.replaceChildren();
    showNext();
  }, seconds * 1000);
}

function connect() {
  const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
  socket = new WebSocket(protocol + location.host + '/ws');
  socket.addEventListener('message', (event) => {
    try {
      const envelope = JSON.parse(event.data);
      if (envelope.type === 'settings') applySettings(envelope.data || {});
      else if (envelope.type === 'reload') window.location.reload();
      else if (envelope.type === 'alert' && envelope.data) {
        queue.push(envelope.data);
        showNext();
      }
    } catch (_) {}
  });
  socket.addEventListener('close', () => {
    if (!shuttingDown) retryTimer = window.setTimeout(connect, 3000);
  });
  socket.addEventListener('error', () => socket.close());
}

applySettings(DEFAULT_SETTINGS);
connect();
window.addEventListener('beforeunload', () => {
  shuttingDown = true;
  window.clearTimeout(hideTimer);
  window.clearTimeout(retryTimer);
  if (socket) socket.close();
});
</script>
</body>
</html>''';

  static String _captionsHtml() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Captions</title>
<style>
  * { box-sizing: border-box; }
  html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; background: transparent; }
  body { display: flex; align-items: flex-end; justify-content: center; padding: 4vh 4vw; }
  #caption {
    max-width: 92vw;
    padding: .35em .65em;
    border-radius: .35em;
    color: white;
    background: rgba(0, 0, 0, .72);
    font: 700 clamp(24px, 4vw, 64px)/1.25 system-ui, sans-serif;
    text-align: center;
    text-shadow: 0 2px 4px #000;
    opacity: 0;
    transition: opacity 160ms ease;
  }
  #caption.visible { opacity: 1; }
</style>
</head>
<body>
<div id="caption" role="status" aria-live="polite"></div>
<script>
(() => {
  const caption = document.getElementById('caption');
  let retry;
  let hide;
  const connect = () => {
    const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
    const ws = new WebSocket(protocol + location.host + '/ws');
    ws.onmessage = (event) => {
      try {
        const envelope = JSON.parse(event.data);
        if (envelope.type === 'reload') return location.reload();
        if (envelope.type !== 'caption') return;
        caption.textContent = envelope.data.text || '';
        caption.classList.toggle('visible', Boolean(caption.textContent));
        window.clearTimeout(hide);
        hide = window.setTimeout(() => caption.classList.remove('visible'), 7000);
      } catch (_) {}
    };
    ws.onclose = () => { retry = window.setTimeout(connect, 3000); };
  };
  connect();
  window.addEventListener('beforeunload', () => {
    window.clearTimeout(retry);
    window.clearTimeout(hide);
  });
})();
</script>
</body>
</html>''';

  static String _overlayHtml() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Overlay</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: transparent;
    overflow: hidden;
    height: 100vh;
    font-family: 'Segoe UI', sans-serif;
  }
  #root { height: 100%; }
  .overlay-shell {
    flex: 1;
    position: relative;
    overflow: visible;
    height: 100%;
    width: 100%;
    display: flex;
    flex-direction: column;
    transition: background-color 0.3s ease;
  }
  .overlay-shell.hide-scrollbar .chat-overlay::-webkit-scrollbar {
    display: none;
  }
  .overlay-shell.hide-scrollbar .chat-overlay {
    -ms-overflow-style: none;
    scrollbar-width: none;
  }
  .chat-overlay {
    flex: 1;
    overflow-y: auto;
    overflow-x: visible;
    padding: 3rem;
    display: flex;
    flex-direction: column;
    gap: 15px;
    scrollbar-width: thin;
    -ms-overflow-style: auto;
    mask-image: linear-gradient(to bottom, transparent 0%, black 8%);
  }
  .chat-item {
    display: flex;
    align-items: flex-start;
    width: fit-content;
    max-width: 85%;
    word-break: break-word;
  }
  .chat-content {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
  }
  .author-row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 4px;
  }
  .author-name {
    color: #fff;
    font-weight: 700;
    line-height: 1.1;
  }
  .author-name.owner { color: #FFD700; }
  .author-name.mod { color: #7EA4FF; }
  .badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 2px 6px;
    border-radius: 999px;
    font-size: 0.8em;
    font-weight: 700;
    line-height: 1;
    white-space: nowrap;
  }
  .owner-badge { background: #FFD700; color: #111; }
  .mod-badge { background: #7EA4FF; color: #111; }
  .member-badge { background: #0F9D58; color: #fff; }
  .twitch-sub-badge { background: #9146FF; color: #fff; }
  .kick-sub-badge { background: #53FC18; color: #111; }
  .superchat-badge { background: #FFD600; color: #111; }
  .custom-badge {
    padding: 0;
    background: transparent;
  }
  .custom-badge img {
    width: 1em;
    height: 1em;
    display: block;
  }
  .timestamp {
    opacity: 0.6;
    font-size: 0.85em;
  }
  .message-text {
    color: #fff;
    min-width: 0;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 6px;
    word-break: break-word;
  }
  .message-text .emoji {
    width: 1.25em;
    height: 1.25em;
    vertical-align: middle;
    margin: 0 0.1em;
  }
  .membership-flair {
    margin-top: 6px;
    opacity: 0.95;
  }
  .superchat-sticker {
    margin-top: 8px;
  }
  .superchat-sticker img {
    max-width: 100px;
    border-radius: 4px;
  }
  .avatar-wrap {
    position: relative;
    flex-shrink: 0;
  }
  .avatar {
    width: 44px;
    height: 44px;
    border-radius: 50%;
    object-fit: cover;
    border: 2px solid rgba(255,255,255,0.2);
    display: block;
  }
  .avatar-fallback {
    width: 44px;
    height: 44px;
    border-radius: 50%;
    border: 2px solid rgba(255,255,255,0.2);
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff;
    font-weight: 700;
    font-size: 0.65em;
    user-select: none;
  }
  .platform-overlay {
    position: absolute;
    bottom: -2px;
    right: -2px;
    width: 14px;
    height: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  @keyframes slide-up {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes slide-left {
    from { opacity: 0; transform: translateX(14px); }
    to { opacity: 1; transform: translateX(0); }
  }
  @keyframes fade-in {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  @keyframes zoom-in {
    from { opacity: 0; transform: scale(0.94); }
    to { opacity: 1; transform: scale(1); }
  }
</style>
</head>
<body>
<div id="root"></div>
<script>
const DEFAULT_SETTINGS = {
  appLanguageCode: 'en',
  chromaMode: false,
  chromaColor: '#00FF00',
  showGrid: false,
  hideScrollbar: false,
  fontSize: 14,
  bgOpacity: 0,
  messageOpacity: 0.45,
  showAvatars: true,
  showPlatformIcons: true,
  showBadges: true,
  showTimestamp: false,
  textStroke: 0,
  textStrokeColor: '#000000',
  lineHeight: 1.5,
  messageGap: 15,
  fontWeight: 400,
  borderRadius: 16,
  textShadow: false,
  showBubble: true,
  superChatBarEnabled: true,
  superChatBarColor: '#1DE9B6',
  superChatBarWidth: 3,
  maxMessages: 100,
  messageTtlSeconds: 20,
  animation: 'slide-up',
  animationDuration: 0.4,
  textAlign: 'left',
  twitchBubbleAccent: true,
  kickBubbleAccent: true,
  threeDEnabled: false,
  perspective: 1000,
  rotateX: 0,
  rotateY: 0,
  rotateZ: 0,
  skewX: 0,
  scale: 1,
};

function platformIcon(platform) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  svg.setAttribute('width', '12');
  svg.setAttribute('height', '12');
  svg.style.flexShrink = '0';
  if (platform === 'twitch') {
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', '#9146FF');
    path.setAttribute('d', 'M11.6 6H13v4.5h-1.4V6zm3.8 0h1.4v4.5h-1.4V6zM4 0L.5 3.5V20.5H6V24l3.5-3.5H12L23.5 9V0H4zm18 8.5L18.5 12H16l-3 3v-3H9.5v-8H22v4.5z');
  } else if (platform === 'kick') {
    svg.setAttribute('viewBox', '0 0 512 512');
    svg.setAttribute('fill', '#53FC18');
    path.setAttribute('d', 'M37 .036h164.448v113.621h54.71v-56.82h54.731V.036h164.448v170.777h-54.73v56.82h-54.711v56.8h54.71v56.82h54.73V512.03H310.89v-56.82h-54.73v-56.8h-54.711v113.62H37V.036z');
  } else {
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', '#FF0000');
    path.setAttribute('d', 'M23.5 6.2a3 3 0 0 0-2.1-2.1C19.5 3.5 12 3.5 12 3.5s-7.5 0-9.4.6A3 3 0 0 0 .5 6.2 31 31 0 0 0 0 12a31 31 0 0 0 .5 5.8A3 3 0 0 0 2.6 20c1.9.5 9.4.5 9.4.5s7.5 0 9.4-.6a3 3 0 0 0 2.1-2.1A31 31 0 0 0 24 12a31 31 0 0 0-.5-5.8zM9.7 15.5V8.5l6.3 3.5-6.3 3.5z');
  }
  svg.appendChild(path);
  return svg;
}

function nameToHue(name) {
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  return Math.abs(hash) % 360;
}

function normalizeUrl(url) {
  if (!url || typeof url !== 'string') return '';
  if (url.startsWith('//')) return 'https:' + url;
  return url;
}

function authorInitials(name) {
  const parts = String(name || '?').trim().split(' ').filter(Boolean);
  return (parts.length > 1 ? parts[0][0] + parts[parts.length - 1][0] : (parts[0] || '?').slice(0, 2)).toUpperCase();
}

function createFallbackAvatar(name) {
  const fallback = document.createElement('div');
  fallback.className = 'avatar-fallback';
  fallback.style.background = 'hsl(' + nameToHue(name || '??') + ', 60%, 40%)';
  fallback.textContent = authorInitials(name);
  return fallback;
}

const UI_STRINGS = {
  en: {
    owner: 'OWNER',
    moderator: 'MOD',
    member: 'MEMBER',
    subscriber: 'SUB',
    newSubscriber: 'New subscriber!',
    subscriptionUpdate: 'Subscription update',
    membershipUpdate: 'Membership update',
  },
  es: {
    owner: 'DUEÑO',
    moderator: 'MOD',
    member: 'MIEMBRO',
    subscriber: 'SUB',
    newSubscriber: '¡Nuevo suscriptor!',
    subscriptionUpdate: 'Actualización de suscripción',
    membershipUpdate: 'Actualización de membresía',
  },
};

function createAvatar(message) {
  const wrap = document.createElement('div');
  wrap.className = 'avatar-wrap';
  const url = normalizeUrl(message.authorAvatarUrl);
  if (url) {
    const image = document.createElement('img');
    image.src = url;
    image.alt = message.author || '';
    image.className = 'avatar';
    image.referrerPolicy = 'no-referrer';
    image.addEventListener('load', scheduleScrollToBottom);
    image.addEventListener('error', () => {
      image.replaceWith(createFallbackAvatar(message.author));
      scheduleScrollToBottom();
    }, { once: true });
    wrap.appendChild(image);
  } else {
    wrap.appendChild(createFallbackAvatar(message.author));
  }
  if (settings.showPlatformIcons) {
    const icon = document.createElement('div');
    icon.className = 'platform-overlay';
    icon.appendChild(platformIcon(message.platform));
    wrap.appendChild(icon);
  }
  return wrap;
}

function addBadge(row, className, label) {
  const badge = document.createElement('span');
  badge.className = 'badge ' + className;
  badge.textContent = label;
  row.appendChild(badge);
}

function appendMessageItems(container, items) {
  if (!Array.isArray(items)) return;
  for (const item of items) {
    if (item && item.kind === 'emoji' && item.url) {
      const image = document.createElement('img');
      image.src = normalizeUrl(item.url);
      image.alt = item.alt || '';
      image.className = 'emoji';
      image.referrerPolicy = 'no-referrer';
      image.addEventListener('load', scheduleScrollToBottom);
      image.addEventListener('error', () => {
        image.replaceWith(document.createTextNode(item.alt || item.text || ''));
        scheduleScrollToBottom();
      }, { once: true });
      container.appendChild(image);
    } else {
      const text = document.createElement('span');
      text.textContent = item && item.text ? item.text : '';
      container.appendChild(text);
    }
  }
}

function createMessageBubble(message, animate) {
  const strings = UI_STRINGS[settings.appLanguageCode] || UI_STRINGS.en;
  const isTwitch = message.platform === 'twitch';
  const isKick = message.platform === 'kick';
  const isSuperChat = !!message.isSuperChat;
  const isMembershipEvent = !!message.isMembershipEvent;

  let backgroundColor = settings.showBubble
    ? 'rgba(0, 0, 0, ' + settings.messageOpacity + ')'
    : 'transparent';

  if (isMembershipEvent) {
    backgroundColor = '#0F9D58';
  } else if (isTwitch && settings.twitchBubbleAccent && settings.showBubble) {
    backgroundColor = 'rgba(97, 25, 210, ' + settings.messageOpacity + ')';
  } else if (isKick && settings.kickBubbleAccent && settings.showBubble) {
    backgroundColor = 'rgba(30, 90, 10, ' + settings.messageOpacity + ')';
  }

  const bubble = document.createElement('div');
  bubble.className = 'chat-item';
  bubble.style.backgroundColor = backgroundColor;
  bubble.style.borderRadius = settings.borderRadius + 'px';
  bubble.style.border = settings.showBubble ? '1px solid rgba(255, 255, 255, 0.1)' : 'none';
  if (isSuperChat && settings.showBubble && settings.superChatBarEnabled) {
    bubble.style.borderBottom = settings.superChatBarWidth + 'px solid ' + settings.superChatBarColor;
  }
  bubble.style.padding = settings.showBubble ? '12px 18px' : '4px 0';
  bubble.style.boxShadow = settings.showBubble ? '0 8px 32px rgba(0, 0, 0, 0.3)' : 'none';
  bubble.style.animation = animate && settings.animation
    ? settings.animation + ' ' + settings.animationDuration + 's cubic-bezier(0.16, 1, 0.3, 1) both'
    : 'none';
  bubble.style.color = isSuperChat || isMembershipEvent ? '#FFFFFF' : 'inherit';
  bubble.style.gap = settings.showAvatars ? '14px' : '0';
  if (settings.showAvatars) bubble.appendChild(createAvatar(message));

  const content = document.createElement('div');
  content.className = 'chat-content';
  const authorRow = document.createElement('div');
  authorRow.className = 'author-row';
  if (settings.showPlatformIcons && !settings.showAvatars) {
    const icon = document.createElement('span');
    icon.style.display = 'inline-flex';
    icon.style.alignItems = 'center';
    icon.style.marginRight = '4px';
    icon.appendChild(platformIcon(message.platform));
    authorRow.appendChild(icon);
  }

  const author = document.createElement('span');
  author.className = 'author-name' + (message.isOwner ? ' owner' : '') + (message.isModerator ? ' mod' : '');
  if (message.color) author.style.color = message.color;
  author.textContent = message.author || '';
  authorRow.appendChild(author);

  if (settings.showBadges) {
    if (message.isOwner) addBadge(authorRow, 'owner-badge', strings.owner);
    if (message.isModerator) addBadge(authorRow, 'mod-badge', strings.moderator);
    if (message.isMembership && !isMembershipEvent) {
      const badgeClass = isTwitch ? 'twitch-sub-badge' : isKick ? 'kick-sub-badge' : 'member-badge';
      addBadge(authorRow, badgeClass, isTwitch || isKick ? strings.subscriber : strings.member);
    }
    if (isSuperChat && message.superChatAmount) addBadge(authorRow, 'superchat-badge', message.superChatAmount);
    const badgeUrl = normalizeUrl(message.badgeImageUrl);
    if (badgeUrl) {
      const customBadge = document.createElement('span');
      customBadge.className = 'badge custom-badge';
      customBadge.title = message.badgeLabel || '';
      const badgeImage = document.createElement('img');
      badgeImage.src = badgeUrl;
      badgeImage.alt = '';
      badgeImage.referrerPolicy = 'no-referrer';
      badgeImage.addEventListener('load', scheduleScrollToBottom);
      badgeImage.addEventListener('error', () => customBadge.remove(), { once: true });
      customBadge.appendChild(badgeImage);
      authorRow.appendChild(customBadge);
    }
  }

  if (settings.showTimestamp && message.timestamp) {
    const timestamp = document.createElement('span');
    timestamp.className = 'timestamp';
    const date = new Date(message.timestamp);
    timestamp.textContent = Number.isNaN(date.getTime()) ? '' : date.toLocaleTimeString(settings.appLanguageCode === 'es' ? 'es-MX' : 'en-US');
    authorRow.appendChild(timestamp);
  }
  content.appendChild(authorRow);

  const messageText = document.createElement('div');
  messageText.className = 'message-text';
  messageText.style.webkitTextStroke = settings.textStroke + 'px ' + settings.textStrokeColor;
  messageText.style.textShadow = settings.textShadow ? '2px 2px 4px rgba(0,0,0,0.8)' : 'none';
  messageText.style.fontWeight = String(settings.fontWeight);
  messageText.style.lineHeight = String(settings.lineHeight);
  messageText.style.textAlign = settings.textAlign;
  appendMessageItems(messageText, message.items);

  if (isMembershipEvent) {
    const flair = document.createElement('div');
    flair.className = 'membership-flair';
    const emphasis = document.createElement('em');
    emphasis.textContent = message.badgeLabel || (isTwitch ? strings.newSubscriber : isKick ? strings.subscriptionUpdate : strings.membershipUpdate);
    flair.appendChild(emphasis);
    messageText.appendChild(flair);
  }

  const stickerUrl = isSuperChat ? normalizeUrl(message.superChatStickerUrl) : '';
  if (stickerUrl) {
    const sticker = document.createElement('div');
    sticker.className = 'superchat-sticker';
    const image = document.createElement('img');
    image.src = stickerUrl;
    image.alt = '';
    image.referrerPolicy = 'no-referrer';
    image.addEventListener('load', scheduleScrollToBottom);
    image.addEventListener('error', () => sticker.remove(), { once: true });
    sticker.appendChild(image);
    messageText.appendChild(sticker);
  }

  content.appendChild(messageText);
  bubble.appendChild(content);
  return bubble;
}

const root = document.getElementById('root');
const shell = document.createElement('div');
shell.className = 'overlay-shell';
const chatOverlay = document.createElement('div');
chatOverlay.className = 'chat-overlay';
shell.appendChild(chatOverlay);
root.appendChild(shell);

let settings = { ...DEFAULT_SETTINGS };
let records = [];
let socket = null;
let retryTimer = 0;
let scrollTask = 0;
let pruneTimer = 0;
let shuttingDown = false;
const resizeObserver = typeof ResizeObserver === 'undefined'
  ? null
  : new ResizeObserver(scheduleScrollToBottom);

function forceScrollToBottom() {
  chatOverlay.scrollTop = chatOverlay.scrollHeight;
}

function scheduleScrollToBottom() {
  if (scrollTask) window.cancelAnimationFrame(scrollTask);
  scrollTask = window.requestAnimationFrame(() => {
    forceScrollToBottom();
    window.requestAnimationFrame(() => {
      forceScrollToBottom();
      window.setTimeout(forceScrollToBottom, 0);
    });
  });
}

function removeRecord(record) {
  if (resizeObserver && record.element) resizeObserver.unobserve(record.element);
  if (record.element) record.element.remove();
}

function pruneMessages() {
  let removed = false;
  const ttl = Number(settings.messageTtlSeconds);
  const cutoff = Date.now() - ttl * 1000;
  if (ttl > 0) {
    while (records.length && records[0].receivedAt < cutoff) {
      removeRecord(records.shift());
      removed = true;
    }
  }
  const limit = Math.max(10, Number(settings.maxMessages) || DEFAULT_SETTINGS.maxMessages);
  while (records.length > limit) {
    removeRecord(records.shift());
    removed = true;
  }
  if (removed) scheduleScrollToBottom();
}

function applyShellSettings() {
  document.documentElement.lang = settings.appLanguageCode || 'en';
  shell.className = 'overlay-shell' + (settings.hideScrollbar ? ' hide-scrollbar' : '');
  shell.style.backgroundColor = settings.chromaMode
    ? settings.chromaColor
    : 'rgba(0, 0, 0, ' + settings.bgOpacity + ')';
  const grid = !settings.chromaMode && settings.showGrid;
  shell.style.backgroundImage = grid
    ? 'linear-gradient(45deg, rgba(0, 0, 0, 0.1) 25%, transparent 25%), linear-gradient(-45deg, rgba(0, 0, 0, 0.1) 25%, transparent 25%), linear-gradient(45deg, transparent 75%, rgba(0, 0, 0, 0.1) 75%), linear-gradient(-45deg, transparent 75%, rgba(0, 0, 0, 0.1) 75%)'
    : 'none';
  shell.style.backgroundSize = grid ? '40px 40px' : '';
  shell.style.backgroundPosition = grid ? '0 0, 0 20px, 20px 20px, 20px 0' : '';
  shell.style.perspective = settings.threeDEnabled ? settings.perspective + 'px' : 'none';
  chatOverlay.style.fontSize = settings.fontSize + 'px';
  chatOverlay.style.gap = settings.messageGap + 'px';
  chatOverlay.style.padding = settings.threeDEnabled ? '4rem 4rem 6rem' : '3rem';
  chatOverlay.style.alignItems = settings.textAlign === 'center' ? 'center' : settings.textAlign === 'right' ? 'flex-end' : 'flex-start';
  chatOverlay.style.transform = settings.threeDEnabled
    ? 'rotateX(' + settings.rotateX + 'deg) rotateY(' + settings.rotateY + 'deg) rotateZ(' + settings.rotateZ + 'deg) skewX(' + settings.skewX + 'deg) scale(' + settings.scale + ')'
    : 'none';
  chatOverlay.style.transformStyle = 'preserve-3d';
}

function renderExistingMessages() {
  if (resizeObserver) resizeObserver.disconnect();
  const fragment = document.createDocumentFragment();
  for (const record of records) {
    record.element = createMessageBubble(record.message, false);
    fragment.appendChild(record.element);
    if (resizeObserver) resizeObserver.observe(record.element);
  }
  chatOverlay.replaceChildren(fragment);
}

function applySettings(next) {
  settings = { ...settings, ...next };
  applyShellSettings();
  pruneMessages();
  renderExistingMessages();
  scheduleScrollToBottom();
}

function addMessage(message) {
  const record = {
    message: message,
    receivedAt: Date.now(),
    element: createMessageBubble(message, true),
  };
  records.push(record);
  chatOverlay.appendChild(record.element);
  if (resizeObserver) resizeObserver.observe(record.element);
  pruneMessages();
  scheduleScrollToBottom();
}

function connect() {
  const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
  socket = new WebSocket(protocol + location.host + '/ws');
  socket.addEventListener('message', (event) => {
    try {
      const envelope = JSON.parse(event.data);
      if (envelope.type === 'settings') applySettings(envelope.data || {});
      else if (envelope.type === 'reload') window.location.reload();
      else if (envelope.type === 'message' && envelope.data) addMessage(envelope.data);
    } catch (_) {}
  });
  socket.addEventListener('close', () => {
    if (!shuttingDown) retryTimer = window.setTimeout(connect, 3000);
  });
  socket.addEventListener('error', () => socket.close());
}

applyShellSettings();
pruneTimer = window.setInterval(pruneMessages, 1000);
connect();
window.addEventListener('beforeunload', () => {
  shuttingDown = true;
  window.clearTimeout(retryTimer);
  window.clearInterval(pruneTimer);
  if (scrollTask) window.cancelAnimationFrame(scrollTask);
  if (resizeObserver) resizeObserver.disconnect();
  if (socket) socket.close();
});
</script>
</body>
</html>''';
}
