import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

const topSupportersWidth = 560;
const topSupportersHeight = 480;

List<Map<String, Object?>> topSupportersFields(AppLocalizations l) => [
      {
        'key': 'type',
        'label': l.galleryRankingType,
        'type': 'select',
        'options': ['auto', 'superchat', 'bits', 'gift', 'kicks', 'chatters'],
        'default': 'auto',
      },
      screenNumber('seconds', l.galleryRotationSeconds, 4, 30, 8),
      screenTextField('currency', l.galleryCurrency, 30),
    ];

Map<String, String> topSupportersFiles() => galleryWidgetFiles(
      topSupportersWidth,
      topSupportersHeight,
      _body,
      _css,
      '$galleryRankingScript\n$_script',
    );

const _body = '''
<section class="widget-panel ranking">
  <header class="widget-header">
    <span class="gallery-logo" hidden></span>
    <div class="ranking-headlines"><h1 id="title"></h1><h2 id="category" hidden></h2></div>
  </header>
  <ol id="ranks" aria-labelledby="category"></ol>
  <p id="empty" class="widget-empty" hidden></p>
</section>
''';

const _css = r'''
.ranking {
  position: absolute; inset: 5px; padding: 21px 24px;
  border-block-start: 4px solid var(--accent);
}
.ranking .widget-header { min-height: 68px; margin-bottom: 16px; }
.ranking .gallery-logo { flex-basis: 57px; height: 50px; }
.ranking-headlines { min-width: 0; }
.ranking h1 { font-size: 32px; line-height: 1.1; letter-spacing: -.03em; }
.ranking h2 { margin: 5px 0 0; font-size: 21px; color: var(--muted); overflow-wrap: anywhere; }
#ranks { display: grid; gap: 7px; margin: 0; padding: 0; list-style: none; }
.rank-row {
  position: relative; display: grid;
  grid-template-columns: 38px 10px minmax(0, 1fr) minmax(0, max-content);
  align-items: center; height: 59px; gap: 11px; min-width: 0; padding-inline: 12px;
  border: 1px solid var(--line); border-radius: calc(var(--radius) - 4px);
  background: var(--row); font-size: 24px; font-weight: 600;
}
.rank-row:first-child {
  border-color: color-mix(in srgb, var(--accent), var(--line) 30%);
  background: color-mix(in srgb, var(--accent) 12%, var(--row));
  font-weight: 700;
}
.rank-number {
  display: grid; place-items: center; width: 34px; height: 34px;
  border-radius: 7px; background: var(--surface); color: var(--muted);
  font-size: 19px; font-variant-numeric: tabular-nums;
}
.rank-row:first-child .rank-number {
  background: color-mix(in srgb, var(--accent) 18%, var(--surface));
  color: var(--ink); box-shadow: inset 0 0 0 1px var(--accent);
}
.rank-value {
  overflow: hidden; max-width: 166px; text-overflow: ellipsis; white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.ranking .widget-empty { padding-top: 18px; border-top: 1px solid var(--line); font-size: 24px; }
''';

const _script = r'''
const text = {
  en: {title: 'Top of the stream', empty: 'No leaderboard entries yet'},
  es: {title: 'Top del directo', empty: 'Todavía no hay datos para clasificar'}
};
const copy = () => text[language];
const category = byId('category');
const empty = byId('empty');
const ranks = byId('ranks');
const rows = new Map();
let configured = false;
let groups = [];
let groupType;
let groupKey;

function show(group, animate) {
  groupType = group?.type;
  const key = JSON.stringify([groupType, group?.currency]);
  if (key !== groupKey) {
    groupKey = key;
    ranks.replaceChildren();
    rows.clear();
    animate = false;
  }
  category.hidden = !group;
  if (group) category.textContent = rankingTitle(group);
  const entries = group?.entries?.slice(0, 5) || [];
  ranks.hidden = entries.length === 0;
  empty.hidden = entries.length > 0;

  // The SDK ranks by total and supplies the tie order. Its rows expose display
  // names only, so use platform/name plus occurrence for duplicate names.
  const occurrences = new Map();
  const ordered = entries.map(entry => {
    const identity = JSON.stringify([entry.platform, entry.name]);
    const occurrence = occurrences.get(identity) || 0;
    occurrences.set(identity, occurrence + 1);
    return {entry, id: identity + ':' + occurrence};
  });
  const keys = new Set(ordered.map(row => row.id));
  const oldPositions = new Map();
  if (animate && !reducedMotion.matches) {
    for (const [id, row] of rows) oldPositions.set(id, row.node.offsetTop);
  } else {
    for (const row of rows.values()) row.animation?.cancel();
  }
  for (const [id, row] of rows) {
    if (keys.has(id)) continue;
    row.node.remove();
    rows.delete(id);
  }
  for (const [index, {id, entry}] of ordered.entries()) {
    let row = rows.get(id);
    if (!row) {
      const {node} = namedEntry('li', entry.platform, entry.name);
      node.className = 'rank-row';
      const rank = textElement('span', 'rank-number', '');
      rank.setAttribute('aria-hidden', 'true');
      const value = textElement('span', 'rank-value', '');
      node.prepend(rank);
      node.appendChild(value);
      row = {node, rank, value};
      rows.set(id, row);
    }
    const rank = String(index + 1);
    if (row.rank.textContent !== rank) row.rank.textContent = rank;
    const value = rankValue(group, groupType === 'chatters' ? entry.messages : entry.value);
    if (row.value.textContent !== value) {
      row.value.textContent = value;
      row.value.title = value;
    }
    const position = ranks.children[index];
    if (position !== row.node) ranks.insertBefore(row.node, position || null);
  }
  for (const [id, oldTop] of oldPositions) {
    const row = rows.get(id);
    if (!row) continue;
    const delta = oldTop - row.node.offsetTop;
    if (!delta) continue;
    row.animation?.cancel();
    row.animation = row.node.animate([{transform: 'translateY(' + delta + 'px)'},
      {transform: 'translateY(0)'}], {duration: 240, easing: 'cubic-bezier(.2,.7,.25,1)'});
  }
}

const schedule = widgetRotation(() => {
  const index = groups.findIndex(group => group.type === groupType);
  show(groups[(index + 1) % groups.length], false);
});

function render(animate = false) {
  if (!configured) return;
  const session = Airstream.state.session;
  groups = rankedSupport(session, fields.currency);
  if (session?.topChatters?.length) groups.push({type: 'chatters', entries: session.topChatters});
  const type = fields.type || 'auto';
  const group = groups.find(item => item.type === (type === 'auto' ? groupType : type));
  show(group || (type === 'auto' ? groups[0] : {type}), animate);
  schedule(type === 'auto' ? groups.length : 0);
}

Airstream.on('session', (_, meta) => render(!meta.replay));
configureWidget(() => {
  configured = true;
  widgetTitle(copy().title);
  empty.textContent = copy().empty;
  stage.hidden = false;
  render();
});
reducedMotion.addEventListener('change', () => {
  if (reducedMotion.matches) for (const row of rows.values()) row.animation?.cancel();
});
''';
