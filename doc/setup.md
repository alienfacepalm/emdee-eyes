# Setup

`emdee-eyes` is a small wrapper around [glow](https://github.com/charmbracelet/glow),
Charm's terminal markdown renderer. There are two implementations — a POSIX
`sh` script and a PowerShell script — kept behaviorally identical; use
whichever matches your platform. This page covers installing either one on
a new machine and confirming it works.

## Requirements

- **macOS or Linux** (also Windows under Git Bash or WSL): a POSIX `sh`
  (already present) and [Homebrew](https://brew.sh) — or, on Linux, your
  distro's own package manager (apt/dnf/yum/pacman/apk), which `install.sh`
  tries first — used to install `glow` and, for running the test suite,
  `bats-core`.
- **Windows**: PowerShell (5.1, already present, or [PowerShell
  7+](https://github.com/PowerShell/PowerShell)) and one of
  [winget](https://learn.microsoft.com/windows/package-manager/winget/)
  (already present on modern Windows), [scoop](https://scoop.sh), or
  [Chocolatey](https://chocolatey.org) — used to install `glow` and, for
  running the test suite, the [Pester](https://pester.dev) module.
- A `~/.local/bin` directory on your `PATH` (most shells already have this;
  see [Troubleshooting](#troubleshooting) if not)

## Install

From the project directory:

```sh
./install.sh
```

```powershell
./install.ps1
```

Each does the same four things for its platform:

1. Installs `glow`, if it isn't already on your `PATH` (via Homebrew or
   your distro's package manager on macOS/Linux; via winget, scoop, or
   choco on Windows).
2. Links the command into `~/.local/bin` — a real symlink to
   `bin/emdee-eyes` on macOS/Linux, or a `~/.local/bin/emdee-eyes.cmd` shim
   pointing at `bin/emdee-eyes.ps1` on Windows.
3. Warns if `~/.local/bin` isn't on your `PATH`.
4. Sets `git config core.hooksPath .githooks`, so `git commit`/`git push`
   run the test suite first and outgoing release tags are validated (see
   [Running the test suite](#running-the-test-suite) and
   [Releasing](../README.md#releasing)).

Because the installed command is a symlink/shim back into this project,
there is exactly one copy of each script — pulling updates to this project
(`git pull`, or however you sync it) updates the live command too, with
nothing to reinstall.

## Verify

```sh
emdee-eyes --help
```

You should see the usage text. Then try it on a real file:

```sh
emdee-eyes README.md
```

Arrow keys / `space` / `b` page through the file, `q` quits — standard
`less`-style navigation. A key-hint banner at the top of the file, and a
status line pinned to the bottom of the screen, are there if you forget.

## Manual install

If you'd rather not run `install.sh`/`install.ps1` — for example, scripting
this into a dotfiles setup — the commands they run are, on macOS/Linux:

```sh
brew install glow
ln -s "$(pwd)/bin/emdee-eyes" ~/.local/bin/emdee-eyes
```

and on Windows:

```powershell
winget install charmbracelet.glow
# then create ~/.local/bin/emdee-eyes.cmd containing:
#   pwsh -NoProfile -File "<project path>\bin\emdee-eyes.ps1" %*
```

## Troubleshooting

**`emdee-eyes: command not found`**
`~/.local/bin` isn't on your `PATH`. Add this to your shell's rc file
(`~/.zshrc`, `~/.bashrc`) and open a new shell:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

**`emdee-eyes: glow not found — install it with: brew install glow`**
The symlink is in place but `glow` itself isn't installed, or isn't on
`PATH` in this particular shell (for example, a non-interactive script
that doesn't source your rc file). Run `brew install glow` and confirm
with `which glow`.

**`install.sh: ~/.local/bin/emdee-eyes already exists and isn't this project's link`**
(or the equivalent `install.ps1` message about `emdee-eyes.cmd`)
Something else is already at that path — a different script, or a stale
symlink/shim from before this project existed. Move or remove it, then
re-run the installer.

**Nothing named `md`**
`emdee-eyes` is deliberately not called `md`, because oh-my-zsh's core
aliases already bind `md` to `mkdir -p` (in `~/.oh-my-zsh/lib/directories.zsh`,
loaded regardless of which plugins you enable). If you don't use
oh-my-zsh, or don't mind losing that shortcut, you're free to add your
own alias — see [onboarding.md](onboarding.md#renaming-it-to-md) for how.

## Running the test suite

The test suite is only needed if you're changing `bin/emdee-eyes` or
`bin/emdee-eyes.ps1` themselves, not for everyday use. Run whichever suite
matches the tooling you have (both, if you have both):

```sh
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y bats

./tests/run.sh
```

On other Linux distributions, install the `bats` package using the system
package manager before running `./tests/run.sh`.

```powershell
Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force   # Windows
./tests/run.ps1
```

Or run `./tests/verify.sh`, which first tests the release hook and then runs
both implementation suites if both are available (otherwise whichever one
is). This is exactly what `.githooks/pre-commit` and `.githooks/pre-push` run
automatically once you've run an installer.

Each suite runs, in order: `tests/unit` (argument-routing logic, stubbed
glow — no dependency on rendering), `tests/regression` (the same stub,
covering specific edge cases like filenames with spaces and width-clamp
boundaries), and `tests/e2e` (the real glow, against the files in
`examples/`). See [usage.md](usage.md) for what each example file
demonstrates.

The repository's GitHub Actions workflow runs both suites for every pull
request and `v*` release tag, and it can also be started manually. The Linux
job installs the POSIX command and the Windows job installs the PowerShell
command, so the installed-command end-to-end checks run in CI instead of
being skipped.
