import 'support/empty_template_library.dart';
import 'package:airstream/services/overlay_server.dart';
import 'dart:io';

import 'package:airstream/application/app_controller.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moves the overlay to the next free port when its port is busy',
      () async {
    final occupiedPort = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final controller = AppController(
        overlay: OverlayServer(templateLibrary: emptyTemplateLibrary()));
    addTearDown(() async {
      await controller.dispose();
      await occupiedPort.close(force: true);
    });

    final ready = controller.overlayStateStream.firstWhere(
      (state) => state.phase == OverlayServerPhase.ready,
    );
    controller.applySettings(
      SettingsModel(
        overlayEnabled: true,
        overlayPort: occupiedPort.port,
      ),
      connectChats: false,
    );

    final state = await ready.timeout(const Duration(seconds: 5));
    expect(state.requestedPort, occupiedPort.port);
    expect(state.port, isNot(occupiedPort.port));
    expect(controller.overlayUrl, 'http://localhost:${state.port}');
  });
}
