param(
    [Parameter(Mandatory)][ValidatePattern('^emulator-[0-9]+$')][string]$DeviceId,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$testPackage = 'com.pillxai.pillxai_client.runtimecheck'
$component = "$testPackage/com.pillxai.pillxai_client.MainActivity"
$report = Join-Path $projectRoot '.tools/android-runtime-check.log'
function Invoke-Adb([string[]]$Arguments) {
    $output = & $adb -s $DeviceId @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments -join ' ')" }
    return $output
}
if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'flutter.cmd') build apk --debug --no-pub -t tool/check_android_runtime.dart --dart-define=PILLXAI_RUNTIME_CHECK=true
    if ($LASTEXITCODE -ne 0) { throw 'Verification build failed.' }
}
$apk = Join-Path $projectRoot 'apps/client/build/app/outputs/flutter-apk/app-debug.apk'
$aapt = Join-Path $env:LOCALAPPDATA 'Android/Sdk/build-tools/36.0.0/aapt.exe'
$badging = (& $aapt dump badging $apk) -join "`n"
if ($LASTEXITCODE -ne 0 -or -not $badging.Contains("package: name='$testPackage'")) {
    throw 'The APK is not the isolated runtimecheck package. Rebuild without -SkipBuild.'
}
Invoke-Adb @('install', '-r', (Join-Path $projectRoot 'apps/client/build/app/outputs/flutter-apk/app-debug.apk'))
# Only the isolated verification application is reset. Never the normal client.
Invoke-Adb @('shell', 'pm', 'clear', $testPackage)
Invoke-Adb @('shell', 'pm', 'grant', $testPackage, 'android.permission.BLUETOOTH_CONNECT')
Invoke-Adb @('shell', 'pm', 'grant', $testPackage, 'android.permission.POST_NOTIFICATIONS')
Invoke-Adb @('logcat', '-c')
Invoke-Adb @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
Invoke-Adb @('shell', 'wm', 'dismiss-keyguard')
Invoke-Adb @('shell', 'am', 'start', '-n', $component)
$deadline = (Get-Date).AddSeconds(100)
$backgrounded = $false
$killed = $false
$evidence = @()
while ((Get-Date) -lt $deadline) {
    $log = (Invoke-Adb @('logcat', '-d', '-s', 'flutter:I', 'AndroidRuntime:E')) -join "`n"
    if ($log.Contains('ANDROID_CHECK_FAILED')) {
        Set-Content $report ($evidence + $log) -Encoding utf8
        throw "Runtime check failed. See $report"
    }
    if (-not $backgrounded -and $log.Contains('ANDROID_CHECK_BACKGROUND_WINDOW')) {
        Invoke-Adb @('shell', 'input', 'keyevent', 'KEYCODE_HOME')
        Invoke-Adb @('shell', 'input', 'keyevent', 'KEYCODE_SLEEP')
        $backgrounded = $true
        $evidence += "$(Get-Date -Format o) backgrounded and screen asleep"
        $service = Invoke-Adb @('shell', 'dumpsys', 'activity', 'services', $testPackage)
        $evidence += $service
        if (-not (($service -join "`n").Contains('isForeground=true'))) { throw 'Service is not foreground.' }
    }
    if (-not $killed -and $log.Contains('ANDROID_CHECK_KILL_WINDOW')) {
        Invoke-Adb @('shell', 'am', 'force-stop', $testPackage)
        Invoke-Adb @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
        Invoke-Adb @('shell', 'wm', 'dismiss-keyguard')
        Invoke-Adb @('shell', 'am', 'start', '-n', $component)
        $killed = $true
        $evidence += "$(Get-Date -Format o) force-stopped and relaunched"
    }
    if ($log.Contains('ANDROID_CHECK_PASSED')) {
        if (-not $backgrounded -or -not $killed) { throw 'Lifecycle steps were not exercised.' }
        Set-Content $report ($evidence + $log) -Encoding utf8
        Write-Output "Android service check passed. Evidence: $report"
        exit 0
    }
    Start-Sleep -Milliseconds 800
}
Set-Content $report ($evidence + $log) -Encoding utf8
throw "Android check timed out. See $report"
