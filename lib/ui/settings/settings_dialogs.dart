part of 'package:airstream/ui/chat_screen.dart';

Future<void> _removeSelectedTtsModel({
  required BuildContext context,
  required AppLocalizations l,
  required SettingsModel settings,
  required SettingsNotifier notifier,
  required AppController appController,
}) async {
  final model = TtsModelCatalog.byId(settings.ttsModelId);
  final remove = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.removeTtsModelTitle(model.name)),
      content: Text(l.removeTtsModelConfirmationNamed(model.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l.remove),
        ),
      ],
    ),
  );
  if (remove != true || !context.mounted) return;
  try {
    await notifier.update(settings.copyWith(ttsEnabled: false));
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
