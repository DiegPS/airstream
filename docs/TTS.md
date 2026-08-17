# Local text to speech

Airstream uses the official `sherpa_onnx` Flutter package and performs all
synthesis locally. Models are not bundled in the application. Enabling TTS
never authorizes a download: the user must explicitly choose **Download model**
or **Test TTS**. If the model is already installed, Airstream may load it from
disk automatically without using the network.

## Production behavior

- Downloads can resume through HTTP range requests.
- Every archive is validated against a pinned byte count and SHA-256 digest.
- Extraction runs in a background isolate and rejects archive path traversal.
- A model becomes visible to the runtime only after all required files pass
  validation and the staging directory is atomically published.
- Incomplete downloads remain resumable. Corrupt downloads are deleted.
- Inference runs in a persistent isolate so Flutter rendering remains fluid and
  the model is loaded once, not once per chat message.
- On Windows, Airstream preloads the packaged ONNX Runtime by absolute path.
  This prevents an older `onnxruntime.dll` in `System32` from silently taking
  precedence and crashing Sherpa at runtime.
- The queue is bounded, URLs are removed, and excessively long messages are
  truncated by Unicode code point rather than UTF-16 unit.
- Disabling TTS stops playback, cancels work, clears the queue, and releases the
  native engine.

## Curated models

| Model | Family | Use case | Languages / voices |
| --- | --- | --- | --- |
| Supertonic 3 Hybrid | Supertonic | Recommended multilingual model; INT8 acoustic stack with clean FP32 vocoder | 31 / 10 |
| Piper Claude | VITS/Piper | Fast Mexican Spanish | 1 / 1 |
| Piper DaveFX | VITS/Piper | Fast European Spanish | 1 / 1 |
| Kitten Nano 0.8 INT8 | Kitten | Tiny English model | 1 / 8 |
| Kokoro 82M INT8 | Kokoro | Natural US/UK English | 1 / 11 |
| Matcha LJSpeech | Matcha + Vocos | Expressive English | 1 / 1 |
| PocketTTS INT8 | Pocket | Zero-shot cloning from a WAV | 2 / bundled samples or custom WAV |
| ZipVoice INT8 | ZipVoice + Vocos | Cloning from a WAV and exact transcript | 2 / bundled samples or custom WAV |

Model URLs, versions, required files, sizes, and hashes live in
`lib/services/tts/tts_model_catalog.dart`. Updating a model is an intentional
catalog change; never replace an archive without also changing its version and
digest.

## Licensing

- Sherpa-ONNX is Apache-2.0 licensed.
- Each catalog entry exposes its model-specific license and upstream page.
- PocketTTS displays an additional warning because its upstream materials have
  carried differing usage notices; users should inspect the bundled license.
- Custom voice cloning should only use audio the user owns or is authorized to
  process.

Airstream does not redistribute these archives. Their upstream release pages
are the source of truth for licenses and notices.
