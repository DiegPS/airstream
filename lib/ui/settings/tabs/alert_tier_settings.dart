part of '../../chat_screen.dart';

class _AlertTierSettings extends StatefulWidget {
  const _AlertTierSettings({
    required this.type,
    required this.settings,
    required this.onChanged,
  });

  final String type;
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onChanged;

  @override
  State<_AlertTierSettings> createState() => _AlertTierSettingsState();
}

class _AlertTierSettingsState extends State<_AlertTierSettings> {
  int _revision = 0;

  List<Map<String, dynamic>> get _tiers => AlertTypeOptions.tiers(
      AlertTypeOptions.sanitize(widget.settings.alertTypeOptions)[widget.type]);

  void _save(List<Map<String, dynamic>> tiers) {
    widget.onChanged(AlertTypeOptions.withTiers(
      widget.settings,
      widget.type,
      tiers,
    ));
  }

  void _update(int index, Map<String, Object?> changes) {
    final tiers = _tiers.toList();
    if (index >= tiers.length) return;
    final option = {...tiers[index], ...changes}
      ..removeWhere((key, value) => value == null);
    tiers[index] = option;
    _save(tiers);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tiers = _tiers;
    final library = MediaLibraryEntries.sanitize(widget.settings.mediaLibrary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        _section(l.alertTiers),
        if (widget.type == 'superchat') Text(l.alertTierCurrency),
        for (final (index, tier) in tiers.indexed) ...[
          const Divider(),
          _AlertTierRow(
            key: ValueKey((_revision, index)),
            type: widget.type,
            index: index,
            tier: tier,
            library: library,
            inheritedMedia:
                AlertTypeOptions.of(widget.settings, widget.type).media,
            onChanged: (changes) => _update(index, changes),
            onRemove: () {
              setState(() => _revision++);
              _save(tiers.toList()..removeAt(index));
            },
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: Key('add-alert-tier-${widget.type}'),
            onPressed: tiers.length == AlertTypeOptions.maxTiers
                ? null
                : () {
                    final max = tiers.fold<num>(
                        0,
                        (max, tier) => (tier['from'] as num) > max
                            ? tier['from'] as num
                            : max);
                    _save([
                      ...tiers,
                      {'from': max + 1}
                    ]);
                  },
            icon: const Icon(Icons.add_rounded),
            label: Text(l.alertTierAdd),
          ),
        ),
      ],
    );
  }
}

class _AlertTierRow extends StatefulWidget {
  const _AlertTierRow({
    super.key,
    required this.type,
    required this.index,
    required this.tier,
    required this.library,
    required this.inheritedMedia,
    required this.onChanged,
    required this.onRemove,
  });

  final String type;
  final int index;
  final Map<String, dynamic> tier;
  final Map<String, Map<String, dynamic>> library;
  final String inheritedMedia;
  final ValueChanged<Map<String, Object?>> onChanged;
  final VoidCallback onRemove;

  @override
  State<_AlertTierRow> createState() => _AlertTierRowState();
}

class _AlertTierRowState extends State<_AlertTierRow> {
  bool _invalidSound = false;
  late final _threshold = TextEditingController(text: '${widget.tier['from']}');
  final _thresholdFocus = FocusNode();

  @override
  void didUpdateWidget(_AlertTierRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_thresholdFocus.hasFocus &&
        oldWidget.tier['from'] != widget.tier['from']) {
      _threshold.text = '${widget.tier['from']}';
    }
  }

  @override
  void dispose() {
    _threshold.dispose();
    _thresholdFocus.dispose();
    super.dispose();
  }

  num? _amount(String value) {
    final amount = num.tryParse(value.trim().replaceAll(',', '.'));
    return amount != null && amount.isFinite && amount > 0 ? amount : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tier = widget.tier;
    final library = widget.library;
    final visuals = library.keys.where((id) => library[id]!['kind'] != 'audio');
    final audio = library.keys.where((id) => library[id]!['kind'] == 'audio');
    final sound =
        tier['sound'] == 'library' ? tier['soundMediaId'] : tier['sound'];
    final media =
        visuals.contains(tier['media']) ? tier['media'] as String : '';
    final soundOptions = ['', 'chime', 'coin', 'fanfare', 'custom', ...audio];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        settingsLabel(l.alertTierFrom),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: Key('alert-tier-from-${widget.type}-${widget.index}'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: settingsInput(),
                controller: _threshold,
                focusNode: _thresholdFocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) =>
                    _amount(v ?? '') == null ? l.alertTierInvalid : null,
                onChanged: (v) {
                  final amount = _amount(v);
                  if (amount != null) widget.onChanged({'from': amount});
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: l.alertTierRemove,
              onPressed: widget.onRemove,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  size: 20, color: Color(0xFFFF6B6B)),
            ),
          ],
        ),
        _dropdownRow(
          l.alertSound,
          soundOptions.contains(sound) ? sound as String : '',
          soundOptions,
          (v) {
            setState(() => _invalidSound = false);
            widget.onChanged({
              'sound': v.isEmpty
                  ? null
                  : audio.contains(v)
                      ? 'library'
                      : v,
              'soundMediaId': audio.contains(v) ? v : null,
              if (v != 'custom') 'soundPath': null,
            });
          },
          optionLabel: (v) =>
              library[v]?['name'] as String? ??
              {
                '': l.alertTierInherit,
                'chime': l.alertSoundChime,
                'coin': l.alertSoundCoin,
                'fanfare': l.alertSoundFanfare,
                'custom': l.alertSoundCustom,
              }[v]!,
        ),
        if (sound == 'custom') ...[
          Row(children: [
            Expanded(
                child: Text(
              tier['soundPath'] == null
                  ? l.alertSoundNoFile
                  : p.basename(tier['soundPath'] as String),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
            TextButton(
              onPressed: () async {
                final picked = await openFile(acceptedTypeGroups: const [
                  XTypeGroup(label: 'Audio', extensions: ['wav', 'mp3', 'ogg']),
                ]);
                if (!mounted || picked == null) return;
                final valid = picked.path.length <= 1024 &&
                    AlertSounds.customFile(picked.path) != null;
                setState(() => _invalidSound = !valid);
                if (valid) widget.onChanged({'soundPath': picked.path});
              },
              child: Text(l.alertSoundChoose),
            ),
          ]),
          if (_invalidSound) Text(l.alertSoundInvalid),
        ],
        _dropdownRow(
          l.alertMedia,
          media,
          ['', ...visuals],
          (v) => widget.onChanged({'media': v.isEmpty ? null : v}),
          optionLabel: (v) =>
              library[v]?['name'] as String? ?? l.alertTierInherit,
        ),
        if (library[media.isEmpty ? widget.inheritedMedia : media]?['kind'] ==
            'video')
          _dropdownRow(
            l.alertMediaAudio,
            tier['mediaAudio']?.toString() ?? '',
            const ['', 'true', 'false'],
            (v) => widget
                .onChanged({'mediaAudio': v.isEmpty ? null : v == 'true'}),
            optionLabel: (v) => {
              '': l.alertTierInherit,
              'true': l.alertTierAudioOn,
              'false': l.alertTierAudioOff,
            }[v]!,
          ),
        _dropdownRow(
          l.alertDuration,
          tier['seconds']?.toString() ?? '',
          ['', for (var seconds = 3; seconds <= 20; seconds++) '$seconds'],
          (v) => widget.onChanged({'seconds': int.tryParse(v)}),
          optionLabel: (v) => v.isEmpty ? l.alertTierInherit : '$v s',
        ),
        _dropdownRow(
          l.alertEntrance,
          tier['animation'] as String? ?? '',
          const ['', 'pop', 'slide-up', 'slide-down', 'fade', 'zoom'],
          (v) => widget.onChanged({'animation': v.isEmpty ? null : v}),
          optionLabel: (v) => {
            '': l.alertTierInherit,
            'pop': l.alertAnimationPop,
            'slide-up': l.alertAnimationSlideUp,
            'slide-down': l.alertAnimationSlideDown,
            'fade': l.alertAnimationFade,
            'zoom': l.alertAnimationZoom,
          }[v]!,
        ),
      ],
    );
  }
}
