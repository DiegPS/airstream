import 'dart:async';
import 'dart:io';

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/media_library_card.dart';
import 'package:airstream/ui/widgets/template_fields.dart';
import 'package:airstream/ui/widgets/templates_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = '1234567890abcdef';
final _info = TemplateInfo(
  'test',
  TemplateManifest('test', {
    'name': 'Una plantilla con un nombre muy largo ' * 20,
    'fields': [
      {'key': 'count', 'type': 'number', 'min': 0, 'max': 500, 'default': 10},
      {'key': 'sound', 'type': 'media', 'kind': 'audio'},
    ],
  }),
  [],
  '.',
);

class _Settings extends SettingsNotifier {
  _Settings(SettingsModel model) : super(systemLanguageCode: () => 'es') {
    state = model;
  }

  @override
  Future<void> update(SettingsModel settings) async => state = settings;
}

class _Templates extends TemplateLibrary {
  _Templates() : super(Directory('.'));
  Map<String, Object?> values = {};
  String html = '<p>Saved</p>';
  @override
  Future<List<TemplateInfo>> list() async => [_info];
  @override
  Future<Map<String, Object?>> editorValues(TemplateInfo info) async =>
      info.manifest.values(values);
  @override
  Future<Map<String, Object?>> resolvedValues(String id) => editorValues(_info);
  @override
  Future<void> writeValues(String id, Map values) async =>
      this.values = Map<String, Object?>.from(values);
  @override
  Future<String?> readTemplateFile(String id, String name) async =>
      name == 'index.html' ? html : null;
  @override
  Future<void> writeTemplateFile(
          String id, String name, String contents) async =>
      html = contents;
}

class _Media extends MediaLibrary {
  _Media() : super(Directory('.'), () => {});
  int deletes = 0;
  @override
  Future<void> delete(String id, {Future<void> Function()? onDeleted}) async {
    deletes++;
    await onDeleted?.call();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, Widget body,
      {required _Templates templates,
      _Media? media,
      SettingsModel model = const SettingsModel()}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _Settings(model)),
        templateLibraryProvider.overrideWith((ref) async => templates),
        templateErrorsProvider.overrideWith((ref) => Stream.value({})),
        templateCountsProvider.overrideWith((ref) => Stream.value({})),
        overlayUrlProvider.overrideWithValue(null),
        if (media != null)
          mediaLibraryProvider.overrideWith((ref) async => media),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: body)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Spanish editor handles Escape without discarding edits silently',
      (tester) async {
    final templates = _Templates();
    await mount(tester, const TemplatesCard(), templates: templates);
    final menu = find.byKey(const Key('template-menu-test'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-edit-test')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('template-editor-html'));
    await tester.enterText(field, '<p>Draft</p>');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '<p>Draft</p>');
    await tester.tap(find.byKey(const Key('template-editor-save')));
    await tester.pumpAndSettle();
    expect(templates.html, '<p>Draft</p>');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish numeric field rejects bounds and saves decimal input',
      (tester) async {
    final templates = _Templates();
    await mount(tester, TemplateFields(library: templates, info: _info),
        templates: templates);
    await tester.tap(find.byKey(const Key('template-fields-test')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('template-field-test-count'));
    await tester.enterText(field, '501');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('entre 0 y 500'), findsOneWidget);
    expect(templates.values, isEmpty);
    expect(find.textContaining('Añade un archivo compatible'), findsOneWidget);
    await tester.enterText(field, '12,5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(templates.values['count'], 12.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish media deletion supports cancel and confirms just once',
      (tester) async {
    final media = _Media();
    await mount(tester, const MediaLibraryCard(),
        templates: _Templates(),
        media: media,
        model: SettingsModel(mediaLibrary: {
          _id: {
            'name': 'Un nombre largo ' * 5,
            'kind': 'audio',
            'ext': 'wav',
            'bytes': 50,
            'addedAt': 0,
          },
        }));
    final delete = find.byKey(const Key('media-delete-$_id'));
    final confirm = find.byKey(const Key('media-delete-confirm'));
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(confirm.hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(media.deletes, 0);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(media.deletes, 1);
    expect(delete, findsNothing);
    expect(find.textContaining('Usa Añadir archivos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Template import shows work and rejects a second submission',
      (tester) async {
    const channel = MethodChannel('plugins.flutter.io/file_selector');
    final messenger = tester.binding.defaultBinaryMessenger;
    final picker = Completer<List<String>>();
    var opens = 0;
    messenger.setMockMethodCallHandler(channel, (_) {
      opens++;
      return picker.future;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await mount(tester, const TemplatesCard(), templates: _Templates());
    final button = find.byKey(const Key('templates-import'));
    final submit = tester.widget<OutlinedButton>(button).onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.text('Importando…'), findsOneWidget);
    expect(opens, 1);
    picker.completeError(PlatformException(code: 'picker-unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo importar la plantilla'),
        findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
  });
}
