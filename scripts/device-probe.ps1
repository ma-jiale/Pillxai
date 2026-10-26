param([Parameter(ValueFromRemainingArguments)][string[]]$ProbeArguments)
& (Join-Path $PSScriptRoot 'dart.ps1') tools/device_probe run bin/probe.dart @ProbeArguments
exit $LASTEXITCODE
