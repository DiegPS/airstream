import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airstream/main.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';

class _WidgetTestSettings extends SettingsNotifier {
  _WidgetTestSettings([String languageCode = 'en']) {
    state = SettingsModel(
      appLanguageCode: languageCode,
      overlayEnabled: false,
    );
  }
}

void main() {
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
}
