# Usage

Full command reference, environment variables, and worked use cases. See
[onboarding.md](onboarding.md) first if this is your first look at
`emdee-eyes`.

## Reference

```
usage: emdee-eyes [file.md|dir|url] ...
       cat file.md | emdee-eyes
```

| Invocation                  | Behavior                                                        |
| ---------------------------- | ---------------------------------------------------------------- |
| `emdee-eyes`                     | Browse markdown files in the current directory (interactive terminal only) |
| `emdee-eyes <dir>`                | Browse markdown files in that directory (interactive terminal only) |
| `emdee-eyes <file.md>`            | Render one file, paged with on-screen key hints if you're at an interactive terminal |
| `emdee-eyes <a.md> <b.md> ...`    | Render each file in turn, with a `── filename ──` separator, all through one pager |
| `emdee-eyes <url>`                | Fetch and render remote markdown                                 |
| `cat x.md \| emdee-eyes`          | Render stdin                                                     |
| `emdee-eyes x.md \| grep foo`     | Plain (unpaged) output, since stdout isn't a terminal            |
| `emdee-eyes -h` / `--help`        | Usage text                                                       |

### Key hints

At an interactive terminal (not when piped or redirected), `emdee-eyes` adds a
`── filename ──` banner above each file's content with a quit/search/page
cheat-sheet next to it, and — as long as you haven't overridden `PAGER` —
the same hints in a status line that stays pinned to the bottom of the
screen no matter how far you've scrolled:

```
── README.md ──  q quit  / search  n/N next  space/b page  g/G top/bottom

  ...file content...

q quit  / search  n/N next  space/b page  g/G top/bottom
```

If you set `PAGER` to something other than the default, only the top
banner shows — a custom pager may not understand `less`'s `-P` prompt
option, so `emdee-eyes` doesn't try to pass it one.

### Environment variables

| Variable    | Default  | Purpose                                                                 |
| ----------- | -------- | ------------------------------------------------------------------------ |
| `MD_STYLE`  | `auto`   | glow style: `auto` (follows terminal background), `dark`, `light`, `notty` (no color codes), or a path to a custom theme JSON |
| `PAGER`     | `less -R`| Pager used for terminal output (one file or several). The `-R` is required — without it, ANSI color codes show up as literal escape text |

On Windows (`bin/emdee-eyes.ps1`), the default pager is also `less -R` if
`less` is on `PATH` (e.g. via `scoop install less` or Git for Windows'
bundled tools), falling back to `more` if not, and finally to unpaged
output if neither is available — the key-hint banner still shows either
way. `PAGER` overrides all of that, same as on macOS/Linux.

### Exit codes

- `0` — success
- `1` — glow's own error (missing file, malformed URL, etc.) — `emdee-eyes`
  passes this straight through
- `127` — `glow` itself isn't installed

## Use cases

The examples below use the files in [`examples/`](../examples), so you can
run them yourself from this project's directory.

### Reviewing a README before you push

The single most common case: you're about to open a PR and want to see
your `README.md` the way a reader will, not as raw markdown source.

```sh
emdee-eyes examples/04-readme-style.md
```

```text
  # A project README, for scale

  This file mimics a typical project README.md, the most common
  thing
  emdee-eyes gets pointed at.

  Setup

    git clone git@example.com:org/project.git
    cd project
    npm install

  Usage

  Run npm start, then open http://localhost:3000.

  Configuration

   Variable          | Default           | Purpose
  -------------------|-------------------|------------------------
   PORT              | 3000              | HTTP port to listen on
   LOG_LEVEL         | info              | debug, info, or warn

  Contributing

  1. Fork the repo
  2. Create a branch: git checkout -b my-feature
  3. Open a pull request

  See CONTRIBUTING.md https://example.com/CONTRIBUTING.md for the
  full
  guide.
```

The table lines up in columns, the shell commands are set off from prose,
and (in a real terminal, stripped here for legibility) both links are
clickable.

### Browsing a docs folder

Instead of `ls doc/` and guessing which file to open, browse them:

```sh
emdee-eyes doc/
```

This opens glow's interactive file picker scoped to `doc/` — arrow keys to
move, `enter` to open a file, `q` to back out. It needs a real terminal;
see [Known limitation](#known-limitation-directory-browsing-needs-a-real-terminal)
below.

### Comparing two versions of a file

Rendering two files in one call puts them back to back with a filename
header between them, useful for a quick side-by-side read (not a diff —
for that, pipe `git diff` through your normal diff viewer):

```sh
emdee-eyes examples/01-basics.md examples/02-code-and-tables.md
```

Each file's header looks like:

```text
── examples/01-basics.md ──

  # Basics
  ...

── examples/02-code-and-tables.md ──

  # Code and tables
  ...
```

### Reading markdown out of git, without a checkout

`emdee-eyes` reads stdin, so anything that can produce markdown text can feed
it — a specific revision of a file, a diff, a GitHub API response:

```sh
git show main:README.md | emdee-eyes
```

### Piping into another tool

When `emdee-eyes`'s stdout isn't a terminal, it skips the pager and drops the
color codes' worth of noise into a `grep`-friendly stream automatically:

```sh
emdee-eyes examples/02-code-and-tables.md | grep -A2 'Fenced code'
```

```text
  Fenced code block

    #!/bin/sh
```

### Rendering tables and code blocks

Markdown tables and fenced code blocks are two of the places raw `cat`
output is hardest to read. `emdee-eyes` lines up table columns and
syntax-highlights fenced code by language:

```sh
emdee-eyes examples/02-code-and-tables.md
```

```text
  # Code and tables

  Fenced code block

    #!/bin/sh
    echo "glow syntax-highlights this by language"

    def greet(name: str) -> str:
        return f"hello, {name}"

  Table

   Command                 | What it does
  -------------------------|--------------------------------------
   emdee-eyes file.md          | Render one file, paged
   emdee-eyes dir/             | Browse markdown files in a directory
   emdee-eyes a.md b.md        | Render several files in one pager

  Task list

  [x] Write the renderer
  [x] Handle multiple files
  [ ] Add syntax highlighting themes
```

### Rendering for a light-background terminal, or for a log file

```sh
MD_STYLE=light emdee-eyes examples/01-basics.md    # matches a light terminal theme
MD_STYLE=notty emdee-eyes examples/01-basics.md > plain.txt  # no color codes at all
```

## Known limitation: directory browsing needs a real terminal

`emdee-eyes` (no file argument) and `emdee-eyes <a-directory>` hand off to glow's
interactive file browser, which is a full terminal UI. It needs an actual
`/dev/tty` to draw itself, so it fails — deliberately, with a clear error
— if you run it from a script, over SSH without a pty, or with output
redirected:

```sh
$ emdee-eyes doc/ > /tmp/out.txt
Error: unable to run tui program: bubbletea: error opening TTY: ...
```

Rendering specific files (`emdee-eyes file.md`, or several of them) has no
such restriction — it works identically whether you're at an interactive
prompt or piping output into another command.

## Further reading

- `glow --help` — options of the underlying renderer, if you want to call
  it directly for something `emdee-eyes` doesn't expose
- [setup.md](setup.md) — installing and troubleshooting
- [onboarding.md](onboarding.md) — the short version of all of this
