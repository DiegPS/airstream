import 'dart:io';

import 'package:airstream/models/app_notice.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports an overlay port conflict instead of publishing a false URL',
      () async {
    final occupiedPort = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final controller = AppController();
    addTearDown(() async {
      await controller.dispose();
      await occupiedPort.close(force: true);
    });

    final failed = controller.overlayStateStream.firstWhere(
      (state) => state.phase == OverlayServerPhase.error,
    );
    controller.applySettings(
      SettingsModel(
        overlayEnabled: true,
        overlayPort: occupiedPort.port,
      ),
      connectChats: false,
    );

    final state = await failed.timeout(const Duration(seconds: 5));
    expect(state.port, occupiedPort.port);
    expect(state.error, isNotNull);
    expect(controller.overlayUrl, isNull);
  });
}
