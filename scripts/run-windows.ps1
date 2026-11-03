param([switch]$Build)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$program = Join-Path $projectRoot 'apps/client/build/windows/x64/runner/Release/pillxai_client.exe'
if ($Build -or -not (Test-Path -LiteralPath $program)) {
    $dataPath = (Join-Path $projectRoot '.var/terminal-sjtu').Replace('\', '/')
    & (Join-Path $PSScriptRoot 'flutter.cmd') build windows --release "--dart-define=PILLXAI_DATA_DIR=$dataPath"
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
}
$existing = Get-Process pillxai_client -ErrorAction SilentlyContinue | Where-Object Path -eq $program
if ($existing) { Write-Output 'Pillxai is already running. Use its existing window.'; exit 0 }
# This is the interactive program explicitly requested for on-machine testing.
Start-Process -FilePath $program -WorkingDirectory $projectRoot
Write-Output 'Pillxai Windows opened. API: https://ixd.sjtu.edu.cn/pillxai ; local execution data: .var/terminal-sjtu'
