import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';

import 'package:flutter/widgets.dart' show Locale;

import 'gallery_base.dart';

List<Map<String, Object?>> queueListFields(AppLocalizations l) => [
      screenNumber('count', l.galleryQueueCount, 5, 30, 10),
      screenToggle('hideWhenClosed', l.galleryQueueHideClosed, false),
    ];

Map<String, String> queueListFiles() => {
      'index.html': _html,
      'style.css': '$galleryCss\n$_css',
      'script.js':
          '(() => {\n"use strict";\n$galleryScript\nconst copy = ${jsonEncode(_copy)};\n$_script\n})();',
    };

final _copy = {
  for (final language in ['en', 'es'])
    language: _localizedCopy(lookupAppLocalizations(Locale(language))),
};

Map<String, String> _localizedCopy(AppLocalizations l) => {
      'heading': l.queueTitle,
      'open': l.queueOpenStatus,
      'paused': l.queuePaused,
      'closed': l.queueClosed,
      'join': l.queueJoinHint('{command}'),
      'joinWhenOpen': l.queueJoinWhenOpen('{command}'),
      'playing': l.queuePlaying,
      'waiting': l.galleryQueueWaiting,
      'empty': l.queueEmpty,
      'nobody': l.queueNobodyPlaying,
      'more': l.galleryQueueMore('{count}'),
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
  <main id="queue" aria-labelledby="heading" hidden>
    <header>
      <span class="gallery-logo" hidden></span>
      <h1 id="heading"></h1>
      <span id="status"></span>
    </header>
    <p id="join"></p>
    <section aria-labelledby="playing-heading">
      <h2 id="playing-heading"></h2>
      <ul id="playing"></ul>
      <p id="nobody"></p>
    </section>
    <section aria-labelledby="waiting-heading">
      <h2 id="waiting-heading"></h2>
      <ol id="waiting"></ol>
      <p id="empty"></p>
      <p id="more" hidden></p>
    </section>
  </main>
</body>
</html>
''';

const _css = r'''
#queue {
  --accent: var(--custom-accent, var(--theme-accent));
  width: min(100% - 32px, 448px);
  max-height: calc(100dvh - 32px);
  overflow: auto;
  scrollbar-width: thin;
  margin: 16px auto;
  padding: 16px;
  border-radius: var(--radius);
  border-top: 3px solid var(--accent);
  box-shadow: var(--shadow);
  background: var(--surface);
}
header { display: flex; align-items: center; gap: 10px; }
h1 { flex: 1; min-width: 0; margin: 0; font-size: clamp(1.25rem, 6vw, 1.65rem); }
#status {
  font-size: .75rem; font-weight: 700; padding: 4px 10px;
  border: 1px solid var(--line); border-radius: 20px; background: var(--row);
}
#queue[data-status="open"] #status { border-color: var(--accent); }
#queue[data-status="paused"] #status { border-color: #ffb15c; }
p { font-size: .875rem; color: var(--muted); margin: 4px 0 0; }
#join { overflow-wrap: anywhere; }
section { margin-top: 10px; padding-top: 8px; border-top: 1px solid var(--line); }
h2 { margin: 0 0 5px; font-size: .875rem; font-weight: 700; }
ul, ol { display: grid; gap: 3px 5px; margin: 0; padding: 0; list-style: none; }
#playing, #queue[data-dense="true"] #waiting { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.queue-row {
  display: flex; min-width: 0; gap: 6px; align-items: center;
  min-height: 24px; padding: 2px 6px;
  background: var(--row); border: 1px solid var(--line);
  border-radius: calc(var(--radius) / 2); font-size: .8125rem;
}
.queue-row[data-priority="true"] { border-inline-start-color: var(--accent); }
.position { flex: 0 0 2ch; color: var(--muted); font-variant-numeric: tabular-nums; }
.dot { flex: 0 0 6px; height: 6px; border-radius: 50%; background: var(--platform); }
.name, .note { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.name { font-weight: 650; }
.note { flex: 0 1 42%; margin-inline-start: auto; color: var(--muted); font-size: .75rem; }
#more { text-align: end; }
.enter { animation: queue-in .22s ease-out both; }
.leave { z-index: 1; pointer-events: none; animation: queue-out .18s ease-in both; }
@keyframes queue-in { from { opacity: .15; transform: translateY(-5px); } }
@keyframes queue-out { to { opacity: 0; transform: translateX(8px); } }
''';

const _script = r'''
const panel = byId('queue');
const waiting = byId('waiting');
const playing = byId('playing');
const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
const waitingRows = new Map(), playingRows = new Map();
let known = new Set(), queue, fields, language;

function makeRow(entry, numbered) {
  const element = document.createElement('li');
  element.className = 'queue-row';
  const position = document.createElement('span');
  position.className = 'position';
  position.hidden = !numbered;
  const dot = document.createElement('span');
  dot.className = 'dot';
  dot.title = {youtube: 'YouTube', twitch: 'Twitch', kick: 'Kick'}[entry.platform] || '';
  dot.style.setProperty('--platform', Airstream.platformColor(entry.platform));
  const name = document.createElement('span');
  name.className = 'name';
  const note = document.createElement('span');
  note.className = 'note';
  element.append(position, dot, name, note);
  return {element, position, name, note};
}

function leave(element) {
  const rect = element.getBoundingClientRect();
  Object.assign(element.style, {
    position: 'fixed', top: rect.top + 'px', left: rect.left + 'px', width: rect.width + 'px'
  });
  element.setAttribute('aria-hidden', 'true');
  element.classList.remove('enter');
  element.classList.add('leave');
  setTimeout(() => element.remove(), 180);
}

function updateRows(list, rows, entries, numbered, animate, currentIds) {
  const visible = new Set(entries.map(entry => entry.id));
  for (const [id, row] of rows) {
    if (visible.has(id)) continue;
    if (animate && !currentIds.has(id)) leave(row.element);
    else row.element.remove();
    rows.delete(id);
  }
  for (const [i, entry] of entries.entries()) {
    let row = rows.get(entry.id);
    if (!row) {
      row = makeRow(entry, numbered);
      rows.set(entry.id, row);
      if (animate && !known.has(entry.id)) {
        row.element.classList.add('enter');
        row.element.addEventListener('animationend', () => row.element.classList.remove('enter'), {once: true});
      }
    }
    if (numbered) row.position.textContent = i + 1;
    row.element.dataset.priority = String(entry.priority === true);
    row.name.textContent = entry.name;
    row.note.textContent = entry.note;
    row.note.hidden = !entry.note;
    const before = list.children[i];
    if (before !== row.element) list.insertBefore(row.element, before || null);
  }
}

function render(animate) {
  if (!fields) return;
  if (!queue) {
    panel.hidden = true;
    updateRows(waiting, waitingRows, [], true, false, new Set());
    updateRows(playing, playingRows, [], false, false, new Set());
    known.clear();
    return;
  }
  const text = copy[language];
  const limit = Math.round(Math.min(30, Math.max(5, fields.count || 10)));
  const shown = queue.entries.slice(0, limit);
  panel.hidden = queue.status === 'closed' && fields.hideWhenClosed === true;
  panel.dataset.status = queue.status;
  panel.dataset.dense = String(shown.length > 14);
  byId('heading').textContent = document.title = text.heading;
  byId('status').textContent = text[queue.status];
  const hint = queue.status === 'open' ? text.join : text.joinWhenOpen;
  byId('join').textContent = hint.replace('{command}', queue.command);
  byId('playing-heading').textContent = text.playing;
  byId('waiting-heading').textContent = text.waiting;
  byId('empty').textContent = text.empty;
  byId('empty').hidden = shown.length !== 0;
  byId('nobody').textContent = text.nobody;
  byId('nobody').hidden = queue.playing.length !== 0;
  const more = queue.entries.length - shown.length;
  byId('more').textContent = text.more.replace('{count}', String(more));
  byId('more').hidden = more === 0;
  const ids = entries => new Set(entries.map(entry => entry.id));
  const waitingIds = ids(queue.entries), playingIds = ids(queue.playing);
  const moving = animate && !panel.hidden && !motion.matches;
  updateRows(waiting, waitingRows, shown, true, moving, waitingIds);
  updateRows(playing, playingRows, queue.playing, false, moving, playingIds);
  known = new Set([...waitingIds, ...playingIds]);
}

Airstream.on('fields', values => {
  fields = values || {};
  language = applyGalleryFields(fields);
  render(false);
});
Airstream.on('queue', (state, meta) => {
  queue = state;
  render(!meta.replay);
});
''';
