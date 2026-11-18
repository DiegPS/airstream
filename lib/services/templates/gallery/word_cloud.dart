import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

List<Map<String, Object?>> wordCloudFields(AppLocalizations l) => [
      screenNumber('minLength', l.galleryWordCloudMinLength, 2, 16, 3),
      screenNumber('maxWords', l.galleryWordCloudMaxWords, 3, 40, 18),
      screenNumber('refresh', l.galleryWordCloudRefresh, 1, 30, 4),
    ];

Map<String, String> wordCloudFiles() => galleryWidgetFiles(
    960,
    480,
    _body,
    _css,
    'const copy = ${widgetCopy((l) => {
          'title': l.galleryWordCloud
        })};\n$_script');

const _body = """
<section class="widget-panel cloud">
  <span class="gallery-logo corner-logo" hidden></span>
  <h1 id="title"></h1>
  <ul id="words"></ul>
</section>
""";

const _css = r"""
.cloud { position: absolute; inset: 8px; display: flex; flex-direction: column;
  padding: 22px 30px; border-block-start: 3px solid var(--accent); }
.cloud h1 { margin: 0; text-align: center; font-size: 25px; color: var(--muted); }
#words { margin: 12px 0 0; padding: 0; list-style: none; flex: 1; overflow: hidden;
  display: flex; flex-wrap: wrap; justify-content: center; align-content: center; gap: 7px 20px; }
#words li { max-width: 240px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis;
  font-size: var(--word-size, 24px); font-weight: 730; line-height: 1.14; }
#words li:nth-child(3n + 1) { color: var(--accent); }
#words li:nth-child(3n + 2) { color: var(--muted); }
""";

const _script = r"""
const words = byId('words');
const recent = [];
const windowMs = 5 * 60 * 1000;
const stop = new Set((
  'a an and are as at be been being but by can could did do does for from had has have he her here ' +
  'him his how i if in into is it its just me might more most my no nor not of on or our out ' +
  'over she so some than that the their them then there these they this those to too up us very ' +
  'was we were what when where which who why will with would you your ' +
  'a al algo ante aquel aqui aquí asi así aunque bien cada como cómo con contra cual cuál cuando cuándo ' +
  'de del desde donde dónde dos el él ella ellas ellos en entre era es esa esas ese eso esos esta está ' +
  'estaba están estas este esto estos fue ha hasta hay la las le les lo los mas más me mi mis mucha mucho ' +
  'muy nada ni no nos o otra otro para pero por porque pues que qué quien quién se sé si sí sin sobre ' +
  'solo sólo son su sus tal tambien también tan tanto te tiene toda todo todos tras tu tú tus un una unas ' +
  'uno unos usted ustedes ya yo y'
).split(/\s+/));
const limit = (key, min, max, fallback) =>
  Math.round(Math.max(min, Math.min(max, fields[key] || fallback)));
let refresh;
function prune(now) {
  while (recent.length && (recent.length > 250 || now - recent[0].at > windowMs)) recent.shift();
}
function render() {
  prune(Date.now());
  const minimum = limit('minLength', 2, 16, 3);
  const counts = new Map();
  for (const message of recent) {
    for (const word of message.words) {
      if (word.length >= minimum) counts.set(word, (counts.get(word) || 0) + 1);
    }
  }
  const ranked = [...counts].sort(([a,x],[b,y]) => y-x || a.localeCompare(b, language))
    .slice(0, limit('maxWords', 3, 40, 18));
  const max = ranked[0]?.[1] || 1;
  words.replaceChildren(...ranked.map(([word, count]) => {
    const node = textElement('li', '', word);
    node.title = word + ' · ' + number(count);
    node.style.setProperty('--word-size', (18 + 30 * Math.sqrt(count / max)) + 'px');
    return node;
  }));
  stage.hidden = !ranked.length;
}
Airstream.on('chat', (message, meta) => {
  if (!message || meta.replay) return;
  const source = message.items?.length
    ? message.items.filter(item => item.kind === 'text').map(item => item.text).join(' ')
    : String(message.text || '');
  const tokens = source.slice(0, 600).normalize('NFC').toLowerCase()
    .replace(/https?:\/\/\S+/g, ' ').match(/[\p{L}\p{M}]+/gu) || [];
  const now = Date.now();
  const words = tokens.filter(word => word.length <= 36 && !stop.has(word));
  if (words.length) {
    const {id, platform, youtubeStreamOrientation, author, authorChannelId} = message;
    recent.push({at: now, words, id, platform, youtubeStreamOrientation, author, authorChannelId});
  }
  prune(now);
});
Airstream.on('delete', event => {
  let changed = false;
  for (let i = recent.length - 1; i >= 0; i--) {
    if (matchesChatDeletion(recent[i], event)) {
      recent.splice(i, 1);
      changed = true;
    }
  }
  if (changed) render();
});
configureWidget(() => {
  widgetTitle(copy[language].title);
  clearInterval(refresh);
  refresh = setInterval(render, limit('refresh', 1, 30, 4) * 1000);
  render();
});
""";
