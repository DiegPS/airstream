import 'dart:async';
import 'dart:io';

import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/native_audio_playback_service.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/settings/settings_search.dart';
import 'package:airstream/ui/widgets/media_library_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _target = '0123456789abcdef';
const _other = 'fedcba9876543210';

void main() {
  for (final language in ['en', 'es']) {
    final locale = Locale(language);
    final l = lookupAppLocalizations(locale);
    test('matches localized labels and synonyms in $language', () {
      final spanish = language == 'es';
      final queries = {
        (spanish ? 'recuperacion ZIP' : 'archive ZIP'): ('backup', 7),
        (spanish ? 'subtitulos' : 'transcription'): ('captions', 1),
        l.chatFontFamily.toUpperCase(): ('textAndNames', 2),
        l.password: ('obs', 3),
        l.mediaRename: ('media', 3),
        l.queueTitle: ('queue', 4),
        l.ruleLabel('kwebhookTitle'): ('rules', 5),
        l.templatesAi: ('templates', 6),
      };
      for (final entry in queries.entries) {
        expect(searchSettings(l, entry.key).map((e) => (e.id, e.tab)),
            contains(entry.value),
            reason: entry.key);
      }
      expect(searchSettings(l, '  '), isEmpty);
      expect(searchSettings(l, 'zz-unknown-setting'), isEmpty);
    });

    testWidgets(
        'filters, renames and closes audio preview at 360 px ($language)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 680);
      addTearDown(tester.view.reset);
      final settings = _MediaSettings(SettingsModel(
        mediaLibrary: const {
          _target: {
            'name': 'Storm.wav',
            'kind': 'audio',
            'ext': 'wav',
            'bytes': 128,
            'addedAt': 1,
          },
          _other: {
            'name': 'Sun.ogg',
            'kind': 'audio',
            'ext': 'ogg',
            'bytes': 180,
            'addedAt': 2,
          },
        },
        alertTypeOptions: const {
          'raid': {'sound': 'library', 'soundMediaId': _target}
        },
        rules: [
          {
            ...RuleSchema.newRule('manual', id: 'demo'),
            'actions': [
              {
                'id': 'play',
                'type': 'sound.play',
                'source': 'library',
                'name': 'coin',
                'mediaId': _target,
              },
            ],
          }
        ],
      ));
      final playback = _PreviewAudio();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsProvider.overrideWith((_) => settings),
          mediaLibraryProvider.overrideWith((_) async => _PreviewLibrary()),
          mediaPreviewAudioProvider.overrideWithValue(() => playback),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const Scaffold(
            body: SingleChildScrollView(child: MediaLibraryCard()),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('media-search'));
      expect(
          tester.widget<TextField>(search).decoration!.hintText, l.mediaSearch);
      final storm = find.byKey(const Key('media-item-$_target'));
      final sun = find.byKey(const Key('media-item-$_other'));
      expect(storm, findsOneWidget);
      expect(sun, findsOneWidget);
      await tester.enterText(search, '  STORM  ');
      await tester.pumpAndSettle();
      expect(storm, findsOneWidget);
      expect(sun, findsNothing);
      await tester.tap(find.byKey(const Key('media-preview-$_target')));
      await tester.pumpAndSettle();
      final audioToggle = find.byKey(const Key('media-audio-preview-toggle'));
      await tester.tap(audioToggle);
      await tester.pumpAndSettle();
      expect(playback.isPlaying, isTrue);
      expect(find.text(l.mediaPreviewStop), findsOneWidget);
      final close = MaterialLocalizations.of(tester.element(audioToggle))
          .closeButtonLabel;
      await tester.tap(find.text(close));
      await tester.pumpAndSettle();
      expect(playback.stopped, isTrue);

      await tester.tap(find.byKey(const Key('media-rename-$_target')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('media-rename-name'));
      final save = find.byKey(const Key('media-rename-save'));
      await tester.enterText(field, '../path');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text(l.mediaRenameInvalid), findsOneWidget);
      await tester.enterText(field, ' Tormenta ');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(settings.current.mediaLibrary.keys, [_target, _other]);
      expect(settings.current.mediaLibrary[_target], {
        'name': 'Tormenta',
        'kind': 'audio',
        'ext': 'wav',
        'bytes': 128,
        'addedAt': 1,
      });
      expect(
          AlertTypeOptions.of(settings.current, 'raid').soundMediaId, _target);
      expect(
          settings.current.rules.single['actions'].single['mediaId'], _target);
      expect(storm, findsNothing);
      expect(find.text(l.mediaNoMatches), findsOneWidget);
      await tester.enterText(search, 'tormenta');
      await tester.pumpAndSettle();
      expect(storm, findsOneWidget);
      expect(sun, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _MediaSettings extends SettingsNotifier {
  _MediaSettings(SettingsModel model) : super(systemLanguageCode: () => '') {
    state = model;
  }

  SettingsModel get current => state;

  @override
  Future<void> update(SettingsModel settings) async => state = settings;
}

class _PreviewLibrary extends MediaLibrary {
  _PreviewLibrary() : super(Directory('unused'), () => {});

  @override
  Future<File> fileFor(MapEntry<String, Map<String, dynamic>> entry) async =>
      File('unused.wav');
}

class _PreviewAudio extends NativeAudioPlaybackService {
  Completer<void>? _playback;
  bool stopped = false;

  @override
  bool get isPlaying => _playback != null;

  @override
  Future<void> playFile(File file,
      {Duration timeout = const Duration(seconds: 20),
      double? volume,
      bool Function()? canStart}) async {
    _playback = Completer<void>();
    await _playback!.future;
    _playback = null;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    _playback?.complete();
  }
}
