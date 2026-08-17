import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airstream/main.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';

class _WidgetTestSettings extends SettingsNotifier {
  _WidgetTestSettings() {
    state = const SettingsModel(overlayEnabled: false);
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
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
