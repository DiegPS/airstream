import 'package:airstream/models/chat_message.dart';
import 'package:airstream/ui/widgets/author_avatar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('initials keep emoji and other surrogate pairs whole',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AuthorAvatar(name: '😀gamer 🎮pro', platform: Platform.twitch),
      ),
    ));
    expect(find.text('😀🎮'), findsOneWidget);
  });

  testWidgets('initials skip leading @ and use the first two words',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AuthorAvatar(name: '@ana maria lopez', platform: Platform.kick),
      ),
    ));
    expect(find.text('AM'), findsOneWidget);
  });
}
