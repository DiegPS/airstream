import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../template_library.dart';
import 'be_right_back.dart';
import 'credits.dart';
import 'gallery_base.dart';
import 'recent_support.dart';
import 'starting_soon.dart';
import 'stream_ending.dart';

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
    version: 3,
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
    version: 1,
    kind: GalleryKind.screen,
    name: (l) => l.galleryStartingSoon,
    description: (l) => l.galleryStartingSoonDescription,
    files: startingSoonFiles,
    fields: startingSoonFields,
  ),
  'be-right-back': GalleryItem(
    id: 'be-right-back',
    version: 1,
    kind: GalleryKind.screen,
    name: (l) => l.galleryBeRightBack,
    description: (l) => l.galleryBeRightBackDescription,
    files: beRightBackFiles,
    fields: beRightBackFields,
  ),
  'stream-ending': GalleryItem(
    id: 'stream-ending',
    version: 1,
    kind: GalleryKind.screen,
    name: (l) => l.galleryStreamEnding,
    description: (l) => l.galleryStreamEndingDescription,
    files: streamEndingFiles,
    fields: streamEndingFields,
  ),
  'credits': GalleryItem(
    id: 'credits',
    version: 1,
    kind: GalleryKind.screen,
    name: (l) => l.galleryCredits,
    description: (l) => l.galleryCreditsDescription,
    files: creditsFiles,
    fields: creditsFields,
  ),
});
