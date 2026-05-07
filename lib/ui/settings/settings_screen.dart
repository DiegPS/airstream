import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airchat_flutter/settings/settings_notifier.dart';
import 'package:airchat_flutter/services/supertonic_helper.dart' show availableLangs;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _ytHandle;
  late TextEditingController _ytLiveId;
  late TextEditingController _twitch;
  late TextEditingController _kick;
  late TextEditingController _kickId;
  late TextEditingController _port;
  late TextEditingController _ttsTestCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _ytHandle = TextEditingController(text: s.youtubeHandle);
    _ytLiveId = TextEditingController(text: s.youtubeLiveId);
    _twitch = TextEditingController(text: s.twitchChannel);
    _kick = TextEditingController(text: s.kickSlug)
      ..addListener(() => setState(() {}));
    _kickId = TextEditingController(
        text: s.kickChatroomId > 0 ? s.kickChatroomId.toString() : '');
    _port = TextEditingController(text: s.overlayPort.toString());
    _ttsTestCtrl = TextEditingController(text: 'Hola, probando sistema Text to Speech.');
  }

  @override
  void dispose() {
    _ytHandle.dispose();
    _ytLiveId.dispose();
    _twitch.dispose();
    _kick.dispose();
    _kickId.dispose();
    _port.dispose();
    _ttsTestCtrl.dispose();
    super.dispose();
  }

  Future<void> _openKickApi(String slug) async {
    final url = 'https://kick.com/api/v2/channels/$slug';
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else {
        await Process.run('xdg-open', [url]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abre manualmente: $url')),
        );
      }
    }
  }

  void _save() {
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    notifier.update(current.copyWith(
      youtubeHandle: _ytHandle.text.trim(),
      youtubeLiveId: _ytLiveId.text.trim(),
      twitchChannel: _twitch.text.trim(),
      kickSlug: _kick.text.trim(),
      kickChatroomId: int.tryParse(_kickId.text.trim()) ?? 0,
      overlayPort: int.tryParse(_port.text) ?? 8080,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

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
          _textField('YouTube handle (e.g. MrBeast)', _ytHandle,
              prefix: '@'),
          _textField('YouTube live ID (optional)', _ytLiveId),
          _textField('Twitch channel', _twitch),
          _textField('Kick slug', _kick),
          _textField(
            'Kick chatroom ID (directo, sin HTTP lookup)',
            _kickId,
            keyboardType: TextInputType.number,
          ),
          if (_kick.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Si el slug no funciona (403 Cloudflare), abre la URL de abajo en un browser, busca "chatroom":{"id": NÚMERO} y pégalo arriba.',
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openKickApi(_kick.text.trim()),
                    child: const Text(
                      'Abrir API',
                      style:
                          TextStyle(color: Color(0xFF53FC18), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

          _section('Overlay Server'),
          Row(children: [
            Expanded(child: _textField('Port', _port, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Column(children: [
              const Text('Enabled', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: s.overlayEnabled,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayEnabled: v)),
                // ignore: deprecated_member_use
        activeColor: const Color(0xFF53FC18),
              ),
            ]),
          ]),

          _section('Appearance'),
          _sliderTile('Font size', s.fontSize, 10, 28, (v) {
            notifier.update(s.copyWith(fontSize: v));
          }),
          _sliderTile('Background opacity', s.bgOpacity, 0, 1, (v) {
            notifier.update(s.copyWith(bgOpacity: v));
          }),
          _sliderTile('Message opacity', s.messageOpacity, 0, 1, (v) {
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

          _section('TTS'),
          _switchTile('Enable TTS', s.ttsEnabled,
              (v) => notifier.update(s.copyWith(ttsEnabled: v))),
          _switchTile('Members only', s.ttsMembersOnly,
              (v) => notifier.update(s.copyWith(ttsMembersOnly: v))),
          _switchTile('Command Mode (!voz)', s.ttsCommandMode,
              (v) => notifier.update(s.copyWith(ttsCommandMode: v))),

          if (s.ttsCommandMode)
            _textField('Command Prefix',
                TextEditingController(text: s.ttsCommandPrefix)
                  ..addListener((() {
                    // We don't save on every keystroke, use a debounce or save on unfocus normally.
                    // For simplicity in this port, we let the Save button handle text fields.
                  })),
                onChanged: (v) => notifier.update(s.copyWith(ttsCommandPrefix: v))),
          
          _textField('Separator Text (e.g "says")',
              TextEditingController(text: s.ttsSeparatorText),
              onChanged: (v) => notifier.update(s.copyWith(ttsSeparatorText: v))),
          
          _dropdownTile('Voice', s.ttsVoice, 
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final appController = ref.read(appControllerProvider);
                    appController.testTts(_ttsTestCtrl.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF53FC18),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Probar'),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  static Widget _dropdownTile(
          String title, String value, List<String> options, ValueChanged<String> onChanged) =>
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
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      );

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
}
