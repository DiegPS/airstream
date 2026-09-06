part of 'package:airstream/ui/chat_screen.dart';

extension _AudioSettingsTabBuilder on _SettingsSidebarState {
  Widget _buildAudioTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
    AppController appController,
    TtsLoadState? ttsLoadState,
    bool ttsBusy,
    LiveCaptionsState captionsState,
    String captionsCopyUrl,
    bool overlayReady,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.ttsCardTitle,
          icon: Icons.record_voice_over_rounded,
          description: l.ttsDescription,
          trailing: Switch(
            value: s.ttsEnabled,
            onChanged: (v) => notifier.update(s.copyWith(ttsEnabled: v)),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.ttsEnabled) ...[
              if (ttsLoadState != null) ...[
                _ttsStatusCard(
                  l,
                  ttsLoadState,
                  onDownload: () async {
                    try {
                      await appController.downloadTtsModel();
                    } catch (_) {
                      // TtsService logs the failure and publishes an error
                      // load state for this card to render.
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
              Builder(builder: (context) {
                final model = TtsModelCatalog.byId(s.ttsModelId);
                final engineId =
                    model.family == TtsModelFamily.vits ? 'piper' : model.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dropdownRow(
                      l.ttsSelectedModel,
                      engineId,
                      const [
                        'supertonic-3-hybrid',
                        'piper',
                        'kitten-nano-en-v0-8-int8',
                        'kokoro-en-v0-19-int8',
                        'matcha-ljspeech-en',
                        'pocket-tts-int8',
                        'zipvoice-distill-int8-zh-en',
                      ],
                      (id) {
                        final next = id == 'piper'
                            ? (s.ttsLanguage == 'es-ES'
                                ? TtsModelCatalog.piperSpain
                                : TtsModelCatalog.piperMexico)
                            : TtsModelCatalog.byId(id);
                        notifier.update(s.copyWith(
                          ttsModelId: next.id,
                          ttsVoice: next.voices.first.id,
                          ttsLanguage: next.languages.first.code,
                          ttsSteps: next.defaultSteps,
                        ));
                      },
                      optionLabel: _ttsEngineName,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text(
                        _ttsModelDescription(l, model.id),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        l.ttsModelStorageDetails(
                          _formatByteSize(model.downloadBytes),
                          _formatByteSize(model.installedBytes),
                        ),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (model.licenseNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          model.licenseNotice!,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                );
              }),
              if (ttsLoadState?.isReady ?? false) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _removeSelectedTtsModel(
                      context: context,
                      l: l,
                      settings: s,
                      notifier: notifier,
                      appController: appController,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: Text(l.removeTtsModel),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Builder(builder: (context) {
                final model = TtsModelCatalog.byId(s.ttsModelId);
                final voice = model.voice(s.ttsVoice).id;
                final languageOptions = model.family == TtsModelFamily.vits
                    ? const ['es-MX', 'es-ES']
                    : model.languages.map((item) => item.code).toList();
                final language = model.family == TtsModelFamily.vits
                    ? (model.id == TtsModelCatalog.piperSpain.id
                        ? 'es-ES'
                        : 'es-MX')
                    : (model.supportsLanguage(s.ttsLanguage)
                        ? s.ttsLanguage
                        : model.languages.first.code);

                return Column(
                  children: [
                    _dropdownRow(
                      l.voice,
                      voice,
                      model.voices.map((v) => v.id).toList(),
                      (v) => notifier.update(s.copyWith(ttsVoice: v)),
                      optionLabel: (id) => _ttsVoiceLabel(l, model, id),
                    ),
                    _dropdownRow(
                      l.language,
                      language,
                      languageOptions,
                      (value) {
                        if (model.family != TtsModelFamily.vits) {
                          notifier.update(s.copyWith(ttsLanguage: value));
                          return;
                        }
                        final next = value == 'es-ES'
                            ? TtsModelCatalog.piperSpain
                            : TtsModelCatalog.piperMexico;
                        notifier.update(s.copyWith(
                          ttsModelId: next.id,
                          ttsVoice: next.voices.first.id,
                          ttsLanguage: value,
                          ttsSteps: next.defaultSteps,
                        ));
                      },
                      optionLabel: (id) => _ttsLanguageLabel(l, id),
                    ),
                    if (model.referenceMode != TtsReferenceMode.none) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.ttsReferenceAudioPath.isEmpty
                                  ? l.usingBundledVoice(
                                      _ttsVoiceLabel(l, model, voice))
                                  : p.basename(s.ttsReferenceAudioPath),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final selected = await openFile(
                                acceptedTypeGroups: const [
                                  XTypeGroup(
                                    label: 'WAV',
                                    extensions: ['wav'],
                                  ),
                                ],
                              );
                              if (selected == null || !context.mounted) return;
                              await notifier.update(s.copyWith(
                                ttsReferenceAudioPath: selected.path,
                              ));
                            },
                            icon:
                                const Icon(Icons.audio_file_rounded, size: 15),
                            label: Text(l.chooseWav),
                          ),
                          if (s.ttsReferenceAudioPath.isNotEmpty)
                            IconButton(
                              tooltip: l.useBundledSample,
                              onPressed: () => notifier.update(s.copyWith(
                                ttsReferenceAudioPath: '',
                                ttsReferenceText: '',
                              )),
                              icon: const Icon(Icons.close_rounded, size: 16),
                            ),
                        ],
                      ),
                      if (model.needsReferenceText &&
                          s.ttsReferenceAudioPath.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _label(l.referenceTranscript),
                        _field(
                          _form.ttsReferenceText,
                          l.referenceTranscriptHint,
                          focusNode: _form.ttsReferenceTextFocus,
                          onChanged: (_) => _queueTextSettingsSave(),
                          onSubmitted: (_) => _saveTextSettings(),
                        ),
                      ],
                    ],
                    if (model.family == TtsModelFamily.supertonic ||
                        model.family == TtsModelFamily.zipvoice ||
                        model.family == TtsModelFamily.pocket)
                      _dropdownRow(
                        l.quality,
                        const [3, 4, 5, 6, 8, 12].contains(s.ttsSteps)
                            ? s.ttsSteps.toString()
                            : model.defaultSteps.toString(),
                        const ['3', '4', '5', '6', '8', '12'],
                        (v) =>
                            notifier.update(s.copyWith(ttsSteps: int.parse(v))),
                        optionLabel: (v) => l.ttsInferenceSteps(int.parse(v)),
                      ),
                    StyledSliderRow(
                      label: l.speed,
                      value: s.ttsSpeed,
                      min: 0.6,
                      max: 1.6,
                      divisions: 20,
                      unit: 'x',
                      onChanged: (v) =>
                          notifier.update(s.copyWith(ttsSpeed: v)),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              _label(l.testText),
              _field(_form.ttsTest, l.ttsTestTextHint),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (ttsBusy || (ttsLoadState?.isLoading ?? false))
                      ? null
                      : () => appController.testTts(
                            _form.ttsTest.text.trim().isEmpty
                                ? l.ttsDefaultTestText
                                : _form.ttsTest.text,
                          ),
                  icon: const Icon(Icons.volume_up_rounded, size: 16),
                  label: Text(
                    ttsBusy
                        ? l.playingTts
                        : (ttsLoadState?.isLoading ?? false)
                            ? l.loadingTts
                            : l.testTts,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF53FC18),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _switchRow(
                l.membersOnly,
                s.ttsMembersOnly,
                (v) => notifier.update(s.copyWith(ttsMembersOnly: v)),
              ),
              _switchRow(
                l.commandMode,
                s.ttsCommandMode,
                (v) => notifier.update(s.copyWith(ttsCommandMode: v)),
              ),
              if (s.ttsCommandMode) ...[
                const SizedBox(height: 8),
                _label(l.commandPrefix),
                _field(
                  _form.ttsPrefix,
                  l.commandPrefixHint,
                  focusNode: _form.ttsPrefixFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
                _switchRow(
                  l.ignoreCommandCase,
                  s.ttsCommandIgnoreCase,
                  (v) => notifier.update(s.copyWith(ttsCommandIgnoreCase: v)),
                ),
              ],
              const SizedBox(height: 8),
              _label(l.separatorText),
              _field(
                _form.ttsSeparator,
                l.separatorTextHint,
                focusNode: _form.ttsSeparatorFocus,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
            ] else ...[
              Text(
                l.ttsDisabledHelp,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        UiCard(
          title: l.localCaptions,
          icon: Icons.subtitles_rounded,
          description: l.captionsDescription,
          trailing: Switch(
            value: s.liveCaptionsEnabled,
            onChanged: (v) => unawaited(notifier.update(
              s.copyWith(liveCaptionsEnabled: v),
            )),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.liveCaptionsEnabled) ...[
              Builder(builder: (context) {
                final model = SpeechModelCatalog.byId(s.liveCaptionsModelId);
                final source =
                    model.supportsLanguage(s.liveCaptionsSourceLanguage)
                        ? s.liveCaptionsSourceLanguage
                        : 'es';
                final targets = model.targetsFor(source);

                return Column(
                  children: [
                    _dropdownRow(
                      l.spokenLanguage,
                      source,
                      model.languages.map((item) => item.code).toList(),
                      (value) => notifier.update(s.copyWith(
                        liveCaptionsSourceLanguage: value,
                        liveCaptionsTargetLanguage: value,
                      )),
                      optionLabel: (value) => _languageLabel(l, value),
                    ),
                    _dropdownRow(
                      l.captionOutput,
                      model.supportsDirection(
                              source, s.liveCaptionsTargetLanguage)
                          ? s.liveCaptionsTargetLanguage
                          : source,
                      targets.map((item) => item.code).toList(),
                      (value) => notifier.update(s.copyWith(
                        liveCaptionsTargetLanguage: value,
                      )),
                      optionLabel: (value) => _languageLabel(l, value),
                    ),
                  ],
                );
              }),
              _switchRow(
                l.sendCaptionsToObs,
                s.liveCaptionsOverlayEnabled,
                (value) => notifier.update(
                  s.copyWith(liveCaptionsOverlayEnabled: value),
                ),
              ),
              _switchRow(
                l.noiseReduction,
                s.liveCaptionsDenoiseEnabled,
                (value) => notifier.update(
                  s.copyWith(liveCaptionsDenoiseEnabled: value),
                ),
              ),
              _switchRow(
                l.voiceCommandsObs,
                s.voiceCommandsEnabled,
                (value) => notifier.update(
                  s.copyWith(voiceCommandsEnabled: value),
                ),
              ),
              if (s.voiceCommandsEnabled) ...[
                const SizedBox(height: 6),
                _label(l.wakeWord),
                _field(
                  _form.voiceWakeWord,
                  'airstream',
                  focusNode: _form.voiceWakeWordFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
                const SizedBox(height: 4),
                Text(
                  l.voiceCommandsExamples,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _captionStatusDescription(l, captionsState.phase),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    if (captionsState.caption.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        captionsState.caption,
                        style: const TextStyle(
                          color: Color(0xFF53FC18),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (captionsState.progress case final progress?) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF333333),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF53FC18),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (captionsState.phase == LiveCaptionsPhase.missingModel ||
                  captionsState.phase == LiveCaptionsPhase.error) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: captionsState.phase ==
                            LiveCaptionsPhase.downloading
                        ? null
                        : () async {
                            try {
                              await appController.downloadLiveCaptionsModel();
                            } catch (error, stack) {
                              AppLogger.error(
                                'Caption model download failed',
                                error: error,
                                stackTrace: stack,
                              );
                            }
                          },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      '${l.downloadCaptionModel} (${_formatByteSize(SpeechModelCatalog.canary.package.downloadBytes)})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF53FC18),
                      side: const BorderSide(color: Color(0xFF53FC18)),
                    ),
                  ),
                ),
              ],
              if (s.liveCaptionsOverlayEnabled && overlayReady) ...[
                const SizedBox(height: 8),
                _overlayUrlCard(
                  l: l,
                  title: l.obsCaptions,
                  overlayUrl: captionsCopyUrl,
                  description: l.obsCaptionsDescription,
                  onCopy: () => Clipboard.setData(
                    ClipboardData(text: captionsCopyUrl),
                  ),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }
}
