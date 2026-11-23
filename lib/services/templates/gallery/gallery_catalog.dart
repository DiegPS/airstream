import 'emote_wall.dart';
import 'scoreboard.dart';
import 'word_cloud.dart';
import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../template_library.dart';
import 'be_right_back.dart';
import 'credits.dart';
import 'gallery_base.dart';
import 'latest_support.dart';
import 'poll_widget.dart';
import 'recent_support.dart';
import 'queue_list.dart';
import 'starting_soon.dart';
import 'stream_ending.dart';
import 'ticker.dart';
import 'top_supporters.dart';

enum GalleryKind { screen, widget }

class GalleryItem {
  const GalleryItem({
    required this.id,
    required this.version,
    required this.kind,
    this.width = 1920,
    this.height = 1080,
    required this.name,
    required this.description,
    required this.files,
    required this.fields,
  });

  final String id;
  final int version, width, height;
  final GalleryKind kind;
  final String Function(AppLocalizations) name, description;
  final Map<String, String> Function() files;
  final List<Map<String, Object?>> Function(AppLocalizations) fields;

  Map<String, Object?> _manifest(String language) {
    final l = lookupAppLocalizations(Locale(language == 'es' ? 'es' : 'en'));
    return {
      'name': name(l),
      'description': description(l),
      'sdk': 1,
      'width': width,
      'height': height,
      'gallery': {'id': id, 'version': version},
      'fields': [...galleryFields(l), ...fields(l)],
    };
  }

  Map<String, Object?> defaults(String language) =>
      TemplateManifest(id, _manifest(language)).values(const {});

  Map<String, String> buildFiles(String language) => {
        'template.json':
            const JsonEncoder.withIndent('  ').convert(_manifest(language)),
        ...files(),
      };
}

final galleryCatalog = Map<String, GalleryItem>.unmodifiable({
  'recent-support': GalleryItem(
    id: 'recent-support',
    version: 5,
    kind: GalleryKind.widget,
    width: 480,
    height: 640,
    name: (l) => l.galleryRecentSupport,
    description: (l) => l.galleryRecentSupportDescription,
    files: recentSupportFiles,
    fields: recentSupportFields,
  ),
  'starting-soon': GalleryItem(
    id: 'starting-soon',
    version: 6,
    kind: GalleryKind.screen,
    name: (l) => l.galleryStartingSoon,
    description: (l) => l.galleryStartingSoonDescription,
    files: startingSoonFiles,
    fields: startingSoonFields,
  ),
  'be-right-back': GalleryItem(
    id: 'be-right-back',
    version: 5,
    kind: GalleryKind.screen,
    name: (l) => l.galleryBeRightBack,
    description: (l) => l.galleryBeRightBackDescription,
    files: beRightBackFiles,
    fields: beRightBackFields,
  ),
  'stream-ending': GalleryItem(
    id: 'stream-ending',
    version: 6,
    kind: GalleryKind.screen,
    name: (l) => l.galleryStreamEnding,
    description: (l) => l.galleryStreamEndingDescription,
    files: streamEndingFiles,
    fields: streamEndingFields,
  ),
  'credits': GalleryItem(
    id: 'credits',
    version: 5,
    kind: GalleryKind.screen,
    name: (l) => l.galleryCredits,
    description: (l) => l.galleryCreditsDescription,
    files: creditsFiles,
    fields: creditsFields,
  ),
  'ticker': GalleryItem(
    id: 'ticker',
    version: 4,
    kind: GalleryKind.widget,
    width: tickerWidth,
    height: tickerHeight,
    name: (l) => l.galleryTicker,
    description: (l) => l.galleryTickerDescription,
    files: tickerFiles,
    fields: tickerFields,
  ),
  'latest-support': GalleryItem(
    id: 'latest-support',
    version: 3,
    kind: GalleryKind.widget,
    width: latestSupportWidth,
    height: latestSupportHeight,
    name: (l) => l.galleryLatestSupport,
    description: (l) => l.galleryLatestSupportDescription,
    files: latestSupportFiles,
    fields: latestSupportFields,
  ),
  'top-supporters': GalleryItem(
    id: 'top-supporters',
    version: 4,
    kind: GalleryKind.widget,
    width: topSupportersWidth,
    height: topSupportersHeight,
    name: (l) => l.galleryTopSupporters,
    description: (l) => l.galleryTopSupportersDescription,
    files: topSupportersFiles,
    fields: topSupportersFields,
  ),
  'queue-list': GalleryItem(
    id: 'queue-list',
    version: 3,
    kind: GalleryKind.widget,
    width: 480,
    height: 720,
    name: (l) => l.queueTitle,
    description: (l) => l.galleryQueueDescription,
    files: queueListFiles,
    fields: queueListFields,
  ),
  'poll': GalleryItem(
    id: 'poll',
    version: 4,
    kind: GalleryKind.widget,
    width: 640,
    height: 480,
    name: (l) => l.pollTitle,
    description: (l) => l.galleryPollDescription,
    files: pollWidgetFiles,
    fields: (_) => const [],
  ),
  'scoreboard': GalleryItem(
    id: 'scoreboard',
    version: 4,
    kind: GalleryKind.widget,
    width: scoreboardWidth,
    height: scoreboardHeight,
    name: (l) => l.galleryScoreboard,
    description: (l) => l.galleryScoreboardDescription,
    files: scoreboardFiles,
    fields: scoreboardFields,
  ),
  'word-cloud': GalleryItem(
    id: 'word-cloud',
    version: 2,
    kind: GalleryKind.widget,
    width: 960,
    height: 480,
    name: (l) => l.galleryWordCloud,
    description: (l) => l.galleryWordCloudDescription,
    files: wordCloudFiles,
    fields: wordCloudFields,
  ),
  'emote-wall': GalleryItem(
    id: 'emote-wall',
    version: 3,
    kind: GalleryKind.widget,
    width: emoteWallWidth,
    height: emoteWallHeight,
    name: (l) => l.galleryEmoteWall,
    description: (l) => l.galleryEmoteWallDescription,
    files: emoteWallFiles,
    fields: emoteWallFields,
  ),
});
