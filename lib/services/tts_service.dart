import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'supertonic_helper.dart';

class TtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Queue<String> _queue = Queue<String>();
  
  TextToSpeech? _textToSpeech;
  Style? _style;
  bool _isInitializing = false;
  bool _isProcessing = false;
  
  // TTS configuration
  final int _totalSteps = 8;
  final double _speed = 1.05;
  String _selectedLang = 'es';
  String _selectedVoice = 'M1';

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      _textToSpeech = await loadTextToSpeech('assets/onnx', useGpu: false);
      _style = await loadVoiceStyle(['assets/voice_styles/$_selectedVoice.json']);
      debugPrint('TTS: Supertonic loaded successfully');
    } catch (e) {
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
          _style = await loadVoiceStyle(['assets/voice_styles/$_selectedVoice.json']);
          debugPrint('TTS: Voice style changed to $_selectedVoice');
        } catch (e) {
          debugPrint('TTS: Failed to change voice style to $_selectedVoice: $e');
        }
      }
    }
  }

  void speak(String text) {
    if (text.trim().isEmpty) return;
    _queue.add(text);
    _processQueue();
  }

  void stop() {
    _queue.clear();
    _audioPlayer.stop();
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

      await _audioPlayer.play(DeviceFileSource(file.absolute.path));
      
      // Wait for playback to finish
      await _audioPlayer.onPlayerComplete.first;
      
      // Delete temporary file
      try {
        file.deleteSync();
      } catch (_) {}
    } catch (e) {
      debugPrint('TTS generation/playback error: $e');
    }
  }

  void dispose() {
    stop();
    _audioPlayer.dispose();
  }
}
