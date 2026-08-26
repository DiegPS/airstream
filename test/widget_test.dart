import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airstream/main.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';

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

    expect(find.text('Dashboard'), findsOneWidget);
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
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Connections'), findsWidgets);
    expect(find.text('Panel'), findsNothing);
    expect(find.text('Conexiones'), findsNothing);

    await tester.tap(find.byTooltip('TTS & Voice'));
    await tester.pump();
    expect(find.text('Voice Reader (TTS)'), findsOneWidget);
    expect(find.text('Lector de voz (TTS)'), findsNothing);
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

    expect(find.text('Panel'), findsOneWidget);
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
