import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'supertonic_helper.dart';
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

  const TtsLoadState({
    this.phase = TtsLoadPhase.idle,
    this.message = 'TTS not initialized.',
    this.currentFile,
    this.loadedAssets = 0,
    this.totalAssets = 0,
    this.loadedBytes = 0,
    this.totalBytes = 0,
    this.voiceStyle,
    this.error,
    this.cacheDirectory,
    this.fromCache = false,
  });

  bool get isLoading =>
      phase == TtsLoadPhase.checking ||
      phase == TtsLoadPhase.downloading ||
      phase == TtsLoadPhase.loading;
  bool get isReady => phase == TtsLoadPhase.ready;
  double? get progress =>
      totalBytes > 0 ? (loadedBytes / totalBytes).clamp(0, 1) : null;

  TtsLoadState copyWith({
    TtsLoadPhase? phase,
    String? message,
    String? currentFile,
    int? loadedAssets,
    int? totalAssets,
    int? loadedBytes,
    int? totalBytes,
    String? voiceStyle,
    String? error,
    String? cacheDirectory,
    bool? fromCache,
  }) =>
      TtsLoadState(
        phase: phase ?? this.phase,
        message: message ?? this.message,
        currentFile: currentFile ?? this.currentFile,
        loadedAssets: loadedAssets ?? this.loadedAssets,
        totalAssets: totalAssets ?? this.totalAssets,
        loadedBytes: loadedBytes ?? this.loadedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        voiceStyle: voiceStyle ?? this.voiceStyle,
        error: error,
        cacheDirectory: cacheDirectory ?? this.cacheDirectory,
        fromCache: fromCache ?? this.fromCache,
      );
}

class TtsService {
  final AudioPlayer? _audioPlayer = Platform.isWindows ? null : AudioPlayer();
  final Queue<String> _queue = Queue<String>();
  final _loadStateController = StreamController<TtsLoadState>.broadcast();
  final _busyController = StreamController<bool>.broadcast();
  final TtsModelCache _modelCache = TtsModelCache();
  Process? _windowsPlaybackProcess;

  TextToSpeech? _textToSpeech;
  Style? _style;
  TtsModelPaths? _modelPaths;
  bool _isInitializing = false;
  bool _isProcessing = false;
  bool _isDisposed = false;
  int _activeSyntheses = 0;
  Future<void> _voiceStyleLoadFuture = Future<void>.value();
  final List<Style> _retiredStyles = <Style>[];
  TtsLoadState _loadState = const TtsLoadState();
  bool _isBusy = false;

  // TTS configuration
  final int _totalSteps = 8;
  final double _speed = 1.05;
  String _selectedLang = 'es';
  String _selectedVoice = 'M1';

  TtsService() {
    _init();
  }

  Stream<TtsLoadState> get loadStateStream => _loadStateController.stream;
  Stream<bool> get busyStream => _busyController.stream;
  TtsLoadState get currentLoadState => _loadState;
  bool get isBusy => _isBusy;

  void _emitLoadState(TtsLoadState next) {
    if (_isDisposed) return;
    _loadState = next;
    if (!_loadStateController.isClosed) {
      _loadStateController.add(next);
    }
  }

  void _setBusy(bool value) {
    if (_isDisposed || _isBusy == value) return;
    _isBusy = value;
    if (!_busyController.isClosed) {
      _busyController.add(value);
    }
  }

  Future<void> _init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    _emitLoadState(_loadState.copyWith(
      phase: TtsLoadPhase.checking,
      message: 'Checking Supertonic cache...',
      error: null,
    ));
    try {
      _modelPaths = await _modelCache.ensureAvailable(
        onProgress: (progress) {
          if (_isDisposed) return;
          final phase = progress.downloadedFiles == progress.totalFiles &&
                  progress.downloadedBytes == progress.totalBytes
              ? TtsLoadPhase.checking
              : TtsLoadPhase.downloading;
          _emitLoadState(_loadState.copyWith(
            phase: phase,
            message: progress.message,
            currentFile: progress.currentFile,
            loadedAssets: progress.downloadedFiles,
            totalAssets: progress.totalFiles,
            loadedBytes: progress.downloadedBytes,
            totalBytes: progress.totalBytes,
            voiceStyle: _selectedVoice,
            cacheDirectory: progress.cacheDirectory,
            fromCache: true,
            error: null,
          ));
        },
      );
      if (_isDisposed) return;

      _textToSpeech = await loadTextToSpeech(
        _modelPaths!.onnxDirectory.path,
        useGpu: false,
        onProgress: (progress) {
          if (_isDisposed) return;
          _emitLoadState(_loadState.copyWith(
            phase: TtsLoadPhase.loading,
            message: progress.message,
            currentFile: progress.assetPath,
            loadedAssets: progress.loadedAssets,
            totalAssets: progress.totalAssets,
            loadedBytes: progress.loadedBytes,
            totalBytes: progress.totalBytes,
            voiceStyle: _selectedVoice,
            cacheDirectory: _modelPaths?.cacheDirectory.path,
            fromCache: true,
            error: null,
          ));
        },
      );
      if (_isDisposed) return;
      final initialVoice = _selectedVoice;
      await _queueVoiceStyleLoad(initialVoice, announceReady: true);
      if (!_isDisposed && _selectedVoice != initialVoice) {
        await _queueVoiceStyleLoad(_selectedVoice, announceReady: true);
      }
      if (_isDisposed) return;
      debugPrint('TTS: Supertonic loaded successfully');
    } catch (e) {
      if (_isDisposed) return;
      _emitLoadState(_loadState.copyWith(
        phase: TtsLoadPhase.error,
        message: 'Failed to load Supertonic.',
        error: e.toString(),
      ));
      debugPrint('TTS: Failed to load Supertonic models: $e');
    } finally {
      _isInitializing = false;
      _processQueue();
    }
  }

  Future<void> updateConfig(String voice, String lang) async {
    if (_isDisposed) return;
    _selectedLang = lang;
    if (_selectedVoice != voice) {
      _selectedVoice = voice;
      if (_textToSpeech != null && !_isInitializing) {
        try {
          await _queueVoiceStyleLoad(_selectedVoice);
          debugPrint('TTS: Voice style changed to $_selectedVoice');
        } catch (e) {
          if (_isDisposed) return;
          _emitLoadState(_loadState.copyWith(
            phase: TtsLoadPhase.error,
            message: 'Failed to load voice style $_selectedVoice.',
            error: e.toString(),
          ));
          debugPrint(
              'TTS: Failed to change voice style to $_selectedVoice: $e');
        }
      }
    }
  }

  Future<void> _queueVoiceStyleLoad(
    String voice, {
    bool announceReady = false,
  }) {
    _voiceStyleLoadFuture =
        _voiceStyleLoadFuture.catchError((_) {}).then((_) async {
      if (_isDisposed) return;
      await _loadVoiceStyleNow(voice, announceReady: announceReady);
    });
    return _voiceStyleLoadFuture;
  }

  Future<void> _loadVoiceStyleNow(
    String voice, {
    bool announceReady = false,
  }) async {
    if (_isDisposed) return;
    final modelPaths = _modelPaths;
    if (modelPaths == null) {
      throw StateError('TTS model cache is not initialized.');
    }
    final assetPath = modelPaths.voiceStylePath(voice);
    final assetSize = await getAssetByteLength(assetPath);
    final loadedBytes = announceReady
        ? _loadState.loadedBytes + (assetSize ?? 0)
        : _loadState.loadedBytes;
    final totalBytes = announceReady
        ? _loadState.totalBytes + (assetSize ?? 0)
        : _loadState.totalBytes;
    _emitLoadState(_loadState.copyWith(
      phase: TtsLoadPhase.loading,
      message:
          'Loading voice style $voice${assetSize != null ? ' (${formatByteSize(assetSize)})' : ''}...',
      currentFile: assetPath,
      voiceStyle: voice,
      cacheDirectory: modelPaths.cacheDirectory.path,
      fromCache: true,
      error: null,
    ));
    final loadedStyle = await loadVoiceStyle([assetPath]);
    if (_isDisposed) return;
    final previousStyle = _style;
    _style = loadedStyle;
    if (previousStyle != null && !identical(previousStyle, loadedStyle)) {
      _retiredStyles.add(previousStyle);
      unawaited(_disposeRetiredStylesIfIdle());
    }
    final nextState = _loadState.copyWith(
      phase: announceReady ? TtsLoadPhase.ready : _loadState.phase,
      message: announceReady
          ? 'Supertonic ready. Voice style $voice loaded.'
          : 'Voice style $voice loaded.',
      currentFile: assetPath,
      voiceStyle: voice,
      loadedAssets:
          announceReady ? _loadState.totalAssets : _loadState.loadedAssets,
      totalAssets: _loadState.totalAssets,
      loadedBytes: loadedBytes,
      totalBytes: totalBytes,
      cacheDirectory: modelPaths.cacheDirectory.path,
      fromCache: true,
      error: null,
    );
    _emitLoadState(nextState);
  }

  void speak(String text) {
    if (_isDisposed) return;
    if (text.trim().isEmpty) return;
    _queue.add(text);
    _setBusy(true);
    _processQueue();
  }

  void stop() {
    if (_isDisposed) return;
    _queue.clear();
    _windowsPlaybackProcess?.kill();
    _windowsPlaybackProcess = null;
    _audioPlayer?.stop();
    _setBusy(false);
  }

  Future<void> _processQueue() async {
    if (_isDisposed) return;
    if (_isProcessing || _queue.isEmpty) return;
    if (_textToSpeech == null || _style == null) {
      // If models failed to load or are still loading, retry later or wait
      if (_isInitializing) {
        // will process queue after init
        return;
      } else {
        // Models failed to load, clear queue to prevent memory leak
        _queue.clear();
        return;
      }
    }

    _isProcessing = true;
    try {
      while (_queue.isNotEmpty) {
        final text = _queue.removeFirst();
        await _generateAndPlay(text);
      }
    } catch (e) {
      debugPrint('TTS error: $e');
    } finally {
      _isProcessing = false;
      _setBusy(_queue.isNotEmpty);
    }
  }

  Future<void> _generateAndPlay(String text) async {
    File? file;
    final textToSpeech = _textToSpeech;
    final style = _style;
    if (textToSpeech == null || style == null) return;
    _activeSyntheses++;
    try {
      final result = await textToSpeech.call(
        text,
        _selectedLang,
        style,
        _totalSteps,
        speed: _speed,
      );

      final wav = result['wav'] is List<double>
          ? result['wav']
          : (result['wav'] as List).cast<double>();

      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.wav';

      writeWavFile(outputPath, wav, _textToSpeech!.sampleRate);

      file = File(outputPath);
      if (!file.existsSync()) {
        throw Exception('Failed to create WAV file');
      }

      await _playAudioFile(file);
    } catch (e) {
      debugPrint('TTS generation/playback error: $e');
    } finally {
      _activeSyntheses--;
      await _disposeRetiredStylesIfIdle();
      if (file != null) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _disposeRetiredStylesIfIdle() async {
    if (_activeSyntheses > 0 || _retiredStyles.isEmpty) {
      return;
    }
    final styles = List<Style>.from(_retiredStyles);
    _retiredStyles.clear();
    for (final style in styles) {
      try {
        await style.dispose();
      } catch (_) {}
    }
  }

  Future<void> _disposeNativeResources() async {
    final currentStyle = _style;
    _style = null;
    if (currentStyle != null) {
      try {
        await currentStyle.dispose();
      } catch (_) {}
    }

    await _disposeRetiredStylesIfIdle();

    final textToSpeech = _textToSpeech;
    _textToSpeech = null;
    if (textToSpeech != null) {
      try {
        await textToSpeech.dispose();
      } catch (_) {}
    }
  }

  Future<void> _playAudioFile(File file) async {
    if (Platform.isWindows) {
      await _playAudioWithWindowsSoundPlayer(file);
      return;
    }

    final player = _audioPlayer;
    if (player == null) {
      throw Exception('No audio player available for this platform');
    }

    await player.play(DeviceFileSource(file.absolute.path));
    await player.onPlayerComplete.first;
  }

  Future<void> _playAudioWithWindowsSoundPlayer(File file) async {
    final process = await Process.start(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r"$player = New-Object System.Media.SoundPlayer $env:AIRCHAT_WAV_PATH; $player.Load(); $player.PlaySync()",
      ],
      environment: {
        'AIRCHAT_WAV_PATH': file.absolute.path,
      },
    );

    _windowsPlaybackProcess = process;
    final exitCode = await process.exitCode;
    if (identical(_windowsPlaybackProcess, process)) {
      _windowsPlaybackProcess = null;
    }

    if (exitCode != 0) {
      final stderr =
          await process.stderr.transform(systemEncoding.decoder).join();
      throw Exception(
          'Windows audio playback failed (exit $exitCode): $stderr');
    }
  }

  void dispose() {
    if (_isDisposed) return;
    stop();
    _isDisposed = true;
    _modelCache.dispose();
    _audioPlayer?.dispose();
    _loadStateController.close();
    _busyController.close();
    unawaited(_disposeNativeResources());
  }
}
