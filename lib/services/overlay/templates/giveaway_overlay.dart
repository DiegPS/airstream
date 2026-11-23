import 'overlay_font.dart';

String giveawayOverlayHtml() => '''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Giveaway</title><style>
* { box-sizing: border-box; }
html, body { width:100%;height:100%;margin:0;overflow:hidden;background:transparent; }
body { display:flex;justify-content:center;align-items:flex-start;padding:24px;font-family:var(--overlay-font-family,system-ui,sans-serif); }
#giveaway { width:min(560px,100%);padding:18px 20px;border-radius:14px;color:white;background:rgba(20,20,20,.9);border-bottom:5px solid #53FC18;box-shadow:0 8px 28px rgba(0,0,0,.45);overflow-wrap:anywhere; }
#giveaway[hidden] { display:none; }
h1 { margin:0 0 14px;font-size:32px;line-height:1.25; }
p { margin:0;color:#ccc;font-size:17px; }
.platform { display:inline-flex;align-items:center;gap:8px; }
.dot { width:10px;height:10px;border-radius:50%;flex-shrink:0; }
::selection { background:#53FC18;color:#141414; }
</style></head><body><div id="giveaway" hidden role="status" aria-live="polite"></div><script>
$overlayFontScript
(() => {
  const STRINGS = {
    en: { title: 'Airstream Giveaway', participants: (n) => group(n) + ' participants', closed: 'Entries closed', winner: 'Winner', drawing: 'Drawing…' },
    es: { title: 'Sorteo Airstream', participants: (n) => group(n) + ' participantes', closed: 'Participación cerrada', winner: 'Ganador', drawing: 'Sorteando…' },
  };
  const PLATFORMS = { youtube: ['YouTube', '#FF0033'], twitch: ['Twitch', '#9146FF'], kick: ['Kick', '#53FC18'] };
  function group(n) { const s = String(Math.round(Number(n) || 0)); let out = ''; for (let i = 0; i < s.length; i++) { if (i > 0 && s[i - 1] !== '-' && (s.length - i) % 3 === 0) out += String.fromCharCode(0x202f); out += s[i]; } return out; }
  function platformLine(prefix, platform) {
    const [name, color] = PLATFORMS[platform] || [String(platform || ''), '#FFFFFF'];
    const line = document.createElement('p'); line.className = 'platform';
    const dot = document.createElement('span'); dot.className = 'dot'; dot.style.background = color;
    line.append(dot, document.createTextNode(prefix + ' · ' + name));
    return line;
  }
  const card = document.getElementById('giveaway');
  let language = 'en', state = null, lastDrawId = null;
  let socket = null, retry = 0, spin = 0, reveal = 0, advance = 0, closing = false, spinning = false;
  const pending = [];
  function resetDraws() {
    cancelSpin(); window.clearTimeout(advance); advance = 0; pending.length = 0;
  }
  function nextDraw() {
    if (!pending.length || spinning || advance) return;
    state = pending.shift();
    animate();
  }
  function cancelSpin() {
    window.clearInterval(spin); window.clearTimeout(reveal); spinning = false;
  }
  function text(tag, value) {
    const node = document.createElement(tag); node.textContent = value; return node;
  }
  function render() {
    const strings = STRINGS[language] || STRINGS.en;
    document.title = strings.title;
    document.documentElement.lang = language;
    card.hidden = !state;
    if (!state) { card.replaceChildren(); return; }
    if (spinning) return;
    if (state.phase === 'drawn' && state.winner) {
      card.replaceChildren(text('h1', state.winner.name), platformLine(strings.winner, state.winner.platform));
    } else {
      card.replaceChildren(text('h1', state.keyword), text('p', state.phase !== 'open' ? strings.closed : strings.participants(state.entrantCount || 0)));
    }
  }
  function animate() {
    spinning = true;
    const name = text('h1', '');
    const strings = STRINGS[language] || STRINGS.en;
    card.hidden = false;
    card.replaceChildren(name, text('p', strings.drawing));
    const tick = () => { name.textContent = Array.from({length: 3}, () => String.fromCharCode(65 + Math.floor(Math.random() * 26))).join(' '); };
    tick(); spin = window.setInterval(tick, 80);
    reveal = window.setTimeout(() => {
      cancelSpin(); render();
      if (pending.length) advance = window.setTimeout(() => { advance = 0; nextDraw(); }, 1600);
    }, 2500);
  }
  function connect() {
    // A giveaway may have been cleared while this page was disconnected.
    resetDraws(); state = null; render();
    const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
    socket = ws;
    ws.addEventListener('open', () => ws.send(JSON.stringify({type:'register', view:'giveaway'})));
    ws.addEventListener('message', (event) => {
      if (ws !== socket) return;
      try {
        const envelope = JSON.parse(event.data);
        if (envelope.type === 'settings' && envelope.data) {
          applyOverlayFont(envelope.data);
          language = envelope.data.appLanguageCode || 'en'; render();
        } else if (envelope.type === 'giveaway') {
          const next = envelope.data || null;
          if (next?.phase === 'drawn' && !envelope.replay) {
            const hidden = new Set(next.hiddenDrawIds);
            if (!next.winner) hidden.add(next.drawId);
            for (let i = pending.length - 1; i >= 0; i--) {
              if (hidden.has(pending[i].drawId)) pending.splice(i, 1);
            }
            if (state?.winner && hidden.has(state.drawId)) {
              cancelSpin();
              window.clearTimeout(advance); advance = 0;
              state = null;
            }
            if (next.winner && next.drawId !== lastDrawId) {
              pending.push(next);
            }
            lastDrawId = next.drawId;
            if (!state?.winner && !pending.length) {
              state = next;
              render();
            }
            nextDraw();
            return;
          }
          resetDraws();
          state = next;
          lastDrawId = next?.phase === 'drawn' ? next.drawId : null;
          render();
        } else if (envelope.type === 'reload') window.location.reload();
      } catch (error) { console.warn('Ignored malformed giveaway message', error); }
    });
    ws.addEventListener('close', () => { if (ws !== socket) return; resetDraws(); state = null; lastDrawId = null; render(); if (!closing) retry = window.setTimeout(connect, 3000); });
    ws.addEventListener('error', () => ws.close());
  }
  connect();
  window.addEventListener('beforeunload', () => { closing = true; window.clearTimeout(retry); resetDraws(); if (socket) socket.close(); });
})();
</script></body></html>''';
