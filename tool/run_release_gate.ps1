param(
  [switch]$Candidate,
  [string]$ModelRoot = '',
  [switch]$SkipBuild,
  [switch]$SkipWindowsSmoke
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ($Candidate -and [string]::IsNullOrWhiteSpace($ModelRoot)) {
  throw 'Candidate mode requires -ModelRoot so no Sherpa native test can be skipped.'
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  Write-Host "`n==> $Name" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE."
  }
}

Push-Location $root
try {
  Invoke-Checked 'Dependency resolution' { flutter pub get }
  Invoke-Checked 'Formatting' {
    dart format --output=none --set-exit-if-changed lib test
  }
  Invoke-Checked 'Static analysis' { flutter analyze }
  Invoke-Checked 'Flutter tests' { flutter test }

  if (-not $SkipBuild) {
    Invoke-Checked 'Windows release build' { flutter build windows --release }
  }

  if (-not $SkipWindowsSmoke) {
    & (Join-Path $PSScriptRoot 'run_windows_smoke.ps1')
  }

  if ($Candidate) {
    & (Join-Path $PSScriptRoot 'run_sherpa_release_tests.ps1') `
      -ModelRoot $ModelRoot
  }

  Write-Host "`nAirStream release gate passed." -ForegroundColor Green
} finally {
  Pop-Location
}
