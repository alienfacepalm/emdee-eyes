#!/usr/bin/env bats
# Unit tests for emdee-eyes's argument-routing and option logic.
#
# These stub out `glow` itself with a fake binary that just records how
# it was called (and echoes stdin back), so we're testing emdee-eyes's own
# decisions — width, style, dir-vs-file, single-vs-multi-file, stdin —
# without depending on glow's actual rendering. Rendering itself is
# covered by the e2e suite in tests/e2e, which uses the real glow.

bats_require_minimum_version 1.5.0

setup() {
    PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    EMDEE_EYES="$PROJECT_DIR/bin/emdee-eyes"

    FAKE_BIN="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$FAKE_BIN"

    GLOW_LOG="$BATS_TEST_TMPDIR/glow.log"
    export GLOW_LOG
    : > "$GLOW_LOG"

    cat > "$FAKE_BIN/glow" <<'FAKE'
#!/bin/sh
# Records its own argv, and echoes stdin back (prefixed) if any was piped.
{
    printf 'ARGS:%s\n' "$*"
    if [ ! -t 0 ]; then
        printf 'STDIN:'
        cat
        printf '\n'
    fi
} >> "$GLOW_LOG"
FAKE
    chmod +x "$FAKE_BIN/glow"

    # A restricted PATH containing the fake glow plus enough of the base
    # system for emdee-eyes's own shell built-ins (tput, cat, printf) to work.
    PATH="$FAKE_BIN:/usr/bin:/bin"
    export PATH

    # The default width emdee-eyes computes when no COLUMNS override is set,
    # derived the same way the script does, so tests aren't hardcoded to
    # one machine's `tput cols` fallback.
    DEFAULT_WIDTH=80
    default_cols=${COLUMNS:-}
    if [ -z "$default_cols" ]; then
        default_cols=$(tput cols 2>/dev/null) || default_cols=""
    fi
    case "$default_cols" in
        ''|*[!0-9]*) ;;
        *)
            DEFAULT_WIDTH=$((default_cols - 4))
            if [ "$DEFAULT_WIDTH" -gt 100 ]; then
                DEFAULT_WIDTH=100
            fi
            if [ "$DEFAULT_WIDTH" -lt 20 ]; then
                DEFAULT_WIDTH=20
            fi
            ;;
    esac
}

@test "--help prints usage and exits 0, even with no glow installed" {
    rm -f "$FAKE_BIN/glow"
    run "$EMDEE_EYES" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage: emdee-eyes"* ]]
}

@test "-h is a synonym for --help" {
    rm -f "$FAKE_BIN/glow"
    run "$EMDEE_EYES" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage: emdee-eyes"* ]]
}

@test "missing glow fails fast with a clear, actionable error" {
    rm -f "$FAKE_BIN/glow"
    # Keep the real machine PATH out of this assertion. CI installs Glow for
    # the e2e suite, and finding that copy here would invalidate this test.
    PATH="$FAKE_BIN" run -127 "$EMDEE_EYES" README.md
    [ "$status" -eq 127 ]
    [[ "$output" == *"glow not found"* ]]
    [[ "$output" == *"brew install glow"* ]]
}

@test "a single file is passed straight through with default width and style" {
    run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH README.md" "$GLOW_LOG"
}

@test "MD_STYLE overrides the default style flag" {
    MD_STYLE=light run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s light -w $DEFAULT_WIDTH README.md" "$GLOW_LOG"
}

@test "width is derived from terminal columns, minus a margin" {
    COLUMNS=60 run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w 56 README.md" "$GLOW_LOG"
}

@test "width is clamped to a maximum of 100 columns on wide terminals" {
    COLUMNS=500 run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w 100 README.md" "$GLOW_LOG"
}

@test "width is clamped to a minimum of 20 columns on narrow terminals" {
    COLUMNS=10 run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w 20 README.md" "$GLOW_LOG"
}

@test "a directory argument is browsed, not treated as a file to render" {
    dir="$BATS_TEST_TMPDIR/docs"
    mkdir -p "$dir"
    run "$EMDEE_EYES" "$dir"
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH $dir" "$GLOW_LOG"
}

@test "multiple files are each rendered individually, with a filename separator" {
    f1="$BATS_TEST_TMPDIR/a.md"
    f2="$BATS_TEST_TMPDIR/b.md"
    : > "$f1"
    : > "$f2"
    run "$EMDEE_EYES" "$f1" "$f2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"── $f1 ──"* ]]
    [[ "$output" == *"── $f2 ──"* ]]
    [ "$(grep -c '^ARGS:' "$GLOW_LOG")" -eq 2 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH $f1" "$GLOW_LOG"
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH $f2" "$GLOW_LOG"
}

@test "multiple files preserve the order given on the command line" {
    f1="$BATS_TEST_TMPDIR/z.md"
    f2="$BATS_TEST_TMPDIR/a.md"
    : > "$f1"
    : > "$f2"
    run "$EMDEE_EYES" "$f1" "$f2"
    [ "$status" -eq 0 ]
    first_pos=$(grep -n -- "── $f1 ──" <<< "$output" | head -1 | cut -d: -f1)
    second_pos=$(grep -n -- "── $f2 ──" <<< "$output" | head -1 | cut -d: -f1)
    [ "$first_pos" -lt "$second_pos" ]
}

@test "stdin is forwarded to glow untouched when no file arguments are given" {
    run bash -c "printf 'hello from stdin' | \"$EMDEE_EYES\""
    [ "$status" -eq 0 ]
    grep -qF -- "STDIN:hello from stdin" "$GLOW_LOG"
}

@test "a nonexistent path is still handed to glow, not rejected by emdee-eyes itself" {
    # emdee-eyes doesn't pre-validate paths — glow reports missing files with
    # its own error. This is covered against the real glow in the e2e
    # suite; here we just confirm emdee-eyes's routing doesn't special-case it.
    run "$EMDEE_EYES" /no/such/file.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH /no/such/file.md" "$GLOW_LOG"
}
