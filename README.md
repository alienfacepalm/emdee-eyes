# emdee-eyes

A markdown viewer for the terminal. `emdee-eyes` is a small wrapper around
[glow](https://github.com/charmbracelet/glow) that adds sane terminal-width
wrapping and one command that does the right thing for a file, a directory,
several files, a URL, or piped stdin.

```sh
emdee-eyes README.md
```

It isn't called `md` — see [why](doc/onboarding.md#why-it-isnt-called-md).

## Platforms

There are two implementations, kept behaviorally identical:

- **[bin/emdee-eyes](bin/emdee-eyes)** — POSIX `sh`. Runs natively on macOS
  and Linux, and on Windows under Git Bash or WSL.
- **[bin/emdee-eyes.ps1](bin/emdee-eyes.ps1)** — PowerShell. Runs natively
  on Windows (PowerShell 5.1 or PowerShell 7+/`pwsh`), and also on macOS or
  Linux if `pwsh` is installed there.

`./install.sh` sets up the `sh` version; `./install.ps1` sets up the
PowerShell version. Use whichever matches your shell — both call the same
`glow` and behave the same way.

## Documentation

- **[doc/setup.md](doc/setup.md)** — installing, verifying, troubleshooting
- **[doc/onboarding.md](doc/onboarding.md)** — a five-minute first look:
  why this exists, the naming decision, the mental model
- **[doc/usage.md](doc/usage.md)** — full command/flag reference, plus
  worked use cases (reviewing a README, browsing a docs folder, `git show`
  output, piping into `grep`) with real example output

## Quick start

```sh
./install.sh          # macOS/Linux/Git Bash/WSL: installs glow and symlinks bin/emdee-eyes into ~/.local/bin
emdee-eyes --help
emdee-eyes examples/01-basics.md
```

```powershell
./install.ps1          # Windows: installs glow and creates a ~/.local/bin/emdee-eyes.cmd shim
emdee-eyes --help
emdee-eyes examples/01-basics.md
```

Both installers also wire up `.githooks` (`git config core.hooksPath
.githooks`) so `git commit` and `git push` run the test suite first — see
[Testing](#testing).

## Project layout

```
bin/emdee-eyes         the sh implementation — source of truth for macOS/Linux/Git Bash/WSL
bin/emdee-eyes.ps1      the PowerShell implementation — source of truth for Windows (and pwsh anywhere)
bin/emdee-eyes.cmd      shim so `emdee-eyes` resolves from cmd.exe/PowerShell to emdee-eyes.ps1
install.sh          installs glow (if needed) and symlinks bin/emdee-eyes
install.ps1          installs glow (if needed) and shims bin/emdee-eyes.ps1
examples/         sample markdown files used by the docs and the e2e tests
tests/unit/       argument-routing tests, glow stubbed out (bats + Pester)
tests/regression/ edge-case coverage, glow stubbed out (bats + Pester)
tests/e2e/        real glow, real example files (bats + Pester)
tests/run.sh      runs the bats suites (unit, regression, e2e) for bin/emdee-eyes
tests/run.ps1     runs the Pester suites (unit, regression, e2e) for bin/emdee-eyes.ps1
tests/verify.sh   runs whichever of the two this machine can — used by .githooks
.githooks/        pre-commit and pre-push hooks that call tests/verify.sh
doc/              setup, onboarding, and usage documentation
```

## Testing

```sh
brew install bats-core                                    # for tests/run.sh
Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force   # for tests/run.ps1
./tests/verify.sh     # runs whichever of the two this machine has tooling for
```

Unit tests stub out `glow` to check `emdee-eyes`'s own argument routing
(width math, style flag, file vs. directory vs. stdin, single vs. multiple
files) in isolation. Regression tests use the same stub to pin down
specific edge cases (filenames with spaces, width-clamp boundaries, `-h`
only special-cased as the first argument, ...). E2E tests run the real
`glow` against the files in `examples/` and check the actual rendered
output, error handling for a missing file, and the directory-browser's
real-terminal requirement. Every suite exists twice — once in bats against
`bin/emdee-eyes`, once in Pester against `bin/emdee-eyes.ps1` — so both
implementations are held to the same behavior.

`.githooks/pre-commit` and `.githooks/pre-push` both run `tests/verify.sh`,
so once you've run either installer, every commit and push is verified
automatically.

## License

Personal tooling; no license file yet. `glow` itself is MIT-licensed by
Charmbracelet.
