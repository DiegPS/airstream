import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

List<Map<String, Object?>> beRightBackFields(AppLocalizations l) => [
      ...screenFields(l),
      screenTextField('title', l.galleryScreenTitle, 100),
      screenNumber('minutes', l.galleryMinutes, 0, 120, 0),
      screenToggle('showChat', l.galleryShowChat, true),
    ];

Map<String, String> beRightBackFiles() => screenFiles(
      'brb',
      '''
<div class="screen-content screen-break">
  <section class="screen-hero">
    <h1 id="title" class="screen-title"></h1>
    <p id="countdown" class="screen-countdown" hidden></p>
  </section>
  $screenChat
</div>
<section id="latest" aria-labelledby="latest-heading" hidden>
  <h2 id="latest-heading"></h2>
  <ul id="latest-entries"></ul>
</section>
''',
      _script,
      css: _css,
    );

const _css = r'''
.screen-brb .screen-content:has(~ #latest:not([hidden])) { bottom: 280px; }
#latest {
  position: absolute; inset: auto 88px 167px; min-height: 95px;
  display: grid; grid-template-columns: 164px minmax(0, 1fr); align-items: center;
  gap: 24px; padding: 14px 24px;
  background: var(--panel); border: 1px solid var(--line); border-radius: var(--radius);
}
#latest h2 { margin: 0; font-size: 25px; line-height: 1.12; }
#latest-entries { display: flex; margin: 0; padding: 0; list-style: none; }
#latest-entries li { min-width: 0; flex: 1; padding-inline: 16px; border-inline-start: 1px solid var(--line); }
.latest-type { display: block; font-size: 17px; color: var(--muted); overflow-wrap: anywhere; }
.latest-person { display: flex; align-items: center; gap: 8px; font-size: 21px; font-weight: 700; }
''';

const _script = r'''
const breakCopy = {
  en: {title: 'Be right back', now: 'Back any second'},
  es: {title: 'Vuelvo enseguida', now: 'Vuelvo en cualquier momento'}
};
const latest = byId('latest');
const entries = byId('latest-entries');
let latestKey;
function renderLatest() {
  const current = supportTypes.flatMap(type => session?.latest?.[type] ? [[type, session.latest[type]]] : []);
  const key = JSON.stringify([language, current]);
  if (key === latestKey) return;
  latestKey = key;
  byId('latest-heading').textContent = copy().latest;
  entries.replaceChildren(...current.map(([type, support]) => {
    const item = document.createElement('li');
    const {node} = namedEntry('div', support.platform, support.name);
    node.className = 'latest-person';
    item.append(textElement('span', 'latest-type', copy().types[type]), node);
    return item;
  }));
  latest.hidden = current.length === 0;
}
const countdown = setupCountdown(() => {
  const minutes = Math.min(120, Math.max(0, fields.minutes || 0)) || (galleryDemo ? 3 : 0);
  return minutes ? Date.now() + minutes * 60000 : null;
}, () => breakCopy[language].now);
let previousMinutes;
configureScreen(first => {
  localTitle(fields.title || breakCopy[language].title);
  if (first || fields.minutes !== previousMinutes) countdown.restart();
  else countdown.update();
  previousMinutes = fields.minutes;
  renderLatest();
}, renderLatest);
''';
