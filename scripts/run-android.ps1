param(
    [string]$ApiUrl = 'http://127.0.0.1:8000',
    [string]$DeviceId,
    [switch]$ReverseLocalApi
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'flutter.cmd') build apk --debug --no-pub -t lib/main.dart "--dart-define=PILLXAI_API_URL=$ApiUrl"
if ($LASTEXITCODE -ne 0) { throw 'Android debug build failed.' }
$apk = Join-Path $projectRoot 'apps/client/build/app/outputs/flutter-apk/app-debug.apk'
Write-Output "Android debug APK: $apk"
if (-not $DeviceId) { exit 0 }
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$running = & $adb -s $DeviceId shell pidof com.pillxai.pillxai_client
if ($running) { throw 'Pillxai is running. Finish tasks and sync, sign out, then stop the idle app in Android settings before installing.' }
& $adb -s $DeviceId install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Installation failed.' }
if ($ReverseLocalApi) {
    if ($ApiUrl -ne 'http://127.0.0.1:8000') { throw 'USB reverse is only supported with the default local API URL.' }
    & $adb -s $DeviceId reverse tcp:8000 tcp:8000
    if ($LASTEXITCODE -ne 0) { throw 'ADB port reverse failed.' }
}
& $adb -s $DeviceId shell am start -n com.pillxai.pillxai_client/.MainActivity
if ($LASTEXITCODE -ne 0) { throw 'App launch failed.' }
