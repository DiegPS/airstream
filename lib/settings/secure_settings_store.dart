import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureSettingsStore {
  Future<String?> readObsPassword();

  Future<void> writeObsPassword(String password);

  Future<void> deleteObsPassword();
}

class FlutterSecureSettingsStore implements SecureSettingsStore {
  static const _obsPasswordKey = 'airstream.obs.password';

  final FlutterSecureStorage _storage;

  const FlutterSecureSettingsStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  @override
  Future<String?> readObsPassword() => _storage.read(key: _obsPasswordKey);

  @override
  Future<void> writeObsPassword(String password) =>
      _storage.write(key: _obsPasswordKey, value: password);

  @override
  Future<void> deleteObsPassword() => _storage.delete(key: _obsPasswordKey);
}
