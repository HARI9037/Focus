$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
python tools/bootstrap.py
if ($LASTEXITCODE -ne 0) { throw 'Bootstrap failed.' }
& "$PSScriptRoot/prepare-signing.ps1"
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Host 'Signed APK: build/app/outputs/flutter-apk/app-release.apk'
