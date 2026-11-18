import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _MciNative = Uint32 Function(
    Pointer<Utf16>, Pointer<Utf16>, Uint32, IntPtr);
typedef _Mci = int Function(Pointer<Utf16>, Pointer<Utf16>, int, int);

typedef _PlaySoundWNative = Int32 Function(
  Pointer<Utf16> sound,
  IntPtr module,
  Uint32 flags,
);
typedef _PlaySoundW = int Function(
  Pointer<Utf16> sound,
  int module,
  int flags,
);

/// Plays generated WAV files without a persistent native callback into Dart.
///
/// Flutter deletes Dart callbacks during Hot Restart, so the Windows path uses
/// the operating system's multimedia API without retaining a Dart callback.
class NativeAudioPlaybackService {
  static const _sndAsync = 0x0001;
  static const _sndNoDefault = 0x0002;
  static const _sndFileName = 0x00020000;

  _PlaySoundW? _playSound;
  Completer<void>? _activePlayback;
  Timer? _completionTimer;
  Process? _process;
  bool _disposed = false;

  bool get isPlaying => _activePlayback != null || _process != null;

  Future<void> startKeepAlive() async {}

  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
    double? volume,
    bool Function()? canStart,
  }) async {
    if (_disposed || canStart?.call() == false) return;
    await stop();
    if (_disposed || canStart?.call() == false) return;

    if (Platform.isWindows && volume != null) {
      await _playMci(file, volume, timeout);
      return;
    }
    if (Platform.isWindows) {
      await _playWindows(file, timeout: timeout);
      return;
    }
    await _playProcess(file, timeout: timeout);
  }

  _Mci? _mci;
  String? _alias;
  static int _aliasSequence = 0;
  String _mciCommand(String command) {
    final input = command.toNativeUtf16();
    final output = calloc<Uint16>(256).cast<Utf16>();
    try {
      final result = (_mci ??= DynamicLibrary.open('winmm.dll')
              .lookupFunction<_MciNative, _Mci>('mciSendStringW'))(
          input, output, 256, 0);
      if (result != 0) throw StateError('Native audio error $result');
      return output.toDartString();
    } finally {
      calloc.free(input);
      calloc.free(output);
    }
  }

  Future<void> _playMci(File file, double volume, Duration timeout) async {
    final alias = 'airstreamRule${++_aliasSequence}';
    // File paths originate exclusively in the application-owned media/cache library.
    if (file.path.contains('"')) throw ArgumentError('Invalid audio path');
    _mciCommand('open "${file.absolute.path}" alias $alias');
    _alias = alias;
    final playback = Completer<void>();
    _activePlayback = playback;
    try {
      _mciCommand('set $alias time format milliseconds');
      _mciCommand(
          'setaudio $alias volume to ${(volume.clamp(0, 1) * 1000).round()}');
      final duration = int.parse(_mciCommand('status $alias length'));
      _mciCommand('play $alias');
      _completionTimer = Timer(Duration(milliseconds: duration), () {
        if (!playback.isCompleted) playback.complete();
      });
      await playback.future.timeout(timeout);
    } finally {
      if (_alias == alias) {
        _mciCommand('close $alias');
        _alias = null;
        _completionTimer?.cancel();
        _completionTimer = null;
        _activePlayback = null;
      }
    }
  }

  Future<void> _playWindows(File file, {required Duration timeout}) async {
    final playback = Completer<void>();
    _activePlayback = playback;
    final sound = file.absolute.path.toNativeUtf16();
    try {
      final started = _windowsPlaySound(
        sound,
        0,
        _sndAsync | _sndNoDefault | _sndFileName,
      );
      if (started == 0) {
        throw StateError('Windows could not play ${file.path}.');
      }
      final duration = await _wavDuration(file);
      _completionTimer = Timer(duration, () {
        if (!playback.isCompleted) playback.complete();
      });
      try {
        await playback.future.timeout(timeout);
      } on TimeoutException {
        _windowsPlaySound(nullptr.cast<Utf16>(), 0, 0);
        rethrow;
      }
    } finally {
      calloc.free(sound);
      _completionTimer?.cancel();
      _completionTimer = null;
      if (identical(_activePlayback, playback)) _activePlayback = null;
    }
  }

  Future<void> _playProcess(File file, {required Duration timeout}) async {
    final command = Platform.isMacOS ? 'afplay' : 'aplay';
    final process = await Process.start(command, [file.absolute.path]);
    _process = process;
    try {
      final exitCode = await process.exitCode.timeout(timeout);
      if (exitCode != 0) {
        throw StateError('$command exited with code $exitCode.');
      }
    } finally {
      if (identical(_process, process)) _process = null;
    }
  }

  Future<void> stop() async {
    final alias = _alias;
    _alias = null;
    if (alias != null) _mciCommand('close $alias');
    _completionTimer?.cancel();
    _completionTimer = null;
    if (Platform.isWindows && _playSound != null) {
      _windowsPlaySound(nullptr.cast<Utf16>(), 0, 0);
    }
    _process?.kill();
    _process = null;
    final playback = _activePlayback;
    _activePlayback = null;
    if (playback != null && !playback.isCompleted) playback.complete();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }

  _PlaySoundW get _windowsPlaySound => _playSound ??= DynamicLibrary.open(
        'winmm.dll',
      ).lookupFunction<_PlaySoundWNative, _PlaySoundW>('PlaySoundW');

  static Future<Duration> _wavDuration(File file) async {
    final builder = await file.openRead(0, 44).fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, bytes) => builder..add(bytes),
        );
    final bytes = builder.takeBytes();
    if (bytes.length < 44) return const Duration(milliseconds: 100);
    final data = ByteData.sublistView(bytes);
    final byteRate = data.getUint32(28, Endian.little);
    final dataSize = data.getUint32(40, Endian.little);
    if (byteRate == 0) return const Duration(milliseconds: 100);
    return Duration(
      microseconds: dataSize * Duration.microsecondsPerSecond ~/ byteRate,
    );
  }
}
