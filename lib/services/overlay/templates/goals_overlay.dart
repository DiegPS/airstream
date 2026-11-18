import 'overlay_font.dart';

String goalsOverlayHtml({bool googleFontsAllowed = false}) => '''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Airstream Goals</title><style>
*{box-sizing:border-box}html,body{margin:0;background:transparent;overflow:hidden;font-family:var(--overlay-font-family,system-ui,sans-serif)}body{padding:24px;color:white}#goals{width:min(560px,100%)}#goals[hidden]{display:none}.goal{padding:18px 20px;margin-bottom:12px;border-radius:14px;background:rgba(20,20,20,.9);overflow-wrap:anywhere}.heading{display:flex;justify-content:space-between;gap:16px;font-size:22px;margin-bottom:12px}.title{min-width:0}.count{flex-shrink:0;font-variant-numeric:tabular-nums}.track{height:14px;background:#444;border-radius:20px;overflow:hidden}.fill{height:100%;background:#53FC18;border-radius:20px;transition:width .5s ease}.reached .fill{background:#ffd166}.celebrate{animation:glow 2s ease}.notice{color:#ffd166;margin-top:8px;font-weight:700}.notice:empty{display:none}.percent{margin-top:6px;color:#ccc;font-variant-numeric:tabular-nums}@keyframes glow{0%,100%{box-shadow:0 0 0 transparent}35%,65%{box-shadow:0 0 24px #ffd166}}@media(prefers-reduced-motion:reduce){.fill{transition:none}.celebrate{animation:none}}
</style></head><body><div id="goals" hidden aria-live="polite"></div><script>
${overlayFontScript(googleFontsAllowed)}
(() => {
  const STRINGS = {en:{title:'Airstream Goals',reached:'Goal reached!'},es:{title:'Metas Airstream',reached:'¡Meta cumplida!'}};
  const root = document.getElementById('goals');
  const rows = new Map();
  let language='en', socket=null, retry=0, closing=false;
  // A narrow space groups thousands the same way in every language.
  function group(n) { const s = String(Math.round(Number(n) || 0)); let out = ''; for (let i = 0; i < s.length; i++) { if (i > 0 && s[i - 1] !== '-' && (s.length - i) % 3 === 0) out += String.fromCharCode(0x202f); out += s[i]; } return out; }
  function node(tag, cls) { const n=document.createElement(tag); n.className=cls; return n; }
  function strings() {return STRINGS[language] || STRINGS.en;}
  function localize() {
    document.title=strings().title; document.documentElement.lang=language;
    for (const row of rows.values()) if (row.timer) row.notice.textContent=strings().reached;
  }
  function clear() {for(const row of rows.values()) window.clearTimeout(row.timer); rows.clear();root.replaceChildren();root.hidden=true;}
  function render(goals,replay) {
    const ids=new Set(goals.map(g=>g.id));
    for (const [id,row] of rows) if (!ids.has(id)) {window.clearTimeout(row.timer);row.box.remove();rows.delete(id);}
    root.hidden=goals.length===0;
    for (const g of goals) {
      let row=rows.get(g.id);
      const celebrate=!!row && !row.reached && g.reached && !replay && !row.celebrated;
      if(!row) {
        const box=node('section','goal'),heading=node('div','heading'),title=node('span','title'),count=node('span','count'),track=node('div','track'),fill=node('div','fill'),notice=node('div','notice'),percent=node('div','percent');
        heading.append(title,count);track.append(fill);box.append(heading,track,percent,notice);root.append(box);
        row={box,title,count,fill,notice,percent,reached:false,celebrated:!!g.reached,timer:0}; rows.set(g.id,row);
      }
      row.title.textContent=g.title;row.count.textContent=group(g.current)+' / '+group(g.target);
      row.percent.textContent=Math.round(g.percent)+'%';row.fill.style.width=Math.max(0,Math.min(100,g.percent))+'%';
      row.box.classList.toggle('reached',!!g.reached);row.reached=!!g.reached;
      if(celebrate) {row.celebrated=true;row.box.classList.add('celebrate');row.notice.textContent=strings().reached;row.timer=window.setTimeout(()=>{row.box.classList.remove('celebrate');row.notice.textContent='';row.timer=0;},2000);}
    }
  }
  function connect() {
    clear();
    const ws=new WebSocket((location.protocol==='https:'?'wss://':'ws://')+location.host+'/ws');socket=ws;
    ws.addEventListener('open',()=>ws.send(JSON.stringify({type:'register',view:'goals'})));
    ws.addEventListener('message',event=>{if(ws!==socket)return;try{const e=JSON.parse(event.data);if(e.type==='goals')render(Array.isArray(e.data)?e.data:[],!!e.replay);else if(e.type==='settings'&&e.data){applyOverlayFont(e.data);language=e.data.appLanguageCode||'en';localize();}else if(e.type==='reload')window.location.reload();}catch(error){console.warn('Ignored malformed goals message',error);}});
    ws.addEventListener('close',()=>{if(ws!==socket)return;clear();if(!closing)retry=window.setTimeout(connect,3000);});
    ws.addEventListener('error',()=>ws.close());
  }
  connect();
  window.addEventListener('beforeunload',()=>{closing=true;window.clearTimeout(retry);clear();if(socket)socket.close();});
})();
</script></body></html>''';
