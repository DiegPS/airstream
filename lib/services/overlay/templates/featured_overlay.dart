import 'overlay_font.dart';

String featuredOverlayHtml({bool googleFontsAllowed = false}) => _featuredPage
    .replaceFirst('/* OVERLAY_FONT */', overlayFontScript(googleFontsAllowed));

const _featuredPage = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Airstream</title>
<style>
* { box-sizing: border-box; }
body { margin: 0; background: transparent; color: #fff;
  font-family: var(--overlay-font-family, "Segoe UI", sans-serif); }
#stage { display: flex; flex-direction: column; justify-content: flex-end;
  align-items: center; height: 100vh; padding: clamp(12px, 4vw, 48px);
  font-size: calc(clamp(20px, 4vw, 48px) * var(--featured-scale, 1)); }
.featured-card { --accent: #bad8ff; width: min(100%, 26em); max-height: 100%;
  overflow: hidden; background: #161922; border-top: 3px solid var(--accent);
  border-radius: 16px; padding: .65em .85em; box-shadow: 0 8px 24px #0007;
  animation: appear .2s ease-out; overflow-wrap: anywhere; }
@keyframes appear { from { opacity: 0; transform: translateY(6px); } }
@media (prefers-reduced-motion: reduce) { .featured-card { animation: none; } }
header { display: flex; align-items: center; gap: .45em; }
.identity { flex: 1; min-width: 0; }
.author { font-weight: 700; }
.platform { color: var(--accent); font-size: .55em; font-weight: 700; }
.avatar { width: 1.55em; height: 1.55em; flex: none; object-fit: cover; border-radius: 50%; }
.amount { color: var(--accent); font-size: .7em; font-weight: 700; max-width: 40%; }
.message { margin-top: .4em; line-height: 1.3; white-space: pre-wrap; }
.emote { height: 1.15em; width: auto; vertical-align: -.21em; }
.emote-stack { display: inline-grid; vertical-align: -.21em; }
.emote-stack > img { grid-area: 1 / 1; }
</style>
</head>
<body>
<main id="stage"></main>
<script>
/* OVERLAY_FONT */
const stage = document.getElementById('stage');
const platforms = {
  youtube: ['YouTube', '#ff9898'], twitch: ['Twitch', '#d4baff'], kick: ['Kick', '#a8f991'],
};
let seconds = 7;
let shownAt = 0;
let hideTimer = 0;
let socket = null;
let retryTimer = 0;
let shuttingDown = false;

function hideFeatured() {
  clearTimeout(hideTimer);
  stage.replaceChildren();
}

function scheduleHide() {
  clearTimeout(hideTimer);
  if (stage.firstElementChild && seconds > 0) {
    hideTimer = setTimeout(hideFeatured, Math.max(0, seconds * 1000 - (Date.now() - shownAt)));
  }
}

function applySettings(settings) {
  applyOverlayFont(settings);
  document.documentElement.lang = settings.appLanguageCode || 'en';
  stage.style.justifyContent = ({ top: 'flex-start', center: 'center' })[settings.featuredPosition] || 'flex-end';
  const scale = Number(settings.featuredFontScale ?? 100);
  stage.style.setProperty('--featured-scale', Math.min(200, Math.max(80, scale)) / 100);
  seconds = settings.featuredSeconds ?? 7;
  scheduleHide();
}

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

function picture(url, className, alt) {
  if (typeof url !== 'string' || !/^https?:\/\//i.test(url)) return null;
  const image = element('img', className);
  image.alt = alt;
  image.src = url;
  image.addEventListener('error', () => {
    if (alt) image.replaceWith(document.createTextNode(alt));
    else image.remove();
  }, { once: true });
  return image;
}

function renderFeatured(data, connection) {
  const [platform, accent] = platforms[data.platform] || ['', '#bad8ff'];
  const card = element('article', 'featured-card');
  card.style.setProperty('--accent', accent);
  const header = element('header');
  const avatar = picture(data.authorAvatarUrl, 'avatar', '');
  if (avatar) header.append(avatar);
  const identity = element('div', 'identity');
  identity.append(element('div', 'author', data.author));
  if (platform) identity.append(element('div', 'platform', platform));
  header.append(identity);
  if (data.amount) header.append(element('div', 'amount', data.amount));
  card.append(header);
  const message = element('div', 'message');
  if (Array.isArray(data.items) && data.items.length) {
    let stack = null;
    for (const item of data.items) {
      if (item.kind !== 'emoji') {
        message.append(document.createTextNode(item.text || ''));
        stack = null;
        continue;
      }
      const image = picture(item.url, 'emote', item.alt || '');
      if (!image) {
        message.append(document.createTextNode(item.alt || ''));
        stack = null;
        continue;
      }
      if (!item.isZeroWidth || !stack) {
        stack = element('span', 'emote-stack');
        message.append(stack);
      }
      stack.append(image);
    }
  } else {
    message.textContent = data.message || '';
  }
  if (message.hasChildNodes()) card.append(message);
  stage.replaceChildren(card);
  shownAt = Date.now();
  scheduleHide();
  requestAnimationFrame(() => requestAnimationFrame(() => {
    if (card.isConnected && data.deliveryId && connection === socket &&
        connection.readyState === WebSocket.OPEN) {
      connection.send(JSON.stringify({ type: 'featuredRendered', deliveryId: data.deliveryId }));
    }
  }));
}

function connect() {
  const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
  const connection = socket = new WebSocket(protocol + location.host + '/ws');
  connection.addEventListener('open', () => {
    connection.send(JSON.stringify({ type: 'register', view: 'featured' }));
  });
  connection.addEventListener('message', ({data}) => {
    try {
      const envelope = JSON.parse(data);
      if (envelope.type === 'settings') applySettings(envelope.data || {});
      else if (envelope.type === 'reload') location.reload();
      else if (envelope.type === 'featuredHide') hideFeatured();
      else if (envelope.type === 'alert' && envelope.data?.kind === 'featured') {
        renderFeatured(envelope.data, connection);
      }
    } catch (error) {
      console.warn('Ignored malformed featured message', error);
    }
  });
  connection.addEventListener('close', () => {
    hideFeatured();
    if (!shuttingDown) retryTimer = setTimeout(connect, 3000);
  });
  connection.addEventListener('error', () => connection.close());
}
connect();
window.addEventListener('beforeunload', () => {
  shuttingDown = true;
  clearTimeout(retryTimer);
  hideFeatured();
  socket?.close();
});
</script>
</body>
</html>''';
