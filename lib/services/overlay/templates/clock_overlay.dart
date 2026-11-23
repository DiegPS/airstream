import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

import 'overlay_font.dart';

String _clockCopy() => jsonEncode({
      for (final language in ['en', 'es'])
        language: _clockStrings(lookupAppLocalizations(Locale(language))),
    });

Map<String, String> _clockStrings(AppLocalizations l) => {
      'title': l.clockTitle,
      'paused': l.clockPaused,
      'ended': l.clockEnded,
    };

String clockOverlayHtml() => '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Airstream Timer</title><style>
* { box-sizing: border-box; }
body { margin: 0; padding: 20px; background: transparent; color: #fff; overflow: hidden;
  font-family: var(--overlay-font-family, system-ui, sans-serif); }
#clock { display: inline-grid; gap: 4px; justify-items: center; max-width: 100%;
  padding: 16px 24px; border-radius: 18px; background: rgba(19, 24, 21, .94);
  box-shadow: 0 6px 18px #0006; border-block-end: 3px solid #53fc18; }
#clock[hidden] { display: none; }
#label { font-size: 20px; overflow-wrap: anywhere; text-align: center; }
#value { font-size: clamp(26px, 12vw, 76px); font-variant-numeric: tabular-nums;
  line-height: 1; font-weight: 800; }
#status { color: #b8e9a6; font-size: 16px; }
#clock[data-style=compact] { grid-auto-flow: column; align-items: baseline; gap: 10px; padding: 9px 14px; }
#clock[data-style=compact] #value { font-size: clamp(20px, 7vw, 36px); }
#clock[data-style=ring][data-mode=countdown] {
  width: min(100%, 210px); aspect-ratio: 1; align-content: center; border: 6px solid transparent;
  border-radius: 50%; background: linear-gradient(#131815,#131815) padding-box,
    conic-gradient(#53fc18 var(--progress, 100%), #334034 0) border-box; }
#clock[data-style=ring][data-mode=countdown] { grid-template-columns: minmax(0, 1fr); }
#clock[data-style=ring][data-mode=countdown] #value { font-size: clamp(20px, 10vw, 41px); }
#clock[data-style=ring][data-mode=countdown][data-hours=true] #value { font-size: clamp(16px, 7vw, 30px); }
#clock[data-style=ring][data-mode=countdown] #label {
  display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2;
  overflow: hidden; font-size: 15px; }
#label[hidden], #status[hidden] { display: none !important; }
</style></head><body>
<section id="clock" hidden><div id="label"></div><div id="value"></div><div id="status"></div></section>
<script>
$overlayFontScript
(() => {
  const root = document.getElementById('clock'), label = document.getElementById('label'),
    value = document.getElementById('value'), status = document.getElementById('status');
  const strings = ${_clockCopy()};
  let state, offset = 0, language = 'en', socket, retry, closing = false;
  const pad = n => String(n).padStart(2, '0');
  function duration(ms, countdown) {
    const seconds = (countdown ? Math.ceil : Math.floor)(Math.max(0, ms) / 1000);
    const minutes = Math.floor(seconds / 60);
    return (minutes >= 60 ? Math.floor(minutes / 60) + ':' + pad(minutes % 60) : minutes)
      + ':' + pad(seconds % 60);
  }
  function render() {
    if (!state) return;
    const now = Date.now() + offset;
    const countdown = state.mode === 'countdown';
    const total = state.durationSeconds * 1000;
    const ms = state.phase === 'running'
      ? (countdown ? Math.max(0, state.anchorMs - now) : state.valueMs + Math.max(0, now - state.anchorMs))
      : (countdown && state.phase === 'idle' ? total : state.valueMs);
    const phase = countdown && state.phase === 'running' && ms === 0 ? 'ended' : state.phase;
    const time = new Date(now);
    root.hidden = false;
    root.dataset.style = state.style;
    root.dataset.mode = state.mode;
    root.style.setProperty('--progress', Math.min(100, ms / total * 100) + '%');
    label.textContent = state.label;
    label.hidden = !state.label;
    value.textContent = state.mode === 'clock'
      ? [time.getHours(), time.getMinutes(), time.getSeconds()].map(pad).join(':')
      : duration(ms, countdown);
    // h:mm:ss needs smaller digits to stay inside the ring.
    root.dataset.hours = String(value.textContent.split(':').length > 2);
    status.textContent = (strings[language] || strings.en)[phase] || '';
    status.hidden = !status.textContent;
  }
  function connect() {
    const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
    socket = ws;
    ws.addEventListener('open', () => ws.send(JSON.stringify({type:'register', view:'clock'})));
    ws.addEventListener('message', event => {
      if (ws !== socket) return;
      try {
        const e = JSON.parse(event.data);
        if (e.type === 'clock' && e.data) {
          state = e.data;
          offset = state.serverNowMs - Date.now();
          render();
        } else if (e.type === 'settings' && e.data) {
          applyOverlayFont(e.data);
          language = e.data.appLanguageCode || 'en';
          document.documentElement.lang = language;
          document.title = (strings[language] || strings.en).title;
          render();
        } else if (e.type === 'reload') location.reload();
      } catch (error) {
        console.warn('Ignored malformed clock message', error);
      }
    });
    ws.addEventListener('close', () => {
      if (closing || ws !== socket) return;
      // A lost server may have reset the clock: show nothing until a fresh snapshot.
      state = null;
      root.hidden = true;
      retry = setTimeout(connect, 3000);
    });
    ws.addEventListener('error', () => ws.close());
  }
  const refresh = setInterval(render, 200);
  connect();
  window.addEventListener('beforeunload', () => {
    closing = true; clearInterval(refresh); clearTimeout(retry); socket?.close();
  });
})();
</script></body></html>''';
