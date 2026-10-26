param([switch]$IncludeUi)
$ErrorActionPreference = 'Stop'
function Assert-Command([string]$Name) {
    if ($LASTEXITCODE -ne 0) { throw "$Name failed ($LASTEXITCODE)." }
}
& (Join-Path $PSScriptRoot 'backend.ps1') lint
Assert-Command 'Backend lint'
& (Join-Path $PSScriptRoot 'backend.ps1') test
Assert-Command 'Backend tests'
foreach ($package in @('packages/device_protocol', 'packages/device_runtime', 'tools/device_probe')) {
    & (Join-Path $PSScriptRoot 'dart.ps1') $package analyze
    Assert-Command "$package analyze"
}
foreach ($package in @('packages/device_protocol', 'packages/device_runtime')) {
    & (Join-Path $PSScriptRoot 'dart.ps1') $package test
    Assert-Command "$package test"
}
& (Join-Path $PSScriptRoot 'contracts.ps1') -Check
Assert-Command 'Contract generation'
if ($IncludeUi) {
    & (Join-Path $PSScriptRoot 'flutter.cmd') analyze --no-pub
    Assert-Command 'Flutter analyze'
    & (Join-Path $PSScriptRoot 'flutter.cmd') test --no-pub
    Assert-Command 'Flutter tests'
}
