import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../template_library.dart';
import 'gallery_base.dart';
import 'recent_support.dart';

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
    version: 2,
    kind: GalleryKind.widget,
    width: 480,
    height: 640,
    name: (l) => l.galleryRecentSupport,
    description: (l) => l.galleryRecentSupportDescription,
    files: recentSupportFiles,
    fields: recentSupportFields,
  ),
});
