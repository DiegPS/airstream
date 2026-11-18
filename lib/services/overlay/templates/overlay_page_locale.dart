import 'dart:convert';

import 'package:airstream/l10n/generated/app_localizations.dart';

String overlayPageLocaleScript(String Function(AppLocalizations) title) {
  final titles = {
    for (final locale in AppLocalizations.supportedLocales)
      locale.languageCode: title(lookupAppLocalizations(locale)),
  };
  return '''
const pageTitles = ${jsonEncode(titles)};
function localizePage(language) {
  document.documentElement.lang = language;
  document.title = pageTitles[language] || pageTitles.en;
}
''';
}
