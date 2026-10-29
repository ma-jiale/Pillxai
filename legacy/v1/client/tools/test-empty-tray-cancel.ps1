param([switch]$VerifyBeforeFix)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$uiSource = Get-Content (Join-Path $clientRoot 'Assets/Scripts/UIManager.cs') -Raw
function Get-MethodSource([string]$name) {
    $match = [regex]::Match($uiSource, '(?m)^        private (?:async )?[^\r\n]+\b' + $name + '\(')
    if (-not $match.Success) { throw "Production method not found: $name" }
    $start = $uiSource.IndexOf('{', $match.Index)
    $depth = 0
    for ($i = $start; $i -lt $uiSource.Length; $i++) {
        if ($uiSource[$i] -eq '{') { $depth++ }
        if ($uiSource[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) { return $uiSource.Substring($match.Index, $i - $match.Index + 1) }
        }
    }
    throw "Unbalanced method: $name"
}
$testSource = Get-Content (Join-Path $PSScriptRoot 'tests/EmptyTrayCancelTests.cs') -Raw
$methods = @('WaitForPillBoxRemovalAsync', 'CancelScanAndReturnHomeAsync') | ForEach-Object { Get-MethodSource $_ }
$source = $testSource.Replace('/* PRODUCTION_UI_METHODS */', ($methods -join "`n"))
if ($VerifyBeforeFix) {
    # Restore the original UI decision in memory; never modify production files.
    $source = $source.Replace("            if (!completion && !deviceLostDialogVisible && checker.CanCancelWithoutRemoval)`r`n                return true;", '')
    $source = $source.Replace("            if (!completion && !deviceLostDialogVisible && checker.CanCancelWithoutRemoval)`n                return true;", '')
}
foreach ($file in @('PillBoxChannel.cs', 'PillBoxUnionChecker.cs', 'PillBoxFeedbackText.cs')) {
    $code = Get-Content (Join-Path $clientRoot "Assets/Scripts/Hardware/PillBox/$file") -Raw
    $source += "`n" + [regex]::Replace($code, '(?m)^using [^;]+;\r?\n', '')
}
# Actual checker and UI cancellation/wait methods; only platform and device are doubles.
Add-Type -TypeDefinition $source -Language CSharp
if ($VerifyBeforeFix) {
    try { [EmptyTrayCancelTests]::Run() }
    catch {
        if ($_.Exception.ToString().Contains('FAIL empty tray closes immediately, auto=False')) {
            Write-Output 'PASS original UI reproduces the empty-tray cancellation failure'
            exit 0
        }
        throw
    }
    throw 'Expected original cancellation to fail the empty-tray regression.'
}
[EmptyTrayCancelTests]::Run()
