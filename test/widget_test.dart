import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airstream/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AirstreamApp()),
    );
    expect(find.byType(AirstreamApp), findsOneWidget);
  });
}
