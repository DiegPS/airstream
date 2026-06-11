import 'package:airstream/services/obs_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OBS state carries recording status and metrics', () {
    final state = const ObsState().copyWith(
      recordingActive: true,
      recordingPaused: true,
      recordingDurationMs: 3723000,
      recordingBytes: 1073741824,
    );

    expect(state.recordingActive, isTrue);
    expect(state.recordingPaused, isTrue);
    expect(state.recordingDurationMs, 3723000);
    expect(state.recordingBytes, 1073741824);
  });

  test('poll failures remain tolerant before marking OBS unstable', () {
    expect(
      ObsService.pollFailureActionFor(1),
      ObsPollFailureAction.preserve,
    );
    expect(
      ObsService.pollFailureActionFor(2),
      ObsPollFailureAction.preserve,
    );
  });

  test('poll failures mark OBS unstable before reconnect threshold', () {
    for (var failures = 3; failures < 8; failures++) {
      expect(
        ObsService.pollFailureActionFor(failures),
        ObsPollFailureAction.unstable,
      );
    }
  });

  test('poll failures reconnect after eight consecutive failures', () {
    expect(
      ObsService.pollFailureActionFor(8),
      ObsPollFailureAction.reconnect,
    );
    expect(
      ObsService.pollFailureActionFor(10),
      ObsPollFailureAction.reconnect,
    );
  });
}
