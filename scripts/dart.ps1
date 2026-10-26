param(
    [Parameter(Mandatory)][string]$Package,
    [Parameter(ValueFromRemainingArguments)][string[]]$DartArguments
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$packagePath = [IO.Path]::GetFullPath((Join-Path $projectRoot $Package))
if (-not $packagePath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar)) {
    throw 'Dart package must be inside the project.'
}
$oldCache = $env:PUB_CACHE
$oldCi = $env:CI
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
try {
    $env:PUB_CACHE = Join-Path $projectRoot '.tools/pub-cache'
    $env:CI = 'true'
    $env:TEMP = Join-Path $projectRoot '.tools/dart-temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    Push-Location $packagePath
    & (Join-Path $projectRoot '.tools/flutter/bin/cache/dart-sdk/bin/dart.exe') @DartArguments
    $result = $LASTEXITCODE
} finally {
    Pop-Location
    $env:PUB_CACHE = $oldCache
    $env:CI = $oldCi
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
}
exit $result
