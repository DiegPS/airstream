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
                child: Text(title ?? l.obsAndOverlay,
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
