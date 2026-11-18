import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:airstream/application/saved_poll.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const streaming = SettingsModel(
    twitchChannel: 'xqc',
    kickSlug: 'xqc',
    youtubeHandle: '@LofiGirl',
    obsHost: 'localhost:4455',
    obsPassword: 'secret',
    overlayEnabled: true,
    overlayPort: 18081,
    appLanguageCode: 'es',
    fontSize: 22,
    ttsEnabled: true,
    highlightWords: ['pregunta'],
  );

  test('a profile keeps the setup but not where Airstream connects', () {
    final profile = SettingsProfiles.capture(streaming);
    expect(profile['fontSize'], 22);
    expect(profile['ttsEnabled'], isTrue);
    expect(profile['highlightWords'], ['pregunta']);
    for (final key in [
      'twitchChannel',
      'kickSlug',
      'youtubeHandle',
      'obsHost',
      'overlayPort',
      'overlayEnabled',
      'appLanguageCode',
      'profiles',
    ]) {
      expect(profile.containsKey(key), isFalse, reason: key);
    }
    expect(profile.containsKey('showYoutubeStreamBadges'), isTrue,
        reason: 'a style option, despite its name');
  });

  test('applying a profile changes the setup and keeps the connections', () {
    final saved = SettingsProfiles.save(streaming, ' Gaming ');
    expect(saved.profiles.keys, ['Gaming']);

    final changed = saved.copyWith(
      fontSize: 14,
      ttsEnabled: false,
      twitchChannel: 'otro',
    );
    final applied =
        SettingsProfiles.apply(changed, changed.profiles['Gaming']!);
    expect(applied.fontSize, 22);
    expect(applied.ttsEnabled, isTrue);
    expect(applied.twitchChannel, 'otro');
    expect(applied.obsPassword, 'secret');
    expect(applied.profiles.keys, ['Gaming']);

    expect(SettingsProfiles.delete(applied, 'Gaming').profiles, isEmpty);
  });

  test('resetting returns the setup to defaults and keeps the rest', () {
    final withProfile = SettingsProfiles.save(streaming, 'Gaming');
    final reset = SettingsProfiles.resetToDefaults(withProfile);
    expect(reset.fontSize, const SettingsModel().fontSize);
    expect(reset.ttsEnabled, isFalse);
    expect(reset.highlightWords, isEmpty);
    expect(reset.twitchChannel, 'xqc');
    expect(reset.appLanguageCode, 'es');
    expect(reset.overlayPort, 18081);
    expect(reset.obsPassword, 'secret');
    expect(reset.profiles.keys, ['Gaming']);
  });

  test('profiles and reset never erase saved polls', () {
    final poll = SavedPoll.fromJson({
      'name': 'Juego',
      'question': '¿Qué jugamos?',
      'options': ['A', 'B'],
      'mode': 'numbered',
    })!;
    final withProfile = SettingsProfiles.save(streaming, 'Gaming');
    // The poll is saved after the profile.
    final current = withProfile.copyWith(savedPolls: [poll]);
    expect(SettingsProfiles.capture(current).containsKey('savedPolls'), false);
    final applied =
        SettingsProfiles.apply(current, current.profiles['Gaming']!);
    expect(applied.savedPolls.single.name, 'Juego');
    expect(SettingsProfiles.resetToDefaults(current).savedPolls.single.name,
        'Juego');
  });

  test('an exported file brings every setting back, without the password', () {
    final withProfile = SettingsProfiles.save(streaming, 'Gaming');
    final file = SettingsProfiles.export(withProfile);
    expect(file, isNot(contains('secret')));

    final imported = SettingsProfiles.import(
      file,
      const SettingsModel(obsPassword: 'current'),
    );
    expect(imported.twitchChannel, 'xqc');
    expect(imported.fontSize, 22);
    expect(imported.profiles['Gaming']!['fontSize'], 22);
    expect(imported.obsPassword, 'current');
    expect(() => SettingsProfiles.import('not json', streaming),
        throwsFormatException);
  });

  test('settings import keeps local media and adds only files already present',
      () async {
    final directory = await Directory.systemTemp.createTemp('profiles-media-');
    addTearDown(() => directory.delete(recursive: true));
    const localId = '0000000000000001';
    const presentId = '0000000000000002';
    const missingId = '0000000000000003';
    const item = {
      'name': 'local.png',
      'kind': 'image',
      'ext': 'png',
      'bytes': 8,
      'addedAt': 0
    };
    const current = SettingsModel(mediaLibrary: {localId: item});
    final renamed = {...item, 'name': 'renamed abroad.png'};
    final incoming = SettingsModel(mediaLibrary: {
      localId: renamed,
      presentId: item,
      missingId: item,
    });
    await File(p.join(directory.path, '$presentId.png'))
        .writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    final restored = SettingsProfiles.import(
        SettingsProfiles.export(incoming), current,
        mediaDirectory: directory);
    expect(restored.mediaLibrary, {localId: item, presentId: item});
  });

  test('profiles survive a save and reload, and bad entries are dropped', () {
    final saved = SettingsProfiles.save(streaming, 'Gaming');
    final restored = SettingsModel.fromJsonString(saved.toJsonString());
    expect(restored.profiles['Gaming']!['fontSize'], 22);

    final corrupt = SettingsModel.fromJson({
      'profiles': {
        'Bueno': {'fontSize': 18},
        'Malo': 'no-es-un-mapa'
      },
    });
    expect(corrupt.profiles.keys, ['Bueno']);
    expect(SettingsModel.fromJson({'profiles': 'nada'}).profiles, isEmpty);
  });
}
