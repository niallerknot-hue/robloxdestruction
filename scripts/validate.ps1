# Runs every automated check on the project and prints a pass/fail summary.
# Exit code is 0 only if every gate passes, so agents and CI can rely on it.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/validate.ps1

$ErrorActionPreference = "Continue"
Set-Location (Split-Path -Parent $PSScriptRoot)

$gates = @()

function Add-Gate([string]$Name, [bool]$Passed) {
    $script:gates += [pscustomobject]@{ Gate = $Name; Passed = $Passed }
}

function Run-Gate([string]$Name, [string]$Tool, [scriptblock]$Command) {
    Write-Host "== $Name" -ForegroundColor Cyan
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        Write-Host "   '$Tool' is not installed or not on PATH. Run 'rokit install'." -ForegroundColor Red
        Add-Gate $Name $false
        return
    }
    $global:LASTEXITCODE = 0
    & $Command
    Add-Gate $Name ($LASTEXITCODE -eq 0)
}

New-Item -ItemType Directory -Force -Path build | Out-Null

Run-Gate "rojo build" "rojo" { rojo build default.project.json -o build/game.rbxl }
Run-Gate "stylua" "stylua" { stylua --check src }
Run-Gate "selene" "selene" { selene src }

Write-Host "== strict header" -ForegroundColor Cyan
$missing = @(Get-ChildItem -Path src -Recurse -Filter *.luau |
    Where-Object { (Get-Content -Path $_.FullName -TotalCount 1) -ne "--!strict" })
foreach ($file in $missing) {
    Write-Host "   missing '--!strict' on line 1: $($file.FullName)" -ForegroundColor Red
}
Add-Gate "strict header" ($missing.Count -eq 0)

Write-Host "== tests" -ForegroundColor Cyan
Write-Host "   no test runner set up yet (skipped, not counted)" -ForegroundColor Yellow

Write-Host "`n== summary" -ForegroundColor Cyan
$gates | Format-Table -AutoSize | Out-String | Write-Host

$failed = @($gates | Where-Object { -not $_.Passed })
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed.Count) gate(s) did not pass" -ForegroundColor Red
    exit 1
}
Write-Host "ALL GATES PASSED" -ForegroundColor Green
exit 0
