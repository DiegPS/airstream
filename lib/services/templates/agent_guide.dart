import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

String markedAgentFile(String name, String body) {
  final hash = sha256.convert(utf8.encode(body));
  final marker = 'airstream:generated v1 sha256=$hash';
  return '${name.endsWith('.md') ? '<!-- $marker -->' : '// $marker'}\n$body';
}

bool unmodifiedAgentFile(String name, String text) {
  final newline = text.indexOf('\n');
  if (newline < 0) return false;
  return markedAgentFile(name, text.substring(newline + 1)) == text;
}

Map<String, String> agentGuideFiles() => {
      'AGENTS.md': markedAgentFile('AGENTS.md', agentGuideBody),
      'CLAUDE.md': markedAgentFile('CLAUDE.md',
          '@AGENTS.md\n\nRead AGENTS.md before doing any work. Follow it and speak in the user’s language.\n'),
      'airstream.d.ts': markedAgentFile('airstream.d.ts', airstreamTypes),
    };

int _sequence = 0;
Future<void> writeGeneratedAgentGuide(Directory root) async {
  if (!await root.exists()) return;
  for (final entry in agentGuideFiles().entries) {
    final target = File(p.join(root.path, entry.key));
    final type = await FileSystemEntity.type(target.path, followLinks: false);
    String? previous;
    if (type != FileSystemEntityType.notFound) {
      if (type != FileSystemEntityType.file) continue;
      try {
        previous = await target.readAsString();
      } on FormatException {
        continue;
      }
      if (previous == entry.value ||
          !unmodifiedAgentFile(entry.key, previous)) {
        continue;
      }
    }
    final temp = File(p.join(root.path,
        '.guide-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}.tmp'));
    try {
      await temp.create(exclusive: true);
      await temp.writeAsString(entry.value, flush: true);
      // Recheck after the async write: preserve edits made in the meantime.
      final now = await FileSystemEntity.type(target.path, followLinks: false);
      if (previous == null
          ? now != FileSystemEntityType.notFound
          : now != FileSystemEntityType.file ||
              await target.readAsString() != previous) {
        continue;
      }
      await temp.rename(target.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}

const airstreamTypes = r'''type Platform = 'youtube' | 'twitch' | 'kick';
type MembershipKind = 'subscription' | 'resubscription' | 'gift';
type Orientation = 'horizontal' | 'vertical';
interface Meta { replay: boolean; test: boolean; }
interface Badge { imageUrl: string | null; label: string; kind: string | null; }
type MessageItem = {kind:'text'; text:string} | {kind:'emoji'; url:string; alt:string; isAnimated:boolean; isCustom:boolean; isZeroWidth:boolean};
interface Chat {
 platform:Platform; id:string; author:string; authorAvatarUrl:string|null; authorChannelId:string;
 badgeImageUrl:string|null; badgeLabel:string|null; badges:Badge[]; color:string|null;
 text:string; items:MessageItem[]; isSuperChat:boolean; superChatAmount:string|null;
 superChatColor:string|null; superChatStickerUrl:string|null; isMembership:boolean;
 isMembershipEvent:boolean; membershipEventKind:MembershipKind|null; membershipMonths:number|null;
 membershipGiftCount:number|null; isOwner:boolean; isModerator:boolean; isVip:boolean; isVerified:boolean;
 youtubeStreamOrientation:Orientation|null; timestamp:string;
 reply:{messageId:string; authorId:string; authorName:string; text:string}|null;
 sharedSource:{messageId:string; channelId:string; messageType:string; badges:Record<string,string>; badgeInfo:Record<string,string>; sourceOnly:boolean}|null;
 isAction:boolean; providerRoomId:string; isFirstMessage:boolean; isReturningChatter:boolean; rewardId:string|null;
}
interface Delete { platform:Platform; scope:'message'|'author'|'platform'; messageId:string; authorChannelId:string; authorName:string; youtubeStreamOrientation:Orientation|null; }
type AlertType = 'superchat'|'membership'|'bits'|'subscription'|'gift'|'raid'|'kicks';
interface Alert {
 platform:Platform; kind:'superchat'|'membership'|'bits'|'raid'|'host'|'kicks'|'featured'; alertType:AlertType|null;
 id:string; author:string; authorAvatarUrl:string|null; authorChannelId:string;
 badgeImageUrl:string|null; badgeLabel:string|null; message:string; amount:string|null;
 color:string|null; stickerUrl:string|null; timestamp:string; membershipKind:MembershipKind|null;
 months:number|null; giftCount:number|null;
 // Only provider alerts (raid/host/kicks) have count. Null is possible.
 count?:number|null;
}
interface ProviderEvent { platform:Platform; kind:'raid'|'unraid'|'pinnedMessage'|'unpinnedMessage'|'poll'|'reward'|'support'|'host'|'goal'|'notice'|'modiversary'|'viewerMilestone'|'watchStreak'|'sharedChat'|'roomState'|'streamOnline'|'streamOffline'|'unknown'; id:string; timestamp:string; authorName:string; text:string; count:number|null; data:Record<string,unknown>; }
interface Goal { id:string; title:string; type:'subs'|'bits'|'kicks'|'manual'; current:number; target:number; percent:number; reached:boolean; }
interface Timer { phase:'idle'|'running'|'paused'|'ended'; endsAtMs:number; remainingMs:number; serverNowMs:number; addedMs:number; }
interface Giveaway { keyword:string; phase:'open'|'closed'|'drawn'; entrantCount:number; winner:{name:string; platform:Platform}|null; drawId:number; }
interface Poll { question:string; options:{label:string; votes:number; percent:number}[]; total:number; closed:boolean; endsAt:number|null; }
interface Caption { text:string; }
type Fields = Record<string,string|number|boolean>;
interface AlertOptions { seconds?:number; animation?:string; sound?:string; media?:string; mediaKind?:string; mediaAudio?:boolean; soundMediaId?:string; soundKey?:string; }
interface Settings {
 appLanguageCode:string;
 chromaMode:boolean;
 chromaColor:string;
 showGrid:boolean;
 hideScrollbar:boolean;
 fontSize:number;
 bgOpacity:number;
 messageOpacity:number;
 showAvatars:boolean;
 showPlatformIcons:boolean;
 showBadges:boolean;
 showYoutubeStreamBadges:boolean;
 showTimestamp:boolean;
 textStroke:number;
 textStrokeColor:string;
 lineHeight:number;
 messageGap:number;
 fontWeight:number;
 borderRadius:number;
 textShadow:boolean;
 showBubble:boolean;
 superChatBarEnabled:boolean;
 superChatBarColor:string;
 superChatBarWidth:number;
 maxMessages:number;
 messageTtlSeconds:number;
 animation:string;
 animationDuration:number;
 textAlign:string;
 twitchBubbleAccent:boolean;
 kickBubbleAccent:boolean;
 threeDEnabled:boolean;
 perspective:number;
 rotateX:number;
 rotateY:number;
 rotateZ:number;
 skewX:number;
 scale:number;
 alertFontSize:number;
 alertDisplaySeconds:number;
 alertShowAvatars:boolean;
 alertPosition:string;
 alertLayout:string;
 alertAnimation:string;
 alertSoundVolume:number;
 alertTypeOptions:Partial<Record<AlertType,AlertOptions>>;
}
interface Events {
 trigger:{name:string; data:string; rule:string}; chat:Chat; delete:Delete; alert:Alert; featured:Alert; goals:Goal[]; timer:Timer;
 giveaway:Giveaway|null; poll:Poll|null; caption:Caption; event:ProviderEvent;
 settings:Settings; fields:Fields; connected:null; disconnected:null;
}
interface AirstreamAPI {
 readonly version:1; readonly template:string; readonly demo:boolean;
 readonly state:Partial<Pick<Events,'goals'|'timer'|'giveaway'|'poll'|'settings'|'fields'>>;
 readonly fields:Fields;
 on<K extends keyof Events>(name:K, handler:(data:Events[K],meta:Meta)=>void):()=>boolean;
 renderMessage(message:Pick<Chat,'text'> & Partial<Pick<Chat,'items'>>,options?:{emoteClass?:string}):DocumentFragment;
 timerRemaining():number; formatDuration(ms:number):string;
 mediaUrl(id:string):string; platformColor(platform:string):string;
}
declare global { interface Window { Airstream:AirstreamAPI; } const Airstream:AirstreamAPI; }
export {};
''';

const agentGuideBody = r'''# Build an Airstream template

Talk to the user in their language. Airstream is a Windows streaming app that combines YouTube, Twitch and Kick chat and serves read-only browser graphics for OBS. A template is a local HTML/CSS/JavaScript page receiving events through window.Airstream.

Create EACH template as a NEW subfolder of this folder. Never edit AGENTS.md, CLAUDE.md or airstream.d.ts. Never touch another template unless asked. Never write outside this templates root. Do not install dependencies, start servers, launch Airstream, or create network write APIs. Use the running Airstream server.

## Files and manifest

Folder id: ^[a-z0-9][a-z0-9-]{0,39}$ (lowercase, at most 40 characters). Choose a free id; never overwrite a folder. Required index.html: at most 2 MiB (2,097,152 bytes). File limit: 50 MiB (52,428,800 bytes). At most 6 path segments below the template folder, including filename. Each segment matches ^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$. No dotfiles, traversal, absolute paths, symlinks or junctions. Use relative URLs such as "style.css", "script.js", "img/logo.png"; a root-relative asset would escape the template URL.

Allowed extensions: html css js mjs json txt svg png jpg jpeg gif webp avif ico woff woff2 ttf otf mp3 wav ogg mp4 webm. No TS compilation is provided. airstream.d.ts is reference documentation, not a browser script.

template.json is a JSON object, at most 65,536 bytes. It is optional in the loader, but always create it. Unknown keys are ignored. All string limits below count Unicode code points after trimming. Keys:
- name: string, max 60, defaults to folder id if absent or non-string (empty string remains empty).
- description: string, max 200, default "".
- author: string, max 60, default "".
- sdk: integer, default 1. Only 1 is supported. Explicit non-1 values report unsupportedSdk.
- width: integer 100..3840 (clamped), default 800.
- height: integer 100..2160 (clamped), default 600.
- network: boolean, default false; only true enables external connections.
- fields: array, default []; only the first 40 entries are examined. Invalid entries and duplicate keys are skipped. Each field has key (required, ^[A-Za-z][A-Za-z0-9_]{0,31}$), label (string max 60, defaults to key), type (required), default (type-specific, see below). Options:
  - text: maxLength integer 1..500 (clamped), default 200; default text ""; values trimmed and truncated.
  - color: #RRGGBB or #RRGGBBAA; normalized lowercase; invalid/missing default becomes #ffffff.
  - number: finite number default 0, clamped to optional finite min/max. Optional step must be finite and positive; no quantization is performed. min > max or non-positive step skips the field.
  - boolean: true/false, default false.
  - select: required options array of 1..30 strings, each at most 60 code points; default must match an option or falls back to the first.
  - media: kind image/video/audio/any (default any); default/values are 16 lowercase hex characters or "". Resolve with Airstream.mediaUrl; kind is metadata, not a URL.

Full manifest example:
```json
{"name":"Latest supporter","description":"The latest stream support","author":"You","sdk":1,"width":640,"height":180,"network":false,"fields":[{"key":"heading","label":"Heading","type":"text","maxLength":100,"default":"Latest supporter"},{"key":"accent","type":"color","default":"#53fc18"},{"key":"seconds","type":"number","min":1,"max":30,"step":1,"default":7},{"key":"enabled","type":"boolean","default":true},{"key":"layout","type":"select","options":["row","column"],"default":"row"},{"key":"logo","type":"media","kind":"image","default":""}]}
```
values.json is written by the app, NEVER by the agent. GET values.json returns sanitized resolved values including defaults even if the disk file is absent. Fields UI is a separate app feature; consume fields when supplied.

## SDK and payload reference

The server injects /sdk/v1.js automatically at /custom/<id>/; DO NOT add a script tag for it. Explicit /sdk/v1.js tags are deduplicated and moved ahead of your code. Open the directory URL, not /index.html (direct file URLs do not inject it). Include your stylesheet and script explicitly in a full HTML document; put your script at the end of body or use defer.

window.Airstream members (read only in intent; do not mutate state):
- version: 1; template: folder id string (empty outside a valid custom path); demo: boolean, true for ?demo=1 or ?demo.
- on(name, handler): registers handler(data, meta), returns unsubscribe(): boolean (Set.delete result). Unknown names or a non-function throw. Handler exceptions are reported. Stored state is replayed asynchronously to a new subscriber; unsubscribe cancels that queued callback.
- state: latest goals, timer, giveaway, poll, settings, fields; keys absent until received. giveaway and poll can be null (cleared). No chat, alert or caption history.
- fields: latest fields object, or {} before receipt.
- renderMessage(message, options = {}): safe DocumentFragment of text and emote img nodes. options.emoteClass defaults to airstream-emote. Append/replaceChildren the result. Fallback to text when items are absent/empty. Set emote dimensions in CSS; the helper does not implement layout for zero-width emotes.
- timerRemaining(): milliseconds left using timer.serverNowMs clock offset; running uses endsAtMs, paused uses remainingMs, otherwise 0. It does not emit ticks.
- formatDuration(ms): nonnegative milliseconds rounded UP to seconds, "5:09" or "1:05:09".
- mediaUrl(id): "/media/" + id for 16 lowercase hex characters, otherwise "".
- platformColor(platform): youtube #ff0033, twitch #9146ff, kick #53fc18, unknown #ffffff.

Every event passes (data, meta). meta.replay and meta.test are booleans. replay means restoring state, not a new celebration; NEVER replay sounds/confetti/celebrations when replay is true. test marks app-generated test events; demo simulation events generally have test:false. Subscribing to stored state gives replay:true,test:false even if the original state came from a test. The SDK reconnects after 3 seconds. Errors and unhandled rejections appear in the console and are reported to the app at most once per 5 seconds while connected (demo has no socket).

Events and WHEN they fire:
- chat: accepted chat message, Chat below; timestamp is an ISO-8601 string, provider IDs are opaque. Roles are already resolved. Amounts are presentation strings, never assume numeric currency.
- delete: moderation deletion, Delete below. scope message matches messageId, author matches authorChannelId/name, platform clears the platform; youtubeStreamOrientation may constrain YouTube deletion. Empty IDs/names can occur.
- alert: automatic support or provider alert, Alert below. alertType superchat (YouTube money), membership (YouTube membership), bits (Twitch), subscription (Twitch/Kick subscription or renewal), gift (gift memberships/subscriptions), raid (Twitch raid/Kick host), kicks (Kick support). kind is membership for membership/subscription/gift, superchat for superchat, bits for bits, raid or host/kicks for provider alerts. count exists ONLY for raid/host/kicks; no count key on message alerts. message is trimmed chat text; provider raid has empty message, kicks has provider text. amount/color/stickerUrl come from superChat and may be null. authorChannelId is empty for provider alerts. months/giftCount/membershipKind may be null. Use alertType to distinguish celebrations.
- trigger: automation event {name:string, data:string, rule:string}. All fields are plain text. Use textContent; never interpret data as HTML. Templates cannot trigger or edit rules.
- featured: manually featured chat copy, same Alert fields, kind:'featured', alertType:null; no deliveryId and no confirmation command. May still contain support amount and membership metadata from the selected message.
- event: provider lifecycle/activity event, ProviderEvent below (including raids, hosts, rewards and provider notices). data is provider-specific, arbitrary JSON; do not assume its keys. This can describe the same activity as an alert: do not celebrate both.
- goals: full array whenever goals update and on connection; 0..3 goals, percent clamped 0..100, reached indicates current >= target.
- timer: snapshot on connection or timer change/addition, Timer below. Millisecond epoch endsAtMs/serverNowMs; remainingMs and addedMs are durations. addedMs is 0 on restoration; avoid duplicate time-added celebrations. Draw your own lightweight tick with timerRemaining().
- giveaway: state on connection/change, Giveaway or null. No id/title/membersOnly/entrant list is exposed. drawId changes on draw, winner is name/platform only; phase drawn plus replay:false can animate a new draw.
- poll: state on connection/change, Poll or null. No id is exposed. options have label/votes/rounded integer percent; endsAt is epoch milliseconds or null for untimed.
- caption: new nonempty caption text, Caption below. Not stored/replayed.
- settings: visual/app preferences on connection or update, Settings below. Values are preferences, not commands. alertTypeOptions has per-type optional overrides (seconds, animation, sound; optional media/mediaKind/mediaAudio; soundMediaId for library sound; soundKey for custom sound). No local file paths are exposed.
- fields: full resolved field values on connection/update; object keyed by manifest field key, sanitized string/number/boolean values, defaults included. React to updates without reloading.
- connected: null, live WebSocket opens and registers; disconnected: null, socket closes. Demo fires neither.

Exact data types and signatures (a `?` property may be absent; `|null` can be null; all other fields are present and non-null). Types number include integer counts and fractional preferences. These declarations are also in ../airstream.d.ts:
```ts
type Platform = 'youtube' | 'twitch' | 'kick';
type MembershipKind = 'subscription' | 'resubscription' | 'gift';
type Orientation = 'horizontal' | 'vertical';
interface Meta { replay: boolean; test: boolean; }
interface Badge { imageUrl: string | null; label: string; kind: string | null; }
type MessageItem = {kind:'text'; text:string} | {kind:'emoji'; url:string; alt:string; isAnimated:boolean; isCustom:boolean; isZeroWidth:boolean};
interface Chat {
 platform:Platform; id:string; author:string; authorAvatarUrl:string|null; authorChannelId:string;
 badgeImageUrl:string|null; badgeLabel:string|null; badges:Badge[]; color:string|null;
 text:string; items:MessageItem[]; isSuperChat:boolean; superChatAmount:string|null;
 superChatColor:string|null; superChatStickerUrl:string|null; isMembership:boolean;
 isMembershipEvent:boolean; membershipEventKind:MembershipKind|null; membershipMonths:number|null;
 membershipGiftCount:number|null; isOwner:boolean; isModerator:boolean; isVip:boolean; isVerified:boolean;
 youtubeStreamOrientation:Orientation|null; timestamp:string;
 reply:{messageId:string; authorId:string; authorName:string; text:string}|null;
 sharedSource:{messageId:string; channelId:string; messageType:string; badges:Record<string,string>; badgeInfo:Record<string,string>; sourceOnly:boolean}|null;
 isAction:boolean; providerRoomId:string; isFirstMessage:boolean; isReturningChatter:boolean; rewardId:string|null;
}
interface Delete { platform:Platform; scope:'message'|'author'|'platform'; messageId:string; authorChannelId:string; authorName:string; youtubeStreamOrientation:Orientation|null; }
type AlertType = 'superchat'|'membership'|'bits'|'subscription'|'gift'|'raid'|'kicks';
interface Alert {
 platform:Platform; kind:'superchat'|'membership'|'bits'|'raid'|'host'|'kicks'|'featured'; alertType:AlertType|null;
 id:string; author:string; authorAvatarUrl:string|null; authorChannelId:string;
 badgeImageUrl:string|null; badgeLabel:string|null; message:string; amount:string|null;
 color:string|null; stickerUrl:string|null; timestamp:string; membershipKind:MembershipKind|null;
 months:number|null; giftCount:number|null;
 // Only provider alerts (raid/host/kicks) have count. Null is possible.
 count?:number|null;
}
interface ProviderEvent { platform:Platform; kind:'raid'|'unraid'|'pinnedMessage'|'unpinnedMessage'|'poll'|'reward'|'support'|'host'|'goal'|'notice'|'modiversary'|'viewerMilestone'|'watchStreak'|'sharedChat'|'roomState'|'streamOnline'|'streamOffline'|'unknown'; id:string; timestamp:string; authorName:string; text:string; count:number|null; data:Record<string,unknown>; }
interface Goal { id:string; title:string; type:'subs'|'bits'|'kicks'|'manual'; current:number; target:number; percent:number; reached:boolean; }
interface Timer { phase:'idle'|'running'|'paused'|'ended'; endsAtMs:number; remainingMs:number; serverNowMs:number; addedMs:number; }
interface Giveaway { keyword:string; phase:'open'|'closed'|'drawn'; entrantCount:number; winner:{name:string; platform:Platform}|null; drawId:number; }
interface Poll { question:string; options:{label:string; votes:number; percent:number}[]; total:number; closed:boolean; endsAt:number|null; }
interface Caption { text:string; }
type Fields = Record<string,string|number|boolean>;
interface AlertOptions { seconds?:number; animation?:string; sound?:string; media?:string; mediaKind?:string; mediaAudio?:boolean; soundMediaId?:string; soundKey?:string; }
interface Settings {
 appLanguageCode:string;
 chromaMode:boolean;
 chromaColor:string;
 showGrid:boolean;
 hideScrollbar:boolean;
 fontSize:number;
 bgOpacity:number;
 messageOpacity:number;
 showAvatars:boolean;
 showPlatformIcons:boolean;
 showBadges:boolean;
 showYoutubeStreamBadges:boolean;
 showTimestamp:boolean;
 textStroke:number;
 textStrokeColor:string;
 lineHeight:number;
 messageGap:number;
 fontWeight:number;
 borderRadius:number;
 textShadow:boolean;
 showBubble:boolean;
 superChatBarEnabled:boolean;
 superChatBarColor:string;
 superChatBarWidth:number;
 maxMessages:number;
 messageTtlSeconds:number;
 animation:string;
 animationDuration:number;
 textAlign:string;
 twitchBubbleAccent:boolean;
 kickBubbleAccent:boolean;
 threeDEnabled:boolean;
 perspective:number;
 rotateX:number;
 rotateY:number;
 rotateZ:number;
 skewX:number;
 scale:number;
 alertFontSize:number;
 alertDisplaySeconds:number;
 alertShowAvatars:boolean;
 alertPosition:string;
 alertLayout:string;
 alertAnimation:string;
 alertSoundVolume:number;
 alertTypeOptions:Partial<Record<AlertType,AlertOptions>>;
}
interface Events {
 trigger:{name:string; data:string; rule:string}; chat:Chat; delete:Delete; alert:Alert; featured:Alert; goals:Goal[]; timer:Timer;
 giveaway:Giveaway|null; poll:Poll|null; caption:Caption; event:ProviderEvent;
 settings:Settings; fields:Fields; connected:null; disconnected:null;
}
interface AirstreamAPI {
 readonly version:1; readonly template:string; readonly demo:boolean;
 readonly state:Partial<Pick<Events,'goals'|'timer'|'giveaway'|'poll'|'settings'|'fields'>>;
 readonly fields:Fields;
 on<K extends keyof Events>(name:K, handler:(data:Events[K],meta:Meta)=>void):()=>boolean;
 renderMessage(message:Pick<Chat,'text'> & Partial<Pick<Chat,'items'>>,options?:{emoteClass?:string}):DocumentFragment;
 timerRemaining():number; formatDuration(ms:number):string;
 mediaUrl(id:string):string; platformColor(platform:string):string;
}
```

## Security, performance and layout

Templates are READ-ONLY. No app commands, OBS control, TTS, writes or featured acknowledgements. Never use innerHTML, insertAdjacentHTML or document.write with event data. Use textContent for names/amounts and Airstream.renderMessage for messages. Treat every event string as untrusted.

Keep the page background transparent. Size the page to template.json width/height; match that size in OBS. No busy loops. Use CSS animations; cap lists, remove old nodes, cancel unused timers/listeners, stop and release old audio/video. Respect autoplay restrictions and avoid unsolicited sound. Never use forms or iframes.

Exact default CSP (PORT is the serving port):
```
default-src 'none'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://unpkg.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://unpkg.com; font-src 'self' data: https://fonts.gstatic.com https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://unpkg.com; img-src 'self' data: blob: http: https:; media-src 'self' data: blob:; connect-src 'self' ws://localhost:PORT ws://127.0.0.1:PORT; worker-src 'self' blob:; object-src 'none'; frame-src 'none'; base-uri 'self'; form-action 'none'
```
With network:true the actual policy additionally allows https: for script-src and media-src, https: wss: for connect-src, and changes frame-src to https:. Even though that policy permits HTTPS frames, do not build templates with iframes. Script CDNs: jsDelivr, cdnjs, unpkg. Styles also allow Google Fonts; fonts allow fonts.gstatic.com and those CDNs. Images can be http/https/data/blob from anywhere. fetch to internet is blocked unless network:true; network:true allows HTTPS, not arbitrary HTTP. CSP does not grant remote CORS permission. No objects; no form submissions. nosniff and no-referrer are set.

## Minimal complete working template

Create a free folder latest-supporter and these four files. Do not create values.json.

template.json:
```json
{"name":"Latest supporter","sdk":1,"width":640,"height":180,"network":false,"fields":[]}
```
index.html:
```html
<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Latest supporter</title><link rel="stylesheet" href="style.css"></head>
<body><main><h1>Latest supporter</h1><p id="supporter">Waiting for support</p></main><script src="script.js"></script></body></html>
```
style.css:
```css
html,body { margin:0; width:640px; height:180px; overflow:hidden; background:transparent; color:white; font:24px system-ui; }
main { box-sizing:border-box; padding:20px; width:620px; border-radius:16px; background:rgba(12,18,25,.85); }
h1 { margin:0 0 12px; font-size:20px; } p { margin:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.airstream-emote { height:1em; vertical-align:middle; }
```
script.js:
```js
'use strict';
const supporter = document.getElementById('supporter');
Airstream.on('alert', (data, meta) => {
  if (meta.replay) return;
  supporter.textContent = data.author + (data.amount ? ' · ' + data.amount : ' · Thank you!');
});
```

## Test and finish

Open http://localhost:<PORT>/custom/<id>/?demo=1 in a browser. PORT is shown in Airstream's Templates tab/URLs, default 8080; use the real port in the user's instruction. Airstream must already be serving; if unavailable, explain that the user must enable it. Do not launch another server.

Demo: initial settings/goals/timer, fields loaded asynchronously; chat every 1.5s; caption every 6s; alert every 7s cycling superchat,membership,bits,subscription,gift,raid,kicks; goals and time additions with membership/bits/subscription/gift; delete every 20s; featured every 25s; poll opens at 3s, closes at 45s; giveaway opens at 5s, draws at 50s. Provider event accompanies demo raid/kicks. No real chat or socket is used. Wait at least 50s to see all types. Demo is a sample, not every possible nullable payload or transition.

Check browser console and fix errors. Add the live URL http://localhost:<PORT>/custom/<id>/ to OBS as a Browser source with manifest width and height (without ?demo=1). Saving files reloads that template's connected pages automatically; values.json changes deliver fields without reload. Root guide files do not reload templates. JavaScript errors also appear in Airstream's Templates tab when live and connected.

Before saying done:
- New valid folder; no existing template or generated guide changed; all four files present.
- Valid manifest and relative assets; sizes/path/types within limits; no values.json written.
- SDK injected, listeners installed after DOM; every used field matches this reference and nulls handled.
- Event text rendered safely; no app commands, forms or iframes; network permission only if needed.
- Transparent page, correct dimensions, bounded nodes/media/timers, replay does not celebrate.
- Demo tested through a complete cycle; console clean. State clearly if browser/OBS testing was unavailable.
- Tell the user in their language the folder id, live OBS URL and recommended width × height.
''';
