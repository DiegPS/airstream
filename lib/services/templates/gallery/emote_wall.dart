import 'package:airstream/l10n/generated/app_localizations.dart';

import 'gallery_base.dart';

const emoteWallWidth = 960;
const emoteWallHeight = 540;

List<Map<String, Object?>> emoteWallFields(AppLocalizations l) => [
      screenNumber('maxEmotes', l.galleryEmoteWallMax, 1, 80, 24),
      screenNumber('size', l.galleryEmoteWallSize, 24, 160, 64),
      screenNumber('lifetime', l.galleryEmoteWallLifetime, 1, 20, 6),
    ];

Map<String, String> emoteWallFiles() => galleryWidgetFiles(
    emoteWallWidth,
    emoteWallHeight,
    _body,
    _css,
    'const copy = ${widgetCopy((l) => {
          'title': l.galleryEmoteWall
        })};\n$_script');

const _body = """
<span class="gallery-logo corner-logo" hidden></span>
<h1 id="title" class="emote-title"></h1>
<div id="emotes"></div>
""";

const _css = r"""
.emote-title { position: absolute; width: 1px; height: 1px; clip-path: inset(50%); overflow: hidden; }
.wall-emote { position: absolute; inset: 0 auto auto 0; width: var(--size); height: var(--size);
  object-fit: contain; transform: translate(var(--x1), var(--y1));
  animation: emote-bounce var(--lifetime) linear both; }
@keyframes emote-bounce {
  0%   { transform: translate(var(--x1), var(--y1)); opacity: 0; }
  12%  { opacity: 1; }
  35%  { transform: translate(var(--x2), var(--y2)); }
  65%  { transform: translate(var(--x3), var(--y1)); }
  85%  { opacity: 1; }
  100% { transform: translate(var(--x4), var(--y2)); opacity: 0; }
}
@media (prefers-reduced-motion: reduce) { .wall-emote { animation: none; } }
""";

const _script = r"""
const emotes = byId('emotes');
const active = [];
const limit = (key, min, max, fallback) =>
  Math.round(Math.max(min, Math.min(max, fields[key] || fallback)));
let ready = false;
let max = 24;
let size = 64;
let lifetime = 6;
function remove(entry) {
  const index = active.indexOf(entry);
  if (index < 0) return;
  active.splice(index, 1);
  clearTimeout(entry.timer);
  entry.img.remove();
  stage.hidden = active.length === 0;
}
function spawn(item) {
  while (active.length >= max) remove(active[0]);
  const img = document.createElement('img');
  img.className = 'wall-emote';
  img.alt = String(item.alt || '');
  img.style.setProperty('--size', size + 'px');
  img.style.setProperty('--lifetime', lifetime + 's');
  for (let i = 1; i <= 4; i++) {
    img.style.setProperty('--x' + i, Math.round(Math.random() * (960 - size)) + 'px');
  }
  img.style.setProperty('--y1', Math.round(Math.random() * (540 - size)) + 'px');
  img.style.setProperty('--y2', (540 - size) + 'px');
  const entry = {img, timer: setTimeout(() => remove(entry), lifetime * 1000)};
  active.push(entry);
  img.addEventListener('error', () => remove(entry), {once: true});
  img.src = item.url;
  emotes.appendChild(img);
  stage.hidden = false;
}
Airstream.on('chat', (message, meta) => {
  if (!ready || meta.replay || !Array.isArray(message?.items)) return;
  const images = message.items.filter(item => item.kind === 'emoji' &&
    typeof item.url === 'string' && /^(https?:\/\/|data:image\/)/i.test(item.url));
  for (const item of images.slice(0, max)) spawn(item);
});
configureWidget(() => {
  widgetTitle(copy[language].title);
  max = limit('maxEmotes', 1, 80, 24);
  size = limit('size', 24, 160, 64);
  lifetime = limit('lifetime', 1, 20, 6);
  while (active.length > max) remove(active[0]);
  ready = true;
});
""";
