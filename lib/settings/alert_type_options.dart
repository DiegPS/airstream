import 'settings_model.dart';
import 'media_library_entries.dart';

const alertTypeIds = [
  'superchat',
  'membership',
  'bits',
  'subscription',
  'gift',
  'raid',
  'kicks',
];

class AlertTypeOption {
  const AlertTypeOption(
      {this.seconds = 0,
      this.animation = '',
      this.sound = '',
      this.soundPath = '',
      this.media = '',
      this.mediaAudio = false,
      this.soundMediaId = ''});
  final String media;
  final bool mediaAudio;
  final String soundMediaId;
  final int seconds;
  final String animation;
  final String sound;
  final String soundPath;
}

abstract final class AlertTypeOptions {
  static const _animations = ['pop', 'slide-up', 'slide-down', 'fade', 'zoom'];

  static Map<String, Map<String, dynamic>> sanitize(Object? raw) {
    final result = <String, Map<String, dynamic>>{};
    if (raw is! Map) return result;
    for (final type in alertTypeIds) {
      final entry = raw[type];
      if (entry is! Map) continue;
      final option = <String, dynamic>{};
      final seconds = entry['seconds'];
      if (seconds is num && seconds.isFinite) {
        final rounded = seconds.round();
        if (rounded >= 3 && rounded <= 20) option['seconds'] = rounded;
      }
      final animation = entry['animation'];
      if (_animations.contains(animation)) option['animation'] = animation;
      final sound = entry['sound'];
      if (const ['chime', 'coin', 'fanfare', 'custom', 'library']
          .contains(sound)) {
        option['sound'] = sound;
        final path = entry['soundPath'];
        if (sound == 'custom' &&
            path is String &&
            path.isNotEmpty &&
            path.length <= 1024) {
          option['soundPath'] = path;
        }
      }
      for (final key in ['media', 'soundMediaId']) {
        final id = entry[key];
        if (id is String && MediaLibraryEntries.idPattern.hasMatch(id)) {
          option[key] = id;
        }
      }
      if (entry['mediaAudio'] is bool) {
        option['mediaAudio'] = entry['mediaAudio'];
      }
      if (option.isNotEmpty) result[type] = option;
    }
    return result;
  }

  static AlertTypeOption of(SettingsModel settings, String type) {
    final entry = resolved(settings)[type];
    return AlertTypeOption(
      media: entry?['media'] as String? ?? '',
      mediaAudio: entry?['mediaAudio'] == true,
      soundMediaId: entry?['soundMediaId'] as String? ?? '',
      seconds: entry?['seconds'] as int? ?? 0,
      animation: entry?['animation'] as String? ?? '',
      sound: entry?['sound'] as String? ?? '',
      soundPath: entry?['soundPath'] as String? ?? '',
    );
  }

  static Map<String, Map<String, dynamic>> resolved(SettingsModel settings) {
    final options = sanitize(settings.alertTypeOptions);
    final library = MediaLibraryEntries.sanitize(settings.mediaLibrary);
    for (final e in options.values) {
      if (!['image', 'video'].contains(library[e['media']]?['kind'])) {
        e.remove('media');
        e.remove('mediaAudio');
      }
      if (e['sound'] == 'library' &&
          library[e['soundMediaId']]?['kind'] != 'audio') {
        e.remove('sound');
        e.remove('soundMediaId');
      }
    }
    return options;
  }

  static SettingsModel withOption(SettingsModel settings, String type,
      {int? seconds,
      String? animation,
      String? sound,
      String? soundPath,
      String? media,
      bool? mediaAudio,
      String? soundMediaId}) {
    final options = sanitize(settings.alertTypeOptions);
    final entry = <String, dynamic>{...?options[type]};
    if (seconds != null) {
      if (seconds == 0) {
        entry.remove('seconds');
      } else {
        entry['seconds'] = seconds;
      }
    }
    if (animation != null) {
      if (animation.isEmpty) {
        entry.remove('animation');
      } else {
        entry['animation'] = animation;
      }
    }
    if (sound != null) {
      if (sound.isEmpty) {
        entry.remove('sound');
        entry.remove('soundPath');
      } else {
        entry['sound'] = sound;
      }
    }
    if (soundPath != null && sound != '') entry['soundPath'] = soundPath;
    if (media != null) {
      entry['media'] = media;
      if (media.isEmpty) entry.remove('mediaAudio');
    }
    if (mediaAudio != null) entry['mediaAudio'] = mediaAudio;
    if (soundMediaId != null) entry['soundMediaId'] = soundMediaId;
    options[type] = entry;
    return settings.copyWith(alertTypeOptions: sanitize(options));
  }
}
