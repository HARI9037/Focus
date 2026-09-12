$ErrorActionPreference = 'Stop'
$focusRoot = Split-Path -Parent $PSScriptRoot
$focusVendor = Join-Path $focusRoot 'build/vendor'
New-Item -ItemType Directory -Force -Path $focusVendor | Out-Null
$focusArchive = Join-Path $focusVendor 'sqlite.tar.gz'
curl.exe -fL --retry 2 --max-time 120 https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz -o $focusArchive
if ($LASTEXITCODE -ne 0) { throw 'SQLite download failed' }
tar.exe -xzf $focusArchive -C $focusVendor
if ($LASTEXITCODE -ne 0) { throw 'SQLite extraction failed' }
