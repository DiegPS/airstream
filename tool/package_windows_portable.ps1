param(
  [string]$OutputDirectory = 'dist',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$release = Join-Path $root 'build\windows\x64\runner\Release'
$output = [IO.Path]::GetFullPath($OutputDirectory, $root)
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $output.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'OutputDirectory must resolve inside the AirStream repository.'
}

Push-Location $root
try {
  if (-not $SkipBuild) {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
      throw "Windows release build failed with exit code $LASTEXITCODE."
    }
  }

  New-Item -ItemType Directory -Force -Path $output | Out-Null
  $archive = Join-Path $output 'airstream-windows-x64.zip'
  if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive
  }
  Compress-Archive -Path (Join-Path $release '*') -DestinationPath $archive
  $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath "$archive.sha256" -Value "$hash  $(Split-Path -Leaf $archive)"
  Write-Host "Created $archive"
  Write-Host "SHA256 $hash"
} finally {
  Pop-Location
}
