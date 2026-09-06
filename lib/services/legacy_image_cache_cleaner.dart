import 'dart:io';

import 'package:airstream/services/app_logger.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class LegacyImageCacheCleaner {
  static const _migrationKey = 'legacy_image_cache_cleaned_v1';
  static const _legacyDirectoryName = 'libCachedImageData';

  static Future<void> cleanupOnce() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_migrationKey) == true) return;

      await DefaultCacheManager().emptyCache();
      final temporaryDirectory = await getTemporaryDirectory();
      final target = Directory(
        p.normalize(p.join(temporaryDirectory.path, _legacyDirectoryName)),
      );
      final expectedParent = p.normalize(temporaryDirectory.absolute.path);
      final actualParent = p.normalize(target.absolute.parent.path);
      if (p.basename(target.path) != _legacyDirectoryName ||
          actualParent != expectedParent) {
        throw StateError('Refusing to clean an unexpected cache path');
      }
      if (await target.exists()) await target.delete(recursive: true);
      await preferences.setBool(_migrationKey, true);
      AppLogger.debug('Legacy image cache cleanup completed');
    } catch (error, stack) {
      AppLogger.warning(
        'Legacy image cache cleanup failed; the app can continue safely',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
