import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

List<Map<String, Object?>> creditsFields(AppLocalizations l) => [
      ...screenFields(l),
      screenToggle('showTopChatters', l.galleryShowTopChatters, false),
      screenTextField('currency', l.galleryCurrency, 30),
      screenTextField('finalText', l.galleryFinalText, 240),
      screenNumber('speed', l.galleryCreditsSpeed, 20, 200, 60),
      screenToggle('loop', l.galleryCreditsLoop, false),
    ];

Map<String, String> creditsFiles() => screenFiles(
      'credits',
      '''
<div class="screen-content credits">
  <h1 id="title" class="screen-title"></h1>
  <div id="credits-window" class="credits-window">
    <div id="credits-roll"></div>
    <div id="credits-page" class="credits-tile" hidden></div>
  </div>
</div>
''',
      _script,
      css: _css,
    );

const _css = r'''
.credits { inset-block-start: 137px; display: flex; flex-direction: column; align-items: center; }
#stage.screen-credits > .gallery-logo { top: 113px; }
.credits .screen-title {
  flex: none; margin: 0 0 24px; font-size: 85px; line-height: 1.12; text-align: center;
}
.credits .screen-title::after {
  content: ''; display: block; width: 74px; height: 3px; margin: 14px auto 0;
  background: var(--accent); box-shadow: 0 0 19px var(--glow, transparent);
}
.credits-window {
  flex: 1; min-height: 0; width: 1020px; position: relative; overflow: hidden;
  mask-image: linear-gradient(transparent, #000 6%, #000 94%, transparent);
}
#credits-roll { width: 100%; }
#credits-roll.rolling { animation: roll-credits var(--roll-duration) linear both; }
@keyframes roll-credits { to { transform: translateY(-100%); } }
.credits-section { padding: 28px 54px 34px; margin: 0 0 26px; text-align: center; }
#stage:is([data-background="media"], [data-background="transparent"]) .credits-section,
#stage:is([data-background="media"], [data-background="transparent"]) .credits .screen-title {
  background: var(--panel); border-radius: var(--radius);
}
#stage:is([data-background="media"], [data-background="transparent"]) .credits .screen-title { padding-inline: 35px; }
.credits-section h2 {
  margin: 0 0 20px; padding: 0 0 18px; border-bottom: 1px solid var(--line);
  font-size: 37px; line-height: 1.22; letter-spacing: -.026em;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.credits-section ul { padding: 0; margin: 0 auto; list-style: none; max-width: 690px; }
.credits-section li { display: flex; align-items: center; justify-content: center; gap: 12px; height: 41px; font-size: 29px; }
.credits-value { color: var(--muted); font-variant-numeric: tabular-nums; }
.credits-section p {
  margin: 0 auto; max-width: 29ch; color: var(--muted); font-size: 30px;
  overflow-wrap: anywhere; display: -webkit-box; -webkit-box-orient: vertical;
  -webkit-line-clamp: 7; overflow: hidden;
}
.credits-tile { position: absolute; inset: 16px 0; display: grid; place-items: center; }
.credits-tile .credits-section { width: 100%; margin: 0; }
@media (prefers-reduced-motion: reduce) {
  #credits-page.credits-fade { animation: credits-fade .28s ease-out both !important; }
}
@keyframes credits-fade { from { opacity: .12; } to { opacity: 1; } }
''';

const _script = r'''
const view = byId('credits-window');
const roll = byId('credits-roll');
const page = byId('credits-page');
let pass;
let pageTimer;
let settingsKey;
let sessionKey;

function currentSessionKey() {
  return session ? session.startedAt || true : null;
}

function creditsIdentity(entry) {
  if (Number.isInteger(entry.sessionIndex)) return entry.sessionIndex;
  const channelId = entry.channelId?.trim();
  return JSON.stringify([entry.platform, channelId ? 'id' : 'name',
    channelId || entry.name.trim().toLowerCase()]);
}

function snapshot() {
  const groups = [];
  const recent = [...(session?.supporters || [])].reverse();
  const ids = new Set(recent.map(entry => entry.id));
  for (const type of supportTypes) {
    const latest = session?.latest?.[type];
    if (latest && !ids.has(latest.id)) recent.push(latest);
  }
  recent.sort((a, b) => (Date.parse(a.at) || 0) - (Date.parse(b.at) || 0));
  for (const type of supportTypes) {
    const names = new Map();
    for (const entry of recent) {
      if (entry.type !== type || !entry.name) continue;
      const key = creditsIdentity(entry);
      // Repeated supporters use their newest appearance and position.
      names.delete(key);
      names.set(key, {name: entry.name, platform: entry.platform, channelId: entry.channelId});
    }
    if (names.size) groups.push({key: 'support:' + type, heading: copy().types[type],
      entries: [...names.values()]});
  }
  for (const group of rankedSupport(session, fields.currency)) {
    groups.push({key: 'rank:' + group.type + ':' + (group.currency || ''),
      heading: rankingTitle(group), entries: group.entries.map(entry => ({
      ...entry, value: rankValue(group, entry.value)
    }))});
  }
  if (fields.showTopChatters && session?.topChatters?.length) {
    groups.push({key: 'chatters', heading: copy().topChatters, entries: session.topChatters.map(entry => ({
      ...entry, value: number(entry.messages)
    }))});
  }
  const finalGroup = {heading: copy().thanks, text: fields.finalText ||
    (galleryDemo ? copy().farewell : '')};
  return {groups, finalGroup, speed: Math.min(200, Math.max(20, fields.speed || 60))};
}

function lostEntries(next) {
  const counts = new Map();
  const entryKey = (group, entry) => group.key + ':' + creditsIdentity(entry);
  for (const group of next.groups) {
    for (const entry of group.entries) {
      const key = entryKey(group, entry);
      counts.set(key, (counts.get(key) || 0) + 1);
    }
  }
  return pass.groups.some(group => group.entries.some(entry => {
    const key = entryKey(group, entry);
    const count = counts.get(key) || 0;
    counts.set(key, count - 1);
    return count <= 0;
  }));
}

function renderSection(group) {
  const section = textElement('section', 'credits-section', '');
  const heading = textElement('h2', '', group.heading);
  heading.title = group.heading;
  section.appendChild(heading);
  if (group.entries) {
    const list = document.createElement('ul');
    for (const entry of group.entries) {
      const {node} = namedEntry('li', entry.platform, entry.name);
      if (entry.value != null) node.appendChild(textElement('span', 'credits-value', entry.value));
      list.appendChild(node);
    }
    section.appendChild(list);
  } else if (group.text) {
    section.appendChild(textElement('p', '', group.text));
  }
  return section;
}

function showPage(group, fade = false) {
  page.replaceChildren(renderSection(group));
  page.hidden = false;
  page.classList.remove('credits-fade');
  if (fade) {
    void page.offsetHeight;
    page.classList.add('credits-fade');
  }
}

function finishPass(pause = 2200) {
  roll.classList.remove('rolling');
  roll.hidden = true;
  showPage(pass.finalGroup, reducedMotion.matches);
  if (fields.loop) pageTimer = setTimeout(startPass, pause);
}

function presentPass() {
  clearTimeout(pageTimer);
  roll.classList.remove('rolling');
  roll.hidden = true;
  page.hidden = true;
  if (!pass.groups.length) {
    roll.replaceChildren();
    finishPass(6000);
    return;
  }
  if (reducedMotion.matches) {
    const pages = pass.groups.flatMap(group => {
      const chunks = [];
      for (let start = 0; start < group.entries.length; start += 10) {
        chunks.push({...group, entries: group.entries.slice(start, start + 10)});
      }
      return chunks;
    });
    let index = 0;
    function advance() {
      if (index === pages.length) {
        finishPass(6000);
        return;
      }
      showPage(pages[index++], true);
      pageTimer = setTimeout(advance, 6000);
    }
    advance();
    return;
  }
  roll.replaceChildren(...pass.groups.map(renderSection));
  // A short lead-in: the first section appears within a couple of seconds.
  roll.style.paddingTop = Math.round(view.clientHeight * 0.3) + 'px';
  roll.hidden = false;
  const height = roll.offsetHeight;
  roll.style.setProperty('--roll-duration', (height / pass.speed) + 's');
  roll.classList.add('rolling');
}

function startPass(next = snapshot()) {
  sessionKey = currentSessionKey();
  pass = next;
  presentPass();
}
roll.addEventListener('animationend', event => {
  if (event.animationName === 'roll-credits') finishPass();
});
reducedMotion.addEventListener('change', () => {
  if (pass) presentPass();
});
window.addEventListener('obsSourceActiveChanged', event => {
  // An OBS source may have been preloaded before any session data arrived.
  if (pass && event.detail?.active === true) startPass();
});
configureScreen(() => {
  localTitle(copy().credits);
  const key = JSON.stringify([language, fields.showTopChatters, fields.currency,
    fields.finalText, fields.speed, fields.loop]);
  if (key !== settingsKey) {
    settingsKey = key;
    startPass();
  }
}, () => {
  if (sessionKey !== currentSessionKey()) {
    startPass();
  } else if (session) {
    const next = snapshot();
    if ((!pass.groups.length && next.groups.length) || lostEntries(next)) {
      startPass(next);
    }
  }
});
''';
