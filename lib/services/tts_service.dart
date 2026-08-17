import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'media_kit_audio_playback_service.dart';
import 'tts/sherpa_tts_engine.dart';
import 'tts/tts_model_catalog.dart';
import 'tts_model_cache.dart';

enum TtsLoadPhase { idle, checking, downloading, loading, ready, error }

class TtsLoadState {
  final TtsLoadPhase phase;
  final String message;
  final String? currentFile;
  final int loadedAssets;
  final int totalAssets;
  final int loadedBytes;
  final int totalBytes;
  final String? voiceStyle;
  final String? error;
  final String? cacheDirectory;
  final bool fromCache;
  final String modelId;

  const TtsLoadState({
    this.phase = TtsLoadPhase.idle,
    this.message = 'TTS is off. Models load only when needed.',
    this.currentFile,
    this.loadedAssets = 0,
    this.totalAssets = 1,
    this.loadedBytes = 0,
    this.totalBytes = 0,
    this.voiceStyle,
    this.error,
    this.cacheDirectory,
    this.fromCache = false,
    this.modelId = 'supertonic-3-int8',
  });

  bool get isLoading =>
      phase == TtsLoadPhase.checking ||
      phase == TtsLoadPhase.downloading ||
      phase == TtsLoadPhase.loading;
  bool get isReady => phase == TtsLoadPhase.ready;
  double? get progress =>
      totalBytes > 0 ? (loadedBytes / totalBytes).clamp(0, 1) : null;
}

class TtsService {
  static const _maxQueuedUtterances = 8;
  static const _maxUtteranceRunes = 260;
  static const _playbackPadding = Duration(seconds: 5);

  final Queue<String> _queue = Queue<String>();
  final StreamController<TtsLoadState> _loadStateController =
      StreamController<TtsLoadState>.broadcast();
  final StreamController<bool> _busyController =
      StreamController<bool>.broadcast();
  final TtsModelCache _modelCache;
  final SherpaTtsEngine _engine;
  final MediaKitAudioPlaybackService _audioPlayback;

  TtsLoadState _loadState = const TtsLoadState();
  Future<void>? _initialization;
  TtsDownloadCancellation? _downloadCancellation;
  bool _processing = false;
  bool _busy = false;
  bool _disposed = false;
  int _generation = 0;
  int _configurationRevision = 0;
  String _modelId = TtsModelCatalog.supertonic.id;
  String _voice = 'M1';
  String _language = 'es';
  double _speed = 1.05;
  int _steps = 8;

  TtsService({
    TtsModelCache? modelCache,
    SherpaTtsEngine? engine,
    MediaKitAudioPlaybackService? audioPlayback,
  })  : _modelCache = modelCache ?? TtsModelCache(),
        _engine = engine ?? SherpaTtsEngine(),
        _audioPlayback = audioPlayback ?? MediaKitAudioPlaybackService();

  Stream<TtsLoadState> get loadStateStream => _loadStateController.stream;
  Stream<bool> get busyStream => _busyController.stream;
  TtsLoadState get currentLoadState => _loadState;
  bool get isBusy => _busy;
  TtsModelDefinition get selectedModel => TtsModelCatalog.byId(_modelId);

  Future<void> updateConfig({
    required bool enabled,
    required String modelId,
    required String voice,
    required String language,
    required double speed,
    required int steps,
  }) async {
    if (_disposed) return;
    final revision = ++_configurationRevision;
    final previousModel = _modelId;
    _modelId = TtsModelCatalog.byId(modelId).id;
    final model = selectedModel;
    _voice = model.voice(voice).id;
    _language = model.supportsLanguage(language)
        ? language
        : model.languages.first.code;
    _speed = speed.clamp(0.6, 1.6);
    _steps = steps.clamp(2, 16);
    if (!enabled) {
      await stop(unload: true);
      if (revision == _configurationRevision) {
        _emit(TtsLoadState(modelId: _modelId));
      }
      return;
    }
    if (previousModel != _modelId) await stop(unload: true);
    if (revision != _configurationRevision) return;
    unawaited(_prepareForConfiguration(revision));
  }

  Future<void> _prepareForConfiguration(int revision) async {
    try {
      await ensureReady();
      // A previous initialization may have been cancelled by a near-simultaneous
      // settings update. Retry once after its whenComplete clears the slot.
      if (revision == _configurationRevision && !_engine.isReady) {
        await Future<void>.delayed(Duration.zero);
        await ensureReady();
      }
    } catch (_) {}
  }

  Future<void> ensureReady() {
    if (_disposed) return Future.error(StateError('TTS is disposed.'));
    if (_engine.isReady && _loadState.modelId == _modelId) {
      return Future.value();
    }
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    final generation = _generation;
    final model = selectedModel;
    final cancellation = TtsDownloadCancellation();
    _downloadCancellation = cancellation;
    try {
      final installation = await _modelCache.ensureAvailable(
        model,
        cancellation: cancellation,
        onProgress: (progress) {
          if (_disposed || generation != _generation) return;
          final phase = switch (progress.phase) {
            TtsInstallPhase.downloading => TtsLoadPhase.downloading,
            TtsInstallPhase.extracting => TtsLoadPhase.loading,
            TtsInstallPhase.verifying ||
            TtsInstallPhase.checking =>
              TtsLoadPhase.checking,
            TtsInstallPhase.error => TtsLoadPhase.error,
            _ => TtsLoadPhase.loading,
          };
          _emit(TtsLoadState(
            phase: phase,
            message: progress.message,
            currentFile: progress.path,
            loadedBytes: progress.receivedBytes,
            totalBytes: progress.totalBytes,
            voiceStyle: _voice,
            cacheDirectory: progress.path,
            modelId: model.id,
          ));
        },
      );
      if (_disposed || generation != _generation) return;
      _emit(TtsLoadState(
          phase: TtsLoadPhase.loading,
          message: 'Loading ${model.name} with Sherpa-ONNX…',
          loadedBytes: model.archiveBytes,
          totalBytes: model.archiveBytes,
          voiceStyle: _voice,
          cacheDirectory: installation.directory.path,
          fromCache: true,
          modelId: model.id));
      await _engine.initialize(installation);
      if (_disposed || generation != _generation) return;
      await _audioPlayback.startKeepAlive();
      _emit(TtsLoadState(
          phase: TtsLoadPhase.ready,
          message: '${model.name} is ready.',
          loadedAssets: 1,
          totalAssets: 1,
          loadedBytes: model.archiveBytes,
          totalBytes: model.archiveBytes,
          voiceStyle: _voice,
          cacheDirectory: installation.directory.path,
          fromCache: true,
          modelId: model.id));
      unawaited(_processQueue());
    } on TtsDownloadCancelledException {
      if (!_disposed && generation == _generation) {
        _emit(TtsLoadState(modelId: model.id));
      }
    } catch (error, stack) {
      debugPrint('TTS initialization failed: $error\n$stack');
      if (!_disposed && generation == _generation) {
        _emit(TtsLoadState(
            phase: TtsLoadPhase.error,
            message: 'TTS could not be prepared.',
            error: error.toString(),
            modelId: model.id));
        _queue.clear();
        _setBusy(false);
      }
      rethrow;
    } finally {
      if (identical(_downloadCancellation, cancellation)) {
        _downloadCancellation = null;
      }
    }
  }

  void speak(String text) {
    if (_disposed) return;
    final prepared = prepareTextForSpeech(text);
    if (prepared.isEmpty) return;
    while (_queue.length >= _maxQueuedUtterances) {
      _queue.removeFirst();
    }
    _queue.add(prepared);
    _setBusy(true);
    unawaited(_processQueue());
  }

  @visibleForTesting
  static String prepareTextForSpeech(String text) {
    final withoutUrls = text.replaceAll(
        RegExp(r'https?:\/\/\S+|www\.\S+', caseSensitive: false), ' ');
    final normalized = withoutUrls.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '';
    final runes = normalized.runes.toList();
    if (runes.length <= _maxUtteranceRunes) return normalized;
    return '${String.fromCharCodes(runes.take(_maxUtteranceRunes)).trim()}…';
  }

  Future<void> _processQueue() async {
    if (_disposed || _processing || _queue.isEmpty) return;
    _processing = true;
    try {
      await ensureReady();
      while (!_disposed && _queue.isNotEmpty && _engine.isReady) {
        final text = _queue.removeFirst();
        await _generateAndPlay(text);
      }
    } catch (error) {
      debugPrint('TTS queue stopped: $error');
    } finally {
      _processing = false;
      _setBusy(_queue.isNotEmpty);
    }
  }

  Future<void> _generateAndPlay(String text) async {
    File? output;
    final generation = _generation;
    try {
      final model = selectedModel;
      final audio = await _engine.synthesize(
          text: text,
          speakerId: model.voice(_voice).speakerId,
          language: _language,
          speed: _speed,
          steps: _steps);
      if (_disposed || generation != _generation || audio.samples.isEmpty) {
        return;
      }
      final temp = await getTemporaryDirectory();
      output = File(p.join(temp.path,
          'airstream_tts_${DateTime.now().microsecondsSinceEpoch}.wav'));
      await output.writeAsBytes(_wavBytes(audio), flush: true);
      final timeout = audio.duration + _playbackPadding;
      await _audioPlayback.playFile(output,
          timeout: timeout < const Duration(seconds: 8)
              ? const Duration(seconds: 8)
              : timeout);
    } catch (error, stack) {
      debugPrint('TTS synthesis/playback failed: $error\n$stack');
    } finally {
      if (output != null && await output.exists()) {
        try {
          await output.delete();
        } catch (_) {}
      }
    }
  }

  static Uint8List _wavBytes(TtsAudio audio) {
    const channels = 1;
    const bitsPerSample = 16;
    final dataSize = audio.samples.length * 2;
    final bytes = Uint8List(44 + dataSize);
    final view = ByteData.sublistView(bytes);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes[offset + i] = value.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    view.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, audio.sampleRate, Endian.little);
    view.setUint32(28, audio.sampleRate * 2, Endian.little);
    view.setUint16(32, 2, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    view.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < audio.samples.length; i++) {
      final sample = math.max(-1.0, math.min(1.0, audio.samples[i]));
      view.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
    }
    return bytes;
  }

  Future<void> stop({bool unload = false}) async {
    _generation++;
    _queue.clear();
    _downloadCancellation?.cancel();
    await _audioPlayback.stop();
    if (unload || _processing) await _engine.cancel();
    _processing = false;
    _setBusy(false);
  }

  Future<bool> isModelInstalled(String modelId) async =>
      await _modelCache.installed(TtsModelCatalog.byId(modelId)) != null;

  Future<void> removeModel(String modelId) async {
    final model = TtsModelCatalog.byId(modelId);
    if (_modelId == model.id) await stop(unload: true);
    await _modelCache.remove(model);
    if (_modelId == model.id) _emit(TtsLoadState(modelId: model.id));
  }

  void _emit(TtsLoadState state) {
    if (_disposed) return;
    _loadState = state;
    if (!_loadStateController.isClosed) _loadStateController.add(state);
  }

  void _setBusy(bool busy) {
    if (_disposed || _busy == busy) return;
    _busy = busy;
    if (!_busyController.isClosed) _busyController.add(busy);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stop(unload: true);
    _disposed = true;
    _modelCache.dispose();
    await _engine.dispose();
    await _audioPlayback.dispose();
    await _loadStateController.close();
    await _busyController.close();
  }
}
