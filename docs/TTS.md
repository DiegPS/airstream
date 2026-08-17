# Local text to speech

Airstream uses the official `sherpa_onnx` Flutter package and performs all
synthesis locally. Models are not bundled in the application; the selected
model is downloaded when TTS is enabled or tested for the first time.

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

| Model | Use case | Languages | Voices | Download |
| --- | --- | ---: | ---: | ---: |
| Supertonic 3 INT8 | Default, best balance of quality and reach | 31 | 10 | ~123 MB |
| Piper `es_ES-sharvard-medium` | Fast, low-resource Spanish | 1 | 2 | ~77 MB |

Model URLs, versions, required files, sizes, and hashes live in
`lib/services/tts/tts_model_catalog.dart`. Updating a model is an intentional
catalog change; never replace an archive without also changing its version and
digest.

## Licensing

- Sherpa-ONNX is Apache-2.0 licensed.
- Supertonic is distributed under Apache-2.0 by Supertone.
- Piper software is MIT licensed. The included SHaRVaRD catalog entry reports
  its upstream dataset/model license as CC BY 3.0; its bundled `MODEL_CARD`
  remains the authority for attribution.

Airstream does not redistribute these archives. Their upstream release pages
are the source of truth for licenses and notices.
