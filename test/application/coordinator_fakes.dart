import 'dart:async';

import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
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

class FakeChannelChatClient implements ChannelChatClient {
  final messageController = StreamController<ChatMessage>.broadcast(sync: true);
  final statusController =
      StreamController<(ServiceStatus, String?)>.broadcast(sync: true);
  int connectCount = 0;
  int disconnectCount = 0;
  bool disposed = false;
  Object? connectError;
  String? lastChannel;

  @override
  Stream<ChatMessage> get messages => messageController.stream;
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
  void speak(String text, {bool allowDownload = false}) => spoken.add(text);
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
  }) async =>
      updateCount++;
  @override
  Future<void> prepareModel() async => prepareCount++;
  @override
  Future<void> dispose() async {
    disposed = true;
    await stateController.close();
  }
}

class FakeOverlayClient implements OverlayClient {
  final clientsController = StreamController<int>.broadcast(sync: true);
  int startCount = 0;
  int stopCount = 0;
  int settingsCount = 0;
  int captionCount = 0;
  bool disposed = false;
  bool hasClients = true;
  Object? startError;
  int activePort = 8080;

  @override
  int get port => activePort;
  @override
  String get overlayUrl => 'http://localhost:$activePort';
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
    activePort = port;
  }

  @override
  void setSettings(SettingsModel settings) => settingsCount++;
  @override
  bool reloadClients() => hasClients;
  @override
  bool broadcastTestAlert(String kind) => hasClients;
  @override
  void broadcastCaption(String text) => captionCount++;
  @override
  Future<void> stop() async => stopCount++;
  @override
  Future<void> dispose() async {
    disposed = true;
    await clientsController.close();
  }
}

class FakeObsClient implements ObsClient {
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
  Future<void> switchScene(String sceneName) async => switchSceneCount++;
  @override
  Future<void> dispose() async {
    disposed = true;
    await statesController.close();
  }
}

Future<void> settleCoordinatorTasks() => Future<void>.delayed(Duration.zero);
