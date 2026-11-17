import 'package:airstream/models/app_notice.dart';
import 'package:airstream/ui/widgets/settings_controls.dart';
import 'package:airstream/ui/widgets/poll_card.dart';
import 'package:airstream/ui/widgets/giveaway_card.dart';
import 'package:airstream/ui/widgets/goals_card.dart';
import 'package:airstream/ui/widgets/subathon_card.dart';
import 'package:airstream/services/overlay_server.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:airstream/services/templates/template_starters.dart';
import 'package:airstream/ui/widgets/template_fields.dart';
import 'package:airstream/ui/widgets/templates_card.dart';
import 'dart:io' as io;
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/ui/widgets/diagnostics_card.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/ui/widgets/recent_alerts_card.dart';
import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'application/coordinator_fakes.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' as widgets;

import 'package:airstream/main.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/ui/widgets/chat_bubble.dart';
import 'package:airstream/ui/widgets/sidebar_tab_bar.dart';
import 'package:airstream/window/window_state.dart';

class _WidgetTestSettings extends SettingsNotifier {
  _WidgetTestSettings([
    String languageCode = 'en',
    String youtubeHandle = '',
    SettingsModel? model,
  ]) {
    state = model ??
        SettingsModel(
          appLanguageCode: languageCode,
          overlayEnabled: false,
          youtubeHandle: youtubeHandle,
        );
  }
}

void main() {
  testWidgets('Chat fields debounce, validate colors, refresh disk and reset',
      (tester) async {
    final temp = (await tester
        .runAsync(() => io.Directory.systemTemp.createTemp('fields-widget-')))!;
    final library = _CountingTemplateLibrary(temp);
    final info = await tester.runAsync(() async {
      final id = await library.createTemplate(
          'Chat', templateStarterFiles(TemplateStarter.chat, 'Chat'));
      return library.get(id);
    });
    final server = OverlayServer(templateLibrary: library);
    final sockets = <io.WebSocket>[];
    final frames = <List<Map>>[];
    await tester.runAsync(() async {
      await library.createTemplate(
          'Other', templateStarterFiles(TemplateStarter.chat, 'Other'));
      await server.start(
          messages: const Stream<ChatMessage>.empty(),
          settings: const SettingsModel(),
          port: 0);
      for (final id in ['chat', 'other']) {
        final socket =
            await io.WebSocket.connect('ws://127.0.0.1:${server.port}/ws');
        sockets.add(socket);
        final received = <Map>[];
        frames.add(received);
        socket.listen((raw) => received.add(jsonDecode(raw as String) as Map));
        socket.add(
            jsonEncode({'type': 'register', 'view': 'custom', 'template': id}));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final received in frames) {
        received.clear();
      }
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        for (final socket in sockets) {
          await socket.close();
        }
        await server.dispose();
        await temp.delete(recursive: true);
      });
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings())
        ],
        child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SingleChildScrollView(
                    child: SizedBox(
                        width: 360,
                        child:
                            TemplateFields(library: library, info: info!)))))));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('template-fields-chat')));
    await tester.pumpAndSettle();
    final color = find.byKey(const Key('template-field-chat-accentColor'));
    final slider = find.byKey(const Key('template-field-chat-maxMessages'));
    expect(tester.widget(slider), isA<Slider>());
    expect(
        tester.widget(
            find.byKey(const Key('template-field-chat-lifetimeSeconds'))),
        isA<TextField>());
    await tester.enterText(color, '#123456');
    await tester.enterText(color, '#abcdef');
    tester.widget<Slider>(slider).onChanged!(25);
    await tester.pump(const Duration(milliseconds: 399));
    expect(library.writes, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await _flushTemplateIO(tester);
    expect(library.writes, 1);
    final values = await tester.runAsync(() => library.resolvedValues('chat'));
    expect(values!['accentColor'], '#abcdef');
    expect(values['maxMessages'], 25);
    expect(frames.first.where((f) => f['type'] == 'fields').last['data'],
        containsPair('accentColor', '#abcdef'));
    expect(frames.first.where((f) => f['type'] == 'reload'), isEmpty);
    expect(
        frames.last
            .where((f) => f['type'] == 'fields' || f['type'] == 'reload'),
        isEmpty);
    await tester.enterText(color, 'wrong');
    await tester.pump(const Duration(milliseconds: 500));
    expect(library.writes, 1);
    expect(
        find.textContaining('This color has not been saved'), findsOneWidget);
    await tester.runAsync(
        () => library.writeValues('chat', {'accentColor': '#445566'}));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    expect(tester.widget<TextField>(color).controller!.text, 'wrong');
    tester.widget<TextField>(color).focusNode!.unfocus();
    await _flushTemplateIO(tester);
    expect(tester.widget<TextField>(color).controller!.text, '#445566');
    await tester.tap(find.byKey(const Key('template-fields-reset-chat')));
    await _flushTemplateIO(tester);
    await tester.pump();
    expect(
        (await tester
            .runAsync(() => library.resolvedValues('chat')))!['accentColor'],
        '#53fc18');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('media fields filter entries by kind', (tester) async {
    final temp = (await tester
        .runAsync(() => io.Directory.systemTemp.createTemp('fields-media-')))!;
    final library = TemplateLibrary(temp);
    final info = TemplateInfo(
        'media',
        TemplateManifest('media', {
          'fields': [
            {'key': 'sound', 'type': 'media', 'kind': 'audio'},
            {'key': 'all', 'type': 'media', 'kind': 'any'}
          ]
        }),
        [],
        temp.path);
    addTearDown(() async {
      await tester.runAsync(() async {
        await library.dispose();
        await temp.delete(recursive: true);
      });
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings(
              'en',
              '',
              const SettingsModel(mediaLibrary: {
                '1234567890abcdef': {'name': 'Sound', 'kind': 'audio'},
                'abcdef1234567890': {'name': 'Picture', 'kind': 'image'}
              })))
        ],
        child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home:
                Scaffold(body: TemplateFields(library: library, info: info)))));
    await tester.tap(find.byKey(const Key('template-fields-media')));
    await tester.pumpAndSettle();
    final sound = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('template-field-media-sound')));
    final all = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('template-field-media-all')));
    expect(sound.items!.map((i) => i.value), ['', '1234567890abcdef']);
    expect(all.items, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final valid in [true, false]) {
    testWidgets('Import ZIP confirmation and rejection valid=$valid',
        (tester) async {
      final temp = (await tester.runAsync(
          () => io.Directory.systemTemp.createTemp('import-widget-')))!;
      final library = TemplateLibrary(io.Directory('${temp.path}/templates'));
      final archive = Archive()
        ..addFile(ArchiveFile('shared/index.html', 1, [1]))
        ..addFile(ArchiveFile(
            'shared/template.json',
            utf8.encode('{"name":"Shared","network":true}').length,
            utf8.encode('{"name":"Shared","network":true}')));
      if (!valid) archive.addFile(ArchiveFile('shared/evil.exe', 1, [1]));
      final zip = io.File('${temp.path}/test.zip');
      await tester
          .runAsync(() => zip.writeAsBytes(ZipEncoder().encode(archive)));
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => [zip.path]);
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await tester.runAsync(() async {
          await library.dispose();
          await temp.delete(recursive: true);
        });
      });
      await tester.pumpWidget(ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
            templateLibraryProvider.overrideWith((ref) async => library),
            templateCountsProvider.overrideWith((ref) => Stream.value({})),
            templateErrorsProvider.overrideWith((ref) => Stream.value({}))
          ],
          child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                  body: SingleChildScrollView(child: TemplatesCard())))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('templates-import')));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(library.exists), false);
      if (valid) {
        expect(find.byKey(const Key('template-import-dialog')), findsOneWidget);
        expect(find.text('Internet access'), findsOneWidget);
        expect(
            find.textContaining('Import only templates from people you trust.'),
            findsOneWidget);
        await tester.tap(find.byKey(const Key('template-import-confirm')));
        await tester.pump();
        await _flushTemplateIO(tester);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('template-shared')), findsOneWidget);
      } else {
        expect(find.text('Unsupported file type.'), findsOneWidget);
        expect(await tester.runAsync(library.list), isEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'Create with AI copies localized instruction and generates guides',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final temp = (await tester
        .runAsync(() => io.Directory.systemTemp.createTemp('ai-widget-')))!;
    final library = TemplateLibrary(io.Directory('${temp.path}/templates'));
    addTearDown(() async {
      await tester.runAsync(() async {
        await library.dispose();
        await temp.delete(recursive: true);
      });
    });
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), (call) async => false);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'), null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) => _WidgetTestSettings(
          'en',
          '',
          const SettingsModel(
              appLanguageCode: 'en',
              overlayEnabled: false,
              overlayPort: 9123))),
      templateLibraryProvider.overrideWith((ref) async => library),
      overlayUrlProvider.overrideWithValue('http://localhost:9456'),
    ], child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('Templates'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(library.exists), isFalse);
    await tester.tap(find.byKey(const Key('templates-ai')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('templates-ai-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('templates-ai-copy')));
    await tester.pumpAndSettle();
    expect(copied, isNull);
    expect(await tester.runAsync(library.exists), isFalse);
    await tester.enterText(
        find.byKey(const Key('templates-ai-description')), 'Latest supporter');
    await tester.tap(find.byKey(const Key('templates-ai-copy')));
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(copied, contains('AGENTS.md'));
    expect(copied, contains('latest-supporter'));
    expect(copied,
        contains('http://localhost:9456/custom/latest-supporter/?demo=1'));
    expect(find.text('Instruction copied'), findsOneWidget);
    for (final name in ['AGENTS.md', 'CLAUDE.md', 'airstream.d.ts']) {
      expect(
          await tester
              .runAsync(() => io.File('${library.rootPath}/$name').exists()),
          isTrue);
    }
  });

  testWidgets(
      'Templates creates copies edits and deletes without creating root on open',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final temp = (await tester.runAsync(
        () => io.Directory.systemTemp.createTemp('template-widget-')))!;
    final library = TemplateLibrary(io.Directory('${temp.path}/templates'));
    addTearDown(() async {
      await tester.runAsync(() async {
        await library.dispose();
        if (await temp.exists()) await temp.delete(recursive: true);
      });
    });
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), (call) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null));
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
      templateLibraryProvider.overrideWith((ref) async => library)
    ], child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('Templates'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Start from an example\nAsk an AI agent\nImport a template someone shared'),
        findsOneWidget);
    expect(await tester.runAsync(library.exists), isFalse);
    Future<void> flushFiles() async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pumpAndSettle();
    }

    Future<void> press(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await flushFiles();
    }

    await press('templates-new');
    await tester.enterText(
        find.byKey(const Key('template-new-name')), 'Mi Chat ñ');
    await press('template-starter-chat');
    await press('template-new-create');
    await flushFiles();
    expect(find.byKey(const Key('template-mi-chat-n')), findsOneWidget);
    await press('template-copy-mi-chat-n');
    expect(copied, 'http://localhost:18080/custom/mi-chat-n/');
    await press('template-menu-mi-chat-n');
    await tester.tap(find.text('Edit code'));
    await flushFiles();
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    final index = await tester
        .runAsync(() => library.readTemplateFile('mi-chat-n', 'index.html'));
    await tester.tap(find.text('CSS'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('template-editor-css')), 'body { color: red; }');
    await press('template-editor-save');
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(
        await tester
            .runAsync(() => library.readTemplateFile('mi-chat-n', 'style.css')),
        'body { color: red; }');
    expect(
        await tester.runAsync(
            () => library.readTemplateFile('mi-chat-n', 'index.html')),
        index);
    await tester.enterText(
        find.byKey(const Key('template-editor-css')), 'body { color: blue; }');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await flushFiles();
    expect(
        await tester
            .runAsync(() => library.readTemplateFile('mi-chat-n', 'style.css')),
        'body { color: blue; }');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final css = await library.safeFile('mi-chat-n', 'style.css');
      await css!.delete();
      final js = await library.safeFile('mi-chat-n', 'script.js');
      await js!.writeAsString('x' * (TemplateLibrary.editorLimit + 1));
    });
    await press('template-menu-mi-chat-n');
    await tester.tap(find.text('Edit code'));
    await flushFiles();
    await press('template-editor-save');
    await tester.tap(find.text('JS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('over 512 KB'), findsOneWidget);
    expect(
        await tester.runAsync(() => library.safeFile('mi-chat-n', 'style.css')),
        isNull);
    expect(
        await tester.runAsync(() async =>
            (await library.safeFile('mi-chat-n', 'script.js'))!.length()),
        TemplateLibrary.editorLimit + 1);
    await tester.tap(find.text('HTML'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('template-editor-html')), '<p>Unsaved</p>');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(
        await tester.runAsync(
            () => library.readTemplateFile('mi-chat-n', 'index.html')),
        index);
    await press('template-menu-mi-chat-n');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await flushFiles();
    await tester.pump();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => library.get('mi-chat-n')), isNull);
    expect(find.byKey(const Key('template-mi-chat-n')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restarting a running subathon passes through idle',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final phases = <String>[];
    final settings =
        _RecordingSettings(const SettingsModel(overlayEnabled: false));
    settings.addListener((s) => phases.add(s.subathonPhase),
        fireImmediately: false);
    await tester.pumpWidget(ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('Live'));
    await tester.pump();
    final start = find.byKey(const Key('subathon-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    phases.clear();
    // OBS would read a running-to-running jump as support-added time.
    await tester.tap(start);
    await tester.pump();
    expect(phases, ['idle', 'running']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('subathon starts adds five minutes pauses and resets in OBS',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings =
        _RecordingSettings(const SettingsModel(overlayEnabled: false));
    await tester.pumpWidget(ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('Live'));
    await tester.pump();
    Future<void> press(String key) async {
      final button = find.byKey(Key(key));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }

    await press('subathon-start');
    expect(settings.state.subathonPhase, 'running');
    final before = settings.state.subathonEndsAtMs;
    await press('subathon-add-5');
    expect(settings.state.subathonEndsAtMs, before + 300000);
    expect(
        tester.widget<Text>(find.byKey(const Key('subathon-remaining'))).data,
        startsWith('1:05:'));
    await press('subathon-pause');
    expect(settings.state.subathonPhase, 'paused');
    await press('subathon-reset');
    expect(settings.state.subathonPhase, 'idle');
    expect(
        tester.widget<Text>(find.byKey(const Key('subathon-remaining'))).data,
        '0:00');
    final rules = find.byKey(const Key('subathon-rules'));
    await tester.ensureVisible(rules);
    await tester.tap(rules);
    await tester.pumpAndSettle();
    expect(find.text('Seconds per subscription or gifted sub'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('System diagnostics is first, shows OBS error and copies report',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) =>
          _WidgetTestSettings('en', '', const SettingsModel(obsEnabled: true))),
      obsStateProvider.overrideWith((ref) => Stream.value(const ObsState(
          error: 'Connection refused', statusMessage: 'Connection refused'))),
    ], child: const AirstreamApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('System & Window'));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('diagnostics-card'));
    expect(card, findsOneWidget);
    expect(tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.text('Desktop Window')).dy));
    final obs = find.byKey(const Key('diagnostics-obs'));
    expect(find.descendant(of: obs, matching: find.text('Connection refused')),
        findsOneWidget);
    final dot = tester
        .widgetList<Container>(
            find.descendant(of: obs, matching: find.byType(Container)))
        .where((w) => w.decoration is BoxDecoration)
        .first;
    expect((dot.decoration! as BoxDecoration).color, const Color(0xFFFF4E45));
    await tester.ensureVisible(find.byKey(const Key('diagnostics-copy')));
    await tester.tap(find.byKey(const Key('diagnostics-copy')));
    await tester.pumpAndSettle();
    expect(copied, contains('obs: ERROR - Connection refused'));
    expect(find.text('Report copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: SizedBox(width: 360, child: DiagnosticsCard()))),
        )));
    await tester.pumpAndSettle();
    expect(find.text('Todo funciona bien'), findsOneWidget);
    expect(find.text('Copiar informe'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Connections shows recent support and replays the selected alert',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final overlay = FakeOverlayClient();
    final alerts = <Map<String, Object?>>[
      {
        'id': 'one',
        'author': 'Ana',
        'platform': 'twitch',
        'alertType': 'subscription',
        'months': 6,
        'timestamp': '2026-11-15T12:30:00Z'
      },
      {
        'id': 'two',
        'author': 'Ben',
        'platform': 'kick',
        'alertType': 'gift',
        'giftCount': 5,
        'timestamp': '2026-11-15T12:20:00Z'
      },
    ];
    overlay.recent.addAll(alerts);
    final app =
        AppController(overlayCoordinator: OverlayCoordinator(overlay: overlay));
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
      appControllerProvider.overrideWithValue(app),
      recentAlertsProvider.overrideWith((ref) => Stream.value(alerts)),
    ], child: const AirstreamApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Connections').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Live'));
    await tester.pumpAndSettle();
    final replay = find.byKey(const Key('recent-alert-replay-one'));
    await tester.ensureVisible(replay);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recent-alerts-card')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('6 months'), findsOneWidget);
    expect(find.text('5 gifted'), findsOneWidget);
    await tester.tap(replay);
    await tester.pumpAndSettle();
    expect(overlay.replayed, ['one']);
    expect(find.text('Shown on stream again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(ProviderScope(
        overrides: [
          appControllerProvider.overrideWithValue(app),
          recentAlertsProvider.overrideWith((ref) => Stream.value(alerts)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: Center(
                  child: SizedBox(width: 360, child: RecentAlertsCard()))),
        )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    overlay.hasClients = false;
    await tester.tap(find.byKey(const Key('recent-alert-replay-two')));
    await tester.pumpAndSettle();
    expect(find.text('Open the alerts overlay in OBS/browser first'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(app.dispose());
  });

  testWidgets('renders the app shell before settings initialization completes',
      (WidgetTester tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
          settingsInitializationProvider.overrideWith(
            (ref) => initialization.future,
          ),
        ],
        child: const AirstreamApp(),
      ),
    );

    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Connections'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    expect(find.byType(AirstreamApp), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Ctrl+B'), findsNothing);
    expect(find.text('Connections'), findsWidgets);
    expect(find.text('Panel'), findsNothing);
    expect(find.text('Conexiones'), findsNothing);

    await tester.tap(find.byTooltip('TTS & Voice'));
    await tester.pump();
    expect(find.text('Voice Reader (TTS)'), findsOneWidget);
    expect(find.text('Lector de voz (TTS)'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('channel input keeps its height when the clear button appears',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    Finder youtubeInput() => find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == '@handle · channel ID · video ID',
        );
    Finder youtubeInputDecorator() => find.descendant(
          of: youtubeInput(),
          matching: find.byType(InputDecorator),
        );

    double paintedHeight() => InputDecorator.containerOf(
          tester.element(find.descendant(
            of: youtubeInputDecorator(),
            matching: find.byType(EditableText),
          )),
        )!
            .size
            .height;

    final emptyHeight = paintedHeight();
    await tester.enterText(youtubeInput(), '@channel');
    await tester.pump();
    final populatedHeight = paintedHeight();

    expect(emptyHeight, 36);
    expect(populatedHeight, emptyHeight);
    expect(find.byTooltip('Clear'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(paintedHeight(), emptyHeight);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('every settings tab renders its own content',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );

    expect(find.text('Connections'), findsWidgets);
    for (final tab in const <(String, String)>[
      ('TTS & Voice', 'Voice Reader (TTS)'),
      ('Appearance', 'Message Design'),
      ('OBS & Overlay', 'OBS Integration'),
      ('System & Window', 'Desktop Window'),
      ('Connections', 'YouTube handle, channel ID, video ID, or URL'),
    ]) {
      await tester.tap(find.byTooltip(tab.$1));
      await tester.pump();
      expect(find.text(tab.$2), findsWidgets, reason: 'tab ${tab.$1}');
      expect(tester.takeException(), isNull, reason: 'tab ${tab.$1}');
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hides the app name while the sidebar is hidden',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    expect(find.text('AIRSTREAM'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('AIRSTREAM'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hides the app name when the window switches to drawer mode',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    expect(find.text('AIRSTREAM'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switches the complete application shell to Spanish',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings('es')),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Panel'), findsNothing);
    expect(find.text('Conexiones'), findsWidgets);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Connections'), findsNothing);

    await tester.tap(find.byTooltip('TTS y voz'));
    await tester.pump();
    expect(find.text('Lector de voz (TTS)'), findsOneWidget);
    expect(find.text('Voice Reader (TTS)'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows a failed chat as an actionable error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _WidgetTestSettings('en', '@missing-channel'),
          ),
          chatSessionPhaseProvider.overrideWith(
            (ref) => ChatSessionPhase.failed,
          ),
          connectionStatusProvider.overrideWith(
            (ref) => Stream.value(
              const {
                'youtube': (ServiceStatus.error, 'channel not found'),
              },
            ),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsWidgets);
    expect(find.textContaining('could not connect'), findsNWidgets(2));
    expect(find.textContaining('YouTube could not connect'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Retry YouTube'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a narrow window without channels offers to open the menu',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    expect(find.textContaining('in the sidebar'), findsNothing);
    await tester.tap(find.byKey(const Key('configure-channels-button')));
    await tester.pumpAndSettle();
    expect(find.text('Connections'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the top bar fits a narrow window while chats run',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(380, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _WidgetTestSettings(
              'en',
              '',
              const SettingsModel(
                overlayEnabled: false,
                youtubeHandle: '@creator',
                twitchChannel: 'creator',
                kickSlug: 'creator',
              ),
            ),
          ),
          chatSessionPhaseProvider.overrideWith(
            (ref) => ChatSessionPhase.connected,
          ),
          connectionStatusProvider.overrideWith(
            (ref) => Stream.value(const {
              'youtube': (ServiceStatus.connected, null),
              'twitch': (ServiceStatus.connecting, null),
              'kick': (ServiceStatus.error, 'HTTP 404'),
            }),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final stop = tester.getRect(find.text('Stop'));
    final youtube = tester.getRect(find.text('YT'));
    expect(youtube.right, lessThan(stop.left));
    final tooltips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tooltip) => tooltip.message)
        .toList();
    expect(tooltips, contains('YouTube: connected'));
    expect(tooltips, contains('Twitch: connecting…'));
    expect(tooltips, contains(contains('Kick could not connect')));
    expect(tooltips, isNot(contains('HTTP 404')));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dual YouTube mode turns YouTube back on',
      (WidgetTester tester) async {
    final settings = _RecordingSettings(
      const SettingsModel(overlayEnabled: false, youtubeEnabled: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    final dualSwitch = find.descendant(
      of: find
          .ancestor(
            of: find.text('Horizontal + vertical'),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(dualSwitch);
    await tester.pump();
    await tester.tap(dualSwitch);
    await tester.pump();

    expect(settings.state.youtubeDualStreamEnabled, isTrue);
    expect(settings.state.youtubeEnabled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a typed channel is ready for the top bar Start button',
      (WidgetTester tester) async {
    final settings = _RecordingSettings(
      const SettingsModel(overlayEnabled: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'channel_name'),
      'creator',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(settings.state.twitchChannel, 'creator');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the overlay port is applied when editing ends, not per key',
      (WidgetTester tester) async {
    final settings = _RecordingSettings(
      const SettingsModel(overlayEnabled: true, overlayPort: 8080),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => settings),
          overlayUrlProvider.overrideWith((ref) => null),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('OBS & Overlay'));
    await tester.pump();

    final port = find.widgetWithText(TextField, '8080');
    await tester.enterText(port, '80');
    await tester.pump(const Duration(milliseconds: 400));
    expect(settings.state.overlayPort, 8080);

    await tester.enterText(port, '8081');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(settings.state.overlayPort, 8081);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('turning click-through on explains how to turn it off',
      (WidgetTester tester) async {
    final window = _FakeWindow();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
          windowStateProvider.overrideWith((ref) => window),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(window.state.clickThrough, isTrue);
    expect(find.textContaining('Press Ctrl+Shift+C to turn it off'),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the top bar offers to silence TTS only while it speaks',
      (WidgetTester tester) async {
    final speaking = StreamController<bool>();
    addTearDown(speaking.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
          ttsBusyProvider.overrideWith((ref) => speaking.stream),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('silence-tts-button')), findsNothing);

    speaking.add(true);
    await tester.pump();
    expect(find.byKey(const Key('silence-tts-button')), findsOneWidget);

    speaking.add(false);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('silence-tts-button')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the preview shows sample messages until the chat starts',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _WidgetTestSettings(
              'en',
              '',
              const SettingsModel(overlayEnabled: false, twitchChannel: 'x'),
            ),
          ),
          chatProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Appearance'));
    await tester.pump();

    await tester.tap(find.descendant(
      of: find
          .ancestor(
            of: find.text('Show sample messages'),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(Switch),
    ));
    await tester.pump();
    expect(find.textContaining('This is a long message', findRichText: true),
        findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AirstreamApp)),
    );
    container.read(chatConnectionProvider.notifier).state = true;
    await tester.pump();
    expect(container.read(chatPreviewProvider), isFalse);
    expect(find.textContaining('This is a long message', findRichText: true),
        findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the chat starts on launch when the user asked for it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _LoadedSettings(
              const SettingsModel(
                overlayEnabled: false,
                twitchChannel: 'creator',
                connectChatOnLaunch: true,
              ),
            ),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AirstreamApp)),
    );
    expect(container.read(chatConnectionProvider), isTrue);

    // Let the chat attempt wind down before the test ends.
    container.read(chatConnectionProvider.notifier).state = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a settings tab keeps its state when the user comes back',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    // Open the collapsed Filters card and type a draft in a channel field.
    await tester.ensureVisible(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked users'), findsOneWidget);

    await tester.tap(find.byTooltip('System & Window'));
    await tester.pump();
    expect(find.text('Blocked users'), findsNothing);

    await tester.tap(find.byTooltip('Connections'));
    await tester.pump();
    expect(find.text('Blocked users'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('OBS stats updates do not rebuild chat messages',
      (WidgetTester tester) async {
    final obs = StreamController<ObsState>();
    addTearDown(obs.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _WidgetTestSettings(
              'en',
              '',
              const SettingsModel(overlayEnabled: false, obsEnabled: true),
            ),
          ),
          obsStateProvider.overrideWith((ref) => obs.stream),
          chatProvider.overrideWith(
            (ref) => Stream.value([
              for (var i = 0; i < 5; i++)
                ChatMessage(
                  platform: Platform.twitch,
                  id: 'message-$i',
                  author: ChatAuthor(name: 'viewer$i', channelId: 'v$i'),
                  items: const [MessageItem.text('hola')],
                  timestamp: DateTime.utc(2026, 5, 9, 12),
                ),
            ]),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(ChatBubble), findsNWidgets(5));

    var bubbleBuilds = 0;
    widgets.debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is ChatBubble) bubbleBuilds++;
    };
    addTearDown(() => widgets.debugOnRebuildDirtyWidget = null);
    for (var i = 0; i < 5; i++) {
      obs.add(ObsState(connected: true, bitrateKbps: 6000.0 + i));
      await tester.pump();
    }
    widgets.debugOnRebuildDirtyWidget = null;

    expect(bubbleBuilds, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('connection badges keep space above them like below the tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _WidgetTestSettings(
              'en',
              '',
              const SettingsModel(
                overlayEnabled: false,
                twitchChannel: 'creator',
                kickSlug: 'creator',
              ),
            ),
          ),
          chatConnectionProvider.overrideWith((ref) => true),
          connectionStatusProvider.overrideWith(
            (ref) => Stream.value(const {
              'twitch': (ServiceStatus.connected, null),
              'kick': (ServiceStatus.connected, null),
            }),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final badges = tester.getRect(
      find.byKey(const Key('sidebar-connection-badges')),
    );
    final tabs = tester.getRect(find.byType(SidebarTabBar));
    // 38 px title bar, then the same 12 px margin the block keeps below.
    expect(badges.top, 38 + 12);
    expect(tabs.top - badges.bottom, 10);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the chat filter hides platforms until the user shows all',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
          chatProvider.overrideWith(
            (ref) => Stream.value([
              for (final platform in Platform.values)
                ChatMessage(
                  platform: platform,
                  id: 'from-${platform.name}',
                  author: ChatAuthor(
                    name: 'viewer-${platform.name}',
                    channelId: 'v-${platform.name}',
                  ),
                  items: [MessageItem.text('hola desde ${platform.name}')],
                  timestamp: DateTime.utc(2026, 11, 15),
                ),
            ]),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(ChatBubble), findsNWidgets(3));

    await tester.tap(find.byKey(const Key('chat-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-filter-twitch')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-filter-kick')).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(ChatBubble), findsOneWidget);
    expect(find.byKey(const Key('chat-filter-bar')), findsOneWidget);
    expect(find.text('Showing: YouTube'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatBubble), findsNWidgets(3));
    expect(find.byKey(const Key('chat-filter-bar')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a chat message opens its actions and can be copied',
      (WidgetTester tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
          chatProvider.overrideWith(
            (ref) => Stream.value([
              ChatMessage(
                platform: Platform.twitch,
                id: 'q1',
                author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
                items: const [MessageItem.text('¿Qué juego sigue?')],
                timestamp: DateTime.utc(2026, 11, 15),
              ),
            ]),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ChatBubble));
    await tester.pumpAndSettle();
    expect(find.text('Show on stream'), findsOneWidget);
    final showOnStream = tester.widget<PopupMenuItem<String>>(
      find.byKey(const Key('message-show-on-stream')),
    );
    expect(showOnStream.enabled, isFalse,
        reason: 'the overlay server is off in this test');

    await tester.tap(find.text('Copy message'));
    await tester.pumpAndSettle();
    expect(copied, 'Ana: ¿Qué juego sigue?');
    expect(find.text('Message copied'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('adds a goal in OBS adjusts by ten and deletes it',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) =>
          _RecordingSettings(const SettingsModel(overlayEnabled: false)))
    ], child: const AirstreamApp()));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AirstreamApp)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Live'));
    await tester.pumpAndSettle();
    final add = find.byKey(const Key('goals-add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal-title')), 'Community');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    final id = container.read(settingsProvider).goals.keys.single;
    final plus = find.byKey(Key('goal-$id-plus10'));
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(find.text('10 / 100'), findsOneWidget);
    expect(container.read(settingsProvider).goals[id]!['current'], 10);
    final delete = find.byKey(Key('goal-$id-delete'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).goals, isEmpty);
    expect(find.text('Community'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a giveaway starts in OBS counts chat and draws a winner',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final youtube = FakeYouTubeChatClient();
    final controller = AppController(
        chatCoordinator: ChatCoordinator(
            youtube: youtube,
            youtubeHorizontal: FakeYouTubeChatClient(),
            youtubeVertical: FakeYouTubeChatClient(),
            twitch: FakeChannelChatClient(),
            kick: FakeChannelChatClient()),
        overlayCoordinator: OverlayCoordinator(overlay: FakeOverlayClient()));
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
      appControllerProvider.overrideWithValue(controller),
    ], child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('Live'));
    await tester.pump();
    final start = find.byKey(const Key('giveaway-start'));
    await tester.ensureVisible(start);
    await tester.enterText(
        find.byKey(const Key('giveaway-keyword')), '!sorteo');
    await tester.pump();
    await tester.tap(start);
    await tester.pump();
    youtube.messageController.add(ChatMessage(
        platform: Platform.youtube,
        id: 'giveaway-entry',
        author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
        items: const [MessageItem.text('!SORTEO')],
        timestamp: DateTime.utc(2026)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('1 participants'), findsOneWidget);
    final draw = find.byKey(const Key('giveaway-draw'));
    await tester.ensureVisible(draw);
    await tester.tap(draw);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('giveaway-winner')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('giveaway-winner'))).data,
        'Ana');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(controller.dispose());
  });

  testWidgets('a poll is created, runs and ends from its card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Live'));
    await tester.pump();

    final start = find.byKey(const Key('poll-start'));
    await tester.ensureVisible(start);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
    await tester.enterText(
        find.byKey(const Key('poll-question')), '¿Qué juego?');
    await tester.enterText(find.byKey(const Key('poll-option-0')), 'Uno');
    await tester.enterText(find.byKey(const Key('poll-option-1')), 'Dos');
    await tester.pump();
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('¿Qué juego?'), findsOneWidget);
    expect(find.textContaining('0 votes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('poll-end')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Final results'), findsOneWidget);

    await tester.tap(find.byKey(const Key('poll-new')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('poll-start')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the session summary opens from the connections tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();

    final button = find.byKey(const Key('session-summary-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Session summary'), findsWidgets);
    expect(find.textContaining('the summary collects'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a profile is saved and applied from the system tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _RecordingSettings(
      const SettingsModel(overlayEnabled: false, fontSize: 22),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('System & Window'));
    await tester.pump();

    final name = find.byKey(const Key('profile-name'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Gaming');
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();
    expect(settings.state.profiles.keys, ['Gaming']);
    expect(find.text('Gaming'), findsOneWidget);

    settings.state = settings.state.copyWith(fontSize: 14);
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-apply-Gaming')));
    await tester.pumpAndSettle();
    expect(settings.state.fontSize, 22);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Ctrl+F searches the chat and Escape closes the search',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
          chatProvider.overrideWith(
            (ref) => Stream.value([
              for (final (i, text) in ['hola a todos', 'buen juego'].indexed)
                ChatMessage(
                  platform: Platform.twitch,
                  id: 'm$i',
                  author: ChatAuthor(name: 'viewer$i', channelId: 'v$i'),
                  items: [MessageItem.text(text)],
                  timestamp: DateTime.utc(2026, 11, 15),
                ),
            ]),
          ),
        ],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(ChatBubble), findsNWidgets(2));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('chat-search-field')), 'juego');
    await tester.pump();
    expect(find.byType(ChatBubble), findsOneWidget);
    expect(find.textContaining('juego'), findsWidgets);

    await tester.tap(find.byKey(const Key('chat-search-close')));
    await tester.pump();
    expect(find.byKey(const Key('chat-search-field')), findsNothing);
    expect(find.byType(ChatBubble), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a global shortcut is recorded from the keyboard',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _RecordingSettings(
      const SettingsModel(overlayEnabled: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const AirstreamApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('System & Window'));
    await tester.pump();

    final record = find.byKey(const Key('shortcut-record-silenceTts'));
    await tester.ensureVisible(record);
    await tester.tap(record);
    await tester.pump();
    expect(find.text('Press the keys…'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.text('Use Ctrl, Alt or Win with the key.'), findsOneWidget);
    expect(settings.state.shortcutSilenceTts, isEmpty);

    await tester.tap(record);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(settings.state.shortcutSilenceTts, 'control+alt+M');
    expect(find.text('Ctrl + Alt + M'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('OBS raid switch toggles the disabled alert setting',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings =
        _RecordingSettings(const SettingsModel(overlayEnabled: true));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        overlayUrlProvider.overrideWith((ref) => null),
      ],
      child: const AirstreamApp(),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('OBS & Overlay'));
    await tester.pump();
    final raid = find.descendant(
        of: find.byKey(const Key('alert-type-raid')),
        matching: find.byType(Switch));
    await tester.ensureVisible(raid);
    await tester.tap(raid);
    await tester.pump();
    expect(settings.state.alertDisabledTypes, ['raid']);
    await tester.tap(raid);
    await tester.pump();
    expect(settings.state.alertDisabledTypes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('OBS style applies and undoes without enabling sample messages',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings =
        _RecordingSettings(const SettingsModel(overlayEnabled: true));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        overlayUrlProvider.overrideWith((ref) => null),
      ],
      child: const AirstreamApp(),
    ));
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AirstreamApp)));
    expect(container.read(chatPreviewProvider), isFalse);
    await tester.tap(find.byTooltip('OBS & Overlay'));
    await tester.pump();
    final row = find.byKey(const Key('overlay-style-preset-bigBubbles'));
    expect(
        tester
            .getSize(find.byKey(const Key('overlay-style-presets-card')))
            .width,
        lessThanOrEqualTo(360));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Big bubbles'));
    await tester.pumpAndSettle();
    expect(settings.state.overlayFontSize, 20);
    expect(find.descendant(of: row, matching: find.byIcon(Icons.check)),
        findsOneWidget);
    expect(container.read(chatPreviewProvider), isFalse);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(settings.state.overlayFontSize, 14);
    expect(container.read(chatPreviewProvider), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'OBS raid options store duration and remove general entrance override',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings =
        _RecordingSettings(const SettingsModel(overlayEnabled: true));
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) => settings),
      overlayUrlProvider.overrideWith((ref) => null),
    ], child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('OBS & Overlay'));
    await tester.pump();
    final expand = find.byKey(const Key('alert-type-options-raid'));
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    final own = find.descendant(
        of: find.byKey(const Key('alert-type-duration-switch-raid')),
        matching: find.byType(Switch));
    await tester.ensureVisible(own);
    await tester.tap(own);
    await tester.pumpAndSettle();
    final duration = find.byKey(const Key('alert-type-duration-raid'));
    expect(tester.getSize(duration).width, lessThanOrEqualTo(360));
    final slider = find.descendant(of: duration, matching: find.byType(Slider));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(45, 0));
    await tester.pumpAndSettle();
    expect(settings.state.alertTypeOptions['raid']!['seconds'],
        inInclusiveRange(3, 20));
    final entrance = find.descendant(
        of: find.byKey(const Key('alert-type-animation-raid')),
        matching: find.byType(DropdownButton<String>));
    await tester.ensureVisible(entrance);
    await tester.tap(entrance);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fade').last);
    await tester.pumpAndSettle();
    expect(settings.state.alertTypeOptions['raid']!['animation'], 'fade');
    await tester.tap(entrance);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use general').last);
    await tester.pumpAndSettle();
    expect(settings.state.alertTypeOptions['raid']!.containsKey('animation'),
        isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('raid stores a library image and audio selection',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _RecordingSettings(
        const SettingsModel(overlayEnabled: true, mediaLibrary: {
      '1234567890abcdef': {
        'name': 'Picture.png',
        'kind': 'image',
        'ext': 'png',
        'bytes': 8,
        'addedAt': 1
      },
      'abcdef1234567890': {
        'name': 'Music.wav',
        'kind': 'audio',
        'ext': 'wav',
        'bytes': 12,
        'addedAt': 1
      },
    }));
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) => settings),
      overlayUrlProvider.overrideWith((ref) => null)
    ], child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('OBS & Overlay'));
    await tester.pump();
    final expand = find.byKey(const Key('alert-type-options-raid'));
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    Future<void> choose(String key, String label) async {
      final dropdown = find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(DropdownButton<String>));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await choose('alert-type-media-raid', 'Picture.png');
    await choose('alert-type-sound-raid', 'Library: Music.wav');
    expect(
        settings.state.alertTypeOptions['raid']!['media'], '1234567890abcdef');
    expect(settings.state.alertTypeOptions['raid']!['sound'], 'library');
    expect(settings.state.alertTypeOptions['raid']!['soundMediaId'],
        'abcdef1234567890');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('raid sound stores Coin and its Test button sends feedback',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings =
        _RecordingSettings(const SettingsModel(overlayEnabled: true));
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsProvider.overrideWith((ref) => settings),
      overlayUrlProvider.overrideWith((ref) => null),
    ], child: const AirstreamApp()));
    await tester.pump();
    await tester.tap(find.byTooltip('OBS & Overlay'));
    await tester.pump();
    final expand = find.byKey(const Key('alert-type-options-raid'));
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    final sound = find.descendant(
        of: find.byKey(const Key('alert-type-sound-raid')),
        matching: find.byType(DropdownButton<String>));
    await tester.ensureVisible(sound);
    await tester.tap(sound);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coin').last);
    await tester.pumpAndSettle();
    expect(settings.state.alertTypeOptions['raid']!['sound'], 'coin');
    final test = find.byKey(const Key('alert-type-test-raid'));
    await tester.ensureVisible(test);
    await tester.tap(test);
    await tester.pump();
    expect(find.text('Open the alerts overlay in OBS/browser first'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final language in ['en', 'es']) {
    for (final ready in [false, true]) {
      testWidgets('360px settings $language server ready=$ready',
          (tester) async {
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('window_manager'), (call) async => false);
        addTearDown(() => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('window_manager'), null));
        final overrides = [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings(
              language,
              '',
              SettingsModel(appLanguageCode: language, overlayEnabled: ready))),
          overlayUrlProvider
              .overrideWithValue(ready ? 'http://localhost:9456' : null),
          overlayServerStateProvider.overrideWith((ref) => Stream.value(
              OverlayServerState(
                  phase: ready
                      ? OverlayServerPhase.ready
                      : OverlayServerPhase.disabled))),
          templateCountsProvider.overrideWith((ref) => Stream.value({})),
        ];
        await tester.pumpWidget(
            ProviderScope(overrides: overrides, child: const AirstreamApp()));
        await tester.pump();
        final sidebarFinder = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_SettingsSidebar');
        final sidebar = tester.widget<Widget>(sidebarFinder);
        final theme = Theme.of(tester.element(sidebarFinder));
        await tester.pumpWidget(ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              theme: theme,
              locale: Locale(language),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SizedBox(width: 360, child: sidebar)),
            )));
        await tester.pumpAndSettle();
        expect(tester.getSize(sidebarFinder).width, 360);
        final live = language == 'en' ? 'Live' : 'En directo';
        final obs = language == 'en' ? 'OBS & Overlay' : 'OBS y superposición';
        await tester.tap(find.byTooltip(obs));
        await tester.pump();
        expect(find.byType(PollCard), findsNothing);
        expect(find.byType(GiveawayCard), findsNothing);
        expect(find.byType(GoalsCard), findsNothing);
        expect(find.byType(SubathonCard), findsNothing);
        expect(find.byType(RecentAlertsCard), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip(live));
        await tester.pump();
        for (final type in [
          PollCard,
          GiveawayCard,
          GoalsCard,
          SubathonCard,
          RecentAlertsCard
        ]) {
          expect(find.byType(type), findsOneWidget);
        }
        expect(find.byKey(const Key('live-server-notice')),
            ready ? findsNothing : findsOneWidget);
        if (ready) {
          final rows = find.descendant(
              of: find.byType(PollCard), matching: find.byType(PageUrlRow));
          expect(tester.widget<PageUrlRow>(rows).url,
              'http://localhost:9456/poll');
          for (final (type, path) in [
            (GiveawayCard, 'giveaway'),
            (GoalsCard, 'goals'),
            (SubathonCard, 'timer')
          ]) {
            expect(
                tester
                    .widget<PageUrlRow>(find.descendant(
                        of: find.byType(type),
                        matching: find.byType(PageUrlRow)))
                    .url,
                'http://localhost:9456/$path');
          }
          String? copied;
          tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
          final copy =
              find.descendant(of: rows, matching: find.byType(IconButton));
          await tester.ensureVisible(copy);
          await tester.tap(copy);
          await tester.pump();
          expect(copied, 'http://localhost:9456/poll');
          tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        }
        final segments = [
          for (final key in ['sub-5', 'sub-1', 'add-1', 'add-5'])
            find.byKey(Key('subathon-$key'))
        ];
        final y = tester.getTopLeft(segments.first).dy;
        for (final segment in segments) {
          expect(tester.getTopLeft(segment).dy, y);
          expect(tester.getSize(segment).width,
              tester.getSize(segments.first).width);
        }
        expect(tester.getSize(find.byType(SubathonCard)).width,
            lessThanOrEqualTo(360));
        expect(tester.takeException(), isNull);
        if (!ready) {
          final button = find.byKey(const Key('live-open-obs'));
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          expect(
              find.text(
                  language == 'en' ? 'OBS Integration' : 'Integración OBS'),
              findsOneWidget);
        }
        await tester
            .tap(find.byTooltip(language == 'en' ? 'Templates' : 'Plantillas'));
        await tester.pump();
        expect(find.byKey(const Key('templates-test')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('Templates test events appear only for an open template page',
      (tester) async {
    final counts = StreamController<Map<String, int>>();
    addTearDown(counts.close);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _WidgetTestSettings()),
          templateCountsProvider.overrideWith((ref) => counts.stream),
        ],
        child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SizedBox(
                    width: 360,
                    child: SingleChildScrollView(child: TemplatesCard()))))));
    await tester.pump();
    expect(find.byKey(const Key('templates-test')), findsNothing);
    counts.add({'example': 1});
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('templates-test')), findsOneWidget);
    counts.add({'example': 0});
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('templates-test')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// Applies updates immediately, without the persisted settings load.
class _RecordingSettings extends _WidgetTestSettings {
  _RecordingSettings(SettingsModel model) : super('en', '', model);

  @override
  Future<void> update(SettingsModel settings) async {
    state = settings;
  }
}

/// Window state without the native plugin.
class _FakeWindow extends WindowStateNotifier {
  @override
  Future<void> toggleClickThrough() async {
    state = state.copyWith(clickThrough: !state.clickThrough);
  }
}

/// Settings that finished loading, as after a normal launch.
class _LoadedSettings extends _WidgetTestSettings {
  _LoadedSettings(SettingsModel model) : super('en', '', model);

  @override
  Future<void> get ready => Future<void>.value();
}

class _CountingTemplateLibrary extends TemplateLibrary {
  _CountingTemplateLibrary(super.root);
  int writes = 0;
  @override
  Future<void> writeValues(String id, Map values) {
    writes++;
    return super.writeValues(id, values);
  }
}

Future<void> _flushTemplateIO(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  await tester.pumpAndSettle();
}
