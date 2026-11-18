import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'rule_events.dart';

/// Observes existing state deliveries; the first connected snapshot is a baseline.
class RuleObsTransitions {
  RuleObsTransitions({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  ObsState? _previous;
  final _expected = <({
    String type,
    String scene,
    int depth,
    RuleEventOrigin? origin,
    DateTime expires
  })>[];
  // OBS may publish the output transition after the command has returned.
  static const _transitionWindow = Duration(seconds: 60);
  int _sequence = 0;
  void Function() expectScene(String scene, int depth) =>
      expect('obs.sceneChanged', depth, scene: normalizeVoiceText(scene));

  void Function() expect(String type, int depth, {String scene = ''}) {
    final now = _clock();
    _expected.removeWhere((e) => !e.expires.isAfter(now));
    final event = (
      type: type,
      scene: scene,
      depth: depth,
      origin: RuleEventOrigin.current,
      expires: now.add(_transitionWindow)
    );
    _expected.add(event);
    return () => _expected.remove(event);
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
    _expected.removeWhere((e) => !e.expires.isAfter(_clock()));
    void add(String type, {String scene = ''}) {
      final matches =
          _expected.where((e) => e.type == type && e.scene == scene);
      // OBS does not identify which command caused a transition. If multiple
      // commands could have caused it, keep the viewer expectation available
      // in case the other command caused this event and the viewer's is late.
      final viewer = matches
          .where((e) => e.origin?.isUnprivilegedViewer == true)
          .firstOrNull;
      final consumed = viewer == null
          ? matches.firstOrNull
          : matches
                  .where((e) => e.origin?.isUnprivilegedViewer != true)
                  .firstOrNull ??
              viewer;
      if (consumed != null) _expected.remove(consumed);
      final expected = viewer ?? consumed;
      events.add(RuleEvent(
        type: type,
        scene: state.currentScene,
        eventId: 'obs:${++_sequence}',
        chainDepth: expected?.depth ?? 0,
        origin: expected?.origin,
      ));
    }

    if (old.outputActive != state.outputActive) {
      add(state.outputActive ? 'obs.streamStarted' : 'obs.streamStopped');
    }
    if (old.recordingActive != state.recordingActive) {
      add(state.recordingActive
          ? 'obs.recordingStarted'
          : 'obs.recordingStopped');
    }
    if (old.currentScene != state.currentScene) {
      add('obs.sceneChanged', scene: normalizeVoiceText(state.currentScene));
    }
    return events;
  }
}
