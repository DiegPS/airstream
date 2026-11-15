import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/overlay_style_presets.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class OverlayStylePresetsCard extends ConsumerWidget {
  const OverlayStylePresetsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final selected = OverlayStylePresets.matching(ref.watch(settingsProvider));
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
    return UiCard(
      key: const Key('overlay-style-presets-card'),
      title: l.overlayStylePresetsTitle,
      margin: EdgeInsets.zero,
      children: [
        if (selected == null)
          Text(l.overlayStyleCustom,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(l.overlayStylePresetsDescription,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 8),
        for (final preset in OverlayStylePreset.values)
          Material(
            color: Colors.transparent,
            child: ListTile(
              key: Key('overlay-style-preset-${preset.name}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(labels[preset]!.$1,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              subtitle: Text(labels[preset]!.$2,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              trailing: selected == preset
                  ? const Icon(Icons.check, size: 18, color: Color(0xFF53FC18))
                  : null,
              onTap: () {
                final previous = ref.read(settingsProvider);
                if (OverlayStylePresets.matching(previous) == preset) return;
                ref
                    .read(settingsProvider.notifier)
                    .update(OverlayStylePresets.apply(previous, preset));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(l.overlayStyleApplied(labels[preset]!.$1)),
                    action: SnackBarAction(
                      label: l.overlayStyleUndo,
                      onPressed: () =>
                          ref.read(settingsProvider.notifier).update(
                                OverlayStylePresets.restoreVisual(
                                    ref.read(settingsProvider), previous),
                              ),
                    ),
                  ));
              },
            ),
          ),
        const SizedBox(height: 8),
        Text(l.overlayStylePreviewHint,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
