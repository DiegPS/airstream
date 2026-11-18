import 'package:airstream/services/overlay/overlay_payload_encoder.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/settings/chat_fonts.dart';
import 'package:airstream/settings/name_color_mode.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

void main() {
  test('featured settings reach the shared page payload', () {
    final payload = OverlayPayloadEncoder.settings(const SettingsModel(
      featuredPosition: 'top',
      featuredFontScale: 160,
      featuredSeconds: 0,
    ));
    expect(payload['featuredPosition'], 'top');
    expect(payload['featuredFontScale'], 160);
    expect(payload['featuredSeconds'], 0);
  });

  test('text and name settings round trip in settings and profiles', () {
    const model = SettingsModel(
      chatFontFamily: 'My Local-Font 2',
      chatFontInstalledOnly: true,
      nameColorMode: NameColorMode.single,
      nameColorSingle: '#FF8800',
      nameRoleColors: false,
      nameReadability: false,
    );
    for (final restored in [
      SettingsModel.fromJson(model.toJson()),
      SettingsProfiles.apply(
        const SettingsModel(),
        SettingsProfiles.capture(model),
      ),
    ]) {
      expect(restored.chatFontFamily, 'My Local-Font 2');
      expect(restored.chatFontInstalledOnly, isTrue);
      expect(restored.nameColorMode, NameColorMode.single);
      expect(restored.nameColorSingle, '#FF8800');
      expect(restored.nameRoleColors, isFalse);
      expect(restored.nameReadability, isFalse);
    }
    final defaults = SettingsModel.fromJson({});
    expect(defaults.chatFontFamily, 'Segoe UI');
    expect(defaults.chatFontInstalledOnly, isFalse);
    expect(defaults.nameColorMode, NameColorMode.platform);
    expect(defaults.nameColorSingle, '#FFFFFF');
    expect(defaults.nameRoleColors, isTrue);
    expect(defaults.nameReadability, isTrue);
  });

  test('invalid custom families never reach the persisted or browser payload',
      () {
    for (final input in [
      'a"b',
      "a'b",
      'a;b',
      'a{b',
      'a}b',
      'a<b',
      'a>b',
      'a\\b',
      'a\n',
      ' ',
      '',
      'a' * 49,
    ]) {
      expect(ChatFonts.validate(input), isNull, reason: input);
      expect(SettingsModel.fromJson({'chatFontFamily': input}).chatFontFamily,
          'Segoe UI',
          reason: input);
      final model = SettingsModel(chatFontFamily: input);
      expect(model.toJson()['chatFontFamily'], 'Segoe UI', reason: input);
      final payload = OverlayPayloadEncoder.settings(model);
      expect(payload['chatFontFamily'], 'Segoe UI', reason: input);
      expect(payload['googleFontStylesheet'], isNull);
    }
    expect(ChatFonts.validate('a' * 48), 'a' * 48);
  });

  test('only listed Google families selected as such produce a stylesheet', () {
    for (final font in ['Arial', 'My Installed-Font 2', 'Open Sans']) {
      final payload = OverlayPayloadEncoder.settings(SettingsModel(
        chatFontFamily: font,
      ));
      expect(payload['chatFontFamily'], font);
      expect(payload['googleFontStylesheet'], isNull);
    }
    final custom = OverlayPayloadEncoder.settings(
      const SettingsModel(chatFontFamily: 'Inter', chatFontInstalledOnly: true),
    );
    expect(custom['chatFontFamily'], 'Inter');
    expect(custom['googleFontStylesheet'], isNull);
    expect(
      OverlayPayloadEncoder.settings(
        const SettingsModel(chatFontFamily: 'Inter'),
      )['googleFontStylesheet'],
      'https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap',
    );
    expect(
      OverlayPayloadEncoder.settings(
        const SettingsModel(chatFontFamily: 'Press Start 2P'),
      )['googleFontStylesheet'],
      'https://fonts.googleapis.com/css2?family=Press+Start+2P:wght@400&display=swap',
    );
  });

  test('all built-in pages subscribe to the font and use its current CSP',
      () async {
    var settings = const SettingsModel(chatFontFamily: 'Arial');
    final handler =
        buildOverlayRoutes((_) => Response.ok(''), settings: () => settings);
    const oldCsp = "default-src 'none'; img-src data: http: https:; "
        "connect-src ws: wss:; style-src 'unsafe-inline'; script-src 'unsafe-inline'";

    for (final page in [
      'chat',
      'alerts',
      'featured',
      'poll',
      'giveaway',
      'goals',
      'timer',
      'captions'
    ]) {
      final request = Request('GET', Uri.parse('http://localhost:8080/$page'));
      final media = page == 'alerts' ? "; media-src 'self'" : '';
      settings = const SettingsModel(chatFontFamily: 'Arial');
      final installed = await handler(request);
      expect(installed.headers['content-security-policy'], oldCsp + media);
      final html = await installed.readAsString();
      expect(html, contains('overlayGoogleFontsAllowed = false;'));
      expect(html, contains('var(--overlay-font-family,'));
      expect(html, contains('settings.chatFontFamily'));
      expect(html, contains('settings.googleFontStylesheet'));
      expect(html, contains("style.setProperty('--overlay-font-family'"));
      expect(
          html, contains('Boolean(stylesheet) !== overlayGoogleFontsAllowed'));
      expect(html, contains('location.reload()'));
      expect(html,
          contains('if (stylesheet && overlayFontLink?.href !== stylesheet)'));
      expect(html, contains('if (overlayFontLink) overlayFontLink.remove()'));
      expect(html, contains("document.createElement('link')"));
      expect(
          html,
          contains(RegExp(
              r'applyOverlayFont\((?:next|settings|envelope\.data|e\.data)\)')));
      expect(html, isNot(contains('<link rel="stylesheet"')));
      if (page == 'chat') {
        expect(html, contains('author.style.color = message.nameColor'));
        expect(html, isNot(contains('author.style.color = message.color')));
        expect(html, isNot(contains('.author-name.mod')));
      }
      settings = const SettingsModel(chatFontFamily: 'Inter');
      final google = await handler(request);
      final googleStyleCsp = oldCsp.replaceFirst("style-src 'unsafe-inline'",
          "style-src 'unsafe-inline' https://fonts.googleapis.com");
      expect(
        google.headers['content-security-policy'],
        '$googleStyleCsp$media; font-src https://fonts.gstatic.com',
      );
      expect(await google.readAsString(),
          contains('overlayGoogleFontsAllowed = true;'));
      settings = settings.copyWith(chatFontInstalledOnly: true);
      final custom = await handler(request);
      expect(custom.headers['content-security-policy'], oldCsp + media);
    }
  });
}
