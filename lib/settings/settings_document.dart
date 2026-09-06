import 'dart:convert';

import 'settings_model.dart';

const int currentSettingsSchemaVersion = 1;

class DecodedSettingsDocument {
  const DecodedSettingsDocument({
    required this.settings,
    required this.requiresRewrite,
    required this.containsLegacyPassword,
  });

  final SettingsModel settings;
  final bool requiresRewrite;
  final bool containsLegacyPassword;
}

abstract final class SettingsDocumentCodec {
  static String encode(SettingsModel settings) => jsonEncode({
        'schemaVersion': currentSettingsSchemaVersion,
        'settings': settings.toJson(),
      });

  static DecodedSettingsDocument decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Settings document must be an object.');
    }
    final document = Map<String, dynamic>.from(decoded);
    if (!document.containsKey('schemaVersion')) {
      final migrated = _migrateLegacy(document);
      return DecodedSettingsDocument(
        settings: SettingsModel.fromJson(migrated),
        requiresRewrite: true,
        containsLegacyPassword: migrated.containsKey('obsPassword'),
      );
    }

    final version = document['schemaVersion'];
    if (version is! int || version < 1) {
      throw FormatException('Invalid settings schema version: $version');
    }
    if (version > currentSettingsSchemaVersion) {
      throw FormatException(
        'Settings schema $version is newer than supported schema '
        '$currentSettingsSchemaVersion.',
      );
    }

    var payload = _payload(document);
    var migrated = false;
    var currentVersion = version;
    while (currentVersion < currentSettingsSchemaVersion) {
      payload = _migrate(currentVersion, payload);
      currentVersion++;
      migrated = true;
    }
    return DecodedSettingsDocument(
      settings: SettingsModel.fromJson(payload),
      requiresRewrite: migrated,
      containsLegacyPassword: payload.containsKey('obsPassword'),
    );
  }

  /// Schema 0 was the original unversioned settings map.
  static Map<String, dynamic> _migrateLegacy(Map<String, dynamic> payload) =>
      Map<String, dynamic>.from(payload);

  static Map<String, dynamic> _payload(Map<String, dynamic> document) {
    final payload = document['settings'];
    if (payload is! Map) {
      throw const FormatException('Settings payload must be an object.');
    }
    return Map<String, dynamic>.from(payload);
  }

  static Map<String, dynamic> _migrate(
    int fromVersion,
    Map<String, dynamic> payload,
  ) {
    switch (fromVersion) {
      default:
        throw StateError('No migration from settings schema $fromVersion.');
    }
  }
}
