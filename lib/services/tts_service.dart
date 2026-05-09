import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'supertonic_helper.dart';

enum TtsLoadPhase { idle, loading, ready, error }

class TtsLoadState {
  final TtsLoadPhase phase;
  final String message;
  final String? currentAsset;
  final int loadedAssets;
  final int totalAssets;
  final int loadedBytes;
  final int totalBytes;
  final String? voiceStyle;
  final String? error;

  const TtsLoadState({
    this.phase = TtsLoadPhase.idle,
    this.message = 'TTS not initialized.',
    this.currentAsset,
    this.loadedAssets = 0,
    this.totalAssets = 0,
    this.loadedBytes = 0,
    this.totalBytes = 0,
    this.voiceStyle,
    this.error,
  });

  bool get isLoading => phase == TtsLoadPhase.loading;
  bool get isReady => phase == TtsLoadPhase.ready;

  TtsLoadState copyWith({
    TtsLoadPhase? phase,
    String? message,
    String? currentAsset,
    int? loadedAssets,
    int? totalAssets,
    int? loadedBytes,
    int? totalBytes,
    String? voiceStyle,
    String? error,
  }) =>
      TtsLoadState(
        phase: phase ?? this.phase,
        message: message ?? this.message,
        currentAsset: currentAsset ?? this.currentAsset,
        loadedAssets: loadedAssets ?? this.loadedAssets,
        totalAssets: totalAssets ?? this.totalAssets,
        loadedBytes: loadedBytes ?? this.loadedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        voiceStyle: voiceStyle ?? this.voiceStyle,
        error: error,
      );
}

class TtsService {
  final AudioPlayer? _audioPlayer = Platform.isWindows ? null : AudioPlayer();
  final Queue<String> _queue = Queue<String>();
  final _loadStateController = StreamController<TtsLoadState>.broadcast();
  Process? _windowsPlaybackProcess;

  TextToSpeech? _textToSpeech;
  Style? _style;
  bool _isInitializing = false;
  bool _isProcessing = false;
  TtsLoadState _loadState = const TtsLoadState();

  // TTS configuration
  final int _totalSteps = 8;
  final double _speed = 1.05;
  String _selectedLang = 'es';
  String _selectedVoice = 'M1';

  TtsService() {
    _init();
  }

  Stream<TtsLoadState> get loadStateStream => _loadStateController.stream;
  TtsLoadState get currentLoadState => _loadState;

  void _emitLoadState(TtsLoadState next) {
    _loadState = next;
    if (!_loadStateController.isClosed) {
      _loadStateController.add(next);
    }
  }

  Future<void> _init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    _emitLoadState(_loadState.copyWith(
      phase: TtsLoadPhase.loading,
      message: 'Initializing Supertonic...',
      error: null,
    ));
    try {
      _textToSpeech = await loadTextToSpeech(
        'assets/onnx',
        useGpu: false,
        onProgress: (progress) {
          _emitLoadState(_loadState.copyWith(
            phase: TtsLoadPhase.loading,
            message: progress.message,
            currentAsset: progress.assetPath,
            loadedAssets: progress.loadedAssets,
            totalAssets: progress.totalAssets,
            loadedBytes: progress.loadedBytes,
            totalBytes: progress.totalBytes,
            voiceStyle: _selectedVoice,
            error: null,
          ));
        },
      );
      await _loadVoiceStyle(_selectedVoice, announceReady: true);
      debugPrint('TTS: Supertonic loaded successfully');
    } catch (e) {
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
    _selectedLang = lang;
    if (_selectedVoice != voice) {
      _selectedVoice = voice;
      if (_textToSpeech != null) {
        try {
          await _loadVoiceStyle(_selectedVoice);
          debugPrint('TTS: Voice style changed to $_selectedVoice');
        } catch (e) {
          _emitLoadState(_loadState.copyWith(
            phase: TtsLoadPhase.error,
            message: 'Failed to load voice style $_selectedVoice.',
            error: e.toString(),
          ));
          debugPrint('TTS: Failed to change voice style to $_selectedVoice: $e');
        }
      }
    }
  }

  Future<void> _loadVoiceStyle(
    String voice, {
    bool announceReady = false,
  }) async {
    final assetPath = 'assets/voice_styles/$voice.json';
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
      currentAsset: assetPath,
      voiceStyle: voice,
      error: null,
    ));
    _style = await loadVoiceStyle([assetPath]);
    final nextState = _loadState.copyWith(
      phase: announceReady ? TtsLoadPhase.ready : _loadState.phase,
      message: announceReady
          ? 'Supertonic ready. Voice style $voice loaded.'
          : 'Voice style $voice loaded.',
      currentAsset: assetPath,
      voiceStyle: voice,
      loadedAssets: announceReady ? _loadState.totalAssets : _loadState.loadedAssets,
      totalAssets: _loadState.totalAssets,
      loadedBytes: loadedBytes,
      totalBytes: totalBytes,
      error: null,
    );
    _emitLoadState(nextState);
  }

  void speak(String text) {
    if (text.trim().isEmpty) return;
    _queue.add(text);
    _processQueue();
  }

  void stop() {
    _queue.clear();
    _windowsPlaybackProcess?.kill();
    _windowsPlaybackProcess = null;
    _audioPlayer?.stop();
  }

  Future<void> _processQueue() async {
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
    }
  }

  Future<void> _generateAndPlay(String text) async {
    try {
      final result = await _textToSpeech!.call(
        text,
        _selectedLang,
        _style!,
        _totalSteps,
        speed: _speed,
      );

      final wav = result['wav'] is List<double>
          ? result['wav']
          : (result['wav'] as List).cast<double>();

      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.wav';

      writeWavFile(outputPath, wav, _textToSpeech!.sampleRate);

      final file = File(outputPath);
      if (!file.existsSync()) {
        throw Exception('Failed to create WAV file');
      }

      await _playAudioFile(file);

      // Delete temporary file
      try {
        file.deleteSync();
      } catch (_) {}
    } catch (e) {
      debugPrint('TTS generation/playback error: $e');
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
      final stderr = await process.stderr.transform(systemEncoding.decoder).join();
      throw Exception('Windows audio playback failed (exit $exitCode): $stderr');
    }
  }

  void dispose() {
    stop();
    _audioPlayer?.dispose();
    _loadStateController.close();
  }
}
