import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_fakes.dart';

void main() {
  late FakeObsClient obs;
  late ObsCoordinator coordinator;

  setUp(() {
    obs = FakeObsClient();
    coordinator = ObsCoordinator(obs: obs);
  });

  tearDown(() => coordinator.dispose());

  test('connects on demand and reconnects after connection settings change',
      () async {
    const initial = SettingsModel(
      obsEnabled: true,
      obsHost: 'localhost:4455',
    );
    coordinator.applySettings(initial, previous: null);
    expect(obs.connectCount, 0);
    await coordinator.connect();
    expect(obs.connectCount, 1);

    final changed = initial.copyWith(obsHost: '192.168.1.10:4455');
    coordinator.applySettings(changed, previous: initial);
    await settleCoordinatorTasks();
    expect(obs.connectCount, 2);
    expect(obs.lastHost, '192.168.1.10:4455');

    await coordinator.disconnect();
    expect(obs.disconnectCount, 1);
  });

  test('turns voice command errors into user notices', () async {
    obs.commandError = StateError('not connected');
    final notice = coordinator.notices.first;
    await coordinator.executeVoiceCommand(
      const VoiceCommand(VoiceCommandType.startRecording),
    );
    expect((await notice).code, AppNoticeCode.voiceCommandFailed);
  });

  test('disposes its service only once', () async {
    await coordinator.dispose();
    await coordinator.dispose();
    expect(obs.disposed, isTrue);
  });
}
