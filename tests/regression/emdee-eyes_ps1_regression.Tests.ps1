# Regression tests for bin/emdee-eyes.ps1 — the PowerShell-implementation
# counterpart to emdee-eyes_regression.bats. Same edge cases, same fake
# glow stub; see that file for why each case is here.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\PwshTestHelpers.ps1')
}

Describe 'emdee-eyes.ps1 regression coverage' {
    BeforeEach {
        $script:FakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
        New-FakeGlowBin -Directory $script:FakeBin
        $script:GlowLog = Join-Path $script:FakeBin 'glow.log'
        Set-Content -Path $script:GlowLog -Value ''
    }

    AfterEach {
        Remove-Item -Recurse -Force -Path $script:FakeBin -ErrorAction SilentlyContinue
    }

    It 'a filename containing spaces is passed through as one argument, not split' {
        $f = Join-Path $script:FakeBin 'my notes.md'
        Set-Content -Path $f -Value ''
        $result = Invoke-Emdee -Arguments @($f) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $f"))
    }

    It 'multiple filenames containing spaces each get their own correct header and glow call' {
        $f1 = Join-Path $script:FakeBin 'first one.md'
        $f2 = Join-Path $script:FakeBin 'second one.md'
        Set-Content -Path $f1 -Value ''
        Set-Content -Path $f2 -Value ''
        $result = Invoke-Emdee -Arguments @($f1, $f2) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match ([regex]::Escape("── $f1 ──"))
        $result.Output | Should -Match ([regex]::Escape("── $f2 ──"))
        $lines = Get-Content $script:GlowLog | Where-Object { $_ -match '^ARGS:' }
        $lines.Count | Should -Be 2
    }

    It 'MD_STYLE set to an empty string falls back to the default, same as unset' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog; MD_STYLE = '' }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $readme"))
    }

    It '--help only short-circuits as the first argument, not a later one' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme, '--help') -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        $lines = Get-Content $script:GlowLog | Where-Object { $_ -match '^ARGS:' }
        $lines.Count | Should -Be 2
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $readme"))
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape('ARGS:-s auto -w 80 --help'))
    }

    It '-h as the first argument prints help and ignores any further arguments' {
        $result = Invoke-Emdee -Arguments @('-h', 'README.md', 'ignored.md') -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'usage: emdee-eyes'
        (Get-Content $script:GlowLog -Raw).Trim() | Should -BeNullOrEmpty
    }

    It 'width clamps to exactly 100 at the boundary, not 99 or 101' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog; COLUMNS = '104' }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 100 $readme"))
    }

    It 'width clamps to exactly 20 at the boundary, not 19 or 21' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog; COLUMNS = '24' }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 20 $readme"))
    }

    It 'an explicit file wins over inherited piped stdin' {
        $readme = Join-Path $PSScriptRoot '..\..\README.md'
        $result = Invoke-Emdee -Arguments @($readme) -StdinText 'ignored stdin' -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        $log = Get-Content $script:GlowLog -Raw
        $log | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $readme"))
        $log | Should -Not -Match 'ignored stdin'
    }

    It 'a directory argument with a trailing slash is still browsed, not rendered as a file' {
        $dir = Join-Path $script:FakeBin 'docs'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $result = Invoke-Emdee -Arguments @("$dir\") -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        Get-Content $script:GlowLog -Raw | Should -Match ([regex]::Escape("ARGS:-s auto -w 80 $dir\"))
    }

    It 'five files in one invocation are all rendered, each exactly once, in order' {
        $files = 1..5 | ForEach-Object {
            $f = Join-Path $script:FakeBin "$_.md"
            Set-Content -Path $f -Value ''
            $f
        }
        $result = Invoke-Emdee -Arguments $files -FakeBinDir $script:FakeBin -Env @{ GLOW_LOG = $script:GlowLog }
        $result.ExitCode | Should -Be 0
        $lines = Get-Content $script:GlowLog | Where-Object { $_ -match '^ARGS:' }
        $lines.Count | Should -Be 5

        $outputLines = $result.Output -split "`r?`n"
        $prevPos = 0
        foreach ($f in $files) {
            $pos = ($outputLines | Select-String -Pattern ([regex]::Escape("── $f ──")) | Select-Object -First 1).LineNumber
            $pos | Should -BeGreaterThan $prevPos
            $prevPos = $pos
        }
    }
}
