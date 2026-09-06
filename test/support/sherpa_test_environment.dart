import 'dart:io';

import 'package:path/path.dart' as p;

String? findSherpaModelDirectory({
  required String environmentKey,
  required String storageKey,
}) {
  final configured = Platform.environment[environmentKey];
  if (configured != null && Directory(configured).existsSync()) {
    return Directory(configured).absolute.path;
  }
  final appData = Platform.environment['APPDATA'];
  if (appData == null) return null;
  for (final product in const ['Airstream', 'airchat_flutter']) {
    final candidate = Directory(
      p.join(appData, 'com.diegps', product, 'tts', 'models', storageKey),
    );
    if (candidate.existsSync()) return candidate.absolute.path;
  }
  return null;
}

String? findSherpaNativeLibraryDirectory() {
  final configured = Platform.environment['AIRSTREAM_SHERPA_LIBRARY_DIR'];
  if (_hasSherpaLibraries(configured)) {
    return Directory(configured!).absolute.path;
  }
  for (final configuration in const ['Release', 'Debug', 'Profile']) {
    final candidate = p.join(
      Directory.current.path,
      'build',
      'windows',
      'x64',
      'runner',
      configuration,
    );
    if (_hasSherpaLibraries(candidate)) {
      return Directory(candidate).absolute.path;
    }
  }
  return null;
}

bool _hasSherpaLibraries(String? directory) {
  if (directory == null) return false;
  return File(p.join(directory, 'onnxruntime.dll')).existsSync() &&
      File(p.join(directory, 'sherpa-onnx-c-api.dll')).existsSync();
}
