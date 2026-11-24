import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/overlay_style_presets.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/settings_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class OverlayStylePresetsCard extends ConsumerStatefulWidget {
  const OverlayStylePresetsCard({super.key});

  @override
  ConsumerState<OverlayStylePresetsCard> createState() =>
      _OverlayStylePresetsCardState();
}

class _OverlayStylePresetsCardState
    extends ConsumerState<OverlayStylePresetsCard> {
  bool _busy = false;

  Future<void> _apply(OverlayStylePreset preset, String name) async {
    if (_busy ||
        OverlayStylePresets.matching(ref.read(settingsProvider)) == preset) {
      return;
    }
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      if (!await confirmLiveAction(context,
              title: l.overlayStyleReplaceConfirm(name),
              action: l.overlayStyleReplace,
              actionKey: const Key('overlay-style-replace-confirm')) ||
          !mounted) {
        return;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      final previous = ref.read(settingsProvider);
      final notifier = ref.read(settingsProvider.notifier);
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      var message = l.overlayStyleApplied(name);
      try {
        await notifier.update(OverlayStylePresets.apply(previous, preset));
      } catch (_) {
        message = l.liveSaveFailed;
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(message),
        action:
            OverlayStylePresets.matching(container.read(settingsProvider)) !=
                    preset
                ? null
                : SnackBarAction(
                    label: l.overlayStyleUndo,
                    onPressed: () async {
                      try {
                        await notifier.update(OverlayStylePresets.restoreVisual(
                            container.read(settingsProvider), previous));
                      } catch (_) {
                        if (messenger.mounted) {
                          messenger.showSnackBar(
                              SnackBar(content: Text(l.liveSaveFailed)));
                        }
                      }
                    },
                  ),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final selected =
        ref.watch(settingsProvider.select(OverlayStylePresets.matching));
    final labels = {
      OverlayStylePreset.classic: (
        l.overlayStyleClassic,
        l.overlayStyleClassicDescription
      ),
      OverlayStylePreset.compactGaming: (
        l.overlayStyleCompactGaming,
        l.overlayStyleCompactGamingDescription
      ),
      OverlayStylePreset.bigBubbles: (
        l.overlayStyleBigBubbles,
        l.overlayStyleBigBubblesDescription
      ),
      OverlayStylePreset.cleanTransparent: (
        l.overlayStyleCleanTransparent,
        l.overlayStyleCleanTransparentDescription
      ),
      OverlayStylePreset.vertical: (
        l.overlayStyleVertical,
        l.overlayStyleVerticalDescription
      ),
    };
    // A section of the overlay server card (its heading comes from the
    // caller), not a card nested inside it.
    return Column(
      key: const Key('overlay-style-presets-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.overlayStylePresetsDescription, style: settingsHintStyle),
        if (selected == null)
          Text(l.overlayStyleCustom, style: settingsHintStyle),
        const SizedBox(height: 4),
        for (final preset in OverlayStylePreset.values)
          Material(
            color: Colors.transparent,
            child: ListTile(
              key: Key('overlay-style-preset-${preset.name}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(labels[preset]!.$1, style: settingsItemTitleStyle),
              subtitle: Text(labels[preset]!.$2, style: settingsHintStyle),
              trailing: selected == preset
                  ? const Icon(Icons.check, size: 18, color: Color(0xFF53FC18))
                  : null,
              selected: selected == preset,
              onTap: _busy || selected == preset
                  ? null
                  : () => _apply(preset, labels[preset]!.$1),
            ),
          ),
        const SizedBox(height: 4),
        Text(l.overlayStylePreviewHint, style: settingsHintStyle),
      ],
    );
  }
}
