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
    await tester.tap(find.byTooltip('OBS & Overlay'));
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
