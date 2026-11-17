import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:airstream/services/templates/agent_guide.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/services/overlay/templates/sdk_v1.dart';
import 'package:airstream/services/overlay/overlay_payload_encoder.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/settings/goals.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SDK maps automation trigger envelopes to trigger listeners', () async {
    final temp = await Directory.systemTemp.createTemp('rule-sdk-');
    try {
      final file = File('${temp.path}/trigger.cjs');
      final sdk = jsonEncode(sdkV1());
      await file.writeAsString("const sdk = $sdk;\n"
          r"""
const vm=require('node:vm');let socket,received;
class WebSocket {constructor(){socket=this;} send(){} addEventListener(name,fn){this[name]=fn;} }
const context={WebSocket,location:{pathname:'/custom/test/',search:'',protocol:'http:',host:'localhost:8080'},URLSearchParams,console,Date,setTimeout:()=>0,clearTimeout(){},addEventListener(){},document:{},queueMicrotask:fn=>fn()};
context.window=context;vm.createContext(context);vm.runInContext(sdk,context);
context.Airstream.on('trigger',data=>received=data);
socket.message({data:JSON.stringify({type:'trigger',data:{name:'celebrate',data:'<plain>',rule:'Bits rule'}})});
if(!received||received.name!=='celebrate'||received.data!=='<plain>'||received.rule!=='Bits rule')throw Error('trigger mapping failed');
console.log('SDK trigger check: PASS (name, data, rule; plain text preserved)');
""");
      final result = await Process.run('node', [file.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      // This output is included in the implementation verification report.
      stdout.write(result.stdout);
    } finally {
      await temp.delete(recursive: true);
    }
  });
  test(
      'guide and declarations cover SDK names, members, manifest and exact CSP',
      () {
    expect(
        agentGuideBody, contains(airstreamTypes.split('declare global').first));
    final sdk = sdkV1();
    final names = RegExp(r"const names = \[([^\]]+)\]").firstMatch(sdk)![1]!;
    for (final m in RegExp("'([^']+)'").allMatches(names)) {
      expect(agentGuideBody, contains(m[1]!));
      expect(airstreamTypes, contains('${m[1]}:'));
    }
    final api = sdk.split('const api = {')[1].split('window.Airstream=api')[0];
    final members = <String>{
      ...RegExp(r'^    (?:get )?(\w+)\(', multiLine: true)
          .allMatches(api)
          .map((m) => m[1]!)
    };
    members.addAll(api
        .split('\n')[1]
        .trim()
        .replaceAll(':1', '')
        .split(',')
        .where((v) => v.isNotEmpty));
    for (final member in members) {
      expect(agentGuideBody, contains(member));
      expect(airstreamTypes, contains(member));
    }
    for (final key in [
      'name',
      'description',
      'author',
      'sdk',
      'width',
      'height',
      'network',
      'fields',
      'key',
      'label',
      'type',
      'default',
      'maxLength',
      'min',
      'max',
      'step',
      'options',
      'kind',
      'text',
      'color',
      'number',
      'boolean',
      'select',
      'media',
      'superchat',
      'membership',
      'bits',
      'subscription',
      'gift',
      'raid',
      'kicks'
    ]) {
      expect(agentGuideBody, contains(key));
    }
    expect(
        agentGuideBody, contains(templateCsp(8080).replaceAll('8080', 'PORT')));
    expect(agentGuideBody,
        contains('http://localhost:<PORT>/custom/<id>/?demo=1'));
    for (final entry in agentGuideFiles().entries) {
      expect(unmodifiedAgentFile(entry.key, entry.value), isTrue);
      final split = entry.value.indexOf('\n');
      expect(
          entry.value.substring(0, split),
          contains(sha256
              .convert(utf8.encode(entry.value.substring(split + 1)))
              .toString()));
      expect(unmodifiedAgentFile(entry.key, '${entry.value}edited'), isFalse);
    }
  });

  test(
      'guide writing preserves edits, upgrades old bodies, ignores root events',
      () async {
    final temp = await Directory.systemTemp.createTemp('guide-policy-');
    final library = TemplateLibrary(Directory('${temp.path}/templates'));
    try {
      await library.watch();
      await library.writeAgentGuide();
      expect(await library.exists(), isFalse);
      await library.ensureRoot();
      final changes = <TemplateChange>[];
      final sub = library.changes.listen(changes.add);
      final agents = File('${library.rootPath}/AGENTS.md');
      final claude = File('${library.rootPath}/CLAUDE.md');
      final types = File('${library.rootPath}/airstream.d.ts');
      await agents.writeAsString(markedAgentFile('AGENTS.md', 'old version\n'));
      await claude.writeAsString('User-authored guide');
      await types.writeAsString('${agentGuideFiles()['airstream.d.ts']}edited');
      await library.writeAgentGuide();
      expect(await agents.readAsString(), agentGuideFiles()['AGENTS.md']);
      expect(await claude.readAsString(), 'User-authored guide');
      expect(await types.readAsString(), endsWith('edited'));
      await agents.delete();
      await Future.wait([library.ensureRoot(), library.ensureRoot()]);
      expect(await agents.readAsString(), agentGuideFiles()['AGENTS.md']);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(changes, isEmpty);
      await sub.cancel();
      await Directory('${library.rootPath}/latest-supporter').create();
      expect(await library.suggestedAgentId('Latest supporter'),
          'latest-supporter-2');
      expect(await library.suggestedAgentId('✨'), 'my-template');
    } finally {
      await library.dispose();
      await temp.delete(recursive: true);
    }
  });

  test(
      'agent dry run: new template validates; real SDK demo matches real payloads',
      () async {
    final temp = await Directory.systemTemp.createTemp('guide-dry-run-');
    final library = TemplateLibrary(temp);
    // Written from the guide: a new implementation, independent of app starters.
    const files = {
      'template.json':
          '{"name":"Support spotlight","sdk":1,"width":600,"height":160,"network":false,"fields":[]}',
      'index.html':
          '<!doctype html><html><head><meta charset="utf-8"><title>Support spotlight</title><link rel="stylesheet" href="style.css"></head><body><p id="latest">Waiting</p><script src="script.js"></script></body></html>',
      'style.css':
          'html,body{margin:0;width:600px;height:160px;background:transparent;color:white;font:28px system-ui}p{padding:20px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;background:rgba(0,0,0,.8)}',
      'script.js':
          "Airstream.on('alert',(support,meta)=>{if(meta.replay)return;document.getElementById('latest').textContent=support.author+' — '+(support.amount||'Thank you');});"
    };
    final node = File('${temp.path}/check.cjs');
    try {
      final id = await library.createTemplate('Support spotlight', files);
      expect((await library.get(id))!.problems, isEmpty);
      final input = jsonEncode({'sdk': sdkV1(), 'script': files['script.js']});
      await node.writeAsString('const input = $input;\n$nodeCheck');
      final result = await Process.run('node', [node.path],
          stdoutEncoding: utf8, stderrEncoding: utf8);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final out = jsonDecode(result.stdout as String) as Map;
      expect(out['errors'], isEmpty);
      expect(out['latest'], startsWith('Demo '));
      final events = out['events'] as Map;
      final msg = ChatMessage(
          platform: Platform.youtube,
          id: 'x',
          author: const ChatAuthor(name: 'X', channelId: 'x'),
          items: const [
            MessageItem.text('Test'),
            MessageItem.emoji(
                EmojiItem(url: 'https://example.com/emote.png', alt: 'Emote'))
          ],
          timestamp: DateTime(2026));
      final now = DateTime.now();
      final expected = <String, dynamic>{
        'chat': OverlayPayloadEncoder.message(msg),
        'delete': OverlayPayloadEncoder.moderation(
            const ChatModerationEvent.message(
                platform: Platform.youtube, messageId: 'x')),
        'event': OverlayPayloadEncoder.providerEvent(ChatProviderEvent(
            platform: Platform.youtube,
            kind: ChatProviderEventKind.raid,
            id: 'x',
            timestamp: now)),
        'settings': OverlayPayloadEncoder.settings(const SettingsModel()),
        'goals': Goals.payload({
          'g': {'title': 'Test', 'type': 'subs', 'current': 0, 'target': 10}
        }),
        'timer': SubathonTimer.payload(
            const SettingsModel(), now.millisecondsSinceEpoch),
        'giveaway':
            ChatGiveaway(keyword: '!test', membersOnly: false).toOverlayJson(),
        'poll':
            const ChatPoll(question: 'Q', options: ['A', 'B']).toOverlayJson(),
        'caption': {'text': 'Caption'},
        'fields': <String, Object?>{},
      };
      void checkShape(dynamic actual, dynamic real, String at) {
        if (actual is Map && real is Map) {
          expect(actual.keys.toSet(), real.keys.toSet(), reason: at);
          for (final key in actual.keys) {
            if (real[key] != null) {
              checkShape(actual[key], real[key], '$at.$key');
            }
          }
        } else if (actual is List && real is List) {
          if (real.isNotEmpty) {
            for (final item in actual) {
              final sample = item is Map && item.containsKey('kind')
                  ? real.firstWhere((candidate) =>
                      candidate is Map && candidate['kind'] == item['kind'])
                  : real.first;
              checkShape(item, sample, at);
            }
          }
        } else if (actual != null && real != null) {
          expect(
              actual is num
                  ? real is num
                  : actual.runtimeType == real.runtimeType,
              isTrue,
              reason: at);
        }
      }

      for (final entry in expected.entries) {
        expect(events[entry.key], isNotEmpty, reason: entry.key);
        for (final data in events[entry.key] as List) {
          checkShape(data, entry.value, entry.key);
        }
      }
      final server =
          await File('lib/services/overlay_server.dart').readAsString();
      Set<String> encoderKeys(String method) =>
          RegExp(r"^        '([^']+)':", multiLine: true)
              .allMatches(server
                  .split('static Map<String, Object?> $method(')[1]
                  .split('};')[0])
              .map((m) => m[1]!)
              .toSet();
      final types = <String>{};
      for (final alert in events['alert'] as List) {
        types.add(alert['alertType'] as String);
        expect(
            (alert as Map).keys.toSet(),
            encoderKeys(['raid', 'kicks'].contains(alert['alertType'])
                ? '_providerAlertData'
                : '_alertData'));
      }
      expect(types, {
        'superchat',
        'membership',
        'bits',
        'subscription',
        'gift',
        'raid',
        'kicks'
      });
      for (final featured in events['featured'] as List) {
        expect((featured as Map).keys.toSet(), encoderKeys('_alertData'));
      }
      // ignore: avoid_print
      print(
          'DRY RUN: 60000ms fake time; no exceptions; latest=${out['latest']}; all demo payload key sets match live encoders.\nFILES: ${jsonEncode(files)}');
    } finally {
      await library.dispose();
      await temp.delete(recursive: true);
    }
  });
}

const nodeCheck = r"""
const vm = require('node:vm');
let now=0, sequence=0;
const timers=[], events={}, errors=[];
const latest={textContent:'Waiting'};
const document={getElementById:()=>latest,createDocumentFragment:()=>({appendChild(){}}),createTextNode:text=>({textContent:text}),createElement:()=>({})};
class FakeDate extends Date { constructor(...args){super(...(args.length?args:[now]));} static now(){return now;} }
const context={document,location:{pathname:'/custom/support-spotlight/',search:'?demo=1',protocol:'http:',host:'localhost:8080'},navigator:{language:'en'},Date:FakeDate,URLSearchParams,console:{error:e=>errors.push(String(e))},queueMicrotask:fn=>fn(),fetch:async()=>({ok:true,json:async()=>({})}),setInterval(fn,ms){timers.push({fn,ms,at:now+ms,id:sequence++});},setTimeout(fn,ms){timers.push({fn,ms:0,at:now+ms,id:sequence++});},clearTimeout(){},addEventListener(){}};
context.window=context;
vm.createContext(context);
vm.runInContext(input.sdk,context);
for(const name of ['chat','delete','alert','featured','goals','timer','giveaway','poll','caption','event','settings','fields']) context.Airstream.on(name,data=>(events[name]??=[]).push(JSON.parse(JSON.stringify(data))));
vm.runInContext(input.script,context);
(async()=>{
 for(let i=0;i<8;i++) await Promise.resolve();
 while(true){timers.sort((a,b)=>a.at-b.at||a.id-b.id);const t=timers.shift();if(!t||t.at>60000)break;now=t.at;t.fn();if(t.ms){t.at+=t.ms;timers.push(t);}await Promise.resolve();}
 process.stdout.write(JSON.stringify({latest:latest.textContent,events,errors}));
})().catch(e=>{console.error(e);process.exitCode=1;});
""";
