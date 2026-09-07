String chatOverlayHtml() => '''<!DOCTYPE html>
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
  .author-name.vip { color: #FF69D4; }
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
  .vip-badge { background: #E919C2; color: #fff; }
  .verified-badge { background: #1D9BF0; color: #fff; }
  .youtube-stream-badge { background: #B3261E; color: #fff; }
  .member-badge { background: #0F9D58; color: #fff; }
  .twitch-sub-badge { background: #9146FF; color: #fff; }
  .kick-sub-badge { background: #53FC18; color: #111; }
  .superchat-badge { background: #FFD600; color: #111; }
  .generic-badge { background: #454545; color: #fff; }
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
  .reply-context {
    color: rgba(255,255,255,0.7);
    font-size: 0.78em;
    line-height: 1.25;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .provider-event {
    color: #fff;
    display: flex;
    align-items: center;
    gap: 8px;
    max-width: min(720px, 90%);
    padding: 8px 12px;
    border-radius: 10px;
    border: 1px solid rgba(255,255,255,0.16);
    background: rgba(0,0,0,0.42);
    font-size: 0.82em;
    overflow: hidden;
  }
  .provider-event-label { font-weight: 800; white-space: nowrap; }
  .provider-event-text {
    opacity: 0.82;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
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
  showYoutubeStreamBadges: true,
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
    verified: 'VERIFIED',
    member: 'MEMBER',
    subscriber: 'SUB',
    newSubscriber: 'New subscriber!',
    resubscribed: (months) => 'Resubscribed for ' + months + ' months',
    giftSubscription: 'Gift subscription',
    subscriptionUpdate: 'Subscription update',
    membershipUpdate: 'Membership update',
    sharedChat: 'SHARED',
    firstMessage: 'FIRST MESSAGE',
    returningChatter: 'RETURNING',
    reward: 'REWARD',
    events: {
      raid: 'Raid', unraid: 'Raid ended', pinnedMessage: 'Pinned message',
      unpinnedMessage: 'Message unpinned', poll: 'Poll', reward: 'Reward',
      host: 'Host', goal: 'Goal', notice: 'Notice',
      modiversary: 'Moderator anniversary', viewerMilestone: 'Viewer milestone',
      watchStreak: 'Watch streak',
      support: 'Support', sharedChat: 'Shared chat', roomState: 'Chat settings updated',
      streamOnline: 'Stream online', streamOffline: 'Stream offline',
      unknown: 'Event'
    },
  },
  es: {
    owner: 'DUEÑO',
    moderator: 'MOD',
    verified: 'VERIFICADO',
    member: 'MIEMBRO',
    subscriber: 'SUB',
    newSubscriber: '¡Nuevo suscriptor!',
    resubscribed: (months) => 'Se resuscribió por ' + months + ' meses',
    giftSubscription: 'Suscripción regalada',
    subscriptionUpdate: 'Actualización de suscripción',
    membershipUpdate: 'Actualización de membresía',
    sharedChat: 'COMPARTIDO',
    firstMessage: 'PRIMER MENSAJE',
    returningChatter: 'HA VUELTO',
    reward: 'RECOMPENSA',
    events: {
      raid: 'Raid', unraid: 'Raid finalizado', pinnedMessage: 'Mensaje fijado',
      unpinnedMessage: 'Mensaje desfijado', poll: 'Encuesta', reward: 'Recompensa',
      host: 'Alojamiento', goal: 'Meta', notice: 'Aviso',
      modiversary: 'Aniversario de moderador', viewerMilestone: 'Hito de audiencia',
      watchStreak: 'Racha de visualización',
      support: 'Apoyo', sharedChat: 'Chat compartido', roomState: 'Configuración del chat actualizada',
      streamOnline: 'Transmisión iniciada', streamOffline: 'Transmisión finalizada',
      unknown: 'Evento'
    },
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

function membershipEventLabel(message, strings, isTwitch, isKick) {
  if (message.membershipEventKind === 'subscription') return strings.newSubscriber;
  if (message.membershipEventKind === 'resubscription') return strings.resubscribed(message.membershipMonths || 0);
  if (message.membershipEventKind === 'gift') return strings.giftSubscription;
  return isTwitch ? strings.newSubscriber : isKick ? strings.subscriptionUpdate : strings.membershipUpdate;
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
  author.className = 'author-name' + (message.isOwner ? ' owner' : '') + (message.isModerator ? ' mod' : '') + (message.isVip ? ' vip' : '');
  if (message.color) author.style.color = message.color;
  author.textContent = message.author || '';
  authorRow.appendChild(author);

  if (settings.showBadges) {
    if (message.sharedSource) addBadge(authorRow, 'generic-badge', strings.sharedChat);
    if (message.isFirstMessage) addBadge(authorRow, 'generic-badge', strings.firstMessage);
    if (message.isReturningChatter) addBadge(authorRow, 'generic-badge', strings.returningChatter);
    if (message.rewardId) addBadge(authorRow, 'generic-badge', strings.reward);
    if (message.isOwner) addBadge(authorRow, 'owner-badge', strings.owner);
    if (message.isModerator) addBadge(authorRow, 'mod-badge', strings.moderator);
    if (message.isVip) addBadge(authorRow, 'vip-badge', 'VIP');
    if (message.isVerified) addBadge(authorRow, 'verified-badge', strings.verified);
    if (settings.showYoutubeStreamBadges && message.youtubeStreamOrientation) {
      const streamLabel = message.youtubeStreamOrientation === 'vertical'
        ? (settings.appLanguageCode === 'es' ? 'VERTICAL' : 'VERTICAL')
        : (settings.appLanguageCode === 'es' ? 'HORIZONTAL' : 'HORIZONTAL');
      addBadge(authorRow, 'youtube-stream-badge', streamLabel);
    }
    if (message.isMembership && !isMembershipEvent) {
      const badgeClass = isTwitch ? 'twitch-sub-badge' : isKick ? 'kick-sub-badge' : 'member-badge';
      addBadge(authorRow, badgeClass, isTwitch || isKick ? strings.subscriber : strings.member);
    }
    if (isSuperChat && message.superChatAmount) addBadge(authorRow, 'superchat-badge', message.superChatAmount);
    const builtInKinds = new Set(['broadcaster', 'owner', 'channel_owner', 'moderator', 'mod', 'vip', 'subscriber', 'sub', 'founder']);
    const badges = Array.isArray(message.badges) ? message.badges : [];
    for (const sourceBadge of badges) {
      const kind = String(sourceBadge.kind || '').toLowerCase();
      if (builtInKinds.has(kind)) continue;
      const badgeUrl = normalizeUrl(sourceBadge.imageUrl);
      if (!badgeUrl) {
        addBadge(authorRow, 'generic-badge', String(sourceBadge.label || kind).toUpperCase());
        continue;
      }
      const customBadge = document.createElement('span');
      customBadge.className = 'badge custom-badge';
      customBadge.title = sourceBadge.label || '';
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

  if (message.reply && (message.reply.authorName || message.reply.text)) {
    const reply = document.createElement('div');
    reply.className = 'reply-context';
    const replyAuthor = String(message.reply.authorName || '').trim();
    const replyText = String(message.reply.text || '').trim();
    reply.textContent = replyAuthor && replyText
      ? '↪ ' + replyAuthor + ': ' + replyText
      : '↪ ' + (replyAuthor || replyText);
    content.appendChild(reply);
  }

  const messageText = document.createElement('div');
  messageText.className = 'message-text';
  messageText.style.webkitTextStroke = settings.textStroke + 'px ' + settings.textStrokeColor;
  messageText.style.textShadow = settings.textShadow ? '2px 2px 4px rgba(0,0,0,0.8)' : 'none';
  messageText.style.fontWeight = String(settings.fontWeight);
  messageText.style.lineHeight = String(settings.lineHeight);
  messageText.style.textAlign = settings.textAlign;
  messageText.style.fontStyle = message.isAction ? 'italic' : 'normal';
  appendMessageItems(messageText, message.items);

  if (isMembershipEvent) {
    const flair = document.createElement('div');
    flair.className = 'membership-flair';
    const emphasis = document.createElement('em');
    emphasis.textContent = membershipEventLabel(message, strings, isTwitch, isKick);
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

function createProviderEventBubble(event) {
  const strings = UI_STRINGS[settings.appLanguageCode] || UI_STRINGS.en;
  const item = document.createElement('div');
  item.className = 'provider-event';
  const label = document.createElement('span');
  label.className = 'provider-event-label';
  label.textContent = (strings.events && strings.events[event.kind]) || strings.events.unknown;
  const detail = document.createElement('span');
  detail.className = 'provider-event-text';
  const parts = [event.authorName, event.text, event.count == null ? '' : String(event.count)].filter(Boolean);
  detail.textContent = parts.join(' · ');
  item.appendChild(platformIcon(event.platform));
  item.appendChild(label);
  if (detail.textContent) item.appendChild(detail);
  return item;
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
    record.element = record.event
      ? createProviderEventBubble(record.event)
      : createMessageBubble(record.message, false);
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

function addProviderEvent(event) {
  if (event.data && event.data.duplicatesMessage === true) return;
  const existing = records.findIndex((record) => record.event &&
    record.event.platform === event.platform && record.event.kind === event.kind &&
    record.event.id === event.id);
  if (existing >= 0) removeRecord(records.splice(existing, 1)[0]);
  const record = {
    event: event,
    receivedAt: Date.now(),
    element: createProviderEventBubble(event),
  };
  records.push(record);
  chatOverlay.appendChild(record.element);
  if (resizeObserver) resizeObserver.observe(record.element);
  pruneMessages();
  scheduleScrollToBottom();
}

function applyModeration(moderation) {
  const orientationMatches = (message) => !moderation.youtubeStreamOrientation ||
    message.youtubeStreamOrientation === moderation.youtubeStreamOrientation;
  const matches = (record) => {
    const message = record.message;
    if (!message || message.platform !== moderation.platform || !orientationMatches(message)) return false;
    if (moderation.scope === 'platform') return true;
    if (moderation.scope === 'message') return !!moderation.messageId && message.id === moderation.messageId;
    if (moderation.scope === 'author') return !!moderation.authorChannelId && message.authorChannelId === moderation.authorChannelId;
    return false;
  };
  const retained = [];
  for (const record of records) {
    if (matches(record)) removeRecord(record);
    else retained.push(record);
  }
  if (retained.length !== records.length) {
    records = retained;
    scheduleScrollToBottom();
  }
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
      else if (envelope.type === 'moderation' && envelope.data) applyModeration(envelope.data);
      else if (envelope.type === 'providerEvent' && envelope.data) addProviderEvent(envelope.data);
    } catch (error) {
      console.warn('Ignored malformed overlay message', error);
    }
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
