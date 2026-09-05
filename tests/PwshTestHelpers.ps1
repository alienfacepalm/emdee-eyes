# Shared helpers for the PowerShell (Pester) test suites covering
# bin/emdee-eyes.ps1. Dot-sourced from tests/unit, tests/regression, and
# tests/e2e's *.Tests.ps1 files.
#
# emdee-eyes.ps1 is invoked as a real child process (not dot-sourced into
# the test runner) because it calls `exit` on every code path — dot-sourcing
# it would tear down the Pester session itself.

$script:EmdeeEyesPs1 = (Resolve-Path (Join-Path $PSScriptRoot '..\bin\emdee-eyes.ps1')).Path

# Creates a fake `glow` on disk that just records how it was invoked (argv
# and, if any was piped, stdin) to $env:GLOW_LOG, mirroring the fake glow
# used by tests/unit/emdee-eyes_unit.bats. This is for unit/regression
# tests only — tests/e2e uses the real glow.
function New-FakeGlowBin {
    param([Parameter(Mandatory)][string]$Directory)

    New-Item -ItemType Directory -Force -Path $Directory | Out-Null

    $glowPs1 = @'
$argsLine = $args -join " "
Add-Content -Path $env:GLOW_LOG -Value "ARGS:$argsLine"
if ([Console]::IsInputRedirected) {
    $stdin = [Console]::In.ReadToEnd()
    Add-Content -Path $env:GLOW_LOG -Value "STDIN:$stdin"
}
exit 0
'@
    $ps1Path = Join-Path $Directory 'glow.ps1'
    Set-Content -Path $ps1Path -Value $glowPs1 -Encoding utf8

    if ($IsWindows) {
        $glowCmd = "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"%~dp0glow.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
        Set-Content -Path (Join-Path $Directory 'glow.cmd') -Value $glowCmd -Encoding ascii -NoNewline
    } else {
        $shPath = Join-Path $Directory 'glow'
        Set-Content -Path $shPath -Value "#!/bin/sh`nexec pwsh -NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`" `"`$@`"`n" -Encoding utf8 -NoNewline
        & chmod +x $shPath
    }
}

# Runs bin/emdee-eyes.ps1 as a real child process with a controlled
# environment, capturing stdout/stderr/exit code the way bats' `run` does.
function Invoke-Emdee {
    param(
        [string[]]$Arguments = @(),
        [string]$StdinText = $null,
        [string]$FakeBinDir = $null,
        [hashtable]$Env = @{}
    )

    $pwshExe = (Get-Command pwsh).Source
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $pwshExe
    $psi.ArgumentList.Add('-NoProfile')
    $psi.ArgumentList.Add('-ExecutionPolicy')
    $psi.ArgumentList.Add('Bypass')
    $psi.ArgumentList.Add('-File')
    $psi.ArgumentList.Add($script:EmdeeEyesPs1)
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # Only redirect stdin when a test actually wants to feed it something.
    # glow itself (not just emdee-eyes.ps1) changes behavior based on
    # whether its own stdin is a pipe, independent of any file argument —
    # redirecting it unconditionally would make every file-argument test
    # accidentally exercise glow's stdin-piped code path instead.
    $psi.RedirectStandardInput = ($null -ne $StdinText)
    $psi.UseShellExecute = $false

    if ($FakeBinDir) {
        # Unit/regression tests: a deliberately restricted PATH containing
        # only the fake glow plus enough of the base system for
        # emdee-eyes.ps1's own logic (pwsh itself, console APIs) to work.
        $sysDir = if ($IsWindows) { $env:SystemRoot + '\System32' } else { '/usr/bin:/bin' }
        $pathSep = if ($IsWindows) { ';' } else { ':' }
        $pwshDir = Split-Path -Parent $pwshExe
        $pathParts = @($FakeBinDir, $pwshDir, $sysDir)
        $psi.Environment['PATH'] = $pathParts -join $pathSep
        if ($IsWindows) {
            $psi.Environment['PATHEXT'] = '.COM;.EXE;.BAT;.CMD'
        }
    } else {
        # e2e tests: use this machine's real PATH, so the real glow
        # (wherever it's actually installed) is found.
        $psi.Environment['PATH'] = $env:PATH
        if ($IsWindows -and $env:PATHEXT) {
            $psi.Environment['PATHEXT'] = $env:PATHEXT
        }
    }

    foreach ($k in $Env.Keys) {
        $psi.Environment[$k] = $Env[$k]
    }

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($null -ne $StdinText) {
        $proc.StandardInput.Write($StdinText)
        $proc.StandardInput.Close()
    }
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    [PSCustomObject]@{
        ExitCode = $proc.ExitCode
        Stdout   = $stdout
        Stderr   = $stderr
        Output   = $stdout + $stderr
    }
}

# The same width-clamp math emdee-eyes.ps1 itself does, from a given
# column count, so tests aren't hardcoded to one machine's console width.
function Get-ClampedWidth {
    param([int]$Columns)
    $width = $Columns - 4
    if ($width -gt 100) { $width = 100 }
    if ($width -lt 20) { $width = 20 }
    return $width
}
