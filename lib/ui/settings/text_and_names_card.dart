part of 'package:airstream/ui/chat_screen.dart';

class _TextAndNamesCard extends StatefulWidget {
  const _TextAndNamesCard({required this.settings, required this.onChanged});

  final SettingsModel settings;
  final ValueChanged<SettingsModel> onChanged;

  @override
  State<_TextAndNamesCard> createState() => _TextAndNamesCardState();
}

class _TextAndNamesCardState extends State<_TextAndNamesCard> {
  static const _otherFont = '';
  static final _samples = [
    for (final (platform, name) in [
      (Platform.youtube, 'Alex'),
      (Platform.twitch, 'Sam'),
      (Platform.kick, 'Luz'),
    ])
      ChatMessage(
        platform: platform,
        id: name,
        author: ChatAuthor(name: name, channelId: ''),
        items: const [],
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        isModerator: platform == Platform.twitch,
      ),
  ];

  late final _customFont = TextEditingController(
    text: _isCustom(widget.settings)
        ? ChatFonts.normalize(widget.settings.chatFontFamily)
        : '',
  );
  late bool _showCustomFont = _isCustom(widget.settings);
  bool _invalidFont = false;

  static bool _isCustom(SettingsModel s) =>
      s.chatFontInstalledOnly ||
      ![...ChatFonts.windows, ...ChatFonts.google]
          .contains(ChatFonts.normalize(s.chatFontFamily));

  @override
  void didUpdateWidget(covariant _TextAndNamesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = widget.settings;
    final old = oldWidget.settings;
    if (old.chatFontFamily == s.chatFontFamily &&
        old.chatFontInstalledOnly == s.chatFontInstalledOnly) {
      return;
    }
    final custom = _isCustom(s);
    if (custom && ChatFonts.validate(_customFont.text) == s.chatFontFamily) {
      return;
    }
    _showCustomFont = custom;
    _invalidFont = false;
    _customFont.text = custom ? ChatFonts.normalize(s.chatFontFamily) : '';
  }

  @override
  void dispose() {
    _customFont.dispose();
    super.dispose();
  }

  void _selectFont(String? family) {
    if (family == null) return;
    setState(() {
      _showCustomFont = family == _otherFont;
      _invalidFont = false;
      if (!_showCustomFont) _customFont.clear();
    });
    if (!_showCustomFont) {
      widget.onChanged(widget.settings.copyWith(
        chatFontFamily: family,
        chatFontInstalledOnly: false,
      ));
    }
  }

  void _editCustomFont(String value) {
    final family = ChatFonts.validate(value);
    setState(() => _invalidFont = family == null);
    if (family != null) {
      widget.onChanged(widget.settings.copyWith(
        chatFontFamily: family,
        chatFontInstalledOnly: true,
      ));
    }
  }

  DropdownMenuItem<String> _fontOption(String family) => DropdownMenuItem(
        value: family,
        child: Text(
          family,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: family,
            fontFamilyFallback: const [ChatFonts.defaultFamily],
          ),
        ),
      );

  DropdownMenuItem<String> _fontGroup(String label) => DropdownMenuItem(
        enabled: false,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Future<void> _pickColor(AppLocalizations l) async {
    final color = await showDialog<String>(
      context: context,
      builder: (context) => _NameColorDialog(
        color: widget.settings.nameColorSingle,
        l: l,
      ),
    );
    if (color != null && mounted) {
      widget.onChanged(widget.settings.copyWith(nameColorSingle: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final l = AppLocalizations.of(context)!;
    final font = ChatFonts.normalize(s.chatFontFamily);
    final modeLabels = {
      NameColorMode.platform: l.nameColorPlatform,
      NameColorMode.platformThenGenerated: l.nameColorPlatformThenGenerated,
      NameColorMode.generated: l.nameColorGenerated,
      NameColorMode.single: l.nameColorSingle,
      NameColorMode.brand: l.nameColorBrand,
    };
    return UiCard(
      title: l.textAndNames,
      icon: Icons.text_fields_rounded,
      children: [
        settingsLabel(l.chatFontFamily),
        settingsDropdown<String>(
          key: const Key('font-family'),
          value: _showCustomFont ? _otherFont : font,
          menuMaxHeight: 360,
          items: [
            _fontGroup(l.chatFontWindows),
            ...ChatFonts.windows.map(_fontOption),
            _fontGroup(l.chatFontGoogle),
            ...ChatFonts.google.map(_fontOption),
            DropdownMenuItem(value: _otherFont, child: Text(l.chatFontOther)),
          ],
          onChanged: _selectFont,
        ),
        if (_showCustomFont) ...[
          const SizedBox(height: 6),
          TextField(
            key: const Key('font-family-custom'),
            controller: _customFont,
            onChanged: _editCustomFont,
            decoration: settingsInput(
              hint: l.chatFontOther,
              error: _invalidFont ? l.chatFontInvalid : null,
            ).copyWith(errorMaxLines: 3),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
        if (!_showCustomFont && ChatFonts.google.contains(font)) ...[
          const SizedBox(height: 6),
          Text(l.chatFontGoogleNote, style: settingsHintStyle),
        ],
        const SizedBox(height: 12),
        settingsLabel(l.nameColorMode),
        settingsDropdown<NameColorMode>(
          key: const Key('name-color-mode'),
          value: s.nameColorMode,
          items: [
            for (final entry in modeLabels.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (mode) {
            if (mode != null) widget.onChanged(s.copyWith(nameColorMode: mode));
          },
        ),
        if (s.nameColorMode == NameColorMode.single) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              style: secondarySettingsStyle(),
              onPressed: () => _pickColor(l),
              icon: _nameColorSwatch(s.nameColorSingle),
              label: Text(s.nameColorSingle),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _switchRow(l.nameRoleColors, s.nameRoleColors,
            (value) => widget.onChanged(s.copyWith(nameRoleColors: value))),
        _switchRow(l.nameReadability, s.nameReadability,
            (value) => widget.onChanged(s.copyWith(nameReadability: value))),
        const SizedBox(height: 8),
        Wrap(
          key: const Key('name-color-preview'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final sample in _samples)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    chatBubbleBackground(sample, s),
                    const Color(0xFF0D0D0D).withValues(alpha: s.bgOpacity),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlatformBadge(
                      platform: sample.platform,
                      mode: PlatformBadgeMode.inline,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        sample.author.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: resolveNameColor(sample, s),
                          fontSize: 13,
                          fontFamily: font,
                          fontFamilyFallback: const [ChatFonts.defaultFamily],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Widget _nameColorSwatch(String hex) {
  final color = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return Icon(Icons.circle, color: Color(0xFF000000 | (color ?? 0xFFFFFF)));
}

class _NameColorDialog extends StatefulWidget {
  const _NameColorDialog({required this.color, required this.l});

  final String color;
  final AppLocalizations l;

  @override
  State<_NameColorDialog> createState() => _NameColorDialogState();
}

class _NameColorDialogState extends State<_NameColorDialog> {
  late String _hex = widget.color;

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final color = SettingsInputNormalizer.hexColor(_hex, fallback: '');
    return AlertDialog(
      title: Text(l.nameColorSingle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              children: [
                for (final swatch in nameColorPalette)
                  IconButton(
                    tooltip: nameColorHex(swatch),
                    icon: _nameColorSwatch(nameColorHex(swatch)),
                    onPressed: () =>
                        Navigator.pop(context, nameColorHex(swatch)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: settingsLabel(l.nameColorHex),
            ),
            TextFormField(
              initialValue: _hex,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: settingsInput(hint: '#RRGGBB'),
              onChanged: (value) => setState(() => _hex = value),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: dialogSecondaryStyle(),
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          style: dialogPrimaryStyle(),
          onPressed: color.isEmpty ? null : () => Navigator.pop(context, color),
          child: Text(l.nameColorUse),
        ),
      ],
    );
  }
}
