import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

List<Map<String, Object?>> recentSupportFields(AppLocalizations l) => [
      {
        'key': 'count',
        'label': l.gallerySupportCount,
        'type': 'number',
        'min': 3,
        'max': 20,
        'step': 1,
        'default': 8,
      },
      {
        'key': 'heading',
        'label': l.galleryHeading,
        'type': 'text',
        'maxLength': 80,
        'default': '',
      },
      {
        'key': 'showEmpty',
        'label': l.galleryShowEmpty,
        'type': 'boolean',
        'default': true,
      },
    ];

Map<String, String> recentSupportFiles() => {
      'index.html': _html,
      'style.css': '$galleryCss\n$_css',
      'script.js':
          '(() => {\n"use strict";\n$galleryScript\n$gallerySupportDescriptions\n$_script\n})();',
    };

const _html = r'''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="style.css">
  <script defer src="script.js"></script>
</head>
<body>
  <main class="support" aria-labelledby="heading" hidden>
    <header><span class="gallery-logo" hidden></span><h1 id="heading"></h1></header>
    <ul id="entries"></ul>
    <p id="more" hidden></p>
    <p id="empty" hidden></p>
  </main>
</body>
</html>
''';

const _css = r'''
.support {
  display: flex;
  flex-direction: column;
  width: min(100% - 32px, 448px);
  max-height: calc(100dvh - 32px);
  margin: 16px auto;
  padding: 18px;
  border-radius: var(--radius);
  background: var(--surface);
  box-shadow: var(--shadow);
}
header { display: flex; align-items: center; min-height: 38px; gap: 12px; margin-bottom: 12px; }
h1 {
  margin: 0; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  font-size: clamp(1.25rem, 6vw, 1.75rem); font-weight: 700; letter-spacing: -.025em;
}
header::after {
  content: ''; height: 2px; min-width: 16px; flex: 1; margin-left: 2px;
  background: var(--custom-accent, var(--theme-accent));
}
:root[data-theme="neon"] header::after { box-shadow: 0 0 14px var(--glow); }
#entries {
  display: grid; gap: 6px; margin: 0; padding: 0; overflow: hidden; min-height: 0;
  list-style: none;
}
#more { margin: 6px 0 0; text-align: end; font-size: .8125rem; color: var(--muted); }
.support-row {
  display: grid; grid-template-columns: 10px minmax(0, 1fr); align-items: center; gap: 11px;
  padding: 7px 11px; min-height: 54px;
  background: var(--row); border: 1px solid var(--line);
  border-radius: calc(var(--radius) - 5px);
}
.platform-dot {
  width: 8px; height: 8px; border-radius: 50%; background: var(--platform);
  box-shadow: inset 0 0 0 1px #322d3c45;
}
.support[data-density="compact"] #entries { gap: 2px; }
.support[data-density="compact"] .support-row { padding-block: 2px; min-height: 23px; line-height: 1.15; }
.support[data-density="compact"] .support-details {
  display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: center; gap: 10px;
}
.support[data-density="compact"] .name { font-size: .875rem; }
.support[data-density="compact"] .description { text-align: end; font-size: .8125rem; }
.name, .description { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.name { font-weight: 700; font-size: 1rem; }
.description, #empty { font-size: .875rem; color: var(--muted); }
#empty { margin: 0; padding: 18px 0 12px; border-top: 1px solid var(--line); }
.enter { animation: enter .24s cubic-bezier(.2,.7,.3,1) both; }
@keyframes enter { from { transform: translateY(-6px); opacity: .15; } }
/* Short sources: compact rows so more supporters fit before "+N more". */
@media (max-height: 420px) {
  .support { margin: 8px auto; padding: 10px 12px; max-height: calc(100dvh - 16px); }
  header { min-height: 0; margin-bottom: 6px; }
  #entries { gap: 2px; }
  .support-row { padding-block: 2px; min-height: 23px; line-height: 1.15; }
  .support-details { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: center; gap: 10px; }
  .name { font-size: .875rem; }
  .description { text-align: end; font-size: .8125rem; }
}
''';

const _script = r'''
const copy = {
  en: {heading: 'Recent support', empty: 'No support yet', more: '+{count} more'},
  es: {heading: 'Apoyos recientes', empty: 'Todavía no hay apoyos', more: '+{count} más'}
};
const panel = document.querySelector('.support');
const heading = document.querySelector('#heading');
const entries = document.querySelector('#entries');
const empty = document.querySelector('#empty');
const rows = new Map();
const platformNames = {youtube: 'YouTube', twitch: 'Twitch', kick: 'Kick'};
let language = 'en';
let numberFormat = new Intl.NumberFormat(language);
const n = value => numberFormat.format(value);
let session;
let fields = Airstream.fields;
let configured = false;

function render(animate) {
  if (!configured) return;
  const text = copy[language];
  const limit = Math.min(20, Math.max(3, Math.round(fields.count || 8)));
  const supporters = (session?.supporters || []).slice(0, limit);
  panel.dataset.density = limit > 8 ? 'compact' : 'comfortable';
  heading.textContent = fields.heading || text.heading;
  document.title = heading.textContent;
  empty.textContent = text.empty;
  empty.hidden = supporters.length > 0;
  panel.hidden = supporters.length === 0 && fields.showEmpty === false;

  const ids = new Set(supporters.map(s => s.id));
  for (const [id, row] of rows) {
    if (ids.has(id)) continue;
    row.element.remove();
    rows.delete(id);
  }
  for (const [index, support] of supporters.entries()) {
    let row = rows.get(support.id);
    if (!row) {
      const element = document.createElement('li');
      element.className = 'support-row';
      const dot = document.createElement('span');
      dot.className = 'platform-dot';
      dot.title = platformNames[support.platform] || support.platform;
      dot.setAttribute('role', 'img');
      dot.setAttribute('aria-label', dot.title);
      dot.style.setProperty('--platform', Airstream.platformColor(support.platform));
      const body = document.createElement('div');
      body.className = 'support-details';
      const name = document.createElement('span');
      name.className = 'name';
      const description = document.createElement('span');
      description.className = 'description';
      body.append(name, description);
      element.append(dot, body);
      row = {element, name, description};
      rows.set(support.id, row);
      if (animate) {
        element.classList.add('enter');
        element.addEventListener('animationend', () => element.classList.remove('enter'), {once: true});
      }
    }
    if (!animate) row.element.classList.remove('enter');
    if (row.name.textContent !== support.name) row.name.textContent = support.name;
    const description = supportDescriptions[language][support.type]?.(support) || '';
    if (row.description.textContent !== description) row.description.textContent = description;
    const position = entries.children[index];
    if (position !== row.element) entries.insertBefore(row.element, position || null);
  }
  // Viewers cannot scroll a browser source: drop the oldest rows until the
  // panel fits and say how many were left out.
  const more = document.querySelector('#more');
  let fitted = supporters.length;
  more.hidden = true;
  while (fitted > 1 && (panel.scrollHeight > panel.clientHeight + 1 ||
      entries.scrollHeight > entries.clientHeight + 1)) {
    fitted--;
    const dropped = supporters[fitted];
    rows.get(dropped.id)?.element.remove();
    rows.delete(dropped.id);
    more.textContent = text.more.replace('{count}', n(supporters.length - fitted));
    more.hidden = false;
  }
}

Airstream.on('fields', next => {
  fields = next || {};
  const nextLanguage = applyGalleryFields(fields);
  if (language !== nextLanguage) numberFormat = new Intl.NumberFormat(nextLanguage);
  language = nextLanguage;
  configured = true;
  render(false);
});
Airstream.on('session', (next, meta) => {
  session = next;
  render(!meta.replay);
});
Airstream.on('disconnected', () => {
  session = null;
  render(false);
});
// Re-fit when OBS resizes the browser source.
window.addEventListener('resize', () => render(false));
''';
