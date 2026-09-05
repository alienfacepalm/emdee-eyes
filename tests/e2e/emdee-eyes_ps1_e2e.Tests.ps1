# End-to-end tests for bin/emdee-eyes.ps1 — the PowerShell-implementation
# counterpart to emdee-eyes_e2e.bats. Runs the real emdee-eyes.ps1 against
# the real glow and the real example markdown files. Requires glow to be
# installed (winget install charmbracelet.glow / scoop install glow /
# choco install glow); tests skip with a clear message if it isn't.
#
# Argument-routing logic (width math, style flag, dir vs file, single vs
# multi file) is covered in tests/unit — this suite only checks end-to-end
# behavior and output content.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\PwshTestHelpers.ps1')
    $script:Examples = (Resolve-Path (Join-Path $PSScriptRoot '..\..\examples')).Path
    $script:GlowAvailable = [bool](Get-Command glow -ErrorAction SilentlyContinue)

    function Remove-Ansi {
        param([string]$Text)
        return ($Text -replace "`e\][^`a]*`a", '') -replace "`e\[[0-9;]*[A-Za-z]", ''
    }
}

Describe 'emdee-eyes.ps1 end-to-end' {
    BeforeEach {
        if (-not $script:GlowAvailable) {
            Set-ItResult -Skipped -Because 'glow is not installed (winget install charmbracelet.glow)'
        }
    }

    It 'rendering a simple file succeeds and preserves its headings and text' {
        $result = Invoke-Emdee -Arguments @((Join-Path $script:Examples '01-basics.md'))
        $result.ExitCode | Should -Be 0
        $plain = Remove-Ansi $result.Output
        $plain | Should -Match 'Basics'
        $plain | Should -Match 'Text formatting'
        $plain | Should -Match 'link to Anthropic'
    }

    It 'MD_STYLE=notty renders plain text with no color codes' {
        $result = Invoke-Emdee -Arguments @((Join-Path $script:Examples '01-basics.md')) -Env @{ MD_STYLE = 'notty' }
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Not -Match "`e\["
    }

    It 'code blocks and tables render without error and keep their content' {
        $result = Invoke-Emdee -Arguments @((Join-Path $script:Examples '02-code-and-tables.md'))
        $result.ExitCode | Should -Be 0
        $plain = Remove-Ansi $result.Output
        $plain | Should -Match 'glow syntax-highlights'
        $plain | Should -Match 'emdee-eyes file\.md'
        $plain | Should -Match 'Add syntax highlighting themes'
    }

    It 'a long document renders in full, without truncation' {
        $result = Invoke-Emdee -Arguments @((Join-Path $script:Examples '03-long-form.md'))
        $result.ExitCode | Should -Be 0
        $plain = Remove-Ansi $result.Output
        $plain | Should -Match 'Section 1'
        $plain | Should -Match 'Section 7'
        $plain | Should -Match 'The end\.'
    }

    It 'a missing file produces a real, non-zero-exit error from glow' {
        $result = Invoke-Emdee -Arguments @((Join-Path $script:Examples 'does-not-exist.md'))
        $result.ExitCode | Should -Not -Be 0
        # glow's own OS-level error text differs by platform (Linux/macOS:
        # "no such file or directory"; Windows: "cannot find the file/path
        # specified") — match either.
        $result.Output | Should -Match 'no such file|cannot find the (file|path)'
    }

    It 'multiple files are each rendered, in order, with filename separators' {
        $f1 = Join-Path $script:Examples '01-basics.md'
        $f2 = Join-Path $script:Examples '02-code-and-tables.md'
        $result = Invoke-Emdee -Arguments @($f1, $f2)
        $result.ExitCode | Should -Be 0
        $plain = Remove-Ansi $result.Output
        $plain | Should -Match '01-basics\.md'
        $plain | Should -Match '02-code-and-tables\.md'
        $lines = $plain -split "`r?`n"
        $firstPos = ($lines | Select-String -Pattern '01-basics\.md' | Select-Object -First 1).LineNumber
        $secondPos = ($lines | Select-String -Pattern '02-code-and-tables\.md' | Select-Object -First 1).LineNumber
        $firstPos | Should -BeLessThan $secondPos
    }

    It 'stdin renders the same as passing the file directly' {
        $stdinText = Get-Content -Raw (Join-Path $script:Examples '04-readme-style.md')
        $result = Invoke-Emdee -Arguments @() -StdinText $stdinText
        $result.ExitCode | Should -Be 0
        $plain = Remove-Ansi $result.Output
        $plain | Should -Match 'Setup'
        $plain | Should -Match 'npm install'
    }

    It 'the installed command (~/.local/bin/emdee-eyes.cmd) resolves to this project' {
        $installed = Join-Path $HOME '.local\bin\emdee-eyes.cmd'
        if (-not (Test-Path -LiteralPath $installed)) {
            Set-ItResult -Skipped -Because 'emdee-eyes.cmd is not installed (run install.ps1 first)'
            return
        }
        $content = Get-Content -LiteralPath $installed -Raw
        $content | Should -Match ([regex]::Escape($script:EmdeeEyesPs1))
        $proc = Start-Process -FilePath $installed -ArgumentList @((Join-Path $script:Examples '01-basics.md')) -NoNewWindow -Wait -PassThru
        $proc.ExitCode | Should -Be 0
    }
}
