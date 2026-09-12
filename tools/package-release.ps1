$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root 'dist'
$windows = Join-Path $root 'build/windows/x64/runner/Release'
$apk = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
foreach ($required in @($apk, "$windows/focus.exe", "$windows/flutter_windows.dll", "$windows/sqlite3.dll", "$windows/data/app.so")) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing release output: $required" }
}
New-Item -ItemType Directory -Force -Path $dist | Out-Null
# Bundle Microsoft's redistributable CRT beside the executable for portable use.
$crt = Get-ChildItem 'C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Redist/MSVC/*/x64/Microsoft.VC143.CRT' -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ redistributable folder missing; install the VS C++ build workload.' }
Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $windows -Force
Copy-Item -LiteralPath $apk -Destination (Join-Path $dist 'Focus-0.2.0-Android.apk') -Force
Compress-Archive -Path "$windows/*" -DestinationPath (Join-Path $dist 'Focus-0.2.0-Windows.zip') -Force
Compress-Archive -LiteralPath (Join-Path $root 'android/focus-release.jks'),(Join-Path $root 'android/key.properties') -DestinationPath (Join-Path $dist 'PRIVATE-signing-recovery.zip') -Force
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $dist 'Focus-0.2.0-Android.apk'),(Join-Path $dist 'Focus-0.2.0-Windows.zip') | ForEach-Object { "$($_.Hash)  $(Split-Path $_.Path -Leaf)" } | Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt')
Write-Host 'Release files saved in dist. Keep PRIVATE-signing-recovery.zip private and backed up.'
