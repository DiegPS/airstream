import 'package:airstream/models/chat_message.dart';
import 'package:airstream/preview/sample_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sample messages cover every platform and never look like chat', () {
    final samples = sampleChatMessages('es');

    expect(samples.map((m) => m.platform).toSet(), Platform.values.toSet());
    expect(samples.every((m) => m.id.startsWith(previewMessagePrefix)), isTrue);
    expect(samples.map((m) => m.dedupeKey).toSet(), hasLength(samples.length));
    expect(samples.any((m) => m.superChat != null), isTrue);
    final membership = samples.singleWhere((m) => m.isMembershipEvent);
    expect(membership.items, isEmpty);
  });

  test('sample messages follow the app language', () {
    expect(sampleChatMessages('en').first.plainText, 'Welcome to the stream!');
    expect(
        sampleChatMessages('es').first.plainText, '¡Bienvenidos al directo!');
  });
}
