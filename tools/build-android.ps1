$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Host 'Development APK: build/app/outputs/flutter-apk/app-debug.apk'
