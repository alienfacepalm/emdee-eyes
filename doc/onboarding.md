# Onboarding

A five-minute tour for anyone picking up `emdee-eyes` for the first time.

## Why this exists

Reading markdown in a terminal with `cat` shows you raw `#`, `**`, backtick
fences, and pipe-delimited tables — the syntax, not the document. `emdee-eyes`
renders that same file the way a browser or editor preview would: headings
styled and ruled off, **bold**/_italic_ actually bold and italic, tables
drawn with box characters, code fenced blocks syntax-highlighted, links
turned into clickable terminal hyperlinks.

It's a thin wrapper, not a renderer of its own — all the actual markdown
parsing and styling is [glow](https://github.com/charmbracelet/glow) (Charm,
MIT-licensed). `emdee-eyes` adds:

- sane terminal-width wrapping (glow's default is the full terminal width,
  which is unreadable on a wide monitor)
- one command that does the right thing whether you give it a file, a
  directory, several files, a URL, or piped stdin
- a clear error if `glow` itself isn't installed

## Why it isn't called `md`

The obvious name for a markdown viewer is `md`. It's taken: oh-my-zsh's
core aliases bind `md` to `mkdir -p`, loaded in every interactive shell
regardless of which plugins are enabled. Overriding it would mean losing
that shortcut everywhere, silently, for anyone who picks up this project.
`emdee-eyes` avoids the collision entirely.

### Renaming it to `md`

If you don't use oh-my-zsh, or you're fine giving up the `mkdir -p`
shortcut, nothing stops you from aliasing it yourself:

```sh
# ~/.zshrc, after oh-my-zsh loads
unalias md 2>/dev/null
alias md=emdee-eyes
```

This is a personal preference, which is why it isn't the default.

## Your first five commands

Run these from this project's directory to get a feel for it (add
`MD_STYLE=notty` in front of any of them if you're piping to something
that doesn't want color codes):

```sh
emdee-eyes --help                            # usage
emdee-eyes examples/01-basics.md              # a single file, paged
emdee-eyes examples/                          # browse a directory (needs a real terminal)
emdee-eyes examples/*.md                      # several files, one after another
cat examples/04-readme-style.md | emdee-eyes  # from stdin
```

## Mental model

`emdee-eyes` looks at what you gave it and picks one of four behaviors:

| You ran...              | It does...                                             |
| ------------------------ | ------------------------------------------------------- |
| `emdee-eyes` (nothing)       | Opens glow's directory browser on the current directory (needs a real terminal — see below) |
| `emdee-eyes a-directory/`    | Same browser, scoped to that directory                  |
| `emdee-eyes one-file.md`     | Renders it, paged if you're at an interactive terminal  |
| `emdee-eyes a.md b.md c.md`  | Renders each in turn, separated by a `── filename ──` header, all through one pager |

Piped input (`cat x.md | emdee-eyes`) is treated the same as a single file.

One real constraint worth knowing early: **directory browsing needs an
actual terminal.** It's glow's interactive file-picker (a full TUI), so it
can't run inside a script, over SSH without a pty, or with output
redirected to a file — you'll get a "could not open TTY" error in those
cases. Rendering one or more specific files works everywhere, TTY or not.

## Where to go next

- [setup.md](setup.md) — installing and troubleshooting
- [usage.md](usage.md) — the full command reference, plus real use cases
  (reviewing a README before a PR, browsing a docs folder, `git show`
  output, comparing two versions of a file) with example commands and
  output
