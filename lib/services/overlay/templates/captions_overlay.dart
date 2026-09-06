String captionsOverlayHtml() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Captions</title>
<style>
  * { box-sizing: border-box; }
  html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; background: transparent; }
  body { display: flex; align-items: flex-end; justify-content: center; padding: 4vh 4vw; }
  #caption {
    max-width: 92vw;
    padding: .35em .65em;
    border-radius: .35em;
    color: white;
    background: rgba(0, 0, 0, .72);
    font: 700 clamp(24px, 4vw, 64px)/1.25 system-ui, sans-serif;
    text-align: center;
    text-shadow: 0 2px 4px #000;
    opacity: 0;
    transition: opacity 160ms ease;
  }
  #caption.visible { opacity: 1; }
</style>
</head>
<body>
<div id="caption" role="status" aria-live="polite"></div>
<script>
(() => {
  const caption = document.getElementById('caption');
  let retry;
  let hide;
  const connect = () => {
    const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
    const ws = new WebSocket(protocol + location.host + '/ws');
    ws.onmessage = (event) => {
      try {
        const envelope = JSON.parse(event.data);
        if (envelope.type === 'reload') return location.reload();
        if (envelope.type !== 'caption') return;
        caption.textContent = envelope.data.text || '';
        caption.classList.toggle('visible', Boolean(caption.textContent));
        window.clearTimeout(hide);
        hide = window.setTimeout(() => caption.classList.remove('visible'), 7000);
      } catch (error) {
        console.warn('Ignored malformed caption message', error);
      }
    };
    ws.onclose = () => { retry = window.setTimeout(connect, 3000); };
  };
  connect();
  window.addEventListener('beforeunload', () => {
    window.clearTimeout(retry);
    window.clearTimeout(hide);
  });
})();
</script>
</body>
</html>''';
