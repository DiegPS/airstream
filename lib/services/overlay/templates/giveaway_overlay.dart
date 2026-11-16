String giveawayOverlayHtml() => '''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Giveaway</title><style>
* { box-sizing: border-box; }
html, body { width:100%;height:100%;margin:0;overflow:hidden;background:transparent; }
body { display:flex;justify-content:center;align-items:flex-start;padding:24px;font-family:system-ui,sans-serif; }
#giveaway { width:min(560px,100%);padding:18px 20px;border-radius:14px;color:white;background:rgba(20,20,20,.9);border-bottom:5px solid #53FC18;box-shadow:0 8px 28px rgba(0,0,0,.45);overflow-wrap:anywhere; }
#giveaway[hidden] { display:none; }
h1 { margin:0 0 14px;font-size:32px;line-height:1.25; }
p { margin:0;color:#ccc;font-size:17px; }
::selection { background:#53FC18;color:#141414; }
</style></head><body><div id="giveaway" hidden role="status" aria-live="polite"></div><script>
(() => {
  const STRINGS = {
    en: { title: 'Airstream Giveaway', participants: (n) => n + ' participants', closed: 'Entries closed', winner: 'Winner', drawing: 'Drawing…' },
    es: { title: 'Sorteo Airstream', participants: (n) => n + ' participantes', closed: 'Participación cerrada', winner: 'Ganador', drawing: 'Sorteando…' },
  };
  const card = document.getElementById('giveaway');
  let language = 'en', state = null, lastDrawId = null;
  let socket = null, retry = 0, spin = 0, reveal = 0, closing = false, spinning = false;
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
      card.replaceChildren(text('h1', state.winner.name), text('p', strings.winner + ' · ' + state.winner.platform));
    } else {
      card.replaceChildren(text('h1', state.keyword), text('p', state.phase === 'closed' ? strings.closed : strings.participants(state.entrantCount || 0)));
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
    reveal = window.setTimeout(() => { cancelSpin(); render(); }, 2500);
  }
  function connect() {
    // A giveaway may have been cleared while this page was disconnected.
    cancelSpin(); state = null; render();
    const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
    socket = ws;
    ws.addEventListener('open', () => ws.send(JSON.stringify({type:'register', view:'giveaway'})));
    ws.addEventListener('message', (event) => {
      if (ws !== socket) return;
      try {
        const envelope = JSON.parse(event.data);
        if (envelope.type === 'settings' && envelope.data) {
          language = envelope.data.appLanguageCode || 'en'; render();
        } else if (envelope.type === 'giveaway') {
          const next = envelope.data || null;
          const shouldAnimate = !envelope.replay && next && next.phase === 'drawn' && next.winner && next.drawId !== lastDrawId;
          if (next && next.phase === 'drawn') lastDrawId = next.drawId;
          // Duplicate packets and language changes must not restart a live draw.
          if (spinning && next && state && next.drawId === state.drawId && !envelope.replay) { state = next; return; }
          cancelSpin(); state = next;
          if (shouldAnimate) animate(); else render();
        } else if (envelope.type === 'reload') window.location.reload();
      } catch (error) { console.warn('Ignored malformed giveaway message', error); }
    });
    ws.addEventListener('close', () => { if (ws !== socket) return; cancelSpin(); render(); if (!closing) retry = window.setTimeout(connect, 3000); });
    ws.addEventListener('error', () => ws.close());
  }
  connect();
  window.addEventListener('beforeunload', () => { closing = true; window.clearTimeout(retry); cancelSpin(); if (socket) socket.close(); });
})();
</script></body></html>''';
