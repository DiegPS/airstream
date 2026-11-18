import 'overlay_font.dart';
import 'overlay_page_locale.dart';

String timerOverlayHtml() => '''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Airstream Timer</title><style>
*{box-sizing:border-box}html,body{margin:0;background:transparent;overflow:hidden;font-family:var(--overlay-font-family,system-ui,sans-serif);color:white}body{padding:24px}#timer{display:inline-block;position:relative;padding:20px 28px;background:rgba(20,20,20,.9);border-radius:14px}#timer[hidden]{display:none}#remaining{font-size:72px;font-weight:750;font-variant-numeric:tabular-nums}#status{font-size:20px;text-align:center}#badge{position:absolute;right:16px;top:0;color:#53fc18;font-size:28px;font-weight:bold;opacity:0}#badge.added{animation:float 1.5s ease-out}@keyframes float{0%{opacity:1;transform:translateY(0)}100%{opacity:0;transform:translateY(-24px)}}@media(prefers-reduced-motion:reduce){#badge.added{animation:none;opacity:1}}
</style></head><body><section id="timer" hidden><div id="remaining">0:00</div><div id="status"></div><div id="badge"></div></section><script>
$overlayFontScript
${overlayPageLocaleScript((l) => l.obsPageTimerTitle)}
(() => {
  const root=document.getElementById('timer'), digits=document.getElementById('remaining'), status=document.getElementById('status'), badge=document.getElementById('badge');
  const STRINGS={en:{paused:'Paused',ended:"Time's up!"},es:{paused:'En pausa',ended:'¡Se acabó el tiempo!'}};
  let state={phase:'idle'},offset=0,language='en',socket=null,retry=0,badgeTimeout=0,closing=false;
  function format(ms){const s=Math.ceil(Math.max(0,ms)/1000),m=Math.floor(s/60),tail=String(s%60).padStart(2,'0');return m>=60?Math.floor(m/60)+':'+String(m%60).padStart(2,'0')+':'+tail:m+':'+tail;}
  function render(){const ms=state.phase==='running'?Math.max(0,state.endsAtMs-(Date.now()+offset)):state.phase==='paused'?state.remainingMs:0;
    root.hidden=state.phase==='idle';digits.textContent=format(ms);
    const phase=state.phase==='running'&&ms===0?'ended':state.phase;
    status.textContent=(STRINGS[language]||STRINGS.en)[phase]||'';
  }
  function clearBadge(){window.clearTimeout(badgeTimeout);badge.className='';badge.textContent='';}
  function connect(){
    const ws=new WebSocket((location.protocol==='https:'?'wss://':'ws://')+location.host+'/ws');socket=ws;
    ws.addEventListener('open',()=>ws.send(JSON.stringify({type:'register',view:'timer'})));
    ws.addEventListener('message',event=>{if(ws!==socket)return;try{const e=JSON.parse(event.data);
      if(e.type==='timer'&&e.data){state=e.data;offset=state.serverNowMs-Date.now();clearBadge();render();
        if(!e.replay&&state.addedMs>0){badge.textContent='+'+format(state.addedMs);void badge.offsetWidth;badge.className='added';badgeTimeout=window.setTimeout(clearBadge,1500);}
      }else if(e.type==='settings'&&e.data){applyOverlayFont(e.data);language=e.data.appLanguageCode||'en';localizePage(language);render();}
      else if(e.type==='reload')window.location.reload();
    }catch(error){console.warn('Ignored malformed timer message',error);}});
    ws.addEventListener('close',()=>{if(ws!==socket)return;clearBadge();if(!closing)retry=window.setTimeout(connect,3000);});
    ws.addEventListener('error',()=>ws.close());
  }
  const refresh=window.setInterval(render,250);connect();
  window.addEventListener('beforeunload',()=>{closing=true;window.clearInterval(refresh);window.clearTimeout(retry);clearBadge();socket?.close();});
})();
</script></body></html>''';
