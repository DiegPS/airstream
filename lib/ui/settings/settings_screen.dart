import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airchat_flutter/settings/settings_model.dart';
import 'package:airchat_flutter/settings/settings_notifier.dart';
import 'package:airchat_flutter/services/supertonic_helper.dart'
    show availableLangs;
import 'package:airchat_flutter/window/window_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
  static String _youtubeInputValue(SettingsModel s) {
    final liveId = s.youtubeLiveId.trim();
    if (liveId.isNotEmpty) return liveId;
    return s.youtubeHandle;
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _ytHandle;
  late TextEditingController _twitch;
  late TextEditingController _kick;
  late TextEditingController _port;
  late TextEditingController _ttsTestCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _ytHandle =
        TextEditingController(text: SettingsScreen._youtubeInputValue(s));
    _twitch = TextEditingController(text: s.twitchChannel);
    _kick = TextEditingController(text: s.kickSlug)
      ..addListener(() => setState(() {}));
    _port = TextEditingController(text: s.overlayPort.toString());
    _ttsTestCtrl =
        TextEditingController(text: 'Hola, probando sistema Text to Speech.');
  }

  @override
  void dispose() {
    _ytHandle.dispose();
    _twitch.dispose();
    _kick.dispose();
    _port.dispose();
    _ttsTestCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    notifier.update(current.copyWith(
      youtubeHandle: _ytHandle.text.trim(),
      youtubeLiveId: '',
      twitchChannel: _twitch.text.trim(),
      kickSlug: _kick.text.trim(),
      overlayPort: int.tryParse(_port.text) ?? 8080,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final ttsLoadState = ref.watch(ttsLoadStateProvider).valueOrNull;
    final ttsBusy = ref.watch(ttsBusyProvider).valueOrNull ?? false;

    // Window state is a separate provider — decoupled from overlay settings.
    final win = ref.watch(windowStateProvider);
    final winNotifier = ref.read(windowStateProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF53FC18))),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Connections'),
          _textField(
            'YouTube handle, channel ID, video ID, or URL',
            _ytHandle,
          ),
          _textField('Twitch channel', _twitch),
          _textField('Kick slug', _kick),
          _section('Overlay Server'),
          Row(children: [
            Expanded(
                child: _textField('Port', _port,
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Column(children: [
              const Text('Enabled',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: s.overlayEnabled,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayEnabled: v)),
                // ignore: deprecated_member_use
                activeColor: const Color(0xFF53FC18),
              ),
            ]),
          ]),

          _section('Window (Windows)'),
          _switchTileWithSubtitle(
            'Frameless',
            'Sin barra de título, sin bordes, sin sombra DWM — igual a Wails DisableFramelessWindowDecorations',
            win.frameless,
            (v) => winNotifier.setFrameless(v),
          ),
          _switchTileWithSubtitle(
            'Click-Through',
            'Los clics pasan a través de la ventana (WS_EX_TRANSPARENT)',
            win.clickThrough,
            (v) => winNotifier.setClickThrough(v),
            activeColor: const Color(0xFFFF6B35),
          ),
          _switchTileWithSubtitle(
            'Always on Top',
            'La ventana se mantiene sobre todas las demás',
            win.alwaysOnTop,
            (v) => winNotifier.setAlwaysOnTop(v),
          ),
          if (win.clickThrough)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFFF6B35)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Click-through activo — desactívalo desde la barra superior antes de intentar interactuar con esta ventana.',
                      style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

          // ── Visual Effects (flutter_acrylic) ─────────────────────────────────
          _section('Appearance'),
          _sliderTile('Font size', s.fontSize, 10, 28, (v) {
            notifier.update(s.copyWith(fontSize: v));
          }),
          _sliderTile('Background opacity', s.bgOpacity, 0, 1, (v) {
            notifier.update(s.copyWith(bgOpacity: v));
          }),
          _sliderTile('Bubble opacity', s.messageOpacity, 0, 1, (v) {
            notifier.update(s.copyWith(messageOpacity: v));
          }),
          _sliderTile('Border radius', s.borderRadius, 0, 24, (v) {
            notifier.update(s.copyWith(borderRadius: v));
          }),
          _sliderTile('Message gap', s.messageGap, 0, 16, (v) {
            notifier.update(s.copyWith(messageGap: v));
          }),
          _switchTile('Show avatars', s.showAvatars,
              (v) => notifier.update(s.copyWith(showAvatars: v))),
          _switchTile('Show badges', s.showBadges,
              (v) => notifier.update(s.copyWith(showBadges: v))),
          _switchTile('Show timestamp', s.showTimestamp,
              (v) => notifier.update(s.copyWith(showTimestamp: v))),
          _switchTile('Show message bubble', s.showBubble,
              (v) => notifier.update(s.copyWith(showBubble: v))),
          _switchTile('Show bubble shadow', s.showBubbleShadow,
              (v) => notifier.update(s.copyWith(showBubbleShadow: v))),

          _section('TTS'),
          _switchTile('Enable TTS', s.ttsEnabled,
              (v) => notifier.update(s.copyWith(ttsEnabled: v))),
          _switchTile('Members only', s.ttsMembersOnly,
              (v) => notifier.update(s.copyWith(ttsMembersOnly: v))),
          _switchTile('Command Mode (!voz)', s.ttsCommandMode,
              (v) => notifier.update(s.copyWith(ttsCommandMode: v))),

          if (s.ttsCommandMode)
            _textField(
                'Command Prefix',
                TextEditingController(text: s.ttsCommandPrefix)
                  ..addListener((() {
                    // We don't save on every keystroke, use a debounce or save on unfocus normally.
                    // For simplicity in this port, we let the Save button handle text fields.
                  })),
                onChanged: (v) =>
                    notifier.update(s.copyWith(ttsCommandPrefix: v))),

          _textField('Separator Text (e.g "says")',
              TextEditingController(text: s.ttsSeparatorText),
              onChanged: (v) =>
                  notifier.update(s.copyWith(ttsSeparatorText: v))),

          _dropdownTile(
              'Voice',
              s.ttsVoice,
              ['M1', 'M2', 'M3', 'M4', 'M5', 'F1', 'F2', 'F3', 'F4', 'F5'],
              (v) => notifier.update(s.copyWith(ttsVoice: v))),

          _dropdownTile('Language', s.ttsLanguage, availableLangs,
              (v) => notifier.update(s.copyWith(ttsLanguage: v))),

          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ttsTestCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Test text',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (ttsBusy || (ttsLoadState?.isLoading ?? false))
                      ? null
                      : () {
                          final appController = ref.read(appControllerProvider);
                          appController.testTts(_ttsTestCtrl.text);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF53FC18),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: Text(
                    ttsBusy
                        ? 'Reproduciendo...'
                        : (ttsLoadState?.isLoading ?? false)
                            ? 'Cargando...'
                            : 'Probar',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF53FC18),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  static Widget _textField(
    String label,
    TextEditingController ctrl, {
    String? prefix,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            prefixText: prefix,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      );

  static Widget _sliderTile(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                // ignore: deprecated_member_use
                activeColor: const Color(0xFF53FC18),
                inactiveColor: const Color(0xFF3A3A3A),
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                value.toStringAsFixed(value < 2 ? 2 : 0),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

  static Widget _dropdownTile(String title, String value, List<String> options,
          ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1E1E1E),
              items: options
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(_ttsOptionLabel(title, e)),
                      ))
                  .toList(),
              selectedItemBuilder: (context) => options
                  .map((e) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _ttsOptionLabel(title, e),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      );

  static String _ttsOptionLabel(String field, String value) {
    return switch (field) {
      'Voice' => _voiceLabel(value),
      'Language' => _languageLabel(value),
      _ => value,
    };
  }

  static String _voiceLabel(String value) {
    final match = RegExp(r'^([MF])(\d+)$').firstMatch(value.trim());
    if (match == null) return value;
    final prefix = match.group(1) == 'F' ? 'Female' : 'Male';
    return '$prefix ${match.group(2)}';
  }

  static String _languageLabel(String value) {
    const labels = {
      'en': 'English',
      'ko': 'Korean',
      'ja': 'Japanese',
      'ar': 'Arabic',
      'bg': 'Bulgarian',
      'cs': 'Czech',
      'da': 'Danish',
      'de': 'German',
      'el': 'Greek',
      'es': 'Spanish',
      'et': 'Estonian',
      'fi': 'Finnish',
      'fr': 'French',
      'hi': 'Hindi',
      'hr': 'Croatian',
      'hu': 'Hungarian',
      'id': 'Indonesian',
      'it': 'Italian',
      'lt': 'Lithuanian',
      'lv': 'Latvian',
      'nl': 'Dutch',
      'pl': 'Polish',
      'pt': 'Portuguese',
      'ro': 'Romanian',
      'ru': 'Russian',
      'sk': 'Slovak',
      'sl': 'Slovenian',
      'sv': 'Swedish',
      'tr': 'Turkish',
      'uk': 'Ukrainian',
      'vi': 'Vietnamese',
    };
    return labels[value] ?? value.toUpperCase();
  }

  static Widget _switchTile(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      SwitchListTile(
        title: Text(label, style: const TextStyle(color: Colors.white70)),
        value: value,
        onChanged: onChanged,
        // ignore: deprecated_member_use
        activeColor: const Color(0xFF53FC18),
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
  static Widget _switchTileWithSubtitle(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    Color activeColor = const Color(0xFF53FC18),
  }) =>
      SwitchListTile(
        title: Text(label, style: const TextStyle(color: Colors.white70)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        value: value,
        onChanged: onChanged,
        // ignore: deprecated_member_use
        activeColor: activeColor,
        contentPadding: EdgeInsets.zero,
        dense: true,
      );

  // ── flutter_acrylic effect selector ────────────────────────────────────────
}
