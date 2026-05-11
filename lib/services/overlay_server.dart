import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/settings/settings_model.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Serves the OBS overlay HTML page and broadcasts chat messages over WebSocket.
class OverlayServer {
  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  StreamSubscription? _msgSub;
  SettingsModel _settings = const SettingsModel();

  int _port = 8080;
  int get port => _port;

  String? _localIp;
  String? get localIp => _localIp;

  String get overlayUrl =>
      _localIp != null ? 'http://$_localIp:$_port' : 'http://localhost:$_port';

  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port = 8080,
  }) async {
    await stop();
    _settings = settings;
    _port = port;
    _localIp = await NetworkInfo().getWifiIP();

    final wsHandler = webSocketHandler((WebSocketChannel ws, _) {
      _clients.add(ws);
      _sendSettingsToClient(ws);
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
      _server =
          await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _port);
    }
    _msgSub = messages.listen(_broadcastMessage);
  }

  void setSettings(SettingsModel settings) {
    _settings = settings;
    _broadcastSettings();
  }

  bool reloadClients() {
    if (_clients.isEmpty) return false;
    _broadcastEnvelope({'type': 'reload'});
    return true;
  }

  Future<void> stop() async {
    await _msgSub?.cancel();
    _msgSub = null;
    await _server?.close(force: true);
    _server = null;
    _clients.clear();
  }

  void _broadcastMessage(ChatMessage msg) {
    _broadcastEnvelope({
      'type': 'message',
      'data': {
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
        'isOwner': msg.isOwner,
        'isModerator': msg.isModerator,
        'isVerified': msg.isVerified,
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
      }
    }
  }

  Map<String, dynamic> _overlaySettingsPayload() => {
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
      };

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
    overflow: hidden;
    height: 100vh;
    font-family: 'Segoe UI', sans-serif;
  }
  #root { height: 100%; }
  .overlay-shell {
    flex: 1;
    position: relative;
    overflow: hidden;
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
    padding: 3rem;
    display: flex;
    flex-direction: column;
    gap: 15px;
    scrollbar-width: thin;
    -ms-overflow-style: auto;
    mask-image: linear-gradient(to bottom, transparent 0%, black 8%);
  }
  .overlay-empty {
    color: rgba(255,255,255,0.75);
    font-size: 13px;
    align-self: flex-start;
    padding: 10px 12px;
    border-radius: 8px;
    background: rgba(0, 0, 0, 0.22);
    border: 1px dashed rgba(255, 255, 255, 0.08);
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
<script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
<script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
<script type="text/babel">
const { useEffect, useMemo, useRef, useState } = React;

const DEFAULT_SETTINGS = {
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

function clampMessages(messages, maxMessages) {
  return messages.slice(-Math.max(10, maxMessages || DEFAULT_SETTINGS.maxMessages));
}

function platformLabel(platform) {
  switch (platform) {
    case 'youtube': return 'YT';
    case 'twitch': return 'TW';
    default: return 'KK';
  }
}

function platformIcon(platform) {
  if (platform === 'twitch') {
    return (
      <svg width="12" height="12" viewBox="0 0 24 24" fill="#9146FF" style={{ flexShrink: 0 }}>
        <path d="M11.6 6H13v4.5h-1.4V6zm3.8 0h1.4v4.5h-1.4V6zM4 0L.5 3.5V20.5H6V24l3.5-3.5H12L23.5 9V0H4zm18 8.5L18.5 12H16l-3 3v-3H9.5v-8H22v4.5z" />
      </svg>
    );
  }
  if (platform === 'kick') {
    return (
      <svg width="12" height="12" viewBox="0 0 512 512" fill="#53FC18" style={{ flexShrink: 0 }}>
        <path d="M37 .036h164.448v113.621h54.71v-56.82h54.731V.036h164.448v170.777h-54.73v56.82h-54.711v56.8h54.71v56.82h54.73V512.03H310.89v-56.82h-54.73v-56.8h-54.711v113.62H37V.036z" />
      </svg>
    );
  }
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="#FF0000" style={{ flexShrink: 0 }}>
      <path d="M23.5 6.2a3 3 0 0 0-2.1-2.1C19.5 3.5 12 3.5 12 3.5s-7.5 0-9.4.6A3 3 0 0 0 .5 6.2 31 31 0 0 0 0 12a31 31 0 0 0 .5 5.8A3 3 0 0 0 2.6 20c1.9.5 9.4.5 9.4.5s7.5 0 9.4-.6a3 3 0 0 0 2.1-2.1A31 31 0 0 0 24 12a31 31 0 0 0-.5-5.8zM9.7 15.5V8.5l6.3 3.5-6.3 3.5z" />
    </svg>
  );
}

function nameToHue(name) {
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  return Math.abs(hash) % 360;
}

function Avatar({ url, name, platform, showPlatformIcons }) {
  const hue = nameToHue(name || '??');
  const initials = (name || '?').slice(0, 2).toUpperCase();

  return (
    <div className="avatar-wrap">
      {url ? (
        <img src={url} alt={name} className="avatar" />
      ) : (
        <div
          className="avatar-fallback"
          style={{ background: `hsl(\${hue}, 60%, 40%)` }}
        >
          {initials}
        </div>
      )}
      {showPlatformIcons ? (
        <div className="platform-overlay">{platformIcon(platform)}</div>
      ) : null}
    </div>
  );
}

function renderMessageItems(items) {
  if (!Array.isArray(items)) return null;
  return items.map((item, index) => {
    if (item.kind === 'emoji' && item.url) {
      return (
        <img
          key={index}
          src={item.url}
          alt={item.alt || ''}
          className="emoji"
        />
      );
    }
    return <span key={index}>{item.text || ''}</span>;
  });
}

function MessageBubble({ message, settings, index }) {
  const isTwitch = message.platform === 'twitch';
  const isKick = message.platform === 'kick';
  const isSuperChat = !!message.isSuperChat;
  const isMembershipEvent = message.isMembership && (!message.items || message.items.length === 0);

  let backgroundColor = settings.showBubble
    ? `rgba(0, 0, 0, \${settings.messageOpacity})`
    : 'transparent';

  if (isMembershipEvent) {
    backgroundColor = '#0F9D58';
  } else if (isTwitch && settings.twitchBubbleAccent && settings.showBubble) {
    backgroundColor = `rgba(97, 25, 210, \${settings.messageOpacity})`;
  } else if (isKick && settings.kickBubbleAccent && settings.showBubble) {
    backgroundColor = `rgba(30, 90, 10, \${settings.messageOpacity})`;
  }

  const defaultBorder = settings.showBubble
    ? '1px solid rgba(255, 255, 255, 0.1)'
    : 'none';
  const superChatBorder = isSuperChat && settings.showBubble && settings.superChatBarEnabled
    ? `\${settings.superChatBarWidth}px solid \${settings.superChatBarColor}`
    : null;

  return (
    <div
      className="chat-item"
      style={{
        backgroundColor,
        borderRadius: `\${settings.borderRadius}px`,
        border: defaultBorder,
        ...(superChatBorder ? { borderBottom: superChatBorder } : {}),
        padding: settings.showBubble ? '12px 18px' : '4px 0',
        boxShadow: settings.showBubble ? '0 8px 32px rgba(0, 0, 0, 0.3)' : 'none',
        animation: settings.animation
          ? `\${settings.animation} \${settings.animationDuration}s cubic-bezier(0.16, 1, 0.3, 1) both`
          : 'none',
        color: (isSuperChat || isMembershipEvent) ? '#FFFFFF' : 'inherit',
        gap: settings.showAvatars ? '14px' : '0',
      }}
    >
      {settings.showAvatars ? (
        <Avatar
          url={message.authorAvatarUrl}
          name={message.author}
          platform={message.platform}
          showPlatformIcons={settings.showPlatformIcons}
        />
      ) : null}
      <div className="chat-content">
        <div className="author-row">
          {settings.showPlatformIcons && !settings.showAvatars ? (
            <span style={{ display: 'inline-flex', alignItems: 'center', marginRight: '4px' }}>
              {platformIcon(message.platform)}
            </span>
          ) : null}
          <span
            className={`author-name \${message.isOwner ? 'owner' : ''} \${message.isModerator ? 'mod' : ''}`}
            style={{ color: message.color || undefined }}
          >
            {message.author}
          </span>
          {settings.showBadges ? (
            <>
              {message.isOwner ? <span className="badge owner-badge">OWNER</span> : null}
              {message.isModerator ? <span className="badge mod-badge">MOD</span> : null}
              {message.isMembership && !isMembershipEvent ? (
                <span className={`badge \${isTwitch ? 'twitch-sub-badge' : isKick ? 'kick-sub-badge' : 'member-badge'}`}>
                  {isTwitch || isKick ? 'SUB' : 'MEMBER'}
                </span>
              ) : null}
              {isSuperChat && message.superChatAmount ? (
                <span className="badge superchat-badge">{message.superChatAmount}</span>
              ) : null}
              {message.badgeImageUrl ? (
                <span className="badge custom-badge" title={message.badgeLabel || ''}>
                  <img src={message.badgeImageUrl} alt="" />
                </span>
              ) : null}
            </>
          ) : null}
          {settings.showTimestamp ? (
            <span className="timestamp">
              {message.timestamp ? new Date(message.timestamp).toLocaleTimeString() : ''}
            </span>
          ) : null}
        </div>

        <div
          className="message-text"
          style={{
            WebkitTextStroke: `\${settings.textStroke}px \${settings.textStrokeColor}`,
            textShadow: settings.textShadow ? '2px 2px 4px rgba(0,0,0,0.8)' : 'none',
            fontWeight: settings.fontWeight,
            lineHeight: settings.lineHeight,
            textAlign: settings.textAlign,
          }}
        >
          {renderMessageItems(message.items)}

          {isMembershipEvent ? (
            <div className="membership-flair">
              <em>{message.badgeLabel || (isTwitch ? 'New Subscriber!' : isKick ? 'Subscription Update' : 'Membership Update')}</em>
            </div>
          ) : null}

          {isSuperChat && message.superChatStickerUrl ? (
            <div className="superchat-sticker">
              <img src={message.superChatStickerUrl} alt="" />
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function OverlayApp() {
  const [messages, setMessages] = useState([]);
  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const scrollToBottomRef = useRef(null);

  useEffect(() => {
    setMessages((current) => clampMessages(current, settings.maxMessages));
  }, [settings.maxMessages]);

  useEffect(() => {
    const node = scrollToBottomRef.current;
    if (!node) return;
    const frame = window.requestAnimationFrame(() => {
      node.scrollIntoView({ behavior: 'smooth', block: 'end' });
    });
    return () => window.cancelAnimationFrame(frame);
  }, [messages, settings.messageGap, settings.fontSize, settings.showBubble]);

  useEffect(() => {
    let ws;
    let retry;

    const connect = () => {
      const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
      ws = new WebSocket(protocol + location.host + '/ws');

      ws.onmessage = (event) => {
        try {
          const envelope = JSON.parse(event.data);
          if (envelope.type === 'settings') {
            setSettings((current) => ({ ...current, ...envelope.data }));
            return;
          }
          if (envelope.type === 'reload') {
            window.location.reload();
            return;
          }
          if (envelope.type === 'message') {
            setMessages((current) =>
              clampMessages([...current, envelope.data], settings.maxMessages)
            );
          }
        } catch (_) {}
      };

      ws.onclose = () => {
        retry = window.setTimeout(connect, 3000);
      };
    };

    connect();

    return () => {
      if (retry) window.clearTimeout(retry);
      if (ws) ws.close();
    };
  }, [settings.maxMessages]);

  const shellStyle = useMemo(() => ({
    backgroundColor: settings.chromaMode
      ? settings.chromaColor
      : `rgba(0, 0, 0, \${settings.bgOpacity})`,
    backgroundImage: (!settings.chromaMode && settings.showGrid)
      ? `
        linear-gradient(45deg, rgba(0, 0, 0, 0.1) 25%, transparent 25%),
        linear-gradient(-45deg, rgba(0, 0, 0, 0.1) 25%, transparent 25%),
        linear-gradient(45deg, transparent 75%, rgba(0, 0, 0, 0.1) 75%),
        linear-gradient(-45deg, transparent 75%, rgba(0, 0, 0, 0.1) 75%)
      `
      : 'none',
    backgroundSize: (!settings.chromaMode && settings.showGrid)
      ? '40px 40px'
      : undefined,
    backgroundPosition: (!settings.chromaMode && settings.showGrid)
      ? '0 0, 0 20px, 20px 20px, 20px 0'
      : undefined,
    perspective: settings.threeDEnabled
      ? `\${settings.perspective}px`
      : 'none',
  }), [
    settings.bgOpacity,
    settings.chromaMode,
    settings.chromaColor,
    settings.showGrid,
    settings.threeDEnabled,
    settings.perspective,
  ]);

  const shellClassName = useMemo(
    () => `overlay-shell \${settings.hideScrollbar ? 'hide-scrollbar' : ''}`,
    [settings.hideScrollbar],
  );

  const overlayStyle = useMemo(() => ({
    fontSize: `\${settings.fontSize}px`,
    gap: `\${settings.messageGap}px`,
    alignItems: settings.textAlign === 'center'
      ? 'center'
      : settings.textAlign === 'right'
        ? 'flex-end'
        : 'flex-start',
    transform: settings.threeDEnabled
      ? `
        rotateX(\${settings.rotateX}deg)
        rotateY(\${settings.rotateY}deg)
        rotateZ(\${settings.rotateZ}deg)
        skewX(\${settings.skewX}deg)
        scale(\${settings.scale})
      `
      : 'none',
    transformStyle: 'preserve-3d',
  }), [
    settings.fontSize,
    settings.messageGap,
    settings.textAlign,
    settings.threeDEnabled,
    settings.rotateX,
    settings.rotateY,
    settings.rotateZ,
    settings.skewX,
    settings.scale,
  ]);

  if (!messages.length) {
    return (
      <div className={shellClassName} style={shellStyle}>
        <div className="chat-overlay" style={overlayStyle}>
          <div className="overlay-empty">Waiting for new chat messages...</div>
        </div>
      </div>
    );
  }

  return (
    <div className={shellClassName} style={shellStyle}>
      <div className="chat-overlay" style={overlayStyle}>
        {messages.map((message, index) => (
          <MessageBubble
            key={message.id ? message.id + '-' + index : index}
            message={message}
            settings={settings}
            index={index}
          />
        ))}
        <div ref={scrollToBottomRef} />
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<OverlayApp />);
</script>
</body>
</html>''';
}
