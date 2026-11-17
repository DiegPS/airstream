String pollOverlayHtml() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Poll</title>
<style>
  * { box-sizing: border-box; }
  html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; background: transparent; }
  body { display: flex; align-items: flex-start; justify-content: center; padding: 24px; font-family: system-ui, sans-serif; }
  #poll {
    width: min(560px, 100%);
    padding: 18px 20px;
    border-radius: 14px;
    color: #fff;
    background: rgba(20, 20, 20, .9);
    border-bottom: 5px solid #53FC18;
    box-shadow: 0 8px 28px rgba(0, 0, 0, .45);
    opacity: 0;
    transform: translateY(-8px);
    transition: opacity 180ms ease, transform 180ms ease;
  }
  #poll.visible { opacity: 1; transform: none; }
  .kicker { color: #53FC18; font-size: 13px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
  .question { margin: 6px 0 14px; font-size: 24px; font-weight: 800; line-height: 1.25; }
  .option { margin: 10px 0; }
  .row { display: flex; justify-content: space-between; gap: 12px; font-size: 17px; font-weight: 700; }
  .command { color: #53FC18; margin-right: 6px; }
  .count { color: rgba(255, 255, 255, .75); white-space: nowrap; }
  .bar { height: 10px; margin-top: 6px; border-radius: 6px; background: rgba(255, 255, 255, .12); overflow: hidden; }
  .fill { height: 100%; border-radius: 6px; background: #53FC18; transition: width 300ms ease; }
  .option.leader .fill { background: #FFC83D; }
  .footer { margin-top: 14px; color: rgba(255, 255, 255, .7); font-size: 14px; font-weight: 600; }
</style>
</head>
<body>
<div id="poll" role="status" aria-live="polite"></div>
<script>
(() => {
  // 208 seconds reads better as 3:28.
  const clock = (s) => s < 60 ? s + ' s' : Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  const STRINGS = {
    en: { poll: 'Poll', vote: 'Vote in chat with', votes: (n) => n === 1 ? '1 vote' : n + ' votes', left: (s) => clock(s) + ' left', closed: 'Final results' },
    es: { poll: 'Encuesta', vote: 'Vota en el chat con', votes: (n) => n === 1 ? '1 voto' : n + ' votos', left: (s) => 'Quedan ' + clock(s), closed: 'Resultados finales' },
  };
  const card = document.getElementById('poll');
  let language = 'en';
  let poll = null;
  let socket = null;
  let retry = 0;
  let ticker = 0;
  let closing = false;

  function text(tag, className, value) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = value;
    return node;
  }

  function footerText(strings) {
    const total = strings.votes(poll.total || 0);
    if (poll.closed) return strings.closed + ' · ' + total;
    if (poll.endsAt) {
      const seconds = Math.max(0, Math.ceil((poll.endsAt - Date.now()) / 1000));
      return total + ' · ' + strings.left(seconds);
    }
    return total;
  }

  function render() {
    window.clearInterval(ticker);
    if (!poll) {
      card.classList.remove('visible');
      return;
    }
    const strings = STRINGS[language] || STRINGS.en;
    const leader = Math.max(0, ...poll.options.map((o) => o.votes));
    const nodes = [text('div', 'kicker', strings.poll), text('div', 'question', poll.question)];
    poll.options.forEach((option, index) => {
      const row = document.createElement('div');
      row.className = 'option' + (option.votes > 0 && option.votes === leader ? ' leader' : '');
      const head = document.createElement('div');
      head.className = 'row';
      const label = document.createElement('span');
      label.append(text('span', 'command', '!' + (index + 1)), document.createTextNode(option.label));
      head.append(label, text('span', 'count', option.percent + '% · ' + option.votes));
      const bar = document.createElement('div');
      bar.className = 'bar';
      const fill = document.createElement('div');
      fill.className = 'fill';
      fill.style.width = option.percent + '%';
      bar.appendChild(fill);
      row.append(head, bar);
      nodes.push(row);
    });
    const footer = text('div', 'footer', '');
    nodes.push(footer);
    card.replaceChildren(...nodes);
    const update = () => { footer.textContent = footerText(strings); };
    update();
    if (!poll.closed && poll.endsAt) ticker = window.setInterval(update, 1000);
    card.classList.add('visible');
  }

  function connect() {
    const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
    socket = new WebSocket(protocol + location.host + '/ws');
  socket.addEventListener('open', () => {
    socket.send(JSON.stringify({ type: 'register', view: 'poll' }));
  });
    socket.addEventListener('message', (event) => {
      try {
        const envelope = JSON.parse(event.data);
        if (envelope.type === 'settings' && envelope.data) {
          language = envelope.data.appLanguageCode || 'en';
          render();
        } else if (envelope.type === 'poll') {
          poll = envelope.data || null;
          render();
        } else if (envelope.type === 'reload') {
          window.location.reload();
        }
      } catch (error) {
        console.warn('Ignored malformed poll message', error);
      }
    });
    socket.addEventListener('close', () => {
      if (!closing) retry = window.setTimeout(connect, 3000);
    });
    socket.addEventListener('error', () => socket.close());
  }

  connect();
  window.addEventListener('beforeunload', () => {
    closing = true;
    window.clearTimeout(retry);
    window.clearInterval(ticker);
    if (socket) socket.close();
  });
})();
</script>
</body>
</html>''';
