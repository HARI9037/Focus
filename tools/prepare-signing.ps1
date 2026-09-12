$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$keyFile = Join-Path $root 'android/focus-release.jks'
$properties = Join-Path $root 'android/key.properties'
if ((Test-Path -LiteralPath $keyFile) -or (Test-Path -LiteralPath $properties)) {
    if ((Test-Path -LiteralPath $keyFile) -and (Test-Path -LiteralPath $properties)) {
        Write-Host 'Existing signing identity retained.'
        exit 0
    }
    throw 'Signing files are incomplete. Restore the original pair; do not replace the existing identity.'
}
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    $keytoolPath = 'C:/Program Files/Microsoft/jdk-17.0.18.8-hotspot/bin/keytool.exe'
} else { $keytoolPath = $keytool.Source }
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$env:FOCUS_SIGNING_PASSWORD = [Convert]::ToBase64String($bytes)
try {
    & $keytoolPath -genkeypair -v -keystore $keyFile -storetype JKS -alias focus -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Focus Personal App' -storepass:env FOCUS_SIGNING_PASSWORD -keypass:env FOCUS_SIGNING_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Signing key generation failed.' }
    @("storeFile=focus-release.jks", "storePassword=$env:FOCUS_SIGNING_PASSWORD", 'keyAlias=focus', "keyPassword=$env:FOCUS_SIGNING_PASSWORD") | Set-Content -LiteralPath $properties -Encoding ascii
    Write-Host 'Signing identity created. Back up android/focus-release.jks and android/key.properties privately; never upload them.'
} finally { Remove-Item Env:FOCUS_SIGNING_PASSWORD -ErrorAction SilentlyContinue }
