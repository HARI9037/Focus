$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
Write-Host 'Distribute the entire build/windows/x64/runner/Release directory, including DLLs and data.'
