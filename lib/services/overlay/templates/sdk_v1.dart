/// Browser SDK for read-only custom overlays.
String sdkV1() => r"""
(() => {
  'use strict';
  if (window.Airstream) return;
  const names = ['chat','delete','alert','featured','goals','timer','giveaway','poll','caption','event','settings','fields','connected','disconnected'];
  const states = new Set(['goals','timer','giveaway','poll','settings','fields']);
  const handlers = new Map(names.map(n => [n,new Set()]));
  const state = {};
  const template = (location.pathname.match(/^\/custom\/([a-z0-9][a-z0-9-]{0,39})(?:\/|$)/) || [,''])[1];
  const query = new URLSearchParams(location.search);
  const demo = query.has('demo') && ['', '1'].includes(query.get('demo'));
  let socket = null, retry = null, closing = false, lastError = -Infinity, offset = 0;
  function report(error,source='',line=null) {
    const message = String(error && error.message || error || 'Template error').slice(0,300);
    console.error(message);
    if (Date.now()-lastError < 5000) return;
    if (socket && socket.readyState === 1) {
      lastError=Date.now();
      try { socket.send(JSON.stringify({type:'templateError',message,source:String(source).split(/[\\/]/).pop().split(/[?#]/)[0],line:Number.isInteger(line)?line:null})); } catch (_) { /* Socket closed during reporting. */ }
    }
  }
  function call(handler,data,meta) { try { handler(data,meta); } catch (e) { report(e); } }
  function emit(name,data,meta={replay:false,test:false}) {
    if (states.has(name)) state[name]=data;
    if (name === 'timer' && data && Number.isFinite(data.serverNowMs)) offset=data.serverNowMs-Date.now();
    for (const h of [...handlers.get(name)]) call(h,data,{...meta});
  }
  const api = {
    version:1,template,demo,state,
    get fields() { return state.fields || {}; },
    on(name,handler) {
      if (!handlers.has(name)) throw new Error('Unknown Airstream event: '+name+'. Valid events: '+names.join(', '));
      if (typeof handler !== 'function') throw new Error('Airstream handler must be a function');
      const set=handlers.get(name); set.add(handler);
      if (states.has(name) && Object.prototype.hasOwnProperty.call(state,name)) {
        const data=state[name]; queueMicrotask(() => { if (set.has(handler)) call(handler,data,{replay:true,test:false}); });
      }
      return () => set.delete(handler);
    },
    timerRemaining() {
      const t=state.timer;
      if (!t) return 0;
      return t.phase === 'running' ? Math.max(0,t.endsAtMs-(Date.now()+offset)) : t.phase === 'paused' ? Math.max(0,t.remainingMs || 0) : 0;
    },
    formatDuration(ms) {
      const s=Math.ceil(Math.max(0,Number(ms)||0)/1000), h=Math.floor(s/3600), m=Math.floor(s%3600/60), sec=String(s%60).padStart(2,'0');
      return h ? h+':'+String(m).padStart(2,'0')+':'+sec : m+':'+sec;
    },
    renderMessage(message,options={}) {
      const fragment=document.createDocumentFragment();
      if (!Array.isArray(message.items) || !message.items.length) { fragment.appendChild(document.createTextNode(String(message.text || ''))); return fragment; }
      for (const item of message.items) {
        if (item.kind === 'emoji') {
          const src=String(item.url || '');
          if (/^(https?:|data:image\/)/i.test(src)) {
            const img=document.createElement('img'); img.className=options.emoteClass || 'airstream-emote'; img.alt=String(item.alt || ''); img.src=src; fragment.appendChild(img);
          } else fragment.appendChild(document.createTextNode(String(item.alt || '')));
        } else fragment.appendChild(document.createTextNode(String(item.text || '')));
      }
      return fragment;
    },
    mediaUrl(id) { return typeof id === 'string' && /^[0-9a-f]{16}$/.test(id) ? '/media/'+id : ''; },
    platformColor(platform) { return platform === 'youtube' ? '#ff0033' : platform === 'twitch' ? '#9146ff' : platform === 'kick' ? '#53fc18' : '#ffffff'; }
  };
  window.Airstream=api;
  window.addEventListener('error',e => report(e.message,e.filename,e.lineno));
  window.addEventListener('unhandledrejection',e => report(e.reason));
  const mapping={message:'chat',moderation:'delete',providerEvent:'event',alert:'alert',featured:'featured',caption:'caption',goals:'goals',timer:'timer',giveaway:'giveaway',poll:'poll',settings:'settings',fields:'fields'};
  function connect() {
    if (closing || socket) return;
    const ws=new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://')+location.host+'/ws'); socket=ws;
    ws.addEventListener('open',() => { if (socket !== ws) return; ws.send(JSON.stringify({type:'register',view:'custom',template})); emit('connected',null); });
    ws.addEventListener('message',e => {
      if (socket !== ws) return;
      let envelope; try { envelope=JSON.parse(e.data); } catch (_) { return; }
      if (!envelope || typeof envelope !== 'object') return;
      if (envelope.type === 'reload') { location.reload(); return; }
      const name=Object.prototype.hasOwnProperty.call(mapping,envelope.type)?mapping[envelope.type]:null;
      if (name) emit(name,envelope.data,{replay:envelope.replay === true,test:envelope.test === true});
    });
    ws.addEventListener('close',() => { if (socket !== ws) return; socket=null; emit('disconnected',null); if (!closing && retry === null) retry=setTimeout(() => { retry=null; connect(); },3000); });
    ws.addEventListener('error',() => { if (socket === ws) ws.close(); });
  }
  window.addEventListener('beforeunload',() => { closing=true; if (retry !== null) clearTimeout(retry); if (socket) socket.close(); });
  if (!demo) { connect(); return; }
  async function demoFields() {
    const read=async name => { try { const r=await fetch('./'+name); return r.ok ? await r.json() : {}; } catch (_) { return {}; } };
    const [manifest,values]=await Promise.all([read('template.json'),read('values.json')]);
    const fields={};
    for (const f of (Array.isArray(manifest.fields)?manifest.fields:[]).slice(0,40)) {
      if (!f || typeof f.key !== 'string' || !/^[A-Za-z][A-Za-z0-9_]{0,31}$/.test(f.key) || Object.prototype.hasOwnProperty.call(fields,f.key)) continue;
      let v=Object.prototype.hasOwnProperty.call(values,f.key)?values[f.key]:f.default;
      switch (f.type) {
        case 'text': v=typeof v === 'string'?v.trim().slice(0,Math.min(500,Math.max(1,f.maxLength || 200))):''; break;
        case 'color': v=typeof v === 'string' && /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v)?v.toLowerCase():'#ffffff'; break;
        case 'number': v=typeof v === 'number' && Number.isFinite(v)?v:0; if (Number.isFinite(f.min)) v=Math.max(f.min,v); if (Number.isFinite(f.max)) v=Math.min(f.max,v); break;
        case 'boolean': v=typeof v === 'boolean'?v:false; break;
        case 'select': if (!Array.isArray(f.options) || !f.options.length) continue; v=f.options.includes(v)?v:f.options[0]; break;
        case 'media': v=typeof v === 'string' && /^[0-9a-f]{16}$/.test(v)?v:''; break;
        default: continue;
      }
      fields[f.key]=v;
    }
    emit('fields',fields,{replay:true,test:false});
  }
  demoFields().catch(e => report(e));
  const replay={replay:true,test:false};
  emit('settings',{appLanguageCode:navigator.language.toLowerCase().startsWith('es')?'es':'en'},replay);
  const goals=[{id:'demo-subs',title:'Demo subscriptions',type:'subs',current:3,target:10},{id:'demo-bits',title:'Demo bits',type:'bits',current:450,target:1000}];
  function sendGoals(meta) { emit('goals',goals.map(g => ({...g,percent:Math.min(100,g.current/g.target*100),reached:g.current>=g.target})),meta); }
  sendGoals(replay);
  let endsAtMs=Date.now()+900000;
  function sendTimer(addedMs=0,meta) { emit('timer',{phase:'running',endsAtMs,remainingMs:Math.max(0,endsAtMs-Date.now()),serverNowMs:Date.now(),addedMs},meta); }
  sendTimer(0,replay);
  const people=['Demo Alex','Demo Luna','Demo Sam','Demo Kai','Demo Sol','Demo Ren','Demo Ari','Demo Max'];
  let chatIndex=0, alertIndex=0, earlier=null;
  const emote='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><text y="20">★</text></svg>');
  function chat() {
    const n=chatIndex++, platform=['youtube','twitch','kick'][n%3];
    return {platform,id:'demo-chat-'+n,author:people[n%8],authorAvatarUrl:null,authorChannelId:'demo-user-'+n%8,badgeImageUrl:null,badgeLabel:n%4===0?'Moderator':null,badges:[],color:api.platformColor(platform),text:'Demo message '+(n+1)+' ★',items:[{kind:'text',text:'Demo message '+(n+1)+' '},{kind:'emoji',url:emote,alt:'★',isAnimated:false,isCustom:false,isZeroWidth:false}],isSuperChat:false,superChatAmount:null,superChatColor:null,superChatStickerUrl:null,isMembership:n%3===0,isMembershipEvent:false,membershipEventKind:null,membershipMonths:null,membershipGiftCount:null,isOwner:n%8===0,isModerator:n%4===0,isVip:n%5===0,isVerified:false,youtubeStreamOrientation:null,timestamp:new Date().toISOString(),reply:null,sharedSource:null,isAction:false,providerRoomId:null,isFirstMessage:false,isReturningChatter:false,rewardId:null};
  }
  setInterval(() => { earlier=chat(); emit('chat',earlier); },1500);
  setInterval(() => {
    const type=['superchat','membership','bits','subscription','gift','raid','kicks'][alertIndex++%7];
    const platform=['superchat','membership'].includes(type)?'youtube':type==='kicks'?'kick':'twitch';
    const data={platform,kind:['subscription','gift'].includes(type)?'membership':type,alertType:type,id:'demo-alert-'+alertIndex,author:people[alertIndex%8],authorAvatarUrl:null,authorChannelId:'demo-user-'+alertIndex%8,badgeImageUrl:null,badgeLabel:null,message:'Clearly fake demo alert',amount:type==='superchat'?'$5.00':type==='bits'?'100 Bits':null,color:api.platformColor(platform),stickerUrl:null,timestamp:new Date().toISOString(),membershipKind:type==='gift'?'gift':type==='subscription'?'subscription':null,months:type==='subscription'?3:null,giftCount:type==='gift'?5:null,count:type==='raid'?42:type==='kicks'?100:null};
    emit('alert',data);
    if (['membership','bits','subscription','gift'].includes(type)) { goals[type==='bits'?1:0].current+=type==='bits'?100:type==='gift'?5:1; sendGoals(); endsAtMs+=60000; sendTimer(60000); }
  },7000);
  setInterval(() => emit('caption',{text:'Demo caption — welcome to the stream!'}),6000);
  setInterval(() => { if (earlier) emit('delete',{platform:earlier.platform,scope:'message',messageId:earlier.id,authorChannelId:earlier.authorChannelId,authorName:earlier.author}); },20000);
  setInterval(() => { const m=chat(); emit('featured',{platform:m.platform,kind:'featured',alertType:null,id:m.id,author:m.author,authorAvatarUrl:null,authorChannelId:m.authorChannelId,badgeImageUrl:null,badgeLabel:null,message:m.text,amount:null,color:m.color,stickerUrl:null,timestamp:m.timestamp,membershipKind:null,months:null,giftCount:null}); },25000);
  const poll={id:'demo-poll',question:'Demo: which game next?',options:[{label:'Adventure',votes:3,percent:60},{label:'Racing',votes:2,percent:40}],total:5,closed:false,endsAt:Date.now()+45000};
  setTimeout(() => emit('poll',poll),3000);
  setTimeout(() => emit('poll',{...poll,closed:true}),45000);
  const giveaway={id:'demo-giveaway',title:'Demo giveaway',keyword:'!demo',phase:'open',entrantCount:8,winner:null,drawId:0};
  setTimeout(() => emit('giveaway',giveaway),5000);
  setTimeout(() => emit('giveaway',{...giveaway,phase:'drawn',drawId:1,winner:{platform:'twitch',name:people[0]}}),50000);
})();
""";
