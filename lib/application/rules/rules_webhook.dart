import 'dart:math';
import 'package:airstream/settings/settings_model.dart';

String newRulesWebhookToken() {
  final random = Random.secure();
  return List.generate(
      32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

SettingsModel enableRulesWebhook(SettingsModel settings, bool enabled) =>
    settings.copyWith(
      rulesWebhookEnabled: enabled,
      rulesWebhookToken: enabled &&
              !RegExp(r'^[0-9a-f]{32,}$').hasMatch(settings.rulesWebhookToken)
          ? newRulesWebhookToken()
          : settings.rulesWebhookToken,
    );

/// Always visits the entire expected secret, regardless of the first mismatch.
/// The expected length is fixed by the locally generated token, never the caller.
bool constantTimeTokenEquals(String expected, String supplied) {
  var difference = expected.length ^ supplied.length;
  for (var i = 0; i < expected.length; i++) {
    difference |= expected.codeUnitAt(i) ^
        (i < supplied.length ? supplied.codeUnitAt(i) : 0);
  }
  // A short or empty stored token (for example from a hand-edited settings
  // file) never authenticates anything.
  return difference == 0 && expected.length >= 32;
}
