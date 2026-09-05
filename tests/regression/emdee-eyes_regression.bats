#!/usr/bin/env bats
# Regression tests for bin/emdee-eyes's argument-routing and option logic.
#
# These target specific edge cases (not already covered by tests/unit) that
# are easy to accidentally break in a future change: filenames with spaces,
# shell parameter-expansion quirks, width-clamp boundaries, and the fact
# that -h/--help is only special-cased as the *first* argument. Like
# tests/unit, glow is stubbed out here — this is about emdee-eyes's own
# decisions, not glow's rendering.

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

    PATH="$FAKE_BIN:/usr/bin:/bin"
    export PATH

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

@test "a filename containing spaces is passed through as one argument, not split" {
    f="$BATS_TEST_TMPDIR/my notes.md"
    : > "$f"
    run "$EMDEE_EYES" "$f"
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH $f" "$GLOW_LOG"
}

@test "multiple filenames containing spaces each get their own correct header and glow call" {
    f1="$BATS_TEST_TMPDIR/first one.md"
    f2="$BATS_TEST_TMPDIR/second one.md"
    : > "$f1"
    : > "$f2"
    run "$EMDEE_EYES" "$f1" "$f2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"── $f1 ──"* ]]
    [[ "$output" == *"── $f2 ──"* ]]
    [ "$(grep -c '^ARGS:' "$GLOW_LOG")" -eq 2 ]
}

@test "MD_STYLE set to an empty string falls back to the default, same as unset" {
    MD_STYLE= run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH README.md" "$GLOW_LOG"
}

@test "--help only short-circuits as the first argument, not a later one" {
    # A literal file named "--help" passed after another file is just a
    # second filename to render, not a flag: emdee-eyes's case statement
    # only ever inspects \$1.
    run "$EMDEE_EYES" README.md --help
    [ "$status" -eq 0 ]
    [ "$(grep -c '^ARGS:' "$GLOW_LOG")" -eq 2 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH README.md" "$GLOW_LOG"
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH --help" "$GLOW_LOG"
}

@test "-h as the first argument prints help and ignores any further arguments" {
    run "$EMDEE_EYES" -h README.md ignored.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage: emdee-eyes"* ]]
    [ ! -s "$GLOW_LOG" ]
}

@test "width clamps to exactly 100 at the boundary, not 99 or 101" {
    COLUMNS=104 run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w 100 README.md" "$GLOW_LOG"
}

@test "width clamps to exactly 20 at the boundary, not 19 or 21" {
    COLUMNS=24 run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w 20 README.md" "$GLOW_LOG"
}

@test "a nonnumeric COLUMNS value falls back to 80 instead of breaking arithmetic" {
    COLUMNS=unknown run "$EMDEE_EYES" README.md
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w 80 README.md" "$GLOW_LOG"
}

@test "a directory argument with a trailing slash is still browsed, not rendered as a file" {
    dir="$BATS_TEST_TMPDIR/docs"
    mkdir -p "$dir"
    run "$EMDEE_EYES" "$dir/"
    [ "$status" -eq 0 ]
    grep -qF -- "ARGS:-s auto -w $DEFAULT_WIDTH $dir/" "$GLOW_LOG"
}

@test "five files in one invocation are all rendered, each exactly once, in order" {
    files=""
    for i in 1 2 3 4 5; do
        f="$BATS_TEST_TMPDIR/$i.md"
        : > "$f"
        files="$files $f"
    done
    # shellcheck disable=SC2086
    run "$EMDEE_EYES" $files
    [ "$status" -eq 0 ]
    [ "$(grep -c '^ARGS:' "$GLOW_LOG")" -eq 5 ]
    prev_pos=0
    for i in 1 2 3 4 5; do
        pos=$(grep -n -- "── $BATS_TEST_TMPDIR/$i.md ──" <<< "$output" | head -1 | cut -d: -f1)
        [ "$pos" -gt "$prev_pos" ]
        prev_pos="$pos"
    done
}
