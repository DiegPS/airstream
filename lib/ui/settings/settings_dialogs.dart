part of 'package:airstream/ui/chat_screen.dart';

Future<void> _removeSelectedTtsModel({
  required BuildContext context,
  required AppLocalizations l,
  required SettingsModel settings,
  required SettingsNotifier notifier,
  required SettingsModel Function() currentSettings,
  required AppController appController,
}) async {
  final model = TtsModelCatalog.byId(settings.ttsModelId);
  final remove = await confirmLiveAction(
    context,
    title: l.removeTtsModelTitle(model.name),
    content: l.removeTtsModelConfirmationNamed(model.name),
    action: l.remove,
  );
  if (!remove || !context.mounted) return;
  try {
    // Settings may have changed while the dialog was open.
    await notifier.update(currentSettings().copyWith(ttsEnabled: false));
    await appController.removeTtsModel(settings.ttsModelId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.ttsModelRemoved)),
      );
    }
  } catch (error, stack) {
    AppLogger.error(
      'Could not remove TTS model',
      error: error,
      stackTrace: stack,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.ttsModelRemovalFailed)),
      );
    }
  }
}
