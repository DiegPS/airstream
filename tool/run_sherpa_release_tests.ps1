param(
  [Parameter(Mandatory = $true)]
  [string]$ModelRoot,
  [string]$NativeLibraryDirectory = "build\windows\x64\runner\Release"
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$models = (Resolve-Path -LiteralPath $ModelRoot).Path
$native = (Resolve-Path -LiteralPath (Join-Path $root $NativeLibraryDirectory)).Path

$modelDirectories = @{
  AIRSTREAM_SUPERTONIC_MODEL_DIR = 'supertonic-3-hybrid-2026-05-11-v1'
  AIRSTREAM_PIPER_MX_MODEL_DIR = 'piper-es-mx-claude-high-int8-2025-12-05'
  AIRSTREAM_PIPER_ES_MODEL_DIR = 'piper-es-es-davefx-medium-int8-2025-12-05'
  AIRSTREAM_KITTEN_MODEL_DIR = 'kitten-nano-en-v0-8-int8-2026-05-12'
  AIRSTREAM_KOKORO_MODEL_DIR = 'kokoro-en-v0-19-int8-2025-08-10'
  AIRSTREAM_MATCHA_MODEL_DIR = 'matcha-ljspeech-en-2026-07-16'
  AIRSTREAM_POCKET_MODEL_DIR = 'pocket-tts-int8-2026-01-26'
  AIRSTREAM_ZIPVOICE_MODEL_DIR = 'zipvoice-distill-int8-zh-en-2026-06-18'
}

foreach ($entry in $modelDirectories.GetEnumerator()) {
  $path = Join-Path $models $entry.Value
  if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    throw "Required Sherpa model is missing: $path"
  }
  Set-Item -LiteralPath "Env:$($entry.Key)" -Value $path
}

$speech = Join-Path $models 'speech-canary-180m-int8-2025-07-07-v1'
if (-not (Test-Path -LiteralPath $speech -PathType Container)) {
  throw "Required captions model is missing: $speech"
}

$env:AIRSTREAM_SHERPA_LIBRARY_DIR = $native
$env:AIRSTREAM_SILERO_VAD_MODEL = Join-Path $speech 'silero_vad.onnx'
$env:AIRSTREAM_GTCRN_MODEL = Join-Path $speech 'gtcrn_simple.onnx'

$requiredFiles = @(
  (Join-Path $native 'onnxruntime.dll'),
  (Join-Path $native 'sherpa-onnx-c-api.dll'),
  $env:AIRSTREAM_SILERO_VAD_MODEL,
  $env:AIRSTREAM_GTCRN_MODEL
)
foreach ($path in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Required native release artifact is missing: $path"
  }
}

Push-Location $root
try {
  flutter test test/sherpa_tts_integration_test.dart test/sherpa_speech_integration_test.dart
  if ($LASTEXITCODE -ne 0) {
    throw "Sherpa release tests failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}
