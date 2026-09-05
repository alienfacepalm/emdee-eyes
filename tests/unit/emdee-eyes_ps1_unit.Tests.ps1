# Unit tests for bin/emdee-eyes.ps1's argument-routing and option logic —
# the PowerShell-implementation counterpart to emdee-eyes_unit.bats.
#
# glow is stubbed out (see tests/PwshTestHelpers.ps1's New-FakeGlowBin) so
# these test emdee-eyes.ps1's own decisions — width, style, dir-vs-file,
# single-vs-multi-file, stdin — without depending on glow's actual
# rendering. Rendering itself is covered by tests/e2e/emdee-eyes_ps1_e2e.Tests.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\PwshTestHelpers.ps1')
}

Describe 'emdee-eyes.ps1 argument routing' {
    BeforeEach {
        $script:FakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
        New-FakeGlowBin -Directory $script:FakeBin
        $script:GlowLog = Join-Path $script:FakeBin 'glow.log'
        Set-Content -Path $script:GlowLog -Value ''
    }

    AfterEach {
        Remove-Item -Recurse -Force -Path $script:FakeBin -ErrorAction SilentlyContinue
    }

    It '--help prints usage and exits 0, even with no glow installed' {
        $result = Invoke-Emdee -Arguments @('--help')
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'usage: emdee-eyes'
    }

    It '-h is a synonym for --help' {
        $result = Invoke-Emdee -Arguments @('-h')
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'usage: emdee-eyes'
    }

    It 'missing glow fails fast with a clear, actionable error' {
        $result = Invoke-Emdee -Arguments @('README.md')
        $result.ExitCode | Should -Be 127
        $result.Output | Should -Match 'glow not found'
    }

    It 'a single file is passed straight through with default width and style' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $readme"))
    }

    It 'MD_STYLE overrides the default style flag' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog; MD_STYLE = 'light' }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s light -w 80 $readme"))
    }

    It 'width is derived from COLUMNS, minus a margin' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog; COLUMNS = '60' }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 56 $readme"))
    }

    It 'width is clamped to a maximum of 100 columns on wide consoles' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog; COLUMNS = '500' }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 100 $readme"))
    }

    It 'width is clamped to a minimum of 20 columns on narrow consoles' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog; COLUMNS = '10' }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 20 $readme"))
    }

    It 'a directory argument is browsed, not treated as a file to render' {
        $dir = Join-Path $script:FakeBin 'docs'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $result = Invoke-Emdee -Arguments @($dir) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $dir"))
    }

    It 'multiple files are each rendered individually, with a filename separator' {
        $f1 = Join-Path $script:FakeBin 'a.md'
        $f2 = Join-Path $script:FakeBin 'b.md'
        Set-Content -Path $f1 -Value ''
        Set-Content -Path $f2 -Value ''
        $result = Invoke-Emdee -Arguments @($f1, $f2) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match ([regex]::Escape("── $f1 ──"))
        $result.Output | Should -Match ([regex]::Escape("── $f2 ──"))
        $lines = Get-Content $script:GlowLog | Where-Object { $_ -match '^ARGS:' }
        $lines.Count | Should -Be 2
    }

    It 'multiple files preserve the order given on the command line' {
        $f1 = Join-Path $script:FakeBin 'z.md'
        $f2 = Join-Path $script:FakeBin 'a.md'
        Set-Content -Path $f1 -Value ''
        Set-Content -Path $f2 -Value ''
        $result = Invoke-Emdee -Arguments @($f1, $f2) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $lines = $result.Output -split "`r?`n"
        $firstPos = ($lines | Select-String -Pattern ([regex]::Escape("── $f1 ──")) | Select-Object -First 1).LineNumber
        $secondPos = ($lines | Select-String -Pattern ([regex]::Escape("── $f2 ──")) | Select-Object -First 1).LineNumber
        $firstPos | Should -BeLessThan $secondPos
    }

    It 'stdin is forwarded to glow untouched when no file arguments are given' {
        $result = Invoke-Emdee -Arguments @() -StdinText 'hello from stdin' -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match 'STDIN:hello from stdin'
    }

    It 'a nonexistent path is still handed to glow, not rejected by emdee-eyes itself' {
        $missing = Join-Path $script:FakeBin 'no\such\file.md'
        $result = Invoke-Emdee -Arguments @($missing) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $missing"))
    }
}
