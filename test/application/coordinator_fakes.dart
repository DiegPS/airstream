import 'package:airstream/services/overlay_server.dart';

import 'dart:async';

import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'dart:io';

import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/services/alert_sound_player.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/settings/settings_model.dart';

class FakeYouTubeChatClient implements YouTubeChatClient {
  final messageController = StreamController<ChatMessage>.broadcast(sync: true);
  final statusController =
      StreamController<(ServiceStatus, String?)>.broadcast(sync: true);
  final metadataController =
      StreamController<YoutubeLiveMetadata?>.broadcast(sync: true);
  final moderationController =
      StreamController<ChatModerationEvent>.broadcast(sync: true);
  int connectCount = 0;
  int disconnectCount = 0;
  bool disposed = false;
  Object? connectError;

  /// When set, connect waits for it, like a slow network lookup.
  Completer<void>? connectGate;
  String resolvedId = 'resolved-id';
  YoutubeLiveMetadata? metadata;

  @override
  Stream<ChatMessage> get messages => messageController.stream;
  @override
  Stream<ChatModerationEvent> get moderationEvents =>
      moderationController.stream;
  @override
  Stream<YoutubeLiveMetadata?> get metadataStream => metadataController.stream;
  @override
  Stream<(ServiceStatus, String?)> get statusStream => statusController.stream;
  @override
  String get resolvedLiveId => resolvedId;
  @override
  YoutubeLiveMetadata? get currentMetadata => metadata;
  @override
  Future<void> connect({String handle = '', String liveId = ''}) async {
    connectCount++;
    await connectGate?.future;
    if (connectError != null) throw connectError!;
  }

  @override
  Future<void> disconnect() async => disconnectCount++;

  @override
  Future<void> dispose() async {
    disposed = true;
    await messageController.close();
    await moderationController.close();
    await metadataController.close();
    await statusController.close();
  }
}

class FakeChannelChatClient
    implements
        ChannelChatClient,
        ModeratingChannelChatClient,
        ProviderEventChatClient,
        MetadataChannelChatClient {
  final messageController = StreamController<ChatMessage>.broadcast(sync: true);
  final statusController =
      StreamController<(ServiceStatus, String?)>.broadcast(sync: true);
  final moderationController =
      StreamController<ChatModerationEvent>.broadcast(sync: true);
  final eventController =
      StreamController<ChatProviderEvent>.broadcast(sync: true);
  final platformMetadataController =
      StreamController<PlatformLiveMetadata?>.broadcast(sync: true);
  int connectCount = 0;
  int disconnectCount = 0;
  bool disposed = false;
  Object? connectError;
  String? lastChannel;

  @override
  Stream<ChatMessage> get messages => messageController.stream;
  @override
  Stream<ChatModerationEvent> get moderationEvents =>
      moderationController.stream;
  @override
  Stream<ChatProviderEvent> get appEvents => eventController.stream;
  @override
  Stream<PlatformLiveMetadata?> get platformMetadataStream =>
      platformMetadataController.stream;
  @override
  Stream<(ServiceStatus, String?)> get statusStream => statusController.stream;
  @override
  Future<void> connect(String channel) async {
    connectCount++;
    lastChannel = channel;
    if (connectError != null) throw connectError!;
  }

  @override
  Future<void> disconnect() async => disconnectCount++;

  @override
  Future<void> dispose() async {
    disposed = true;
    await messageController.close();
    await moderationController.close();
    await eventController.close();
    await platformMetadataController.close();
    await statusController.close();
  }
}

class FakeTtsClient implements TtsClient {
  final loadController = StreamController<TtsLoadState>.broadcast(sync: true);
  final busyController = StreamController<bool>.broadcast(sync: true);
  final errorController = StreamController<Object>.broadcast(sync: true);
  final spoken = <String>[];
  int updateCount = 0;
  int prepareCount = 0;
  int removeCount = 0;
  bool disposed = false;
  bool busy = false;
  TtsLoadState loadState = const TtsLoadState();

  @override
  Stream<TtsLoadState> get loadStateStream => loadController.stream;
  @override
  Stream<bool> get busyStream => busyController.stream;
  @override
  Stream<Object> get playbackErrors => errorController.stream;
  @override
  TtsLoadState get currentLoadState => loadState;
  @override
  bool get isBusy => busy;
  @override
  bool get isPlayingAudio => busy;
  @override
  Future<void> updateConfig({
    required bool enabled,
    required String modelId,
    required String voice,
    required String language,
    required double speed,
    required int steps,
    required String referenceAudioPath,
    required String referenceText,
  }) async =>
      updateCount++;
  @override
  Future<void> prepareModel() async => prepareCount++;
  @override
  Future<void> removeModel(String modelId) async => removeCount++;
  @override
  void speak(String text, {Object? tag, bool allowDownload = false}) {
    spoken.add(text);
    tags.add(tag);
  }

  final tags = <Object?>[];
  int silenceCount = 0;

  @override
  int cancelWhere(bool Function(Object tag) test) {
    var cancelled = 0;
    for (var i = tags.length - 1; i >= 0; i--) {
      final tag = tags[i];
      if (tag != null && test(tag)) {
        tags.removeAt(i);
        spoken.removeAt(i);
        cancelled++;
      }
    }
    return cancelled;
  }

  @override
  Future<void> silence() async => silenceCount++;
  @override
  Future<void> dispose() async {
    disposed = true;
    await loadController.close();
    await busyController.close();
    await errorController.close();
  }
}

class FakeCaptionsClient implements CaptionsClient {
  final stateController =
      StreamController<LiveCaptionsState>.broadcast(sync: true);
  int updateCount = 0;
  int prepareCount = 0;
  bool disposed = false;
  @override
  Stream<LiveCaptionsState> get states => stateController.stream;
  @override
  Future<void> updateConfig({
    required bool enabled,
    required String sourceLanguage,
    required String targetLanguage,
    required bool denoise,
  }) async {
    updateCount++;
  }

  @override
  Future<void> prepareModel() async => prepareCount++;
  @override
  Future<void> dispose() async {
    disposed = true;
    await stateController.close();
  }
}

class FakeOverlayClient implements OverlayClient {
  final alertQueueOperations = <AlertQueueOperation>[];
  int featuredRemoveCount = 0;
  @override
  Stream<AlertQueueStatus> get alertQueueStatusStream => const Stream.empty();
  @override
  void controlAlertQueue(AlertQueueOperation op) =>
      alertQueueOperations.add(op);
  @override
  void removeFeaturedMessage() => featuredRemoveCount++;

  final recent = <Map<String, Object?>>[];
  final replayed = <String>[];
  int clearRecentCount = 0;
  @override
  List<Map<String, Object?>> get recentAlertsSnapshot =>
      List.unmodifiable(recent);
  @override
  Stream<List<Map<String, Object?>>> get recentAlerts =>
      Stream.value(recentAlertsSnapshot);
  @override
  bool replayRecentAlert(String id) {
    replayed.add(id);
    return hasClients && recent.any((alert) => alert['id'] == id);
  }

  @override
  void clearRecentAlerts() {
    clearRecentCount++;
    recent.clear();
  }

  final clientsController = StreamController<int>.broadcast(sync: true);
  int startCount = 0;
  int stopCount = 0;
  int settingsCount = 0;
  int captionCount = 0;
  final supportAlerts = <ChatMessage>[];
  @override
  void broadcastChatSupport(ChatMessage message) => supportAlerts.add(message);
  int moderationCount = 0;
  int providerEventCount = 0;
  bool disposed = false;
  bool hasClients = true;
  Object? startError;
  int activePort = 8080;

  /// Ports another app already uses.
  Set<int> busyPorts = {};

  @override
  int get port => activePort;
  @override
  String get overlayUrl => 'http://localhost:$activePort';
  @override
  Stream<Map<String, int>> get viewCountsStream => Stream.value(const {});
  @override
  Stream<int> get clientCountStream => clientsController.stream;
  @override
  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port = 8080,
  }) async {
    startCount++;
    if (startError != null) throw startError!;
    if (busyPorts.contains(port)) {
      throw const SocketException('Only one usage of each socket address');
    }
    activePort = port;
  }

  @override
  void setSettings(SettingsModel settings) => settingsCount++;
  @override
  bool reloadClients() => hasClients;
  @override
  bool broadcastTestAlert(String kind) => hasClients;
  final featured = <ChatMessage>[];
  final polls = <Map<String, Object?>?>[];
  @override
  void broadcastPoll(Map<String, Object?>? poll) => polls.add(poll);
  final goals = <List<Map<String, Object?>>>[];
  @override
  void broadcastGoals(List<Map<String, Object?>> value,
          {bool replay = false}) =>
      goals.add(value);
  final giveaways = <Map<String, Object?>?>[];
  @override
  void broadcastGiveaway(Map<String, Object?>? giveaway) =>
      giveaways.add(giveaway);
  @override
  FeaturedMessageDelivery broadcastFeaturedMessage(ChatMessage message) {
    if (!hasClients) return FeaturedMessageDelivery.noReceiver();
    featured.add(message);
    return FeaturedMessageDelivery(
      message.id,
      FeaturedMessageStatus.sent,
      Future.value(FeaturedMessageStatus.rendered),
    );
  }

  @override
  void broadcastCaption(String text) => captionCount++;
  @override
  void broadcastModeration(ChatModerationEvent event) => moderationCount++;
  @override
  void broadcastProviderEvent(ChatProviderEvent event) => providerEventCount++;
  @override
  Future<void> stop() async {
    stopCount++;
    await stopGate?.future;
  }

  Completer<void>? stopGate;
  @override
  Future<void> dispose() async {
    disposed = true;
    await clientsController.close();
  }
}

class FakeObsClient implements ObsClient {
  final ruleControls = <String>[];
  @override
  Future<void> ruleSource(
      String scene, String source, String visibility) async {
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleMute(String input, String state) async {
    ruleControls.add('mute:$input:$state');
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleText(String source, String text) async {
    ruleControls.add('text:$source:$text');
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleFilter(String source, String filter, String state) async {
    ruleControls.add('filter:$source:$filter:$state');
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleStream(bool start) async {
    ruleControls.add('stream:$start');
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleReplay(String operation) async {
    ruleControls.add('replay:$operation');
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleMedia(String source, String operation) async {
    ruleControls.add('media:$source:$operation');
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleVolume(String input, bool change, int db) async {
    ruleControls.add('volume:$input:$change:$db');
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> ruleRefresh(String source) async {
    ruleControls.add('refresh:$source');
    if (commandError != null) throw commandError!;
  }

  final statesController = StreamController<ObsState>.broadcast(sync: true);
  ObsState state = const ObsState();
  int connectCount = 0;
  int disconnectCount = 0;
  int startRecordingCount = 0;
  int stopRecordingCount = 0;
  int pauseRecordingCount = 0;
  int resumeRecordingCount = 0;
  int switchSceneCount = 0;
  bool disposed = false;
  Object? commandError;
  String? lastHost;
  String? lastScene;

  @override
  ObsState get currentState => state;
  @override
  Stream<ObsState> get stateStream => statesController.stream;
  @override
  Future<void> connect({required String host, required String password}) async {
    connectCount++;
    lastHost = host;
  }

  @override
  Future<void> disconnect() async => disconnectCount++;
  @override
  Future<void> startRecording() async {
    startRecordingCount++;
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> stopRecording() async => stopRecordingCount++;
  @override
  Future<void> pauseRecording() async => pauseRecordingCount++;
  @override
  Future<void> resumeRecording() async => resumeRecordingCount++;
  @override
  Future<void> switchScene(String sceneName) async {
    switchSceneCount++;
    lastScene = sceneName;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await statesController.close();
  }
}

Future<void> settleCoordinatorTasks() => Future<void>.delayed(Duration.zero);

class FakeAlertSound implements AlertSoundClient {
  final sources = <String>[];
  int get plays => sources.length;
  bool disposed = false;

  @override
  Future<void> play(
    String source, {
    required Map<String, Map<String, dynamic>> library,
    required bool Function() canStart,
  }) async {
    if (canStart()) sources.add(source);
  }

  @override
  Future<void> dispose() async => disposed = true;
}
