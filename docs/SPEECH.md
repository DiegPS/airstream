# Local speech tools

Airstream uses Sherpa-ONNX for an offline microphone pipeline:

`PCM microphone → GTCRN noise reduction → Silero VAD → Canary ASR/translation`

The pipeline runs outside Flutter's UI isolate. Audio is never uploaded. VAD
limits recognition work to speech segments, Canary restores punctuation and
capitalization, and the output can be shown in Airstream or sent to the
independent OBS browser source at `/captions`.

## Product behavior

- Captions are disabled by default.
- Enabling captions never starts a download. The user must press **Download
  caption model**.
- Canary supports transcription in English, Spanish, German, and French, plus
  translation between those supported directions exposed by the model.
- Optional GTCRN streaming enhancement improves recognition in noisy rooms.
- Voice commands require a configurable wake word and are limited to explicit
  OBS recording and scene actions.
- The model archive, VAD, and denoiser have pinned sizes and SHA-256 digests and
  use the same resumable, staged installer as TTS.

## Why these Sherpa capabilities

Live captions combine the Sherpa features that directly fit a streamer:
offline ASR, translation, punctuation/capitalization, VAD, and streaming noise
reduction. Keyword spotting is redundant once the caption recognizer is loaded;
the wake-word parser provides the same guarded workflow without another model.
Speaker identification, diarization, language identification, and audio tagging
are not enabled for the single-microphone workflow because they add models and
memory without a reliable product action. They remain capabilities of the
underlying Sherpa package, not user-facing claims made by Airstream.

## Licensing

Canary 180M Flash is distributed under CC BY 4.0, Silero VAD under MIT, and the
Sherpa-ONNX runtime under Apache-2.0. Airstream downloads upstream artifacts on
explicit request and does not redistribute them in the application binary.
