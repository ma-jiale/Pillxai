param([switch]$Build, [string]$Distribution = 'Ubuntu-24.04')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$program = Join-Path $projectRoot 'apps/client/build/windows/x64/runner/Release/pillxai_client.exe'
if ($Build -or -not (Test-Path -LiteralPath $program)) {
    $dataPath = (Join-Path $projectRoot '.var/terminal').Replace('\', '/')
    & (Join-Path $PSScriptRoot 'flutter.cmd') build windows --release "--dart-define=PILLXAI_DATA_DIR=$dataPath"
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
}
function Test-BackendReady {
    try { return (Invoke-RestMethod 'http://127.0.0.1:8000/health/ready' -TimeoutSec 2).status -eq 'ready' }
    catch { return $false }
}
if (-not (Test-BackendReady)) {
    & (Join-Path $PSScriptRoot 'backend.ps1') db-start -Distribution $Distribution
    if ($LASTEXITCODE -ne 0) { throw 'Project database failed to start.' }
    & (Join-Path $PSScriptRoot 'backend.ps1') migrate -Distribution $Distribution
    if ($LASTEXITCODE -ne 0) { throw 'Project database migration failed.' }
    $linuxRoot = (& wsl -d $Distribution --exec wslpath -a $projectRoot).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve WSL project directory.' }
    $log = Join-Path $projectRoot '.var/windows-backend'
    Start-Process -FilePath 'wsl.exe' -WindowStyle Hidden -ArgumentList @(
        '-d', $Distribution, '--cd', $linuxRoot, '--exec', 'bash', 'scripts/backend.sh', 'serve'
    ) -RedirectStandardOutput "$log.out.log" -RedirectStandardError "$log.err.log" | Out-Null
    $deadline = (Get-Date).AddSeconds(30)
    while (-not (Test-BackendReady) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    if (-not (Test-BackendReady)) { throw "Backend not ready; inspect $log.err.log. An older process may still own port 8000." }
}
$existing = Get-Process pillxai_client -ErrorAction SilentlyContinue | Where-Object Path -eq $program
if ($existing) { Write-Output 'Pillxai is already running. Use its existing window.'; exit 0 }
# This is the interactive program explicitly requested for on-machine testing.
Start-Process -FilePath $program -WorkingDirectory $projectRoot
Write-Output 'Pillxai Windows opened. API: http://127.0.0.1:8000 ; local execution data: .var/terminal'
