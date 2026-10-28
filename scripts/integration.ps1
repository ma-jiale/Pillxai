# M0/M1 integration: backend.ps1 serve must already be running on this computer.
# Full production-task/identity/device integration belongs to M4.
param([switch]$Business)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'backend.ps1') migrate
if ($LASTEXITCODE -ne 0) { throw 'Database migration failed.' }
& (Join-Path $PSScriptRoot 'backend.ps1') test
if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL integration failed.' }
& (Join-Path $PSScriptRoot 'dart.ps1') apps/client run tool/check_backend.dart
if ($LASTEXITCODE -ne 0) { throw 'Windows to WSL contract check failed.' }
if ($Business) {
    $credentials = Join-Path (Split-Path $PSScriptRoot -Parent) '.var/local-login.json'
    if (-not (Test-Path $credentials)) { throw 'Run backend.ps1 seed before the business check.' }
    & (Join-Path $PSScriptRoot 'dart.ps1') apps/client run tool/check_business.dart
    if ($LASTEXITCODE -ne 0) { throw 'Authenticated business check failed.' }
}
& (Join-Path $PSScriptRoot 'device-probe.ps1') simulate --seconds 1
if ($LASTEXITCODE -ne 0) { throw 'Simulated byte stream check failed.' }
