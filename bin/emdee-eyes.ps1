#!/usr/bin/env pwsh
# emdee-eyes — render markdown in the terminal with glow. (PowerShell port)
#
# This is a line-for-line port of bin/emdee-eyes (the POSIX sh original) for
# machines without a POSIX shell. Keep the two in sync: any behavior change
# here should also go into bin/emdee-eyes, and vice versa.
#
#   emdee-eyes.ps1                  browse markdown files in the current directory
#   emdee-eyes.ps1 <dir>            browse markdown files in that directory
#   emdee-eyes.ps1 <file.md> ...    render one or more files (paged if stdout is a console)
#   emdee-eyes.ps1 <url>            fetch and render remote markdown
#   Get-Content x.md | emdee-eyes.ps1   render stdin
#
# Env:
#   MD_STYLE   glow style: auto (default), dark, light, notty, or a theme JSON path
#   PAGER      pager to use for terminal output (default: less -R, falling back to more)

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

$ErrorActionPreference = 'Stop'

function Write-Usage {
    @'
usage: emdee-eyes [file.md|dir|url] ...
       Get-Content file.md | emdee-eyes

Renders markdown with glow. With no arguments, browses markdown files
in the current directory. Multiple files are rendered together in one
pager. At a real console, key hints (quit/search/page) show above the
content and, with the default pager, in a status line at the bottom.
See `glow --help` for the underlying renderer's own options.

Env:
  MD_STYLE   glow style: auto (default), dark, light, notty, or a theme JSON path
  PAGER      pager for terminal output (default: less -R, falling back to more)
'@
}

if ($Files.Count -ge 1 -and ($Files[0] -eq '-h' -or $Files[0] -eq '--help')) {
    Write-Usage
    exit 0
}

$glowCommand = Get-Command glow -CommandType Application -ErrorAction SilentlyContinue
if (-not $glowCommand) {
    [Console]::Error.WriteLine('emdee-eyes: glow not found — install it with: winget install charmbracelet.glow')
    exit 127
}
$glowPath = $glowCommand.Source

$style = if ($env:MD_STYLE) { $env:MD_STYLE } else { 'auto' }

$width = 80
$cols = $null
if ($env:COLUMNS) {
    $cols = [int]$env:COLUMNS
} elseif (-not [Console]::IsOutputRedirected) {
    try { $cols = $Host.UI.RawUI.WindowSize.Width } catch { $cols = $null }
}
if ($cols) {
    $width = $cols - 4
    if ($width -gt 100) { $width = 100 }
    if ($width -lt 20) { $width = 20 }
}

$stdinIsConsole = -not [Console]::IsInputRedirected
$stdoutIsConsole = -not [Console]::IsOutputRedirected
$script:renderRc = 0

# Glow prioritizes redirected stdin over an explicit source argument. When
# this wrapper inherited redirected input but was given a file/URL, launch
# Glow with the platform's null device so the explicit source still wins.
function Invoke-GlowSource {
    param([Parameter(Mandatory)][string]$Source)

    if ($IsWindows) {
        $shim = Join-Path ([IO.Path]::GetTempPath()) ("emdee-eyes-$([Guid]::NewGuid()).cmd")
        try {
            $body = "@echo off`r`n`"%~1`" -s `"%~2`" -w `"%~3`" `"%~4`" <NUL`r`nexit /b %ERRORLEVEL%`r`n"
            [IO.File]::WriteAllText($shim, $body, [Text.Encoding]::ASCII)
            & $shim $glowPath $style ([string]$width) $Source
            $script:renderRc = $LASTEXITCODE
        } finally {
            Remove-Item -LiteralPath $shim -Force -ErrorAction SilentlyContinue
        }
    } else {
        & sh -c 'exec "$1" -s "$2" -w "$3" "$4" </dev/null' sh `
            $glowPath $style ([string]$width) $Source
        $script:renderRc = $LASTEXITCODE
    }
}

# No args and stdin is a console: browse the current directory.
if ($Files.Count -eq 0 -and $stdinIsConsole) {
    & $glowPath -s $style -w $width .
    exit $LASTEXITCODE
}

# Single directory argument: browse that directory. Wrapped in try/catch
# because Test-Path throws (rather than returning $false) for inputs that
# look like a PSDrive-qualified path, e.g. a "https://..." URL argument.
$isDir = $false
if ($Files.Count -eq 1) {
    try { $isDir = Test-Path -LiteralPath $Files[0] -PathType Container } catch { $isDir = $false }
}
if ($Files.Count -eq 1 -and $isDir) {
    if ($stdinIsConsole) {
        & $glowPath -s $style -w $width $Files[0]
        exit $LASTEXITCODE
    }
    Invoke-GlowSource -Source $Files[0]
    exit $script:renderRc
}

$esc = [char]27
# glow's default styles prefix rendered level-2..6 headings with their own
# markdown syntax ("## " through "###### ", still colored/bold, but showing
# the raw symbols) while level-1 headings just get a plain space. Each
# prefix is always its own self-contained escape+text+reset run, so
# stripping it can't misfire on real "#" characters in prose or code —
# those are always merged into a longer colored run, never isolated like this.
$headingPrefixPattern = [regex]::new("$esc\[[0-9;]*m#{2,6} $esc\[m")
filter Remove-HeadingPrefix {
    $_ -replace $headingPrefixPattern, ''
}

# Action hints shown only at an interactive console: a top banner above
# each file's content, and (for the default pager) a persistent bottom
# status line. Piped/redirected output stays plain, since a script or
# a filter on the other end has no use for either.
$hints = 'q quit  / search  n/N next  space/b page  g/G top/bottom'
$showHints = $stdoutIsConsole

# glow itself only accepts a single file/url/stdin argument, so anything
# with more than one file is rendered here as a loop, one glow call per file.
function Get-RenderedOutput {
    if ($Files.Count -eq 0) {
        # No file arguments: read from stdin.
        & $glowPath -s $style -w $width -
        $script:renderRc = $LASTEXITCODE
        return
    }
    foreach ($f in $Files) {
        if ($Files.Count -gt 1) {
            $header = "── $f ──"
            if ($showHints) { $header = "$header  $hints" }
            "`n$esc[1;36m$header$esc[0m`n"
        } elseif ($showHints) {
            "`n$esc[1;36m── $f ──  $hints$esc[0m`n"
        }
        if ($stdinIsConsole) {
            & $glowPath -s $style -w $width $f
            $script:renderRc = $LASTEXITCODE
        } else {
            Invoke-GlowSource -Source $f
        }
    }
}

function Get-Pager {
    if ($env:PAGER) {
        $parts = $env:PAGER -split '\s+'
        $rest = if ($parts.Length -gt 1) { $parts[1..($parts.Length - 1)] } else { @() }
        return @{ Command = $parts[0]; Args = @($rest) }
    }
    if (Get-Command less -ErrorAction SilentlyContinue) {
        return @{ Command = 'less'; Args = @('-R', "-Ps$hints ") }
    }
    if (Get-Command more -ErrorAction SilentlyContinue) {
        return @{ Command = 'more'; Args = @() }
    }
    return $null
}

if ($showHints) {
    $pager = Get-Pager
    if ($pager) {
        Get-RenderedOutput | Remove-HeadingPrefix | & $pager.Command @($pager.Args)
    } else {
        # No pager available (e.g. plain Windows PowerShell with neither
        # $env:PAGER, less, nor more on PATH): fall back to unpaged output
        # rather than failing outright.
        Get-RenderedOutput | Remove-HeadingPrefix
    }
} else {
    Get-RenderedOutput | Remove-HeadingPrefix
}

exit $script:renderRc
