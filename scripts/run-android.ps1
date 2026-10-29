param(
    [string]$ApiUrl = 'http://127.0.0.1:8000',
    [string]$DeviceId,
    [switch]$ReverseLocalApi
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$package = 'com.pillxai.pillxai_client.development'
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if ($ReverseLocalApi -and $ApiUrl -ne 'http://127.0.0.1:8000') {
    throw 'USB reverse is only supported with the default local API URL.'
}
if ($DeviceId) {
    if ($DeviceId -notmatch '^emulator-[0-9]+$') {
        throw 'Development APKs are emulator-only. Install the signed Android Client Release artifact on physical tablets.'
    }
    $emulated = & $adb -s $DeviceId shell getprop ro.kernel.qemu
    if ($LASTEXITCODE -ne 0 -or "$emulated".Trim() -ne '1') { throw 'A verified emulator is required.' }
}
& (Join-Path $PSScriptRoot 'flutter.cmd') build apk --debug --no-pub -t lib/main.dart "--dart-define=PILLXAI_API_URL=$ApiUrl"
if ($LASTEXITCODE -ne 0) { throw 'Android debug build failed.' }
$apk = Join-Path $projectRoot 'apps/client/build/app/outputs/flutter-apk/app-debug.apk'
Write-Output "Emulator development APK (not for distribution): $apk"
if (-not $DeviceId) { exit 0 }
$running = & $adb -s $DeviceId shell pidof $package
if ($running) { throw 'Pillxai is running. Finish tasks and sync, sign out, then stop the idle app in Android settings before installing.' }
& $adb -s $DeviceId install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Installation failed.' }
if ($ReverseLocalApi) {
    & $adb -s $DeviceId reverse tcp:8000 tcp:8000
    if ($LASTEXITCODE -ne 0) { throw 'ADB port reverse failed.' }
}
& $adb -s $DeviceId shell am start -n "$package/com.pillxai.pillxai_client.MainActivity"
if ($LASTEXITCODE -ne 0) { throw 'App launch failed.' }
