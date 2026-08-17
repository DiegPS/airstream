# Airstream

Airstream is a desktop-first Flutter application that combines live chat from
YouTube, Twitch, and Kick with a configurable OBS overlay and local text to
speech. It is designed to keep the streaming workflow in one lightweight app.

## Highlights

- Unified, deduplicated multi-platform chat.
- Browser-source OBS overlay and stream/recording telemetry.
- Fully local TTS powered by Sherpa-ONNX; chat text never leaves the device.
- Every Sherpa TTS family: Supertonic, Piper/VITS, Kitten, Kokoro, Matcha,
  PocketTTS, and ZipVoice, including custom offline voice cloning.
- Verified, resumable, explicit model downloads; enabling a feature never
  starts a download.
- Local microphone captions and EN/ES/DE/FR translation with Silero VAD,
  optional GTCRN noise reduction, and a dedicated OBS browser source.
- Wake-word protected OBS voice commands for recording and scene changes.
- Persistent visual, filtering, connection, overlay, and TTS settings.

## Development

The local chat packages referenced by `pubspec.yaml` must be available next to
this repository. Then run:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Create a Windows release build with `flutter build windows`.

The model integrity guarantees, architecture, and licensing notes are described
in [docs/TTS.md](docs/TTS.md) and [docs/SPEECH.md](docs/SPEECH.md).
