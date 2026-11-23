import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

List<Map<String, Object?>> streamEndingFields(AppLocalizations l) => [
      ...screenFields(l),
      screenTextField('title', l.galleryScreenTitle, 100),
      screenToggle('showDuration', l.galleryShowDuration, true),
      screenToggle('showMessages', l.galleryShowMessages, true),
      screenToggle('showChatters', l.galleryShowChatters, true),
      screenToggle('showSupporters', l.galleryShowSupporters, true),
      screenToggle('showTopSupporters', l.galleryShowTopSupporters, true),
      screenToggle('showTopChatters', l.galleryShowTopChatters, false),
      screenTextField('currency', l.galleryCurrency, 30),
    ];

Map<String, String> streamEndingFiles() => screenFiles(
      'ending',
      '''
<div class="screen-content ending">
  <header class="screen-hero">
    <h1 id="title" class="screen-title"></h1>
  </header>
  <dl id="stats" hidden></dl>
  <div id="rankings" hidden></div>
</div>
''',
      _script,
      css: _css,
    );

const _css = r'''
.ending { display: flex; flex-direction: column; justify-content: center; gap: 26px; }
.ending .screen-hero { width: 100%; padding: 12px 34px 14px; }
.ending .screen-hero::before { margin-bottom: 22px; }
.ending .screen-title { font-size: 92px; -webkit-line-clamp: 2; }
#stats {
  display: flex; margin: 0; padding: 15px 44px; border-radius: var(--radius);
  background: var(--panel); border: 1px solid var(--line);
}
.stat { display: flex; flex: 1; flex-direction: column-reverse; min-width: 0; text-align: center; padding: 6px 15px; }
.stat + .stat { border-inline-start: 1px solid var(--line); }
.stat dt { font-size: 24px; color: var(--muted); }
.stat dd { margin: 0; font-size: 63px; letter-spacing: -.035em; line-height: 1.05; font-weight: 700; font-variant-numeric: tabular-nums; }
#rankings { display: grid; grid-auto-flow: column; grid-auto-columns: minmax(0, 1fr); gap: 14px; }
.ranking {
  min-width: 0; padding: 14px 20px; background: var(--panel);
  border: 1px solid var(--line); border-radius: var(--radius);
}
.ranking h2 {
  margin: 0 0 8px; padding-bottom: 9px; border-bottom: 1px solid var(--line);
  font-size: 22px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ranking ol { list-style: none; padding: 0; margin: 0; }
.ranking li { display: flex; gap: 9px; align-items: center; min-width: 0; font-size: 20px; line-height: 1.55; }
.ranking-value { margin-inline-start: auto; color: var(--muted); font-variant-numeric: tabular-nums; }
''';

const _script = r'''
const statsCopy = {
  en: {duration: 'Duration', messages: 'Messages', chatters: 'Chatters', supporters: 'Supporters'},
  es: {duration: 'Duración', messages: 'Mensajes', chatters: 'Participantes', supporters: 'Personas que apoyaron'}
};
const stats = byId('stats');
const rankings = byId('rankings');
let durationNode;
let durationTimer;
let statKey;
let rankKey;

function updateDuration() {
  const start = Date.parse(session?.startedAt);
  const end = Date.parse(session?.endedAt);
  if (durationNode) durationNode.textContent = Number.isFinite(start)
    ? Airstream.formatDuration((Number.isFinite(end) ? end : Date.now()) - start) : '—';
}

function renderEnding() {
  // Without session data (app disconnected) the stats are unknown, not zero:
  // hide them instead of telling viewers the stream had no activity.
  if (!session) {
    if (durationTimer != null) clearInterval(durationTimer);
    durationTimer = null;
    durationNode = null;
    statKey = null;
    rankKey = null;
    stats.replaceChildren();
    rankings.replaceChildren();
    stats.hidden = true;
    rankings.hidden = true;
    return;
  }
  const values = [
    ['duration', fields.showDuration, null],
    ['messages', fields.showMessages, session?.messages ?? 0],
    ['chatters', fields.showChatters, session?.chatters ?? 0],
    ['supporters', fields.showSupporters, session?.supporterCount ??
      new Set((session?.supporters || []).map(s => s.platform + ':' + s.name)).size]
  ].filter(([, show]) => show !== false);
  const newStatKey = JSON.stringify([language, values]);
  if (newStatKey !== statKey) {
    statKey = newStatKey;
    durationNode = null;
    stats.replaceChildren(...values.map(([key, , value]) => {
      const item = textElement('div', 'stat', '');
      const cell = textElement('dd', '', value === null ? '' : number(value));
      if (key === 'duration') durationNode = cell;
      item.append(textElement('dt', '', statsCopy[language][key]), cell);
      return item;
    }));
    stats.hidden = values.length === 0;
  }
  updateDuration();
  const ticking = durationNode && session?.startedAt && !session.endedAt;
  if (ticking && durationTimer == null) durationTimer = setInterval(updateDuration, 1000);
  if (!ticking && durationTimer != null) {
    clearInterval(durationTimer);
    durationTimer = null;
  }

  const groups = fields.showTopSupporters === false ? [] : rankedSupport(session, fields.currency);
  if (fields.showTopChatters && session?.topChatters?.length) {
    groups.push({entries: session.topChatters.slice(0, 5)});
  }
  const newRankKey = JSON.stringify([language, groups]);
  if (newRankKey === rankKey) return;
  rankKey = newRankKey;
  rankings.replaceChildren(...groups.map(group => {
    const section = textElement('section', 'ranking', '');
    const heading = group.type ? rankingTitle(group) : copy().topChatters;
    const title = textElement('h2', '', heading);
    title.title = heading;
    const list = document.createElement('ol');
    for (const entry of group.entries) {
      const {node} = namedEntry('li', entry.platform, entry.name);
      node.appendChild(textElement('span', 'ranking-value', group.type ? rankValue(group, entry.value) : number(entry.messages)));
      list.appendChild(node);
    }
    section.append(title, list);
    return section;
  }));
  rankings.hidden = groups.length === 0;
}
configureScreen(() => {
  localTitle(fields.title || copy().thanks);
  renderEnding();
}, renderEnding);
''';
