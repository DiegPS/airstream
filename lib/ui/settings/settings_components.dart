part of 'package:airstream/ui/chat_screen.dart';

Widget _shortcutRow(String keys, String description) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Text(
            keys,
            style: const TextStyle(
              color: Color(0xFF53FC18),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _switchTileWithSubtitle(
  String title,
  String subtitle,
  bool value,
  ValueChanged<bool>? onChanged, {
  Color? activeThumbColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeThumbColor ?? const Color(0xFF53FC18),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    ),
  );
}

String _ttsEngineName(String engineId) => switch (engineId) {
      'supertonic-3-hybrid' => 'Supertonic',
      'piper' => 'Piper',
      'kitten-nano-en-v0-8-int8' => 'KittenTTS',
      'kokoro-en-v0-19-int8' => 'Kokoro',
      'matcha-ljspeech-en' => 'Matcha-TTS',
      'pocket-tts-int8' => 'Pocket TTS',
      'zipvoice-distill-int8-zh-en' => 'ZipVoice',
      _ => TtsModelCatalog.byId(engineId).name,
    };

String _ttsLanguageLabel(
  AppLocalizations l,
  String languageCode,
) {
  if (languageCode == 'es-MX') return l.spanishMexico;
  if (languageCode == 'es-ES') return l.spanishSpain;
  return _languageLabel(l, languageCode);
}

String _languageLabel(AppLocalizations l, String languageCode) =>
    switch (languageCode) {
      'ar' => l.languageArabic,
      'bg' => l.languageBulgarian,
      'zh' => l.languageChinese,
      'hr' => l.languageCroatian,
      'cs' => l.languageCzech,
      'da' => l.languageDanish,
      'nl' => l.languageDutch,
      'en' => l.english,
      'et' => l.languageEstonian,
      'fi' => l.languageFinnish,
      'fr' => l.languageFrench,
      'de' => l.languageGerman,
      'el' => l.languageGreek,
      'hi' => l.languageHindi,
      'hu' => l.languageHungarian,
      'id' => l.languageIndonesian,
      'it' => l.languageItalian,
      'ja' => l.languageJapanese,
      'ko' => l.languageKorean,
      'lv' => l.languageLatvian,
      'lt' => l.languageLithuanian,
      'pl' => l.languagePolish,
      'pt' => l.languagePortuguese,
      'ro' => l.languageRomanian,
      'ru' => l.languageRussian,
      'sk' => l.languageSlovak,
      'sl' => l.languageSlovenian,
      'es' => l.spanish,
      'sv' => l.languageSwedish,
      'tr' => l.languageTurkish,
      'uk' => l.languageUkrainian,
      'vi' => l.languageVietnamese,
      _ => languageCode.toUpperCase(),
    };

String _alignmentLabel(AppLocalizations l, String value) => switch (value) {
      'center' => l.alignmentCenter,
      'right' => l.alignmentRight,
      _ => l.alignmentLeft,
    };

String _animationLabel(AppLocalizations l, String value) => switch (value) {
      'slide-left' => l.animationSlideLeft,
      'fade-in' => l.animationFadeIn,
      'zoom-in' => l.animationZoomIn,
      _ => l.animationSlideUp,
    };

String _ttsModelDescription(AppLocalizations l, String modelId) =>
    switch (modelId) {
      'supertonic-3-hybrid' => l.ttsModelSupertonicDescription,
      'piper-es-mx-claude-high-int8' => l.ttsModelPiperMexicoDescription,
      'piper-es-es-davefx-medium-int8' => l.ttsModelPiperSpainDescription,
      'kitten-nano-en-v0-8-int8' => l.ttsModelKittenDescription,
      'kokoro-en-v0-19-int8' => l.ttsModelKokoroDescription,
      'matcha-ljspeech-en' => l.ttsModelMatchaDescription,
      'pocket-tts-int8' => l.ttsModelPocketDescription,
      'zipvoice-distill-int8-zh-en' => l.ttsModelZipVoiceDescription,
      _ => TtsModelCatalog.byId(modelId).name,
    };

String _ttsVoiceLabel(
  AppLocalizations l,
  TtsModelDefinition model,
  String voiceId,
) {
  final compactVoice = RegExp(r'^([FM])(\d)$').firstMatch(voiceId);
  if (compactVoice != null) {
    final number = compactVoice.group(2)!;
    final description = compactVoice.group(1) == 'F'
        ? l.femaleVoice(number)
        : l.maleVoice(number);
    return '$voiceId · $description';
  }
  final kittenVoice = RegExp(r'^(female|male)-(\d)$').firstMatch(voiceId);
  if (kittenVoice != null) {
    final number = kittenVoice.group(2)!;
    return kittenVoice.group(1) == 'female'
        ? l.femaleVoice(number)
        : l.maleVoice(number);
  }
  return switch (voiceId) {
    'claude' => 'Claude · ${l.male}',
    'davefx' => 'DaveFX · ${l.male}',
    'af' => '${l.defaultVoice} US · ${l.female}',
    'ljspeech' => 'LJSpeech · ${l.female}',
    'bria' => 'Bria · ${l.includedSample}',
    'news-female' => '${l.newsVoice} · ${l.includedSample}',
    'news-female-2' => '${l.newsVoiceNumber(2)} · ${l.includedSample}',
    'leijun' => 'Lei Jun · ${l.includedSample}',
    _ => model.voice(voiceId).label,
  };
}

String _ttsStatusDescription(
  AppLocalizations l,
  TtsLoadPhase phase,
) =>
    switch (phase) {
      TtsLoadPhase.ready => l.ttsStatusReadyDescription,
      TtsLoadPhase.checking => l.ttsStatusCheckingDescription,
      TtsLoadPhase.downloading => l.ttsStatusDownloadingDescription,
      TtsLoadPhase.loading => l.ttsStatusLoadingDescription,
      TtsLoadPhase.error => l.ttsStatusErrorDescription,
      TtsLoadPhase.idle => l.ttsStatusIdleDescription,
    };

String _captionStatusDescription(
  AppLocalizations l,
  LiveCaptionsPhase phase,
) =>
    switch (phase) {
      LiveCaptionsPhase.idle => l.captionStatusIdle,
      LiveCaptionsPhase.missingModel => l.captionStatusMissingModel,
      LiveCaptionsPhase.downloading => l.captionStatusDownloading,
      LiveCaptionsPhase.loading => l.captionStatusLoading,
      LiveCaptionsPhase.listening => l.captionStatusListening,
      LiveCaptionsPhase.transcribing => l.captionStatusTranscribing,
      LiveCaptionsPhase.error => l.captionStatusError,
    };

Widget _ttsStatusCard(
  AppLocalizations l,
  TtsLoadState state, {
  VoidCallback? onDownload,
}) {
  final model = TtsModelCatalog.byId(state.modelId);
  final (label, color) = switch (state.phase) {
    TtsLoadPhase.ready => (l.ready, const Color(0xFF53FC18)),
    TtsLoadPhase.checking => (l.checking, Colors.lightBlueAccent),
    TtsLoadPhase.downloading => (l.downloading, Colors.orangeAccent),
    TtsLoadPhase.loading => (l.loading, Colors.amber),
    TtsLoadPhase.error => (l.error, Colors.redAccent),
    TtsLoadPhase.idle => (l.voiceStatusNotDownloaded, Colors.white38),
  };

  final isDownloading = state.phase == TtsLoadPhase.downloading;
  final isLoading = state.phase == TtsLoadPhase.loading ||
      state.phase == TtsLoadPhase.checking;
  final isBusy = isDownloading || isLoading;

  final bytesText = state.totalBytes > 0
      ? '${_formatByteSize(state.loadedBytes)} / ${_formatByteSize(state.totalBytes)}'
      : null;
  final percentageText = state.progress != null
      ? '${((state.progress ?? 0) * 100).clamp(0, 100).toStringAsFixed(0)}%'
      : null;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.ttsModelStatusBadge(model.name, label),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (percentageText != null && isDownloading)
              Text(
                percentageText,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          _ttsStatusDescription(l, state.phase),
          maxLines: 2,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (isBusy) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: state.progress,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (bytesText != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                bytesText,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ],
        if (onDownload != null &&
            (state.phase == TtsLoadPhase.idle ||
                state.phase == TtsLoadPhase.error)) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text(l.downloadTtsModel),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF53FC18),
              side: const BorderSide(color: Color(0xFF3B6B2B)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _section(String t) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        t.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF53FC18),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

Widget _sidebarHeader({
  required String? youtubeValue,
  required String twitchValue,
  required String kickValue,
  required Map<String, (ServiceStatus, String?)> statusMap,
}) {
  final badges = <Widget>[
    if (youtubeValue != null && youtubeValue.trim().isNotEmpty)
      _platformStatusBadge(
        'YouTube',
        youtubeValue.trim(),
        statusMap['youtube']?.$1 ?? ServiceStatus.idle,
      ),
    if (twitchValue.trim().isNotEmpty)
      _platformStatusBadge(
        'Twitch',
        twitchValue.trim(),
        statusMap['twitch']?.$1 ?? ServiceStatus.idle,
      ),
    if (kickValue.trim().isNotEmpty)
      _platformStatusBadge(
        'Kick',
        kickValue.trim(),
        statusMap['kick']?.$1 ?? ServiceStatus.idle,
      ),
  ];

  if (badges.isEmpty) return const SizedBox.shrink();

  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: badges,
  );
}

Widget _platformStatusBadge(
  String platform,
  String value,
  ServiceStatus status,
) {
  final color = switch (status) {
    ServiceStatus.connected => const Color(0xFF53FC18),
    ServiceStatus.connecting => Colors.amber,
    ServiceStatus.error => const Color(0xFFFF6B6B),
    ServiceStatus.idle => Colors.white38,
  };

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1F1F1F),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF2C2C2C)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$platform: $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _switchRow(
  String label,
  bool value,
  ValueChanged<bool> onChanged,
) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );

Widget _dropdownRow(
  String label,
  String value,
  List<String> options,
  ValueChanged<String> onChanged, {
  String Function(String value)? optionLabel,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: options
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(optionLabel?.call(e) ?? e),
                          ))
                      .toList(),
                  selectedItemBuilder: (context) => options
                      .map((e) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              optionLabel?.call(e) ?? e,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

Widget _inlineErrorMessage(
  AppLocalizations l,
  String platform, {
  required VoidCallback onRetry,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFB3261E).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: Color(0xFFFF8A80),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l.platformConnectionFailed(platform),
            style: const TextStyle(
              color: Color(0xFFFFB4AB),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFFB4AB),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 28),
          ),
          child: Text(
            l.retryPlatform(platform),
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

Widget _statusMessage(
  String message, {
  required Color color,
  required IconData icon,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontSize: 11, height: 1.3),
          ),
        ),
      ],
    ),
  );
}

Widget _overlayUrlCard({
  required AppLocalizations l,
  required String title,
  required String overlayUrl,
  required String description,
  required VoidCallback onCopy,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF2C2C2C)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              height: 26,
              child: OutlinedButton.icon(
                onPressed: onCopy,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFACCBFF),
                  side: const BorderSide(color: Color(0xFF35527A)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.copy_rounded, size: 12),
                label: Text(
                  l.copy,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SelectableText(
          overlayUrl,
          style: const TextStyle(
            color: Color(0xFFACCBFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

Widget _alertTestButtons({
  required AppLocalizations l,
  required void Function(String kind) onTest,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF2C2C2C)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.testAlerts,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _alertTestButton(
              l.superChat,
              () => onTest('superchat'),
            ),
            _alertTestButton(
              l.noMessage,
              () => onTest('superchat-empty'),
            ),
            _alertTestButton(
              l.member,
              () => onTest('membership'),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _alertTestButton(String label, VoidCallback onPressed) {
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFACCBFF),
      side: const BorderSide(color: Color(0xFF35527A)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

Widget _obsHudGroupLabel(String label) {
  return Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );
}
