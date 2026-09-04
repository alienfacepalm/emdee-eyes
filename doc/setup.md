# Setup

`emdee-eyes` is a small shell wrapper around [glow](https://github.com/charmbracelet/glow),
Charm's terminal markdown renderer. This page covers installing it on a new
machine and confirming it works.

## Requirements

- macOS or Linux with a POSIX `sh` (already present)
- [Homebrew](https://brew.sh) — used to install `glow` and, for running the
  test suite, `bats-core`
- A `~/.local/bin` directory on your `PATH` (most shells already have this;
  see [Troubleshooting](#troubleshooting) if not)

## Install

From the project directory:

```sh
./install.sh
```

This does three things:

1. Installs `glow` via Homebrew, if it isn't already on your `PATH`.
2. Symlinks `bin/emdee-eyes` into `~/.local/bin/emdee-eyes`.
3. Warns if `~/.local/bin` isn't on your `PATH`.

Because `~/.local/bin/emdee-eyes` is a symlink back to `bin/emdee-eyes` in this
project, there is exactly one copy of the script — pulling updates to this
project (`git pull`, or however you sync it) updates the live command too,
with nothing to reinstall.

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

If you'd rather not run `install.sh` — for example, scripting this into a
dotfiles setup — the two commands it runs are:

```sh
brew install glow
ln -s "$(pwd)/bin/emdee-eyes" ~/.local/bin/emdee-eyes
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
Something else is already at that path — a different script, or a stale
symlink from before this project existed. Move or remove it, then
re-run `install.sh`.

**Nothing named `md`**
`emdee-eyes` is deliberately not called `md`, because oh-my-zsh's core
aliases already bind `md` to `mkdir -p` (in `~/.oh-my-zsh/lib/directories.zsh`,
loaded regardless of which plugins you enable). If you don't use
oh-my-zsh, or don't mind losing that shortcut, you're free to add your
own alias — see [onboarding.md](onboarding.md#renaming-it-to-md) for how.

## Running the test suite

The test suite is only needed if you're changing `bin/emdee-eyes` itself, not
for everyday use.

```sh
brew install bats-core
./tests/run.sh
```

This runs `tests/unit` (argument-routing logic, stubbed glow — no
dependency on rendering) followed by `tests/e2e` (the real glow, against
the files in `examples/`). See [usage.md](usage.md) for what each example
file demonstrates.
