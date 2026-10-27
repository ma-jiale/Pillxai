param(
    [ValidateSet('bootstrap','db-init','db-start','db-stop','migrate','serve','test','lint','export','seed')]
    [string]$Action = 'serve',
    [string]$DataDirectory,
    [string]$Distribution = 'Ubuntu-24.04',
    [string]$ApiHost = '127.0.0.1'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$linuxRoot = (& wsl -d $Distribution --exec wslpath -a $projectRoot).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve the project path inside WSL.' }
$arguments = @('-d', $Distribution, '--cd', $linuxRoot, '--exec', 'env', "PILLXAI_API_HOST=$ApiHost", 'bash', 'scripts/backend.sh', $Action)
if ($DataDirectory) { $arguments += $DataDirectory }
& wsl @arguments
exit $LASTEXITCODE
