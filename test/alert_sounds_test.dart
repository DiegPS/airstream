import 'dart:async';
import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/main.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final name in AlertSounds.builtIn) {
    test('$name is a quiet, short mono PCM WAV without endpoint clicks', () {
      final bytes = AlertSounds.wav(name);
      expect(identical(bytes, AlertSounds.wav(name)), isTrue);
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(data.getUint32(4, Endian.little), bytes.length - 8);
      expect(data.getUint16(20, Endian.little), 1);
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint16(34, Endian.little), 16);
      final size = data.getUint32(40, Endian.little);
      expect(size, bytes.length - 44);
      expect(size / 2 / 22050, lessThan(1.2));
      for (var offset = 44; offset < bytes.length; offset += 2) {
        expect(data.getInt16(offset, Endian.little).abs() / 32767,
            lessThanOrEqualTo(0.32));
      }
      expect(data.getInt16(44, Endian.little).abs(), lessThan(100));
      expect(
          data.getInt16(bytes.length - 2, Endian.little).abs(), lessThan(100));
    });
  }
  test(
      'custom files require an allowed extension, regular file and at most 5 MB',
      () {
    final dir = Directory.systemTemp.createTempSync('airstream-sounds-');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final extension in ['WAV', 'mp3', 'ogg']) {
      final file = File('${dir.path}/valid.$extension')
        ..writeAsBytesSync([1, 2]);
      expect(AlertSounds.customFile(file.path)?.path, file.path);
      expect(
          AlertSounds.contentType(file.path),
          {
            'WAV': 'audio/wav',
            'mp3': 'audio/mpeg',
            'ogg': 'audio/ogg'
          }[extension]);
    }
    final boundary = File('${dir.path}/boundary.wav')
      ..writeAsBytesSync(Uint8List(5 * 1024 * 1024));
    expect(AlertSounds.customFile(boundary.path), isNotNull);
    boundary.writeAsBytesSync([0], mode: FileMode.append);
    expect(AlertSounds.customFile(boundary.path), isNull);
    final executable = File('${dir.path}/bad.exe')..writeAsStringSync('no');
    final directory = Directory('${dir.path}/directory.wav')..createSync();
    for (final path in [
      '',
      '${dir.path}/missing.wav',
      executable.path,
      directory.path
    ]) {
      expect(AlertSounds.customFile(path), isNull);
    }
  });
  testWidgets('raid Test calls the controller with raid after choosing Coin',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _SoundTestController();
    addTearDown(() {
      unawaited(controller.dispose());
    });
    final settings = _SoundTestSettings();
    await tester.pumpWidget(ProviderScope(overrides: [
      appControllerProvider.overrideWithValue(controller),
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
    final button = find.byKey(const Key('alert-type-test-raid'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(controller.testKinds, ['raid']);
    expect(find.text('Test alert sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _SoundTestController extends AppController {
  final testKinds = <String>[];
  @override
  bool testOverlayAlert(String kind) {
    testKinds.add(kind);
    return true;
  }
}

class _SoundTestSettings extends SettingsNotifier {
  _SoundTestSettings() {
    state = const SettingsModel(overlayEnabled: true);
  }
  @override
  Future<void> update(SettingsModel settings) async {
    state = settings;
  }
}
