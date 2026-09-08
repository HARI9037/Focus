$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
python tools/bootstrap.py
if ($LASTEXITCODE -ne 0) { throw 'Runner setup failed.' }
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
Write-Host 'Ready: flutter run -d windows, or flutter run -d <android-device-id>'
