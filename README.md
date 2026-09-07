# emdee-eyes

[![Tests](https://github.com/alienfacepalm/emdee-eyes/actions/workflows/tests.yml/badge.svg)](https://github.com/alienfacepalm/emdee-eyes/actions/workflows/tests.yml)

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
.githooks`) so `git commit` and `git push` run the test suite first. Release
tags receive additional checks before push — see [Releasing](#releasing).

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
tests/verify.sh   tests the hooks, then runs whichever implementation suites this machine can
.githooks/        commit, push, and release-tag checks
doc/              setup, onboarding, and usage documentation
```

## Testing

For the POSIX suite, install Bats with the package manager for your platform:

```sh
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y bats

./tests/run.sh
```

For the PowerShell suite, install Pester:

```powershell
Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force
./tests/run.ps1
```

Or run every suite available on the current machine:

```sh
./tests/verify.sh
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

GitHub Actions runs the POSIX suite on Ubuntu and the PowerShell suite on
Windows for pull requests, manual dispatches, and `v*` release tags. Unlike
local verification, CI always runs both implementations and
installs real copies of Glow and `emdee-eyes` for the end-to-end coverage.

## Releasing

Releases are annotated, `v`-prefixed [Semantic Versioning](https://semver.org/)
tags made from `master`. Put useful release notes in the tag annotation:

```sh
git switch master
git pull --ff-only
git tag -a v1.2.3 -m 'Describe the user-visible changes in 1.2.3'
git push origin v1.2.3
```

The pre-push hook rejects malformed or lightweight release tags, empty tag
annotations, tags outside the release branch, and updates or deletions of an
existing release tag. It then runs the normal verification suite. Pre-release
and build suffixes such as `v2.0.0-rc.1` and `v2.0.0+build.7` are accepted.

These are local guardrails, not access control: Git permits bypassing a
pre-push hook with `--no-verify`, and hooks are not copied by `git clone`.
Protect release tags on the remote as the authoritative enforcement layer.

## License

Personal tooling; no license file yet. `glow` itself is MIT-licensed by
Charmbracelet.
