# emdee-eyes

A markdown viewer for the terminal. `emdee-eyes` is a small `sh` wrapper
around [glow](https://github.com/charmbracelet/glow) that adds sane
terminal-width wrapping and one command that does the right thing for a
file, a directory, several files, a URL, or piped stdin.

```sh
emdee-eyes README.md
```

It isn't called `md` — see [why](doc/onboarding.md#why-it-isnt-called-md).

## Documentation

- **[doc/setup.md](doc/setup.md)** — installing, verifying, troubleshooting
- **[doc/onboarding.md](doc/onboarding.md)** — a five-minute first look:
  why this exists, the naming decision, the mental model
- **[doc/usage.md](doc/usage.md)** — full command/flag reference, plus
  worked use cases (reviewing a README, browsing a docs folder, `git show`
  output, piping into `grep`) with real example output

## Quick start

```sh
./install.sh          # installs glow (via brew) and symlinks bin/emdee-eyes into ~/.local/bin
emdee-eyes --help
emdee-eyes examples/01-basics.md
```

## Project layout

```
bin/emdee-eyes        the script — source of truth, symlinked to ~/.local/bin/emdee-eyes
install.sh        installs glow (if needed) and creates the symlink
examples/         sample markdown files used by the docs and the e2e tests
tests/unit/       argument-routing tests, glow stubbed out (bats)
tests/e2e/        real glow, real example files (bats)
tests/run.sh      runs both suites
doc/              setup, onboarding, and usage documentation
```

## Testing

```sh
brew install bats-core
./tests/run.sh
```

Unit tests stub out `glow` to check `emdee-eyes`'s own argument routing
(width math, style flag, file vs. directory vs. stdin, single vs. multiple
files) in isolation. E2E tests run the real `glow` against the files in
`examples/` and check the actual rendered output, error handling for a
missing file, and the directory-browser's real-terminal requirement.

## License

Personal tooling; no license file yet. `glow` itself is MIT-licensed by
Charmbracelet.
