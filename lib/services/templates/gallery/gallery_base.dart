import 'package:airstream/l10n/generated/app_localizations.dart';

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
* { box-sizing: border-box; }
body { margin: 0; background: transparent; }
[hidden] { display: none !important; }
.gallery-logo { flex: 0 0 40px; height: 40px; }
.gallery-logo img { display: block; width: 100%; height: 100%; object-fit: contain; }
::selection { color: var(--surface); background: var(--theme-accent); }
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation: none !important; transition: none !important; }
}
''';

const galleryScript = r'''
const fonts = ['DM Sans', 'Barlow', 'Outfit'];
const root = document.documentElement;
const branding = document.querySelector('.gallery-logo');
let logo;
let fontSheet;
let activeFont;
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
  const url = Airstream.mediaUrl(fields.logo);
  branding.hidden = !url;
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
