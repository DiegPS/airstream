import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

String widgetCopy(Map<String, String> Function(AppLocalizations) strings) =>
    jsonEncode({
      for (final language in ['en', 'es'])
        language: strings(lookupAppLocalizations(Locale(language))),
    });

List<Map<String, Object?>> galleryFields(AppLocalizations l) => [
      {
        'key': 'theme',
        'label': l.galleryTheme,
        'type': 'select',
        'options': ['neon', 'minimal', 'warm'],
        'default': 'neon',
      },
      {
        'key': 'font',
        'label': l.galleryFont,
        'type': 'select',
        'options': ['system', 'DM Sans', 'Barlow', 'Outfit'],
        'default': 'system',
      },
      {
        'key': 'accent',
        'label': l.galleryAccent,
        'type': 'color',
        'default': '#bee863',
      },
      {
        'key': 'logo',
        'label': l.galleryLogo,
        'type': 'media',
        'kind': 'image',
        'default': '',
      },
      {
        'key': 'language',
        'label': l.galleryLanguage,
        'type': 'select',
        'options': ['en', 'es'],
        'default': l.localeName,
      },
    ];

const galleryCss = r'''
:root {
  --surface: #151b25;
  --row: #202937;
  --line: #354353;
  --ink: #f5f8fd;
  --muted: #bac7d7;
  --radius: 16px;
  --shadow: 0 10px 24px #070a13a8;
  --theme-accent: #bee863;
  --font: system-ui;
  font: 16px/1.3 var(--font), system-ui, sans-serif;
  color: var(--ink);
}
:root[data-theme="minimal"] {
  --surface: #f8f8fa;
  --row: #edecf1;
  --line: #c9c7d3;
  --ink: #211e2a;
  --muted: #514b60;
  --radius: 12px;
  --shadow: 0 4px 14px #17112329;
  --theme-accent: #59449d;
}
:root[data-theme="warm"] {
  --surface: #362820;
  --row: #47362a;
  --line: #715743;
  --ink: #fff5ea;
  --muted: #e9cdb9;
  --radius: 16px;
  --shadow: 0 9px 20px #26170fad;
  --theme-accent: #ffaf76;
}
:root[data-theme="neon"] {
  --glow: color-mix(in srgb, var(--custom-accent, var(--theme-accent)) 38%, transparent);
}
:root[data-theme="neon"] h1 {
  text-shadow: 0 2px 26px var(--glow);
}
* { box-sizing: border-box; }
body { margin: 0; background: transparent; }
[hidden] { display: none !important; }
.gallery-logo { flex: 0 0 40px; height: 40px; }
.gallery-logo img { display: block; width: 100%; height: 100%; object-fit: contain; }
.corner-logo { position: absolute; top: 16px; left: 16px; width: 56px; height: 56px; z-index: 2; }
::selection { color: var(--surface); background: var(--theme-accent); }
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation: none !important; transition: none !important; }
}
''';

List<Map<String, Object?>> screenFields(AppLocalizations l) => [
      {
        'key': 'background',
        'label': l.galleryBackground,
        'type': 'select',
        'options': ['theme', 'transparent', 'media'],
        'default': 'theme',
      },
      {
        'key': 'backgroundMedia',
        'label': l.galleryBackgroundMedia,
        'type': 'media',
        'kind': 'visual',
        'default': '',
      },
      screenTextField('messages', l.galleryMessages, 500),
    ];

Map<String, Object?> screenTextField(
  String key,
  String label,
  int maxLength, [
  String value = '',
]) =>
    {
      'key': key,
      'label': label,
      'type': 'text',
      'maxLength': maxLength,
      'default': value,
    };

Map<String, Object?> screenToggle(String key, String label, bool value) => {
      'key': key,
      'label': label,
      'type': 'boolean',
      'default': value,
    };

Map<String, Object?> screenNumber(
  String key,
  String label,
  int min,
  int max,
  int value,
) =>
    {
      'key': key,
      'label': label,
      'type': 'number',
      'min': min,
      'max': max,
      'step': 1,
      'default': value,
    };

const screenChat = '''
<aside id="chat" class="screen-chat" aria-labelledby="chat-heading" hidden>
  <h2 id="chat-heading"></h2>
  <ol id="chat-messages"></ol>
</aside>
''';

Map<String, String> screenFiles(
  String kind,
  String body,
  String script, {
  String css = '',
}) =>
    {
      'index.html': '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="style.css">
  <script defer src="script.js"></script>
</head>
<body>
  <main id="stage" class="screen-$kind" hidden>
    <div id="background-media" aria-hidden="true"></div>
    <div class="screen-frame" aria-hidden="true"></div>
    <div class="gallery-logo" hidden></div>
    $body
    <div id="messages" hidden><p></p><p></p></div>
  </main>
</body>
</html>
''',
      'style.css': '$galleryCss\n$_screenCss\n$css',
      'script.js': '(() => {\n"use strict";\n$galleryScript\n'
          '$gallerySupportTypes\n$galleryDomScript\n$galleryRankingScript\n'
          '$_screenScript\n$script\n})();',
    };

const _screenCss = r'''
html, body { width: 100%; height: 100%; overflow: hidden; }
#stage {
  --accent: var(--custom-accent, var(--theme-accent));
  --panel: var(--surface);
  --wash: color-mix(in srgb, var(--row) 55%, var(--surface));
  --orbit: color-mix(in srgb, var(--accent) 22%, transparent);
  position: absolute; top: 50%; left: 50%;
  width: 1920px; height: 1080px;
  transform: translate(-50%, -50%) scale(var(--stage-scale, 1));
  overflow: hidden; isolation: isolate;
  background: var(--surface);
}
#stage::before {
  content: ''; position: absolute; inset: -12%; z-index: -2;
  background:
    radial-gradient(ellipse at 73% 14%, var(--orbit), transparent 51%),
    radial-gradient(ellipse at 2% 85%, color-mix(in srgb, var(--accent) 10%, transparent), transparent 45%),
    linear-gradient(140deg, var(--surface) 15%, var(--wash) 85%);
  animation: screen-drift 40s ease-in-out infinite alternate;
}
@keyframes screen-drift { to { transform: translate(-4%, 3%) rotate(-5deg) scale(1.06); } }
#stage[data-background="transparent"] { background: transparent; }
#stage[data-background="transparent"]::before,
#stage[data-background="media"]::before { display: none; }
#background-media { position: absolute; inset: 0; z-index: -2; }
#background-media > * { display: block; width: 100%; height: 100%; object-fit: cover; }
#stage[data-background="media"] .screen-frame { border-color: var(--accent); }
.screen-frame {
  position: absolute; inset: 38px; z-index: -1; pointer-events: none;
  border: 1px solid var(--line); border-radius: 28px;
}
.screen-frame::before, .screen-frame::after {
  content: ''; position: absolute; width: 108px; height: 58px;
  border: 2px solid var(--accent);
}
.screen-frame::before { top: -1px; left: -1px; border-right: 0; border-bottom: 0; border-radius: 28px 0 0; }
.screen-frame::after { bottom: -1px; right: -1px; border-top: 0; border-left: 0; border-radius: 0 0 28px; }
:root[data-theme="neon"] .screen-frame { box-shadow: inset 0 0 25px var(--glow), 0 7px 40px #070a133d; }
:root[data-theme="minimal"] .screen-frame { border-radius: 4px; }
:root[data-theme="minimal"] .screen-frame::before,
:root[data-theme="minimal"] .screen-frame::after { border-radius: 4px; }
#stage > .gallery-logo {
  position: absolute; z-index: 1; top: 79px; left: 88px;
  width: 172px; height: 82px; padding: 8px 12px;
  background: var(--panel); border: 1px solid var(--line);
  border-radius: var(--radius);
}
#stage > .gallery-logo img { object-position: center; }
.screen-content { position: absolute; inset: 185px 88px 186px; }
.screen-break { display: grid; gap: 50px; align-items: center; }
.screen-break:has(.screen-chat:not([hidden])) { grid-template-columns: minmax(0, 1fr) 510px; }
.screen-hero {
  min-width: 0; justify-self: center; width: min(100%, 1210px);
  padding: 32px 52px 42px; text-align: center;
}
.screen-hero::before {
  content: ''; display: block; width: 110px; height: 4px; margin: 0 auto 34px;
  border-radius: 2px; background: var(--accent);
  box-shadow: 0 0 25px var(--glow, transparent);
}
.screen-break:has(.screen-chat:not([hidden])) .screen-hero { text-align: start; padding-inline: 40px; }
.screen-break:has(.screen-chat:not([hidden])) .screen-hero::before { margin-inline: 0; }
#stage[data-background="media"] .screen-hero,
#stage[data-background="transparent"] .screen-hero {
  background: var(--panel); border-radius: var(--radius);
}
.screen-title {
  margin: 0; font-size: 112px; line-height: 1.02; letter-spacing: -.04em;
  font-weight: 700; text-wrap: balance; overflow-wrap: anywhere;
  display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 3;
  overflow: hidden; padding-bottom: .08em;
}
.screen-subtitle {
  margin: 22px 0 0; color: var(--muted); font-size: 33px;
  overflow-wrap: anywhere; display: -webkit-box; -webkit-box-orient: vertical;
  -webkit-line-clamp: 2; overflow: hidden;
}
.screen-countdown {
  margin: 28px 0 0; font-size: 70px; line-height: 1.14;
  font-variant-numeric: tabular-nums; font-weight: 600; letter-spacing: -.03em;
}
.screen-countdown[data-complete="true"] { font-size: 46px; }
.screen-chat {
  width: 100%; height: 590px; padding: 24px 28px;
  background: var(--panel); border: 1px solid var(--line);
  border-radius: var(--radius); overflow: hidden;
}
.screen-chat h2 { margin: 0 0 12px; font-size: 26px; padding-bottom: 13px; border-bottom: 1px solid var(--line); }
#chat-messages { display: grid; gap: 6px; list-style: none; padding: 0; margin: 0; }
.screen-chat li {
  height: 75px; padding: 8px 11px 8px 16px; min-width: 0; overflow: hidden;
  background: var(--row); border-radius: 8px;
  font-size: 21px; line-height: 1.2;
}
.chat-author { display: flex; align-items: center; gap: 9px; font-weight: 700; }
.screen-name { display: block; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.platform-dot { flex: none; display: inline-block; width: 9px; height: 9px; border-radius: 50%; background: var(--platform); }
.chat-author .screen-name { color: var(--author, var(--ink)); }
.chat-text {
  margin: 3px 0 0; overflow: hidden; overflow-wrap: anywhere;
  display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2;
}
.airstream-emote { height: 1.12em; max-width: 3em; object-fit: contain; vertical-align: -.18em; }
.chat-enter { animation: screen-chat-in .23s cubic-bezier(.16, 1, .3, 1) both; }
@keyframes screen-chat-in { from { opacity: 0; transform: translateY(8px); } }
#messages {
  position: absolute; inset: auto 88px 79px; min-height: 64px;
  display: grid; grid-template-columns: minmax(0, 1fr); place-items: center;
  border-top: 1px solid var(--line); background: var(--panel); border-radius: 0 0 var(--radius) var(--radius);
}
#messages p {
  grid-area: 1 / 1; margin: 13px 36px; min-width: 0; max-width: calc(100% - 72px);
  overflow: hidden; white-space: nowrap; text-overflow: ellipsis;
  font-size: 27px; color: var(--muted); opacity: 0;
  transition: opacity .4s ease;
}
#messages p.active { opacity: 1; }
''';

const gallerySupportTypes = r'''
const supportTypes = ['superchat', 'membership', 'bits', 'subscription', 'gift', 'raid', 'kicks'];
''';

const gallerySupportDescriptions = r'''
const supportDescriptions = {
  en: {
    superchat: s => ['Super Chat', s.amount].filter(Boolean).join(' '),
    membership: s => s.months ? n(s.months) + '-month member' : 'New member',
    bits: s => s.amount || (s.value == null ? 'Bits' : n(s.value) + ' Bits'),
    subscription: s => s.months ? n(s.months) + (s.months === 1 ? ' month' : ' months') + ' subscribed' : 'New subscription',
    // YouTube gifts memberships; Kick hosts rather than raids.
    gift: s => 'Gifted ' + n(s.count ?? 1) + (s.platform === 'youtube'
      ? ((s.count ?? 1) === 1 ? ' membership' : ' memberships')
      : ((s.count ?? 1) === 1 ? ' sub' : ' subs')),
    raid: s => {
      const label = s.platform === 'kick' ? 'Host' : 'Raid';
      return s.count == null ? label : label + ' with ' + n(s.count) + (s.count === 1 ? ' viewer' : ' viewers');
    },
    kicks: s => s.value == null ? 'Kicks' : n(s.value) + ' Kicks'
  },
  es: {
    superchat: s => ['Super Chat', s.amount].filter(Boolean).join(' '),
    membership: s => s.months ? 'Membresía de ' + n(s.months) + (s.months === 1 ? ' mes' : ' meses') : 'Nueva membresía',
    bits: s => s.value == null ? (s.amount || 'Bits') : n(s.value) + ' bits',
    subscription: s => s.months ? 'Suscripción de ' + n(s.months) + (s.months === 1 ? ' mes' : ' meses') : 'Nueva suscripción',
    gift: s => 'Regaló ' + n(s.count ?? 1) + (s.platform === 'youtube'
      ? ((s.count ?? 1) === 1 ? ' membresía' : ' membresías')
      : ((s.count ?? 1) === 1 ? ' suscripción' : ' suscripciones')),
    raid: s => {
      const label = s.platform === 'kick' ? 'Host' : 'Raid';
      return s.count == null ? label : label + ' con ' + n(s.count) + (s.count === 1 ? ' espectador' : ' espectadores');
    },
    kicks: s => s.value == null ? 'Kicks' : n(s.value) + ' kicks'
  }
};
''';

const galleryDomScript = r'''
function textElement(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  node.textContent = text;
  return node;
}
function namedEntry(tag, platform, name) {
  const node = document.createElement(tag);
  const dot = textElement('span', 'platform-dot', '');
  dot.style.setProperty('--platform', Airstream.platformColor(platform));
  dot.setAttribute('aria-hidden', 'true');
  const label = textElement('bdi', 'screen-name', name);
  label.title = name;
  node.append(dot, label);
  return {node, label};
}
''';

const galleryRankingScript = r'''
const rankingLabels = {
  en: {superchat: 'Top Super Chats', bits: 'Top bits', gift: 'Top gifted subs',
    kicks: 'Top kicks', chatters: 'Top chatters'},
  es: {superchat: 'Mayores Super Chats', bits: 'Más bits', gift: 'Más regalos',
    kicks: 'Más kicks', chatters: 'Quienes más escribieron'}
};

function rankedSupport(data, currencyPreference) {
  const rankings = data?.top;
  if (!rankings) return [];
  const currencies = Object.keys(rankings.superchat || {}).filter(key => rankings.superchat[key]?.length);
  const counts = new Map();
  for (const support of data.supporters || []) {
    if (support.type === 'superchat') counts.set(support.currency, (counts.get(support.currency) || 0) + 1);
  }
  const uses = key => data.superchatCounts?.[key] ?? counts.get(key) ?? 0;
  const currency = currencies.includes(currencyPreference) ? currencyPreference :
    currencies.sort((a, b) => uses(b) - uses(a) ||
      rankings.superchat[b].length - rankings.superchat[a].length)[0];
  return [
    {type: 'superchat', currency, entries: rankings.superchat?.[currency]},
    ...['bits', 'gift', 'kicks'].map(type => ({type, entries: rankings[type]}))
  ].filter(group => group.entries?.length);
}

function rankValue(group, value) {
  if (group.type !== 'superchat' || !group.currency) return number(value);
  const digits = Number.isInteger(value) ? 0 : 2;
  return group.currency + new Intl.NumberFormat(language, {minimumFractionDigits: digits, maximumFractionDigits: 2}).format(value);
}

function rankingTitle(group) {
  return rankingLabels[language][group.type] + (group.currency ? ' · ' + group.currency : '');
}
''';

const _screenScript = r'''
const stage = byId('stage');
const backgroundMedia = byId('background-media');
const messages = byId('messages');
const messageLines = [...messages.children];
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const galleryDemo = Airstream.demo && location.pathname.startsWith('/gallery/');
const screenCopy = {
  en: {
    chat: 'Live chat', latest: 'Latest support', topChatters: rankingLabels.en.chatters,
    thanks: 'Thanks for watching', credits: 'Credits', farewell: 'See you at the next stream.',
    rotating: 'Say hello in chat | Thanks for spending time with us',
    types: {superchat: 'Super Chats', membership: 'Members', bits: 'Bits',
      subscription: 'Subscribers', gift: 'Gifted subs', raid: 'Raids', kicks: 'Kicks'}
  },
  es: {
    chat: 'Chat en vivo', latest: 'Apoyos recientes', topChatters: rankingLabels.es.chatters,
    thanks: 'Gracias por acompañarnos', credits: 'Créditos', farewell: 'Nos vemos en el próximo directo.',
    rotating: 'Saluda en el chat | Gracias por pasar este rato aquí',
    types: {superchat: 'Super Chats', membership: 'Miembros', bits: 'Bits',
      subscription: 'Suscriptores', gift: 'Regalos', raid: 'Raids', kicks: 'Kicks'}
  }
};
let fields = {};
let session = null;
let language = 'en';
let numberFormat = new Intl.NumberFormat(language);
const copy = () => screenCopy[language];
const number = value => numberFormat.format(value);
fitGalleryStage(stage, 1920, 1080);

let mediaRequest;
let mediaKey;
function updateBackground() {
  const mode = fields.background === 'transparent' ? 'transparent' : 'theme';
  const url = fields.background === 'media' ? Airstream.mediaUrl(fields.backgroundMedia) : '';
  const key = url || mode;
  if (mediaKey === key) return;
  mediaKey = key;
  mediaRequest?.abort();
  const video = backgroundMedia.querySelector('video');
  if (video) {
    video.pause();
    video.removeAttribute('src');
    video.load();
  }
  backgroundMedia.replaceChildren();
  stage.dataset.background = mode;
  if (!url) return;
  const request = new AbortController();
  mediaRequest = request;
  // The existing media endpoint supplies the MIME type on a one-byte range.
  fetch(url, {headers: {Range: 'bytes=0-0'}, signal: request.signal}).then(response => {
    const type = response.headers.get('content-type') || '';
    if (!response.ok || request.signal.aborted || !/^(image|video)\//.test(type)) return;
    const isVideo = type.startsWith('video/');
    const media = document.createElement(isVideo ? 'video' : 'img');
    if (isVideo) {
      media.muted = true;
      media.loop = true;
      media.autoplay = true;
      media.playsInline = true;
    } else {
      media.alt = '';
    }
    media.addEventListener(isVideo ? 'loadeddata' : 'load', () => {
      if (!request.signal.aborted) stage.dataset.background = 'media';
    }, {once: true});
    media.addEventListener('error', () => {
      if (!request.signal.aborted) {
        media.remove();
        stage.dataset.background = 'theme';
      }
    }, {once: true});
    backgroundMedia.appendChild(media);
    media.src = url;
  }).catch(() => {});
}

let rotationSource;
let rotation;
function updateMessages() {
  const source = fields.messages || (galleryDemo ? copy().rotating : '');
  if (source === rotationSource) return;
  rotationSource = source;
  clearInterval(rotation);
  const lines = splitGalleryMessages(source);
  messages.hidden = lines.length === 0;
  let index = 0, front = 0;
  messageLines[0].textContent = lines[0] || '';
  messageLines[0].classList.add('active');
  messageLines[1].classList.remove('active');
  if (lines.length < 2) return;
  rotation = setInterval(() => {
    const back = 1 - front;
    index = (index + 1) % lines.length;
    messageLines[back].textContent = lines[index];
    showGalleryLayer(messageLines, back);
    front = back;
  }, 8000);
}

const chat = byId('chat');
const chatMessages = byId('chat-messages');
const chatRows = [];
if (chat) {
  Airstream.on('chat', message => {
    if (message.id && chatRows.some(row => row.message.platform === message.platform &&
        row.message.youtubeStreamOrientation === message.youtubeStreamOrientation &&
        row.message.id === message.id)) return;
    const row = document.createElement('li');
    const {node: author, label} = namedEntry('div', message.platform, message.author);
    author.className = 'chat-author';
    if (typeof message.color === 'string' && /^#[0-9a-f]{6}$/i.test(message.color)) {
      label.style.setProperty('--author', 'color-mix(in srgb, ' + message.color + ' 38%, var(--ink))');
    }
    const body = document.createElement('p');
    body.className = 'chat-text';
    body.appendChild(Airstream.renderMessage(message));
    row.append(author, body);
    if (chatRows.length === 6) chatRows.shift().node.remove();
    chatRows.push({message, node: row});
    row.classList.add('chat-enter');
    chatMessages.appendChild(row);
  });
  Airstream.on('delete', event => {
    for (let i = chatRows.length - 1; i >= 0; i--) {
      const {message, node} = chatRows[i];
      if (matchesChatDeletion(message, event)) {
        node.remove();
        chatRows.splice(i, 1);
      }
    }
  });
}

function setupCountdown(targetTime, completeText) {
  const line = byId('countdown');
  let deadline = null;
  let timer;
  function update() {
    line.hidden = deadline === null;
    if (deadline === null) return;
    const remaining = deadline - Date.now();
    line.dataset.complete = String(remaining <= 0);
    line.textContent = remaining <= 0 ? completeText() : Airstream.formatDuration(remaining);
    if (remaining <= 0) clearInterval(timer);
  }
  function restart() {
    clearInterval(timer);
    deadline = targetTime();
    if (deadline !== null && deadline > Date.now()) timer = setInterval(update, 1000);
    update();
  }
  window.addEventListener('obsSourceActiveChanged', event => {
    if (event.detail?.active === true) restart();
  });
  return {update, restart};
}

function localTitle(title) {
  byId('title').textContent = title;
  document.title = title;
}
function subtitleText(value) {
  const subtitle = byId('subtitle');
  subtitle.textContent = value;
  subtitle.hidden = !value;
}

function configureScreen(onFields, onSession = () => {}) {
  let configured = false;
  Airstream.on('session', next => {
    session = next;
    if (configured) onSession();
  });
  Airstream.on('fields', next => {
    fields = next || {};
    const nextLanguage = applyGalleryFields(fields);
    if (nextLanguage !== language) numberFormat = new Intl.NumberFormat(nextLanguage);
    language = nextLanguage;
    updateBackground();
    updateMessages();
    if (chat) {
      chat.hidden = fields.showChat === false;
      byId('chat-heading').textContent = copy().chat;
    }
    stage.hidden = false;
    onFields(!configured);
    configured = true;
  });
}
''';

const galleryScript = r'''
const byId = id => document.getElementById(id);
function matchesChatDeletion(message, event) {
  if (!event || message.platform !== event.platform ||
      (event.youtubeStreamOrientation &&
        message.youtubeStreamOrientation !== event.youtubeStreamOrientation)) return false;
  if (Number.isInteger(event.sequence)) return message.sequence === event.sequence;
  return event.scope === 'platform' ||
    (event.scope === 'message' && event.messageId && message.id === event.messageId) ||
    (event.scope === 'author' &&
      ((event.authorChannelId && message.authorChannelId === event.authorChannelId) ||
       (event.authorName && message.author?.toLowerCase() === event.authorName.toLowerCase())));
}
const fonts = ['DM Sans', 'Barlow', 'Outfit'];
const root = document.documentElement;
const branding = document.querySelector('.gallery-logo');
let logo;
let fontSheet;
let activeFont;
function fitGalleryStage(stage, width, height) {
  function fit() {
    stage.style.setProperty('--stage-scale', Math.min(window.innerWidth / width, window.innerHeight / height));
  }
  fit();
  window.addEventListener('resize', fit);
}

function splitGalleryMessages(source) {
  return source.split('|').map(line => line.trim()).filter(Boolean);
}

function showGalleryLayer(layers, front) {
  layers[front].classList.add('active');
  layers[1 - front].classList.remove('active');
}

function applyGalleryFields(fields) {
  root.dataset.theme = ['neon', 'minimal', 'warm'].includes(fields.theme) ? fields.theme : 'neon';
  const language = fields.language === 'es' ? 'es' : 'en';
  root.lang = language;
  const accent = fields.accent;
  // Preserve the palette of each theme while the shared accent is at its default.
  if (typeof accent === 'string' && /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(accent) && accent !== '#bee863') {
    root.style.setProperty('--custom-accent', accent);
  } else {
    root.style.removeProperty('--custom-accent');
  }
  const font = fonts.includes(fields.font) ? fields.font : 'system';
  if (activeFont !== font) {
    activeFont = font;
    fontSheet?.remove();
    fontSheet = null;
    if (font === 'system') {
      root.style.removeProperty('--font');
    } else {
      fontSheet = document.createElement('link');
      fontSheet.rel = 'stylesheet';
      fontSheet.href = 'https://fonts.googleapis.com/css2?family=' +
        encodeURIComponent(font) + ':wght@400;600;700&display=swap';
      document.head.appendChild(fontSheet);
      root.style.setProperty('--font', '"' + font + '"');
    }
  }
  // A widget without a logo slot must still render the rest of its fields.
  const url = branding ? Airstream.mediaUrl(fields.logo) : null;
  if (branding) branding.hidden = !url;
  if (url) {
    if (!logo) {
      logo = document.createElement('img');
      logo.alt = '';
      branding.appendChild(logo);
    }
    if (logo.getAttribute('src') !== url) logo.src = url;
  } else {
    logo?.remove();
    logo = null;
  }
  return language;
}
''';

Map<String, String> galleryWidgetFiles(
  int width,
  int height,
  String body,
  String css,
  String script,
) =>
    {
      'index.html': '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="style.css">
  <script defer src="script.js"></script>
</head>
<body>
  <main id="stage" aria-labelledby="title" hidden>
    $body
  </main>
</body>
</html>
''',
      'style.css': '$galleryCss\n$_widgetCss\n'
          '#stage { width: ${width}px; height: ${height}px; }\n$css',
      'script.js': '(() => {\n"use strict";\n$galleryScript\n'
          '$galleryDomScript\n$_widgetScript\n'
          'fitGalleryStage(stage, $width, $height);\n$script\n})();',
    };

const _widgetCss = r'''
html, body { width: 100%; height: 100%; overflow: hidden; }
#stage {
  --accent: var(--custom-accent, var(--theme-accent));
  position: absolute; top: 50%; left: 50%;
  transform: translate(-50%, -50%) scale(var(--stage-scale, 1));
  overflow: hidden;
}
.widget-panel {
  border: 1px solid var(--line); border-radius: var(--radius);
  background: var(--surface);
}
:root[data-theme="neon"] .widget-panel { box-shadow: inset 0 0 24px var(--glow); }
.widget-header { display: flex; align-items: center; gap: 12px; min-width: 0; }
.widget-header h1, .widget-empty, .widget-layer p { margin: 0; }
.widget-header .gallery-logo { flex-basis: 44px; height: 35px; }
.widget-empty { color: var(--muted); }
.screen-name { display: block; min-width: 0; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
.platform-dot {
  width: 10px; height: 10px; border-radius: 50%; background: var(--platform);
  box-shadow: inset 0 0 0 1px #322d3c45;
}
.widget-layer { grid-area: 1 / 1; opacity: 0; min-width: 0; }
.widget-layer.active { opacity: 1; }
''';

const _widgetScript = r'''
const stage = byId('stage');
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
let fields = {};
let language = 'en';
let numberFormat = new Intl.NumberFormat(language);
const number = value => numberFormat.format(value);

function widgetTitle(title) {
  byId('title').textContent = title;
  document.title = title;
}

function configureWidget(onFields) {
  Airstream.on('fields', next => {
    fields = next || {};
    const nextLanguage = applyGalleryFields(fields);
    if (language !== nextLanguage) numberFormat = new Intl.NumberFormat(nextLanguage);
    language = nextLanguage;
    onFields();
  });
}

function widgetRotation(advance) {
  let interval;
  let activeSeconds = 0;
  return count => {
    const seconds = count < 2 ? 0 : Math.min(30, Math.max(4, fields.seconds || 8));
    if (activeSeconds === seconds) return;
    activeSeconds = seconds;
    clearInterval(interval);
    if (seconds) interval = setInterval(advance, seconds * 1000);
  };
}
''';
