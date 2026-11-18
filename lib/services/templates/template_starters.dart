import 'dart:convert';

import 'package:airstream/services/overlay/templates/alert_moderation.dart';

enum TemplateStarter { blank, chat, alerts, goal }

Map<String, String> templateStarterFiles(TemplateStarter starter, String name) {
  Map<String, Object?> number(String key, num min, num max, num value) => {
        'key': key,
        'label': key,
        'type': 'number',
        'min': min,
        'max': max,
        'step': 1,
        'default': value
      };
  Map<String, Object?> color(String key, String value) =>
      {'key': key, 'label': key, 'type': 'color', 'default': value};
  final fields = switch (starter) {
    TemplateStarter.blank => <Map<String, Object?>>[],
    TemplateStarter.chat => [
        number('fontSize', 12, 48, 20),
        color('accentColor', '#53fc18'),
        number('maxMessages', 3, 50, 12),
        {
          'key': 'showAvatars',
          'label': 'showAvatars',
          'type': 'boolean',
          'default': true
        },
        number('lifetimeSeconds', 0, 600, 0)
      ],
    TemplateStarter.alerts => [
        number('displaySeconds', 2, 30, 6),
        color('accentColor', '#ffb15c'),
        number('fontSize', 16, 64, 28),
        {
          'key': 'sound',
          'label': 'sound',
          'type': 'media',
          'kind': 'audio',
          'default': ''
        }
      ],
    TemplateStarter.goal => [
        color('barColor', '#53fc18'),
        number('goalIndex', 1, 3, 1),
        number('height', 16, 80, 36)
      ],
  };
  return {
    'template.json': jsonEncode({
      'name': name,
      'sdk': 1,
      'width':
          starter == TemplateStarter.blank || starter == TemplateStarter.chat
              ? 400
              : 800,
      'height': switch (starter) {
        TemplateStarter.chat => 600,
        TemplateStarter.goal => 120,
        _ => 300
      },
      'fields': fields
    }),
    'index.html': r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="style.css"><script defer src="script.js"></script></head><body><main id="content"></main></body></html>''',
    'style.css': _css,
    'script.js': switch (starter) {
      TemplateStarter.blank => _blank,
      TemplateStarter.chat => _chat,
      TemplateStarter.alerts => _alerts,
      TemplateStarter.goal => _goal
    },
  };
}

const _css = r'''
:root { --accent: #53fc18; font: 20px system-ui, sans-serif; color: #f5f5f5; color-scheme: dark; }
* { box-sizing: border-box; } body { margin: 0; background: transparent; padding: 12px; }
[hidden] { display: none !important; }
#content { display: flex; flex-direction: column; gap: 8px; }
.card { background: #191919; border: 1px solid #383838; border-radius: 14px; padding: 16px; overflow-wrap: anywhere; }
.author { color: var(--accent); font-weight: 700; } .avatar { width: 32px; height: 32px; border-radius: 50%; vertical-align: middle; margin-right: 8px; }
.airstream-emote { height: 1.25em; vertical-align: middle; } .platform { height: 3px; border-radius: 3px; margin-bottom: 8px; }
.card > div:first-child { color: var(--accent); }
#content.goal { gap: 0; padding: 12px 16px; }
.track { background: #343434; border-radius: 8px; overflow: hidden; margin-top: 8px; }
.fill { height: 100%; width: 0; background: var(--accent); transition: width .6s cubic-bezier(.16, 1, .3, 1); }
.celebrate .fill { animation: celebrate 1s ease-out; }
@keyframes celebrate { 40% { filter: brightness(1.8); } }
.enter { animation: enter .3s ease-out; } .leave { animation: leave .3s ease-in forwards; }
@keyframes enter { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: translateY(0); } }
@keyframes leave { to { opacity: 0; transform: translateY(-12px); } }
@media (prefers-reduced-motion: reduce) { *, .fill { animation: none; transition: none; } }
''';

const _blank = r'''
// The server injects SDK v1 before this script. Subscribe with Airstream.on.
// Events: chat, delete, alert, featured, goals, timer, giveaway, poll,
// caption, event, settings, fields, connected, disconnected.
// Helpers: renderMessage, platformColor, mediaUrl, timerRemaining, formatDuration.
// Properties: version, template, demo, state, fields. on returns an unsubscribe function.
const content = document.querySelector('#content');
content.classList.add('card');
content.textContent = 'Waiting for an Airstream event';
for (const name of ['chat','delete','alert','featured','goals','timer','giveaway','poll','caption','event','settings','fields','connected','disconnected']) {
  Airstream.on(name, data => { content.textContent = name + ': ' + JSON.stringify(data); });
}
''';

const _chat = r'''
const content = document.querySelector('#content');
let fields = {fontSize:20, accentColor:'#53fc18', maxMessages:12, showAvatars:true, lifetimeSeconds:0};
const messages = [];
function prune() {
  const now = Date.now();
  for (const item of [...messages]) {
    if ((fields.lifetimeSeconds > 0 && now - item.time >= fields.lifetimeSeconds * 1000) || messages.length > fields.maxMessages) {
      item.node.remove(); messages.splice(messages.indexOf(item),1);
    }
  }
}
// Fields arrive again whenever values are edited; no reload is needed.
Airstream.on('fields', values => {
  fields = {...fields,...values}; content.style.fontSize = fields.fontSize + 'px';
  content.style.setProperty('--accent',fields.accentColor);
  for (const item of messages) if (item.avatar) item.avatar.hidden = !fields.showAvatars;
  prune();
});
Airstream.on('chat', message => {
  const node = document.createElement('article'); node.classList.add('card');
  const bar = document.createElement('div'); bar.classList.add('platform'); bar.style.background = Airstream.platformColor(message.platform); node.appendChild(bar);
  let avatar = null;
  if (message.authorAvatarUrl && /^https?:/i.test(message.authorAvatarUrl)) {
    avatar = document.createElement('img'); avatar.classList.add('avatar'); avatar.src = message.authorAvatarUrl; avatar.alt = ''; avatar.hidden = !fields.showAvatars; node.appendChild(avatar);
  }
  const author = document.createElement('span'); author.classList.add('author'); author.textContent = message.author; author.style.color = message.color || 'var(--accent)'; node.appendChild(author);
  const text = document.createElement('div');
  // renderMessage creates safe text and emote nodes, never HTML from chat.
  text.appendChild(Airstream.renderMessage(message)); node.appendChild(text); content.appendChild(node);
  messages.push({node,avatar,message,time:Date.now()}); prune();
});
Airstream.on('delete', event => {
  for (const item of [...messages]) {
    const message = item.message;
    if (message.platform !== event.platform ||
        (event.youtubeStreamOrientation &&
         message.youtubeStreamOrientation !== event.youtubeStreamOrientation)) continue;
    const matches = Number.isInteger(event.sequence) ? message.sequence === event.sequence :
      event.scope === 'platform' ||
      (event.scope === 'message' && event.messageId && message.id === event.messageId) ||
      (event.scope === 'author' &&
       ((event.authorChannelId && message.authorChannelId === event.authorChannelId) ||
        (event.authorName && String(message.author || '').toLowerCase() === String(event.authorName).toLowerCase())));
    if (matches) {
      item.node.remove(); messages.splice(messages.indexOf(item),1);
    }
  }
});
setInterval(prune,1000);
''';

const _alerts = alertModerationScript +
    r'''
const content = document.querySelector('#content');
let fields = {displaySeconds:6, accentColor:'#ffb15c', fontSize:28, sound:''};
let language = 'en', active = null;
let queue = [];
Airstream.on('settings', settings => { language = settings.appLanguageCode === 'es' ? 'es' : 'en'; });
Airstream.on('fields', values => { fields = {...fields,...values}; content.style.fontSize = fields.fontSize + 'px'; content.style.setProperty('--accent',fields.accentColor); });
const titles = {
  en:{superchat:'Super Chat',membership:'New member',bits:'Bits',subscription:'New subscriber',gift:'Gifted subscriptions',raid:'Raid',kicks:'Kicks',featured:'Featured message'},
  es:{superchat:'Super Chat',membership:'Nuevo miembro',bits:'Bits',subscription:'Nueva suscripción',gift:'Suscripciones regaladas',raid:'Incursión',kicks:'Kicks',featured:'Mensaje destacado'}
};
function addLine(card, value) {
  if (value == null) return null;
  const line = document.createElement('div');
  line.textContent = String(value);
  card.appendChild(line);
  return line;
}

function finish() {
  clearTimeout(active.timer);
  active.card.remove();
  active = null;
  next();
}

function next() {
  if (active || !queue.length) return;
  active = queue.shift();
  const {event} = active;
  const card = active.card = document.createElement('article');
  card.classList.add('card','enter');
  addLine(card, titles[language][event.alertType || event.kind] || (language === 'es' ? 'Alerta' : 'Alert'));
  active.authorLine = addLine(card, event.author);
  addLine(card, event.amount || event.count || event.giftCount);
  active.messageLine = addLine(card, event.message);
  content.appendChild(card);
  if (fields.sound) {
    active.audio = new Audio(Airstream.mediaUrl(fields.sound));
    active.audio.play().catch(() => { /* Browser autoplay permissions may block audio. */ });
  }
  active.timer = setTimeout(() => {
    card.classList.add('leave');
    active.timer = setTimeout(finish,300);
  },fields.displaySeconds * 1000);
}

function redact(item, hideAuthor = false) {
  item.event.message = null;
  item.messageLine?.remove();
  item.messageLine = null;
  if (hideAuthor) {
    Object.assign(item.event, {author: null, authorChannelId: '', authorAvatarUrl: null,
      badgeLabel: null, badgeImageUrl: null});
    item.authorLine?.remove();
    item.authorLine = null;
  }
}

function removeFeatures(matches) {
  queue = queue.filter(({event}) => event.kind !== 'featured' || !matches(event));
  if (active?.event.kind === 'featured' && matches(active.event)) {
    active.audio?.pause();
    finish();
  }
}

Airstream.on('delete', deletion => {
  const matches = event => matchesAlertModeration(event, deletion);
  if (!Number.isInteger(deletion.sequence)) {
    for (const item of [...queue, active]) {
      if (item && item.event.kind !== 'featured' && matches(item.event)) redact(item);
    }
  }
  removeFeatures(matches);
});

Airstream.on('filters', filters => {
  const {blocksAuthor, blocksText} = alertBlockMatcher(filters);
  for (const item of [...queue, active]) {
    if (!item || item.event.kind === 'featured' || item.event.kind === 'custom') continue;
    const hideAuthor = blocksAuthor(item.event);
    if (hideAuthor || blocksText(item.event)) redact(item, hideAuthor);
  }
  removeFeatures(event => blocksAuthor(event) || blocksText(event));
});

// Test and replay events are intentionally shown like live alerts.
for (const name of ['alert','featured']) Airstream.on(name, event => {
  queue.push({event: {...event}});
  next();
});
''';

const _goal = r'''
const content = document.querySelector('#content'); content.classList.add('card','goal'); content.hidden = true;
const label = document.createElement('div'), track = document.createElement('div'), fill = document.createElement('div');
track.classList.add('track'); fill.classList.add('fill'); track.appendChild(fill); content.appendChild(label); content.appendChild(track);
let fields = {barColor:'#53fc18',goalIndex:1,height:36}, goals = [], previous = null, selected = null, celebration = null;
function draw(meta = {replay:true}) {
  const goal = goals[fields.goalIndex - 1]; content.hidden = !goal;
  if (!goal) { previous = null; selected = null; return; }
  const percent = goal.target > 0 ? Math.max(0,Math.min(100,goal.current / goal.target * 100)) : 0;
  label.textContent = goal.title + ' · ' + goal.current + ' / ' + goal.target + ' · ' + Math.round(percent) + '%';
  fill.style.width = percent + '%'; track.style.height = fields.height + 'px'; content.style.setProperty('--accent',fields.barColor);
  if (!meta.replay && selected === goal.id && previous !== null && previous < goal.target && goal.current >= goal.target) {
    content.classList.add('celebrate'); clearTimeout(celebration); celebration = setTimeout(() => content.classList.remove('celebrate'),1000);
  }
  previous = goal.current; selected = goal.id;
}
// Replayed state draws immediately without celebrating a goal already reached.
Airstream.on('goals',(values,meta) => { goals = values || []; draw(meta); });
Airstream.on('fields',values => { if (values.goalIndex && fields.goalIndex !== values.goalIndex) previous = null; fields = {...fields,...values}; draw(); });
''';
