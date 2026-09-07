param(
  [string]$Executable = 'build\windows\x64\runner\Release\airstream.exe',
  [int]$StartupSeconds = 8
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$executablePath = (Resolve-Path -LiteralPath (Join-Path $root $Executable)).Path
$workingDirectory = Split-Path -Parent $executablePath
$process = $null

try {
  $process = Start-Process `
    -FilePath $executablePath `
    -WorkingDirectory $workingDirectory `
    -WindowStyle Hidden `
    -PassThru

  $deadline = [DateTime]::UtcNow.AddSeconds($StartupSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    if ($process.HasExited) {
      throw "AirStream exited during startup with code $($process.ExitCode)."
    }
    Start-Sleep -Milliseconds 250
  }

  Write-Host "Windows process startup smoke passed (PID $($process.Id))."
} finally {
  if ($null -ne $process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id
    $process.WaitForExit(5000) | Out-Null
  }
}
