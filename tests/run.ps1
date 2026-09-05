#!/usr/bin/env pwsh
# Runs the PowerShell-implementation (bin/emdee-eyes.ps1) test suite: unit
# tests (stubbed glow), regression tests (stubbed glow, specific past-bug
# and edge-case coverage), then e2e tests (real glow, real example files).
#
# This only covers the PowerShell implementation. See tests/run.sh for the
# POSIX sh implementation's equivalent suite (bin/emdee-eyes), and
# tests/verify.sh to run whichever of the two this machine can.
$ErrorActionPreference = 'Stop'
$Dir = $PSScriptRoot

$pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0.0' } | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) {
    Write-Error "run.ps1: Pester 5+ not found — install it with: Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force"
    exit 1
}
Import-Module Pester -MinimumVersion 5.0.0

$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $Dir 'unit'),
    (Join-Path $Dir 'regression'),
    (Join-Path $Dir 'e2e')
)
$config.Run.Exit = $false
$config.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0) {
    exit 1
}
exit 0
