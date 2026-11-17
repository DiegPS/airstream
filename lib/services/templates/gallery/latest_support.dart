import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

const latestSupportWidth = 640;
const latestSupportHeight = 160;

List<Map<String, Object?>> latestSupportFields(AppLocalizations l) => [
      {
        'key': 'mode',
        'label': l.galleryLatestSupportMode,
        'type': 'select',
        'options': ['newest', 'rotate'],
        'default': 'newest',
      },
      screenNumber('seconds', l.galleryRotationSeconds, 4, 30, 8),
      screenToggle('showEmpty', l.galleryShowEmpty, true),
    ];

Map<String, String> latestSupportFiles() => galleryWidgetFiles(
      latestSupportWidth,
      latestSupportHeight,
      _body,
      _css,
      '$gallerySupportTypes\n$gallerySupportDescriptions\n$_script',
    );

const _body = '''
<section class="widget-panel latest-card">
  <header class="widget-header">
    <span class="gallery-logo" hidden></span><h1 id="title"></h1>
  </header>
  <div id="support-display" aria-live="polite">
    <div id="support-a" class="widget-layer" aria-hidden="true"></div>
    <div id="support-b" class="widget-layer" aria-hidden="true"></div>
  </div>
  <p id="empty" class="widget-empty" hidden></p>
</section>
''';

const _css = r'''
.latest-card {
  position: absolute; inset: 3px;
  border-inline-start: 5px solid var(--accent); padding: 13px 24px;
  display: grid; grid-template-rows: 37px minmax(0, 1fr);
}
.latest-card h1 { font-size: 18px; font-weight: 700; letter-spacing: .07em; text-transform: uppercase; }
#support-display { display: grid; min-width: 0; align-items: center; }
#support-display.fading .widget-layer { transition: opacity .28s ease; }
.latest-name {
  display: grid; grid-template-columns: 10px minmax(0, 1fr); align-items: center; gap: 12px;
  font-size: 34px; font-weight: 700; line-height: 1.15;
}
.latest-detail {
  color: var(--muted); font-size: 23px; padding-inline-start: 22px;
  overflow: hidden; white-space: nowrap; text-overflow: ellipsis;
}
.latest-card .widget-empty { align-self: center; font-size: 25px; }
''';

const _script = r'''
const text = {
  en: {title: 'Latest support', empty: 'No support yet'},
  es: {title: 'Último apoyo', empty: 'Todavía no hay apoyos'}
};
const n = number;
const display = byId('support-display');
const layers = [byId('support-a'), byId('support-b')];
const empty = byId('empty');
let configured = false;
let session;
let selectedType;
let candidates = [];
let front = 0;
let displayedKey;
let entrance;

function show(support, motion) {
  stage.hidden = !support && fields.showEmpty === false;
  display.hidden = !support;
  empty.hidden = !!support;
  if (!support) {
    entrance?.cancel();
    displayedKey = undefined;
    return;
  }
  const key = JSON.stringify([support.id, language]);
  if (key === displayedKey) return;
  entrance?.cancel();
  entrance = null;
  displayedKey = key;
  if (motion === 'fade') {
    front = 1 - front;
    display.classList.add('fading');
  } else {
    display.classList.remove('fading');
    layers[1 - front].replaceChildren();
  }
  const {node: name} = namedEntry('div', support.platform, support.name);
  name.className = 'latest-name';
  const description = supportDescriptions[language][support.type]?.(support) || '';
  const layer = layers[front];
  layer.replaceChildren(name, textElement('p', 'latest-detail', description));
  layer.setAttribute('aria-hidden', 'false');
  layers[1 - front].setAttribute('aria-hidden', 'true');
  showGalleryLayer(layers, front);
  if (motion === 'enter' && !reducedMotion.matches) {
    entrance = layer.animate([{opacity: 0, transform: 'translateY(9px)'},
      {opacity: 1, transform: 'translateY(0)'}], {duration: 260, easing: 'cubic-bezier(.16,1,.3,1)'});
  }
}

const schedule = widgetRotation(() => {
  const index = candidates.findIndex(support => support.type === selectedType);
  const next = candidates[(index + 1) % candidates.length];
  selectedType = next.type;
  show(next, 'fade');
});

function render(animate = false) {
  if (!configured) return;
  if (fields.mode === 'rotate') {
    candidates = supportTypes.map(type => session?.latest?.[type]).filter(Boolean);
    const support = candidates.find(item => item.type === selectedType) || candidates[0];
    selectedType = support?.type;
    show(support);
    schedule(candidates.length);
  } else {
    selectedType = undefined;
    schedule(0);
    show(session?.supporters?.[0], animate ? 'enter' : undefined);
  }
}

Airstream.on('session', (next, meta) => {
  if (meta.replay) entrance?.cancel();
  const latest = next?.supporters?.[0];
  const animate = !meta.replay && latest && !session?.supporters?.some(s => s.id === latest.id);
  session = next;
  render(animate);
});
configureWidget(() => {
  configured = true;
  widgetTitle(text[language].title);
  empty.textContent = text[language].empty;
  render();
});
reducedMotion.addEventListener('change', () => {
  if (reducedMotion.matches) entrance?.cancel();
});
''';
