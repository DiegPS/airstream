import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'rule_events.dart';

/// Observes existing state deliveries; the first connected snapshot is a baseline.
class RuleObsTransitions {
  RuleObsTransitions({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  ObsState? _previous;
  final _expected = <({String scene, int depth, DateTime expires})>[];
  int _sequence = 0;
  void expectScene(String scene, int depth) {
    _expected.removeWhere((e) => !e.expires.isAfter(_clock()));
    _expected.add((
      scene: scene,
      depth: depth,
      expires: _clock().add(const Duration(seconds: 5))
    ));
  }

  List<RuleEvent> observe(ObsState state) {
    final old = _previous;
    _previous = state.connected ? state : null;
    if (!state.connected ||
        old == null ||
        old.connectionGeneration != state.connectionGeneration) {
      _expected.clear();
      return [];
    }
    final events = <RuleEvent>[];
    void add(String type, {int depth = 0}) => events.add(RuleEvent(
        type: type,
        scene: state.currentScene,
        eventId: 'obs:${++_sequence}',
        chainDepth: depth));
    if (old.outputActive != state.outputActive) {
      add(state.outputActive ? 'obs.streamStarted' : 'obs.streamStopped');
    }
    if (old.recordingActive != state.recordingActive) {
      add(state.recordingActive
          ? 'obs.recordingStarted'
          : 'obs.recordingStopped');
    }
    if (old.currentScene != state.currentScene) {
      _expected.removeWhere((e) => !e.expires.isAfter(_clock()));
      final expected = _expected
          .where((e) =>
              normalizeVoiceText(e.scene) ==
              normalizeVoiceText(state.currentScene))
          .firstOrNull;
      if (expected != null) _expected.remove(expected);
      add('obs.sceneChanged', depth: expected?.depth ?? 0);
    }
    return events;
  }
}
