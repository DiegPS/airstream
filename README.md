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

Run the complete local gate (format, analysis, tests, Windows release build,
and native launch smoke test) with:

```powershell
.\tool\run_release_gate.ps1
```

The final candidate additionally requires every native Sherpa model test:

```powershell
.\tool\run_release_gate.ps1 -Candidate -ModelRoot C:\path\to\models
```

Create a portable Windows archive and SHA-256 checksum with
`.\tool\package_windows_portable.ps1`. Microsoft Store MSIX identity and
signing are intentionally performed with the publisher identity assigned by
Partner Center; the portable archive does not pretend to be a signed Store
package.

The model integrity guarantees, architecture, and licensing notes are described
in [docs/TTS.md](docs/TTS.md) and [docs/SPEECH.md](docs/SPEECH.md).

See [PRIVACY.md](PRIVACY.md) for the data-processing and local-storage policy.
