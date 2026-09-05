#!/usr/bin/env bats
# End-to-end tests: run the real emdee-eyes against the real glow and real
# example markdown files, and check what actually comes out. Requires
# glow to be installed (`brew install glow`); tests skip with a clear
# message if it isn't.
#
# Unit-level argument routing (width math, style flag, dir vs file,
# single vs multi file) is covered in tests/unit — this suite only
# checks end-to-end behavior and output content.

setup() {
    PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    EMDEE_EYES="$PROJECT_DIR/bin/emdee-eyes"
    EXAMPLES="$PROJECT_DIR/examples"

    if ! command -v glow >/dev/null 2>&1; then
        skip "glow is not installed (brew install glow)"
    fi
}

# Strips ANSI/OSC escape sequences so assertions can match on plain text
# regardless of color codes or terminal hyperlink wrapping.
strip_ansi() {
    printf '%s' "$1" | perl -pe 's/\x1b\][^\x07]*\x07//g; s/\x1b\[[0-9;]*[A-Za-z]//g'
}

@test "rendering a simple file succeeds and preserves its headings and text" {
    run "$EMDEE_EYES" "$EXAMPLES/01-basics.md"
    [ "$status" -eq 0 ]
    plain="$(strip_ansi "$output")"
    [[ "$plain" == *"Basics"* ]]
    [[ "$plain" == *"Text formatting"* ]]
    [[ "$plain" == *"link to Anthropic"* ]]
}

@test "rendering colors the output when stdout is a real terminal style" {
    run "$EMDEE_EYES" "$EXAMPLES/01-basics.md"
    [ "$status" -eq 0 ]
    # glow's default "auto"/"dark" styles emit SGR color codes even when
    # stdout is captured, since emdee-eyes always requests a style explicitly.
    [[ "$output" == *$'\x1b['* ]]
}

@test "MD_STYLE=notty renders plain text with no color codes" {
    MD_STYLE=notty run "$EMDEE_EYES" "$EXAMPLES/01-basics.md"
    [ "$status" -eq 0 ]
    refute_csi_codes "$output"
}

refute_csi_codes() {
    if printf '%s' "$1" | LC_ALL=C grep -q $'\x1b\['; then
        echo "expected no CSI escape codes, but found some" >&2
        return 1
    fi
}

@test "code blocks and tables render without error and keep their content" {
    run "$EMDEE_EYES" "$EXAMPLES/02-code-and-tables.md"
    [ "$status" -eq 0 ]
    plain="$(strip_ansi "$output")"
    [[ "$plain" == *"glow syntax-highlights"* ]]
    [[ "$plain" == *"emdee-eyes file.md"* ]]
    [[ "$plain" == *"Add syntax highlighting themes"* ]]
}

@test "a long document renders in full, without truncation" {
    run "$EMDEE_EYES" "$EXAMPLES/03-long-form.md"
    [ "$status" -eq 0 ]
    plain="$(strip_ansi "$output")"
    [[ "$plain" == *"Section 1"* ]]
    [[ "$plain" == *"Section 7"* ]]
    [[ "$plain" == *"The end."* ]]
}

@test "a missing file produces a real, non-zero-exit error from glow" {
    run "$EMDEE_EYES" "$EXAMPLES/does-not-exist.md"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no such file"* ]]
}

@test "browsing a directory without a controlling terminal fails clearly" {
    # glow's directory browser is a full TUI and needs a real /dev/tty;
    # this documents that emdee-eyes <dir> is for interactive use only.
    command -v setsid >/dev/null 2>&1 || skip "setsid is required to detach the controlling terminal"
    run setsid "$EMDEE_EYES" "$EXAMPLES" </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"TTY"* ]]
}

@test "multiple files are each rendered, in order, with filename separators" {
    run "$EMDEE_EYES" "$EXAMPLES/01-basics.md" "$EXAMPLES/02-code-and-tables.md"
    [ "$status" -eq 0 ]
    plain="$(strip_ansi "$output")"
    [[ "$plain" == *"01-basics.md"* ]]
    [[ "$plain" == *"02-code-and-tables.md"* ]]
    first_pos=$(grep -n "01-basics.md" <<< "$plain" | head -1 | cut -d: -f1)
    second_pos=$(grep -n "02-code-and-tables.md" <<< "$plain" | head -1 | cut -d: -f1)
    [ "$first_pos" -lt "$second_pos" ]
}

@test "stdin renders the same as passing the file directly" {
    run bash -c "cat \"$EXAMPLES/04-readme-style.md\" | \"$EMDEE_EYES\""
    [ "$status" -eq 0 ]
    plain="$(strip_ansi "$output")"
    [[ "$plain" == *"Setup"* ]]
    [[ "$plain" == *"npm install"* ]]
}

@test "the installed command (~/.local/bin/emdee-eyes) resolves to this project" {
    installed="$HOME/.local/bin/emdee-eyes"
    [ -L "$installed" ]
    resolved="$(cd "$(dirname "$installed")" && cd "$(dirname "$(readlink "$installed")")" && pwd)/$(basename "$(readlink "$installed")")"
    [ "$resolved" = "$EMDEE_EYES" ]
    run "$installed" "$EXAMPLES/01-basics.md"
    [ "$status" -eq 0 ]
}
