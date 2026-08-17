# Airstream

Airstream is a desktop-first Flutter application that combines live chat from
YouTube, Twitch, and Kick with a configurable OBS overlay and local text to
speech. It is designed to keep the streaming workflow in one lightweight app.

## Highlights

- Unified, deduplicated multi-platform chat.
- Browser-source OBS overlay and stream/recording telemetry.
- Fully local TTS powered by Sherpa-ONNX; chat text never leaves the device.
- Curated quality and lightweight voice models with verified, resumable
  downloads.
- Multilingual Supertonic 3 voices plus a fast Spanish Piper option.
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

The TTS architecture, model integrity guarantees, and attribution are described
in [docs/TTS.md](docs/TTS.md).
