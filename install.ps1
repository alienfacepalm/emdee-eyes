#!/usr/bin/env pwsh
# Installs emdee-eyes on Windows: checks/installs the glow dependency, then
# writes a shim into ~/.local/bin so edits in this project take effect
# immediately everywhere the command is used, and wires up the git hooks
# that run the test suite before commit/push.
$ErrorActionPreference = 'Stop'

$ProjectDir = $PSScriptRoot
$BinDir = Join-Path $HOME '.local\bin'
$Target = Join-Path $BinDir 'emdee-eyes.cmd'
$Ps1Source = Join-Path $ProjectDir 'bin\emdee-eyes.ps1'

if (-not (Get-Command glow -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host 'installing glow via winget...'
        winget install --id charmbracelet.glow -e --accept-source-agreements --accept-package-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host 'installing glow via scoop...'
        scoop install glow
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host 'installing glow via choco...'
        choco install glow -y
    } else {
        Write-Error "install.ps1: glow not found and no supported package manager (winget/scoop/choco) is available.`nInstall glow yourself: https://github.com/charmbracelet/glow"
        exit 1
    }
    if (-not (Get-Command glow -ErrorAction SilentlyContinue)) {
        Write-Warning 'glow was installed but is not yet on PATH in this session — open a new shell before running emdee-eyes.'
    }
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$shimContent = @"
@echo off
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$Ps1Source" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "$Ps1Source" %*
)
exit /b %ERRORLEVEL%
"@

if (Test-Path -LiteralPath $Target) {
    $existing = Get-Content -LiteralPath $Target -Raw
    if ($existing.Trim() -eq $shimContent.Trim()) {
        Write-Host "already linked: $Target"
    } else {
        Write-Error "install.ps1: $Target already exists and isn't this project's shim.`nRemove or back it up, then re-run install.ps1."
        exit 1
    }
} else {
    Set-Content -LiteralPath $Target -Value $shimContent -Encoding ascii
    Write-Host "linked $Target -> $Ps1Source"
}

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if (($userPath -split ';') -notcontains $BinDir -and ($env:PATH -split ';') -notcontains $BinDir) {
    Write-Warning "$BinDir is not on your PATH — add it, e.g. in PowerShell's profile:`n  `$env:PATH = `"$BinDir;`$env:PATH`""
} else {
    Write-Host "$BinDir is already on PATH"
}

$GitDir = Join-Path $ProjectDir '.git'
if (Test-Path -LiteralPath $GitDir) {
    Push-Location $ProjectDir
    try {
        git config core.hooksPath .githooks
        Write-Host 'git hooks: core.hooksPath set to .githooks (runs the test suite before commit/push)'
    } finally {
        Pop-Location
    }
}

Write-Host 'done. try: emdee-eyes --help'
