import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

const tickerWidth = 1920;
const tickerHeight = 64;

List<Map<String, Object?>> tickerFields(AppLocalizations l) => [
      screenTextField('messages', l.galleryTickerMessages, 500),
      screenNumber('speed', l.galleryTickerSpeed, 30, 200, 80),
      screenToggle('showCustom', l.galleryTickerShowCustom, true),
      screenToggle('showLatest', l.galleryTickerShowLatest, true),
      screenToggle('showGoals', l.galleryTickerShowGoals, true),
      screenToggle('showTimer', l.galleryTickerShowTimer, true),
      screenToggle('showEmpty', l.galleryTickerShowEmpty, false),
    ];

Map<String, String> tickerFiles() => galleryWidgetFiles(
      tickerWidth,
      tickerHeight,
      _body,
      _css,
      '$gallerySupportTypes\n$gallerySupportDescriptions\n$_script',
    );

const _body = '''
<section class="widget-panel ticker">
  <h1 id="title" class="visually-hidden"></h1>
  <div id="ticker-track"></div>
  <div id="ticker-still" hidden></div>
  <div class="gallery-logo" hidden></div>
</section>
''';

const _css = r'''
.ticker {
  height: 100%; display: flex; align-items: center; overflow: hidden;
  border-radius: calc(var(--radius) - 4px); border-block-end: 2px solid var(--accent);
}
.visually-hidden {
  position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%);
}
.ticker .gallery-logo {
  position: absolute; inset: 1px auto 3px 1px; width: 94px; height: auto;
  padding: 9px 16px; background: var(--surface); border-inline-end: 1px solid var(--line);
  border-radius: calc(var(--radius) - 5px) 0 0 calc(var(--radius) - 5px);
}
#ticker-track, .ticker-group { display: flex; width: max-content; flex: none; }
#ticker-track.rolling { animation: ticker-scroll var(--ticker-duration) linear infinite; }
@keyframes ticker-scroll { to { transform: translateX(var(--ticker-distance)); } }
.ticker-item {
  flex: none; display: flex; align-items: center; min-width: 92px;
  padding-inline: 22px 16px; gap: 24px; font-size: 27px; font-weight: 600;
}
.ticker-item::after {
  content: ''; width: 8px; height: 8px; flex: none; border-radius: 50%;
  background: var(--accent); box-shadow: 0 0 12px var(--glow, transparent);
}
.ticker-label { max-width: 1740px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ticker-time { display: inline-block; width: 10ch; font-variant-numeric: tabular-nums; }
#ticker-still { flex: 1; min-width: 0; padding-inline: 20px; }
.ticker:has(.gallery-logo:not([hidden])) #ticker-still { padding-inline-start: 110px; }
#ticker-still .ticker-item { min-width: 0; }
#ticker-still .ticker-item::after { display: none; }
@media (prefers-reduced-motion: reduce) {
  #ticker-still .ticker-item { animation: ticker-fade .35s ease-out both !important; }
}
@keyframes ticker-fade { from { opacity: 0; } }
''';

const _script = r'''
const text = {
  en: {
    title: 'Ticker', demo: 'Welcome to the stream! ✦ | Say hello in chat',
    timer: 'Subathon', goals: {subs: 'Subs goal', bits: 'Bits goal', kicks: 'Kicks goal'},
    latest: {superchat: 'Latest Super Chat', membership: 'Latest membership', bits: 'Latest bits',
      subscription: 'Latest subscription', gift: 'Latest gift', raid: 'Latest Raid', kicks: 'Latest kicks'}
  },
  es: {
    title: 'Barra informativa', demo: '¡Bienvenidos al directo! ✦ | Saluda en el chat',
    timer: 'Subatón', goals: {subs: 'Meta de suscripciones', bits: 'Meta de bits', kicks: 'Meta de kicks'},
    latest: {superchat: 'Último Super Chat', membership: 'Última membresía', bits: 'Últimos bits',
      subscription: 'Última suscripción', gift: 'Último regalo', raid: 'Último Raid', kicks: 'Últimos kicks'}
  }
};
const n = number;
const track = byId('ticker-track');
const still = byId('ticker-still');
const galleryDemo = Airstream.demo && location.pathname.startsWith('/gallery/');
let configured = false;
let requested;
let applied;
let periodWidth = 0;
let fontRevision = 0;
let timeNodes = [];
let clock;
let fadeTimer;
let fadeIndex = 0;
let stillKey;

function collectItems() {
  const copy = text[language];
  const items = [];
  if (fields.showCustom !== false) {
    const source = fields.messages || (galleryDemo ? copy.demo : '');
    items.push(...splitGalleryMessages(source).map(label => ({label})));
  }
  if (fields.showLatest !== false) {
    for (const type of supportTypes) {
      const support = Airstream.state.session?.latest?.[type];
      if (!support) continue;
      const detail = type === 'superchat' ? support.amount : supportDescriptions[language][type](support);
      items.push({label: copy.latest[type] + ': ' + support.name +
        (detail ? (type === 'superchat' ? ' ' : ' · ') + detail : '')});
    }
  }
  if (fields.showGoals !== false) {
    for (const goal of Airstream.state.goals || []) {
      const title = (galleryDemo && copy.goals[goal.type]) || goal.title;
      items.push({label: title + ' ' + number(goal.current) + '/' + number(goal.target)});
    }
  }
  if (fields.showTimer !== false && Airstream.state.timer?.phase === 'running' && Airstream.timerRemaining() > 0) {
    items.push({label: copy.timer + ' · ', timer: true});
  }
  if (items.length === 0 && fields.showEmpty === true) items.push({label: copy.title});
  return items;
}

function makeItem(item) {
  const node = textElement('div', 'ticker-item', '');
  const label = textElement('span', 'ticker-label', item.label);
  if (item.timer) {
    const time = textElement('span', 'ticker-time', Airstream.formatDuration(Airstream.timerRemaining()));
    timeNodes.push(time);
    label.appendChild(time);
  }
  node.appendChild(label);
  return node;
}

function appendGroup(items, widths) {
  const group = textElement('div', 'ticker-group', '');
  if (widths) group.setAttribute('aria-hidden', 'true');
  for (const [index, item] of items.entries()) {
    const node = makeItem(item);
    if (widths) node.style.width = widths[index] + 'px';
    group.appendChild(node);
  }
  track.appendChild(group);
  return group;
}

function applyLoop() {
  if (requested.key === applied?.key && requested.speed === applied.speed) return;
  const rebuild = requested.key !== applied?.key;
  applied = requested;
  track.classList.remove('rolling');
  stage.hidden = applied.items.length === 0;
  if (rebuild) {
    track.replaceChildren();
    timeNodes = [];
  }
  if (stage.hidden) return;
  if (rebuild) {
    const first = appendGroup(applied.items);
    // Freeze the measured widths so timer digits and late-loading fonts cannot
    // change the distance partway through a pass.
    const widths = Array.from(first.children, item => item.offsetWidth);
    for (const [index, item] of Array.from(first.children).entries()) item.style.width = widths[index] + 'px';
    periodWidth = first.offsetWidth;
    if (!periodWidth) return;
    // Even a single short item must fill the viewport at every loop position.
    const copies = Math.ceil(stage.clientWidth / periodWidth);
    for (let i = 0; i < copies; i++) appendGroup(applied.items, widths);
  }
  if (!periodWidth) return;
  track.style.setProperty('--ticker-distance', -periodWidth + 'px');
  track.style.setProperty('--ticker-duration', periodWidth / applied.speed + 's');
  // Start the new timing at zero at this iteration boundary.
  void track.offsetWidth;
  track.classList.add('rolling');
}

function showStill() {
  const items = requested.items;
  stage.hidden = items.length === 0;
  fadeIndex = items.length ? fadeIndex % items.length : 0;
  const item = items[fadeIndex];
  const key = JSON.stringify(item);
  if (key === stillKey) return;
  stillKey = key;
  timeNodes = [];
  still.replaceChildren(...(item ? [makeItem(item)] : []));
}

function updateClock() {
  const remaining = Airstream.timerRemaining();
  const value = Airstream.formatDuration(remaining);
  for (const node of timeNodes) if (node.textContent !== value) node.textContent = value;
  if (remaining <= 0) refresh();
}

function refresh() {
  if (!configured) return;
  const items = collectItems();
  requested = {
    items, key: JSON.stringify([items, fields.font, fontRevision]),
    speed: Math.min(200, Math.max(30, fields.speed || 80))
  };
  const running = Airstream.state.timer?.phase === 'running' && Airstream.timerRemaining() > 0;
  const removeTimer = timeNodes.length > 0 && !running;
  if (reducedMotion.matches) {
    if (removeTimer || stage.hidden || items.length < 2) showStill();
    if (items.length < 2) {
      clearInterval(fadeTimer);
      fadeTimer = null;
    } else if (!fadeTimer) {
      fadeTimer = setInterval(() => {
        fadeIndex++;
        showStill();
      }, 5000);
    }
  } else if (removeTimer || stage.hidden || !track.classList.contains('rolling')) {
    applyLoop();
  }
  const showClock = running && (fields.showTimer !== false || timeNodes.length > 0);
  if (showClock && !clock) clock = setInterval(updateClock, 1000);
  if (!showClock && clock) {
    clearInterval(clock);
    clock = null;
  }
}

function resetMotion() {
  track.classList.remove('rolling');
  track.replaceChildren();
  still.replaceChildren();
  clearInterval(fadeTimer);
  fadeTimer = null;
  fadeIndex = 0;
  stillKey = undefined;
  stage.hidden = true;
  track.hidden = reducedMotion.matches;
  still.hidden = !reducedMotion.matches;
  applied = null;
  timeNodes = [];
  refresh();
}

track.addEventListener('animationiteration', event => {
  if (event.animationName === 'ticker-scroll' && !reducedMotion.matches) applyLoop();
});
document.fonts?.addEventListener('loadingdone', () => {
  fontRevision++;
  refresh();
});
reducedMotion.addEventListener('change', resetMotion);
Airstream.on('session', refresh);
Airstream.on('goals', (_, meta) => meta.replay && configured ? resetMotion() : refresh());
Airstream.on('timer', (_, meta) => {
  if (meta.replay && configured) resetMotion();
  else refresh();
  if (timeNodes.length && Airstream.state.timer?.phase === 'running') updateClock();
});
configureWidget(() => {
  widgetTitle(text[language].title);
  if (!configured) {
    configured = true;
    resetMotion();
  } else {
    refresh();
  }
});
''';
