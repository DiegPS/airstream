import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Localization delegates for the app.
///
/// Flutter's generated `AppLocalizations.localizationsDelegates` still lists
/// the SDK's deprecated Material and Cupertino delegates; these come from
/// material_ui, which also covers Cupertino and widgets.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
