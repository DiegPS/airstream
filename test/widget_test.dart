import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airstream/main.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/application/app_providers.dart';

class _WidgetTestSettings extends SettingsNotifier {
  _WidgetTestSettings([
    String languageCode = 'en',
    String youtubeHandle = '',
  ]) {
    state = SettingsModel(
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
}
