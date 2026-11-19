import 'alert_moderation.dart';
import 'featured_source_activity.dart';
import 'overlay_font.dart';
import 'overlay_page_locale.dart';

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
    font-family: var(--overlay-font-family, 'Segoe UI', sans-serif);
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
  .featured-stage { display: none; }
  #root.has-pinned-featured {
    display: grid;
    grid-template-rows: repeat(2, minmax(0, 1fr));
  }
  .has-pinned-featured .alert-stage {
    padding: clamp(8px, 3vh, 24px) clamp(8px, 5vw, 48px);
    overflow: hidden;
  }
  .has-pinned-featured .featured-stage { display: flex; }
  .has-pinned-featured .featured-stage.above-alerts { grid-row: 1; }
  #root.featured-centered { grid-template-rows: repeat(3, minmax(0, 1fr)); }
  .featured-centered .featured-stage { grid-row: 2; }
  .featured-centered.alerts-below-featured .alert-stage:not(.featured-stage) { grid-row: 3; }
  .has-pinned-featured .alert-card {
    min-width: min(360px, 100%);
    max-height: 100%;
    overflow: auto;
  }
  .has-pinned-featured .alert-media { max-height: min(220px, 24vh); }
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
  .alert-card.stacked { flex-direction: column; text-align: center; }
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
  .alert-media { max-height: 220px; max-width: 100%; object-fit: contain; border-radius: 8px; }
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
  @keyframes alert-slide-up {
    from { opacity: 0; transform: translateY(40px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes alert-slide-down {
    from { opacity: 0; transform: translateY(-40px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes alert-fade {
    from { opacity: 0; } to { opacity: 1; }
  }
  @keyframes alert-zoom {
    from { opacity: 0; transform: scale(0.6); }
    to { opacity: 1; transform: scale(1); }
  }
</style>
</head>
<body>
<div id="root"></div>
<script>
$overlayFontScript
${overlayPageLocaleScript((l) => l.obsPageAlertsTitle)}
const DEFAULT_SETTINGS = {
  appLanguageCode: 'en',
  alertFontSize: 28,
  alertDisplaySeconds: 7,
  featuredSeconds: 7,
  featuredPosition: 'bottom',
  featuredFontScale: 100,
  alertShowAvatars: true,
  alertPosition: 'center',
  alertLayout: 'row',
  alertAnimation: 'pop',
  alertTypeOptions: {},
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
  if (alert.kind === 'featured') return '#FFC83D';
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
    fromChat: 'From chat',
    bits: 'Twitch Bits',
    subscription: 'Subscription',
    subscribed: 'subscribed',
    resubscribed: (months) => 'subscribed for ' + months + ' months',
    gift: 'Gift',
    gifted: 'gifted',
    subscriptionOne: 'a subscription',
    subscriptionMany: 'subscriptions',
    membershipOne: 'a membership',
    membershipMany: 'memberships',
    raid: 'Raid',
    host: 'Host',
    kicks: 'Kicks',
    raiding: 'is raiding',
    hosting: 'is hosting you',
    withViewers: (count) => ' with ' + count + (count === 1 ? ' viewer' : ' viewers'),
  },
  es: {
    someone: 'Alguien',
    sent: 'envió',
    superChat: 'un Super Chat',
    becameMember: 'se convirtió en miembro',
    membership: 'Membresía',
    fromChat: 'Del chat',
    bits: 'Twitch Bits',
    subscription: 'Suscripción',
    subscribed: 'se suscribió',
    resubscribed: (months) => 'cumple ' + months + ' meses de suscripción',
    gift: 'Regalo',
    gifted: 'regaló',
    subscriptionOne: 'una suscripción',
    subscriptionMany: 'suscripciones',
    membershipOne: 'una membresía',
    membershipMany: 'membresías',
    raid: 'Raid',
    host: 'Host',
    kicks: 'Kicks',
    raiding: 'llega de raid',
    hosting: 'comparte tu directo',
    withViewers: (count) => ' con ' + count + (count === 1 ? ' espectador' : ' espectadores'),
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

const ENTRANCES = {
  pop: 'alert-in', 'slide-up': 'alert-slide-up',
  'slide-down': 'alert-slide-down', fade: 'alert-fade', zoom: 'alert-zoom',
};

function typeOption(alert) {
  if (alert.kind === 'custom') return { seconds: alert.seconds, media: alert.media, mediaKind: alert.mediaKind };
  return alert.kind === 'featured' ? {} : alert.option || (settings.alertTypeOptions || {})[alert.alertType] || {};
}

function featuredText(alert, strings) {
  return {
    title: String(alert.author || strings.someone),
    kicker: platformLabel(alert.platform) + ' · ' + strings.fromChat,
  };
}

function alertLabels(alert, strings, author) {
  let title = alert.kind === 'superchat'
    ? author + ' ' + strings.sent + ' ' + (alert.amount || strings.superChat)
    : author + ' ' + strings.becameMember;
  let kicker = alert.kind === 'superchat'
    ? platformLabel(alert.platform) + ' Super Chat'
    : platformLabel(alert.platform) + ' ' + strings.membership;
  if (alert.kind === 'featured') {
    ({title, kicker} = featuredText(alert, strings));
  } else if (alert.kind === 'bits') {
    title = author + ' ' + strings.sent + ' ' + (alert.amount || '');
    kicker = strings.bits;
  } else if (alert.kind === 'raid' || alert.kind === 'host') {
    const raid = alert.kind === 'raid';
    title = author + ' ' + (raid ? strings.raiding : strings.hosting) +
      (alert.count == null ? '' : strings.withViewers(alert.count));
    kicker = platformLabel(alert.platform) + ' · ' + (raid ? strings.raid : strings.host);
  } else if (alert.kind === 'kicks') {
    title = author + ' ' + strings.sent + ' ' +
      (alert.count == null ? '' : alert.count + ' ') + strings.kicks;
    kicker = platformLabel(alert.platform) + ' · ' + strings.kicks;
  } else if (alert.kind === 'membership' && alert.membershipKind === 'gift') {
    const youtube = alert.platform === 'youtube';
    const count = Number(alert.giftCount) || 1;
    const giftText = count > 1
      ? count + ' ' + (youtube ? strings.membershipMany : strings.subscriptionMany)
      : (youtube ? strings.membershipOne : strings.subscriptionOne);
    title = author + ' ' + strings.gifted + ' ' + giftText;
    kicker = platformLabel(alert.platform) + ' · ' + strings.gift;
  } else if (alert.kind === 'membership' && alert.platform !== 'youtube' &&
      (alert.membershipKind === 'subscription' || alert.membershipKind === 'resubscription')) {
    title = author + ' ' + (alert.membershipKind === 'resubscription' && alert.months > 1
      ? strings.resubscribed(alert.months) : strings.subscribed);
    kicker = platformLabel(alert.platform) + ' · ' + strings.subscription;
  }
  if (alert.kind === 'custom') { title = String(alert.title || ''); kicker = ''; }
  return {title, kicker};
}

function renderAlert(alert, target = stage) {
  const strings = UI_STRINGS[settings.appLanguageCode] || UI_STRINGS.en;
  const accent = alertAccent(alert);
  const author = String(alert.author || strings.someone);
  const message = String(alert.message || '').trim();
  const {title, kicker} = alertLabels(alert, strings, author);
  const avatarUrl = normalizeUrl(alert.authorAvatarUrl);
  const stickerUrl = normalizeUrl(alert.stickerUrl);

  const card = document.createElement('div');
  card.className = 'alert-card' + (settings.alertLayout === 'stacked' ? ' stacked' : '');
  const entrance = typeOption(alert).animation || settings.alertAnimation;
  card.style.animationName = ENTRANCES[entrance] || ENTRANCES.pop;
  card.style.borderBottom = '5px solid ' + accent;

  if (settings.alertShowAvatars && alert.kind !== 'custom') {
    if (avatarUrl) {
      card.appendChild(createImage('alert-avatar', avatarUrl, author, (image) => {
        const fallback = document.createElement('div');
        fallback.className = 'alert-avatar alert-avatar-fallback';
        fallback.textContent = initials(image.alt);
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
  const option = typeOption(alert);
  if (option.media && ['image', 'video'].includes(option.mediaKind)) {
    const url = '/media/' + encodeURIComponent(option.media);
    const medium = option.mediaKind === 'image'
      ? createImage('alert-media', url, '') : document.createElement('video');
    if (option.mediaKind === 'video') {
      medium.className = 'alert-media';
      medium.autoplay = true;
      medium.playsInline = true;
      medium.muted = !option.mediaAudio;
      medium.preload = 'none';
      medium.src = url;
      medium.addEventListener('error', () => { releaseMedia(medium); medium.remove(); }, { once: true });
    }
    copy.appendChild(medium);
  }
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
  if (target === stage) clearMedia();
  target.replaceChildren(card);
}

const root = document.getElementById('root');
const stage = document.createElement('div');
stage.className = 'alert-stage';
root.appendChild(stage);
const featuredStage = document.createElement('div');
root.appendChild(featuredStage);
let settings = { ...DEFAULT_SETTINGS };
let queue = [];
let active = null;
let pinnedFeatured = null;
let pinnedShownAt = 0;
let pinnedHideTimer = 0;
let activeSound = null;
let paused = false;
let queueReady = false;
let lastQueueStatus = '';
let hideTimer = 0;
let featuredShownAt = 0;
let retryTimer = 0;
let socket = null;
$featuredSourceActivityScript
$alertModerationScript
let shuttingDown = false;
const acknowledgedFeatured = new WeakSet();

function applySettings(next) {
  applyOverlayFont(next);
  const previousFeaturedSeconds = settings.featuredSeconds;
  const previousLanguage = settings.appLanguageCode;
  settings = { ...settings, ...next };
  if (settings.featuredSeconds !== previousFeaturedSeconds) {
    if (active?.kind === 'featured') {
      if (featuredDuration() > 0) {
        scheduleFeaturedHide();
      } else {
        showPinnedFeatured(active, featuredShownAt);
        finishAlert();
      }
    } else if (pinnedFeatured) {
      schedulePinnedHide();
    }
  }
  if (settings.appLanguageCode !== previousLanguage) {
    const strings = UI_STRINGS[settings.appLanguageCode] || UI_STRINGS.en;
    if (pinnedFeatured) updateFeaturedLabels(pinnedFeatured, featuredStage, strings);
    if (active?.kind === 'featured') updateFeaturedLabels(active, stage, strings);
  }
  localizePage(settings.appLanguageCode || 'en');
  applyAlertStyle();
}

function updateFeaturedLabels(alert, target, strings) {
  const {title, kicker} = featuredText(alert, strings);
  target.querySelector('.alert-title').textContent = title;
  target.querySelector('.alert-kicker').textContent = kicker;
  const fallback = target.querySelector('.alert-avatar-fallback');
  if (fallback) fallback.textContent = initials(title);
  const avatar = target.querySelector('img.alert-avatar');
  if (avatar) avatar.alt = title;
}

function applyAlertStyle() {
  const align = position => ({top: 'flex-start', bottom: 'flex-end'})[position] || 'center';
  const fontSize = Number(settings.alertFontSize) || DEFAULT_SETTINGS.alertFontSize;
  const scale = Math.min(200, Math.max(80, Number(settings.featuredFontScale))) / 100;
  const timedFeature = active?.kind === 'featured';
  stage.style.fontSize = (timedFeature ? fontSize * scale : fontSize) + 'px';
  stage.style.alignItems = align(timedFeature ? settings.featuredPosition : settings.alertPosition);
  featuredStage.style.fontSize = fontSize * scale + 'px';
  featuredStage.style.alignItems = align(settings.featuredPosition);
  featuredStage.className = 'alert-stage featured-stage' +
    (settings.featuredPosition === 'top' ? ' above-alerts' : '');
  if (pinnedFeatured) {
    root.className = 'has-pinned-featured';
    if (settings.featuredPosition === 'center') {
      root.className += ' featured-centered';
      if (settings.alertPosition === 'bottom') root.className += ' alerts-below-featured';
    }
  }
}

const MAX_PENDING_ALERTS = 20;

function enqueueAlert(alert) {
  if (alert.kind === 'featured') {
    clearPinnedFeatured();
    queue = queue.filter(pending => pending.kind !== 'featured');
    if (queueReady && !(featuredDuration() > 0)) {
      showPinnedFeatured(alert);
      if (active?.kind === 'featured') finishAlert();
      return;
    }
    queue.unshift(alert);
    if (queue.length > MAX_PENDING_ALERTS) {
      const oldest = queue.findIndex((pending) => pending.kind !== 'featured');
      if (oldest !== -1) completeAlertDelivery(queue.splice(oldest, 1)[0], 'alertDiscarded');
    }
  } else {
    if (queue.length >= MAX_PENDING_ALERTS) {
      const oldest = queue.findIndex((pending) => pending.kind !== 'featured');
      if (oldest === -1) {
        completeAlertDelivery(alert, 'alertDiscarded');
        return;
      }
      completeAlertDelivery(queue.splice(oldest, 1)[0], 'alertDiscarded');
    }
    queue.push(alert);
  }
  if (alert.kind === 'featured' && active?.kind === 'featured') finishAlert();
  if (active) preloadNextImage();
}

function releaseMedia(media) {
  media.pause();
  media.removeAttribute('src');
  media.load();
}
function clearMedia() {
  stage.querySelectorAll('video').forEach(releaseMedia);
}
let preloadedId = '';
function preloadNextImage() {
  const option = queue.length ? typeOption(queue[0]) : {};
  const id = option.mediaKind === 'image' ? option.media || '' : '';
  if (id && id !== preloadedId) { const image = new Image(); image.src = '/media/' + encodeURIComponent(id); }
  preloadedId = id;
}
function reportQueue() {
  if (!queueReady || socket?.readyState !== WebSocket.OPEN) return;
  const status = JSON.stringify({
    type: 'alertQueue', paused, pending: queue.length, active: active !== null,
  });
  if (status !== lastQueueStatus) {
    socket.send(status);
    lastQueueStatus = status;
  }
}

function stopActiveSound() {
  if (activeSound) releaseMedia(activeSound);
  activeSound = null;
}

function finishAlert() {
  window.clearTimeout(hideTimer);
  hideTimer = 0;
  stopActiveSound();
  completeAlertDelivery(active, 'alertDiscarded');
  active = null;
  applyAlertStyle();
  clearMedia();
  stage.replaceChildren();
  showNext();
}

function controlQueue(op) {
  if (op === 'pause' || op === 'resume') {
    paused = op === 'pause';
    queueReady = true;
  } else if (op === 'skip' && active) {
    finishAlert();
    return;
  } else if (op === 'clear') {
    queue.forEach(alert => completeAlertDelivery(alert, 'alertDiscarded'));
    queue = [];
    preloadNextImage();
  }
  showNext();
}

function removeMatchingFeatured(matches) {
  queue = queue.filter(alert => alert.kind !== 'featured' || !matches(alert));
  if (pinnedFeatured && matches(pinnedFeatured)) clearPinnedFeatured();
  if (active?.kind === 'featured' && matches(active)) finishAlert();
  preloadNextImage();
  reportQueue();
}

function redactModeratedAlerts(moderation) {
  const matches = alert => matchesAlertModeration(alert, moderation);
  removeMatchingFeatured(matches);
  if (Number.isInteger(moderation.sequence)) return;
  for (const alert of queue) {
    if (alert.kind !== 'featured' && matches(alert)) alert.message = '';
  }
  if (active?.kind !== 'featured' && matches(active)) {
    active.message = '';
    stage.querySelector('.alert-message')?.remove();
  }
}

function applyAlertFilters(filters) {
  const {blocksAuthor, blocksText} = alertBlockMatcher(filters);
  for (const alert of [...queue, active]) {
    if (!alert || alert.kind === 'featured' || alert.kind === 'custom') continue;
    const hideAuthor = blocksAuthor(alert);
    if (!hideAuthor && !blocksText(alert)) continue;
    alert.message = '';
    if (hideAuthor) {
      Object.assign(alert, {author: '', authorChannelId: '', authorAvatarUrl: null,
        badgeLabel: null, badgeImageUrl: null});
    }
    if (alert !== active) continue;
    stage.querySelector('.alert-message')?.remove();
    if (hideAuthor) {
      const strings = UI_STRINGS[settings.appLanguageCode] || UI_STRINGS.en;
      stage.querySelector('.alert-title').textContent = alertLabels(alert, strings, strings.someone).title;
      const avatar = stage.querySelector('.alert-avatar');
      if (avatar) {
        const fallback = document.createElement('div');
        fallback.className = 'alert-avatar alert-avatar-fallback';
        fallback.textContent = initials(strings.someone);
        avatar.replaceWith(fallback);
      }
    }
  }
  removeMatchingFeatured(alert => blocksAuthor(alert) || blocksText(alert));
}

function hideFeatured() {
  queue = queue.filter(alert => alert.kind !== 'featured');
  clearPinnedFeatured();
  preloadNextImage();
  if (active?.kind === 'featured') finishAlert();
  else reportQueue();
}

function featuredDuration() {
  return Number(settings.featuredSeconds ?? DEFAULT_SETTINGS.featuredSeconds);
}

function clearPinnedFeatured() {
  if (!pinnedFeatured) return;
  window.clearTimeout(pinnedHideTimer);
  pinnedHideTimer = 0;
  pinnedFeatured = null;
  featuredStage.replaceChildren();
  root.className = '';
}

function schedulePinnedHide() {
  window.clearTimeout(pinnedHideTimer);
  const seconds = featuredDuration();
  pinnedHideTimer = seconds > 0 ? window.setTimeout(clearPinnedFeatured,
    Math.max(0, seconds * 1000 - (Date.now() - pinnedShownAt))) : 0;
}

function showPinnedFeatured(alert, shownAt = Date.now()) {
  pinnedFeatured = alert;
  pinnedShownAt = shownAt;
  applyAlertStyle();
  renderAlert(alert, featuredStage);
  schedulePinnedHide();
  acknowledgeFeatured(alert, featuredStage, () => pinnedFeatured);
}

function scheduleFeaturedHide() {
  window.clearTimeout(hideTimer);
  hideTimer = window.setTimeout(finishAlert,
    Math.max(0, featuredDuration() * 1000 - (Date.now() - featuredShownAt)));
}

function afterPaint(displayed, target, getDisplayed, acknowledge) {
  const connection = displayed.deliverySocket;
  // Confirm only after the card has reached a browser paint frame.
  requestAnimationFrame(() => requestAnimationFrame(() => {
    if (getDisplayed() === displayed &&
        connection === socket && connection.readyState === WebSocket.OPEN &&
        target.firstElementChild?.isConnected) {
      acknowledge();
    }
  }));
}

function acknowledgeFeatured(displayed, target, getDisplayed) {
  if (!displayed.deliveryId) return;
  afterPaint(displayed, target, getDisplayed, () => {
    if (!acknowledgedFeatured.has(displayed)) {
      const connection = displayed.deliverySocket;
      connection.send(JSON.stringify({
        type: 'featuredRendered', deliveryId: displayed.deliveryId,
      }));
      acknowledgedFeatured.add(displayed);
    }
  });
}

function completeAlertDelivery(alert, type) {
  if (!alert?.alertDeliveryId) return;
  const connection = alert.deliverySocket;
  if (connection === socket && connection.readyState === WebSocket.OPEN) {
    connection.send(JSON.stringify({type, deliveryId: alert.alertDeliveryId}));
    delete alert.alertDeliveryId;
  }
}

function showNext() {
  if (queueReady && queue[0]?.kind === 'featured' && !(featuredDuration() > 0)) {
    showPinnedFeatured(queue.shift());
    preloadNextImage();
  }
  // Pausing holds alerts, not a message the streamer just chose to feature
  // (featured cards always sit at the front of the queue).
  if (!queueReady || active || queue.length === 0 ||
      (paused && queue[0].kind !== 'featured')) {
    reportQueue();
    return;
  }
  active = queue.shift();
  applyAlertStyle();
  renderAlert(active);
  preloadNextImage();
  const sound = typeOption(active).sound;
  const volume = Number(settings.alertSoundVolume ?? 70);
  if (active.kind !== 'featured' && sound && volume > 0) {
    const url = ['chime', 'coin', 'fanfare'].includes(sound)
      ? '/sounds/' + sound + '.wav'
      : sound === 'custom'
        ? '/sounds/custom/' + encodeURIComponent(active.alertType) + (active.option ? '?tier=' : '?k=') + encodeURIComponent(typeOption(active).soundKey || '')
        : sound === 'library' && typeOption(active).soundMediaId
          ? '/media/' + encodeURIComponent(typeOption(active).soundMediaId) : null;
    if (url) {
      const audio = activeSound = new Audio(url);
      audio.volume = Math.min(100, volume) / 100;
      audio.play().catch(() => {});
    }
  }
  if (active.kind === 'featured') {
    acknowledgeFeatured(active, stage, () => active);
    featuredShownAt = Date.now();
    scheduleFeaturedHide();
  } else {
    const displayed = active;
    if (displayed.alertDeliveryId) {
      afterPaint(displayed, stage, () => active,
        () => completeAlertDelivery(displayed, 'alertRendered'));
    }
    const seconds = Math.max(1, Number(typeOption(active).seconds) || Number(settings.alertDisplaySeconds) || DEFAULT_SETTINGS.alertDisplaySeconds);
    const duration = active.kind !== 'custom' && queue.length >= 5
      ? Math.max(2, seconds / 2) : seconds;
    hideTimer = window.setTimeout(finishAlert, duration * 1000);
  }
  reportQueue();
}

function connect() {
  const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
  const connection = socket = new WebSocket(protocol + location.host + '/ws');
  queueReady = false;
  lastQueueStatus = '';
  connection.addEventListener('open', () => {
    registerSource(connection, 'alerts', {alertDisplayAck: true});
  });
  connection.addEventListener('message', (event) => {
    try {
      const envelope = JSON.parse(event.data);
      if (envelope.type === 'settings') applySettings(envelope.data || {});
      else if (envelope.type === 'reload') window.location.reload();
      else if (envelope.type === 'alertControl') controlQueue(envelope.op);
      else if (envelope.type === 'moderation' && envelope.data) redactModeratedAlerts(envelope.data);
      else if (envelope.type === 'filters' && envelope.data) applyAlertFilters(envelope.data);
      else if (envelope.type === 'featuredHide') hideFeatured();
      else if (envelope.type === 'alert' && envelope.data) {
        envelope.data.deliverySocket = connection;
        envelope.data.alertDeliveryId = envelope.alertDeliveryId;
        // A message the streamer chose goes before waiting alerts.
        enqueueAlert(envelope.data);
        showNext();
      }
    } catch (error) {
      console.warn('Ignored malformed alert message', error);
    }
  });
  connection.addEventListener('close', () => {
    if (socket !== connection) return;
    queueReady = false;
    queue = [];
    preloadedId = '';
    clearPinnedFeatured();
    finishAlert();
    if (!shuttingDown) retryTimer = window.setTimeout(connect, 3000);
  });
  connection.addEventListener('error', () => connection.close());
}

applySettings(DEFAULT_SETTINGS);
connect();
window.addEventListener('beforeunload', () => {
  shuttingDown = true;
  window.clearTimeout(hideTimer);
  window.clearTimeout(retryTimer);
  clearPinnedFeatured();
  stopActiveSound();
  clearMedia();
  if (socket) socket.close();
});
</script>
</body>
</html>''';
