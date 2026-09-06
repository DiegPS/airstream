String alertsOverlayHtml() => '''<!DOCTYPE html>
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
