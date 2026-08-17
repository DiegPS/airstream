enum TtsModelFamily { supertonic, piper }

class TtsVoiceOption {
  final String id;
  final String label;
  final int speakerId;

  const TtsVoiceOption(this.id, this.label, this.speakerId);
}

class TtsLanguageOption {
  final String code;
  final String label;

  const TtsLanguageOption(this.code, this.label);
}

class TtsModelDefinition {
  final String id;
  final String version;
  final String name;
  final String description;
  final TtsModelFamily family;
  final Uri archiveUri;
  final int archiveBytes;
  final int installedBytes;
  final String sha256;
  final String archiveRoot;
  final List<String> requiredFiles;
  final List<TtsLanguageOption> languages;
  final List<TtsVoiceOption> voices;
  final String licenseName;
  final Uri licenseUri;

  const TtsModelDefinition({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.family,
    required this.archiveUri,
    required this.archiveBytes,
    required this.installedBytes,
    required this.sha256,
    required this.archiveRoot,
    required this.requiredFiles,
    required this.languages,
    required this.voices,
    required this.licenseName,
    required this.licenseUri,
  });

  String get storageKey => '$id-$version';

  bool supportsLanguage(String code) =>
      languages.any((language) => language.code == code);

  TtsVoiceOption voice(String id) => voices.firstWhere(
        (voice) => voice.id == id,
        orElse: () => voices.first,
      );
}

const _supertonicLanguages = <TtsLanguageOption>[
  TtsLanguageOption('en', 'English'),
  TtsLanguageOption('ko', '한국어'),
  TtsLanguageOption('es', 'Español'),
  TtsLanguageOption('pt', 'Português'),
  TtsLanguageOption('fr', 'Français'),
  TtsLanguageOption('de', 'Deutsch'),
  TtsLanguageOption('zh', '中文'),
  TtsLanguageOption('ja', '日本語'),
  TtsLanguageOption('ru', 'Русский'),
  TtsLanguageOption('ar', 'العربية'),
  TtsLanguageOption('it', 'Italiano'),
  TtsLanguageOption('nl', 'Nederlands'),
  TtsLanguageOption('pl', 'Polski'),
  TtsLanguageOption('tr', 'Türkçe'),
  TtsLanguageOption('sv', 'Svenska'),
  TtsLanguageOption('da', 'Dansk'),
  TtsLanguageOption('no', 'Norsk'),
  TtsLanguageOption('fi', 'Suomi'),
  TtsLanguageOption('cs', 'Čeština'),
  TtsLanguageOption('hu', 'Magyar'),
  TtsLanguageOption('ro', 'Română'),
  TtsLanguageOption('bg', 'Български'),
  TtsLanguageOption('el', 'Ελληνικά'),
  TtsLanguageOption('he', 'עברית'),
  TtsLanguageOption('uk', 'Українська'),
  TtsLanguageOption('vi', 'Tiếng Việt'),
  TtsLanguageOption('th', 'ไทย'),
  TtsLanguageOption('id', 'Bahasa Indonesia'),
  TtsLanguageOption('ms', 'Bahasa Melayu'),
  TtsLanguageOption('hi', 'हिन्दी'),
  TtsLanguageOption('bn', 'বাংলা'),
];

const _supertonicVoices = <TtsVoiceOption>[
  TtsVoiceOption('F1', 'F1 · Femenina 1', 0),
  TtsVoiceOption('F2', 'F2 · Femenina 2', 1),
  TtsVoiceOption('F3', 'F3 · Femenina 3', 2),
  TtsVoiceOption('F4', 'F4 · Femenina 4', 3),
  TtsVoiceOption('F5', 'F5 · Femenina 5', 4),
  TtsVoiceOption('M1', 'M1 · Masculina 1', 5),
  TtsVoiceOption('M2', 'M2 · Masculina 2', 6),
  TtsVoiceOption('M3', 'M3 · Masculina 3', 7),
  TtsVoiceOption('M4', 'M4 · Masculina 4', 8),
  TtsVoiceOption('M5', 'M5 · Masculina 5', 9),
];

class TtsModelCatalog {
  static final TtsModelDefinition supertonic = TtsModelDefinition(
    id: 'supertonic-3-int8',
    version: '2026-05-11',
    name: 'Supertonic 3 Multilingual',
    description: 'Best quality · 31 languages · 10 voices · INT8',
    family: TtsModelFamily.supertonic,
    archiveUri: Uri.parse(
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2',
    ),
    archiveBytes: 128774318,
    installedBytes: 145316356,
    sha256: '82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427',
    archiveRoot: 'sherpa-onnx-supertonic-3-tts-int8-2026-05-11',
    requiredFiles: const [
      'duration_predictor.int8.onnx',
      'text_encoder.int8.onnx',
      'vector_estimator.int8.onnx',
      'vocoder.int8.onnx',
      'tts.json',
      'unicode_indexer.bin',
      'voice.bin',
    ],
    languages: _supertonicLanguages,
    voices: _supertonicVoices,
    licenseName: 'Apache-2.0',
    licenseUri: Uri.parse('https://github.com/supertone-inc/supertonic'),
  );

  static final TtsModelDefinition piperSpanish = TtsModelDefinition(
    id: 'piper-es-sharvard-medium',
    version: '1',
    name: 'Piper Español Ligero',
    description: 'Fastest · Spanish · 2 voices · small download',
    family: TtsModelFamily.piper,
    archiveUri: Uri.parse(
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'vits-piper-es_ES-sharvard-medium.tar.bz2',
    ),
    archiveBytes: 80318184,
    installedBytes: 94680398,
    sha256: 'b30a7a83df0518f0ee1c7039506648cade99f1f9b498fc49ed2ced2e2536bb5a',
    archiveRoot: 'vits-piper-es_ES-sharvard-medium',
    requiredFiles: const [
      'es_ES-sharvard-medium.onnx',
      'tokens.txt',
      'espeak-ng-data',
    ],
    languages: const [TtsLanguageOption('es', 'Español')],
    voices: const [
      TtsVoiceOption('speaker-0', 'Voz 1', 0),
      TtsVoiceOption('speaker-1', 'Voz 2', 1),
    ],
    licenseName: 'CC BY 3.0 (SHaRVaRD dataset)',
    licenseUri: Uri.parse('https://creativecommons.org/licenses/by/3.0/'),
  );

  static final List<TtsModelDefinition> models = [supertonic, piperSpanish];

  static TtsModelDefinition byId(String id) => models.firstWhere(
        (model) => model.id == id,
        orElse: () => supertonic,
      );
}
