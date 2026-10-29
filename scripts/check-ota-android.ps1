param(
    [Parameter(Mandatory)][ValidatePattern('^emulator-[0-9]+$')][string]$DeviceId,
    [switch]$SkipBuild,
    [switch]$SkipApkBuild,
    [switch]$RecoveryOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
$adb = Join-Path $sdk 'platform-tools/adb.exe'
$buildTools = Join-Path $sdk 'build-tools/36.0.0'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools/gradle'
$env:ANDROID_USER_HOME = Join-Path $projectRoot '.tools/android-user'
$env:PUB_CACHE = Join-Path $projectRoot '.tools/pub-cache'
$evidence = Join-Path $projectRoot '.var/ota-check'
$fixtures = Join-Path $projectRoot '.var/ota-fixtures'
New-Item -ItemType Directory -Force $evidence, $fixtures | Out-Null
$package = 'com.pillxai.pillxai_client.runtimecheck'
$instrumentation = "$package.test/com.pillxai.pillxai_client.OtaInstrumentation"
function Assert-Exit([string]$Name) { if ($LASTEXITCODE -ne 0) { throw "$Name failed ($LASTEXITCODE)." } }
function Invoke-Adb([string[]]$Arguments) {
    $output = & $adb -s $DeviceId @Arguments
    Assert-Exit 'ADB'
    return $output
}
if (-not $SkipBuild -and -not $RecoveryOnly) {
    if (-not $SkipApkBuild) {
    & (Join-Path $PSScriptRoot 'flutter.cmd') build apk --debug --no-pub --target-platform android-x64 --build-name=0.2.0 --build-number=1002 --dart-define=PILLXAI_RUNTIME_CHECK=true
    Assert-Exit 'Upgrade APK build'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'apps/client/build/app/outputs/flutter-apk/app-debug.apk') -Destination (Join-Path $fixtures 'upgrade.apk')
    $testKey = Join-Path $evidence 'wrong-signer.jks'
    if (-not (Test-Path -LiteralPath $testKey)) {
        & (Join-Path $env:JAVA_HOME 'bin/keytool.exe') -genkeypair -keystore $testKey -storepass ota-test-only -keypass ota-test-only -alias ota-test -keyalg RSA -keysize 2048 -validity 30 -dname 'CN=OTA isolated test'
        Assert-Exit 'Test-only signing key'
    }
    & (Join-Path $buildTools 'apksigner.bat') sign --ks $testKey --ks-pass pass:ota-test-only --key-pass pass:ota-test-only --out (Join-Path $fixtures 'wrong-signer.apk') (Join-Path $fixtures 'upgrade.apk')
    Assert-Exit 'Wrong-signature test fixture'
    & (Join-Path $PSScriptRoot 'flutter.cmd') build apk --debug --no-pub --target-platform android-x64 --build-name=0.1.0 --build-number=1001 --dart-define=PILLXAI_RUNTIME_CHECK=true
    Assert-Exit 'Base APK build'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'apps/client/build/app/outputs/flutter-apk/app-debug.apk') -Destination (Join-Path $evidence 'base.apk')
    }
    $defines = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('PILLXAI_RUNTIME_CHECK=true'))
    Push-Location (Join-Path $projectRoot 'apps/client/android')
    try {
        $ndkVersions = (Get-ChildItem -LiteralPath (Join-Path $sdk 'ndk') -Directory).Name -join ','
        & .\gradlew.bat :app:assembleDebugAndroidTest "-Pdart-defines=$defines" -Ptarget-platform=android-x64 "-Pflutter.androidSdkRoot=$sdk" "-Pflutter.installedNdkVersions=$ndkVersions"
        Assert-Exit 'Native instrumentation build'
    } finally { Pop-Location }
}
$base = Join-Path $evidence 'base.apk'
$badging = (& (Join-Path $buildTools 'aapt.exe') dump badging $base) -join "`n"
Assert-Exit 'APK identity'
if (-not $badging.Contains("package: name='$package'")) { throw 'Refusing to touch a non-test package.' }
if ((Invoke-Adb @('shell', 'getprop', 'ro.kernel.qemu')).Trim() -ne '1') { throw 'Emulator required.' }
if ($RecoveryOnly) {
    # Separate ADB recovery evidence after a blocked installer; never reported as OTA success.
    $upgrade = Join-Path $fixtures 'upgrade.apk'
    $identity = (& (Join-Path $buildTools 'aapt.exe') dump badging $upgrade) -join "`n"
    Assert-Exit 'Upgrade APK identity'
    if (-not $identity.Contains("package: name='$package' versionCode='1002'")) { throw 'Expected isolated upgrade fixture.' }
    Invoke-Adb @('install', '-r', $upgrade)
    $output = (Invoke-Adb @('shell', 'am', 'instrument', '-w', '-e', 'mode', 'recovery', $instrumentation)) -join "`n"
    [IO.File]::WriteAllText((Join-Path $evidence 'adb-recovery.log'), $output)
    if (-not $output.Contains('OTA_NATIVE_RECOVERY_PASSED')) { throw 'ADB upgrade recovery failed.' }
    Write-Output 'ADB replacement/data recovery passed; system-confirmed OTA installation remains unverified.'
    exit 0
}
Invoke-Adb @('install', '-r', '-d', $base)
# Reset only this explicitly isolated test application, never the real Pillxai package.
Invoke-Adb @('shell', 'pm', 'clear', $package)
Invoke-Adb @('install', '-r', (Join-Path $projectRoot 'apps/client/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk'))
Invoke-Adb @('shell', 'appops', 'set', $package, 'REQUEST_INSTALL_PACKAGES', 'allow')
Invoke-Adb @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
Invoke-Adb @('shell', 'wm', 'dismiss-keyguard')
foreach ($mode in @('verify', 'cancel')) {
    $output = (Invoke-Adb @('shell', 'am', 'instrument', '-w', '-e', 'mode', $mode, $instrumentation)) -join "`n"
    [IO.File]::WriteAllText((Join-Path $evidence "$mode.log"), $output)
    if (-not $output.Contains("OTA_NATIVE_$($mode.ToUpper())_PASSED")) { throw "Native $mode failed; see $evidence" }
}
$installLog = Join-Path $evidence 'install.log'
$installer = Start-Process -FilePath $adb -ArgumentList @('-s', $DeviceId, 'shell', 'am', 'instrument', '-w', '-e', 'mode', 'install', $instrumentation) -WindowStyle Hidden -RedirectStandardOutput $installLog -RedirectStandardError (Join-Path $evidence 'install-error.log') -PassThru
$deadline = (Get-Date).AddSeconds(90)
$clicked = $false
$upgraded = $false
while ((Get-Date) -lt $deadline) {
    $version = (Invoke-Adb @('shell', 'dumpsys', 'package', $package)) -join "`n"
    if ($version -match 'versionCode=1002\b') { $upgraded = $true; break }
    if ((Test-Path -LiteralPath $installLog) -and ((Get-Content -LiteralPath $installLog -Raw) -match 'OTA_CONFIRMATION_OPEN')) {
        Invoke-Adb @('shell', 'uiautomator', 'dump', '/sdcard/pillxai-ota-install.xml') | Out-Null
        [xml]$ui = (Invoke-Adb @('shell', 'cat', '/sdcard/pillxai-ota-install.xml')) -join "`n"
        if ($ui.OuterXml -match 'App blocked to protect your device') {
            [IO.File]::WriteAllText((Join-Path $evidence 'system-install-blocked.xml'), $ui.OuterXml)
            throw 'Play Protect blocked this test APK. System installation is not verified; device protection remains enabled.'
        }
        $button = $ui.SelectNodes('//node') | Where-Object {
            $_.package -match 'packageinstaller' -and $_.enabled -eq 'true' -and $_.text -match '^(Update|Install|更新|安装)$'
        } | Select-Object -First 1
        if (-not $clicked -and $button -and $button.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
            $x = [int]( ([int]$Matches[1] + [int]$Matches[3]) / 2 )
            $y = [int]( ([int]$Matches[2] + [int]$Matches[4]) / 2 )
            Invoke-Adb @('shell', 'input', 'tap', "$x", "$y")
            $clicked = $true
        }
    }
    Start-Sleep -Milliseconds 500
}
if (-not $clicked -or -not $upgraded) { throw "System installation was not verified; see $evidence" }
$output = (Invoke-Adb @('shell', 'am', 'instrument', '-w', '-e', 'mode', 'recovery', $instrumentation)) -join "`n"
[IO.File]::WriteAllText((Join-Path $evidence 'recovery.log'), $output)
if (-not $output.Contains('OTA_NATIVE_RECOVERY_PASSED')) { throw "Upgrade data/lock recovery failed; see $evidence" }
Write-Output "OTA emulator checks passed. Evidence: $evidence"
