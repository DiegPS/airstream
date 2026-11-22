import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';

InputDecoration settingsInput({String? hint, String? error}) => InputDecoration(
      hintText: hint,
      errorText: error,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E2E2E))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E2E2E))),
    );
const _settingsGreen = Color(0xFF53FC18);

/// Body text of the settings panel: the size and colour every card uses.
const settingsBodyStyle =
    TextStyle(color: Colors.white70, fontSize: 12, height: 1.35);

/// Titles inside a card (a rule, a gallery item, a switch with a hint).
const settingsItemTitleStyle =
    TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600);

/// Hints under a title.
const settingsHintStyle =
    TextStyle(color: Colors.white54, fontSize: 11, height: 1.3);

/// The app's look for stock Material controls (lists, text and outlined
/// buttons, expanding rows, dividers, menus), so screens and dialogs built
/// from plain widgets match the hand-styled settings cards.
ThemeData withAirstreamComponents(ThemeData base) => base.copyWith(
      listTileTheme: const ListTileThemeData(
        dense: true,
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 4,
        titleTextStyle: settingsItemTitleStyle,
        subtitleTextStyle: settingsHintStyle,
        iconColor: Colors.white70,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _settingsGreen,
          disabledForegroundColor: Colors.white30,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 32),
          visualDensity: VisualDensity.compact,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF3A3A3A)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        tilePadding: EdgeInsets.zero,
        iconColor: _settingsGreen,
        collapsedIconColor: Colors.white54,
        shape: Border(),
        collapsedShape: Border(),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFF2A2A2A), thickness: 1),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF1E1E1E),
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );

/// The settings panel's text sizes: 12 px body text and 13 px typed text, on
/// top of [withAirstreamComponents] (applied again for panels tested alone).
class SettingsPanelTheme extends StatelessWidget {
  const SettingsPanelTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = withAirstreamComponents(Theme.of(context));
    // Typed text in fields matches the fields styled by hand (13 px).
    const fieldText = TextStyle(color: Colors.white, fontSize: 13);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.copyWith(
          bodyLarge: base.textTheme.bodyLarge?.merge(fieldText) ?? fieldText,
          titleMedium:
              base.textTheme.titleMedium?.merge(fieldText) ?? fieldText,
        ),
      ),
      child: DefaultTextStyle.merge(style: settingsBodyStyle, child: child),
    );
  }
}

/// The settings drop-down: a boxed field like [settingsInput], never the
/// underlined stock one. [key] goes to the [DropdownButton] itself.
Widget settingsDropdown<T>({
  Key? key,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?>? onChanged,
  double? menuMaxHeight,
  DropdownButtonBuilder? selectedItemBuilder,
  bool expanded = true,
}) =>
    Container(
      // As tall as a settings text field and button, so rows line up.
      constraints: const BoxConstraints(minHeight: 40),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: key,
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          isExpanded: expanded,
          menuMaxHeight: menuMaxHeight,
          selectedItemBuilder: selectedItemBuilder,
          dropdownColor: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          iconEnabledColor: Colors.white54,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );

Widget settingsLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(color: Colors.white70, fontSize: 12)));
ButtonStyle primarySettingsStyle() => ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF53FC18),
      foregroundColor: Colors.black,
      disabledBackgroundColor: const Color(0xFF262626),
      minimumSize: const Size(double.infinity, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
ButtonStyle secondarySettingsStyle({bool destructive = false}) =>
    OutlinedButton.styleFrom(
      foregroundColor: destructive ? const Color(0xFFFF6B6B) : Colors.white,
      side: const BorderSide(color: Color(0xFF3A3A3A)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

/// A state shown next to a tool (queue open, subathon paused): a coloured
/// dot and text, so it never reads as one more button.
Widget settingsStatus(String text, Color color, {Key? key}) => Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );

/// Main action of a dialog: the settings look, sized to its label. The panel
/// style stretches to the full width, which in a dialog pushed Cancel and the
/// action onto separate lines.
ButtonStyle dialogPrimaryStyle() => ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF53FC18),
      foregroundColor: Colors.black,
      disabledBackgroundColor: const Color(0xFF262626),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      minimumSize: const Size(88, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

/// Cancel / secondary action of a dialog, next to [dialogPrimaryStyle];
/// [destructive] (red text) confirms deleting or resetting something.
ButtonStyle dialogSecondaryStyle({bool destructive = false}) =>
    OutlinedButton.styleFrom(
      foregroundColor: destructive ? const Color(0xFFFF6B6B) : Colors.white,
      side: const BorderSide(color: Color(0xFF3A3A3A)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      minimumSize: const Size(88, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

class PageUrlRow extends StatelessWidget {
  const PageUrlRow(
      {super.key,
      required this.url,
      this.title,
      this.description,
      this.onCopy});
  final String url;
  final String? title, description;
  final VoidCallback? onCopy;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2C2C2C))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                // Untitled rows (live tools) say what the link is for, not
                // the name of the OBS tab.
                child: Text(title ?? l.pageUrlForObs,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: l.copyUrl,
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: Colors.white70,
                onPressed:
                    onCopy ?? () => Clipboard.setData(ClipboardData(text: url)))
          ]),
          SelectableText(url,
              style: const TextStyle(
                  color: Color(0xFFACCBFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace')),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10, height: 1.3))
          ],
        ]));
  }
}
