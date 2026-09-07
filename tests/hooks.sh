#!/bin/sh
# Dependency-free tests for the release-tag policy used by pre-push.
set -eu

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CHECK="$PROJECT_DIR/.githooks/check-release-tag"
PRE_PUSH="$PROJECT_DIR/.githooks/pre-push"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

git -C "$TMP_DIR" init -q -b master
git -C "$TMP_DIR" config user.name 'Hook Test'
git -C "$TMP_DIR" config user.email 'hook-test@example.invalid'
printf 'first\n' > "$TMP_DIR/file.txt"
git -C "$TMP_DIR" add file.txt
git -C "$TMP_DIR" commit -qm 'first'

zero_oid=0000000000000000000000000000000000000000
zero_oid_sha256=0000000000000000000000000000000000000000000000000000000000000000

expect_pass() {
    description=$1
    shift
    if ! (cd "$TMP_DIR" && "$CHECK" "$@") >/dev/null 2>&1; then
        echo "hooks.sh: expected pass: $description" >&2
        exit 1
    fi
}

expect_fail() {
    description=$1
    shift
    if (cd "$TMP_DIR" && "$CHECK" "$@") >/dev/null 2>&1; then
        echo "hooks.sh: expected failure: $description" >&2
        exit 1
    fi
}

expect_pre_push_fail() {
    description=$1
    update=$2
    if printf '%s\n' "$update" | (cd "$TMP_DIR" && "$PRE_PUSH" origin unused) >/dev/null 2>&1; then
        echo "hooks.sh: expected pre-push failure: $description" >&2
        exit 1
    fi
}

git -C "$TMP_DIR" tag -a v1.2.3 -m 'Release 1.2.3'
valid_oid=$(git -C "$TMP_DIR" rev-parse v1.2.3)
expect_pass 'annotated SemVer release' refs/tags/v1.2.3 "$valid_oid" "$zero_oid" origin
expect_pass 'SHA-256-format zero remote id' refs/tags/v1.2.3 "$valid_oid" "$zero_oid_sha256" origin

git -C "$TMP_DIR" tag v1.2.4
lightweight_oid=$(git -C "$TMP_DIR" rev-parse v1.2.4)
expect_fail 'lightweight release tag' refs/tags/v1.2.4 "$lightweight_oid" "$zero_oid" origin
expect_pre_push_fail 'lightweight tag update parsing' \
    "refs/tags/v1.2.4 $lightweight_oid refs/tags/v1.2.4 $zero_oid"
expect_pre_push_fail 'release tag deletion' \
    "(delete) $zero_oid refs/tags/v1.2.3 $valid_oid"
git -C "$TMP_DIR" tag -a v1.2.5 -m ''
empty_message_oid=$(git -C "$TMP_DIR" rev-parse v1.2.5)
expect_fail 'empty tag annotation' refs/tags/v1.2.5 "$empty_message_oid" "$zero_oid" origin
expect_fail 'malformed release version' refs/tags/v01.2.3 "$valid_oid" "$zero_oid" origin
expect_fail 'numeric prerelease with a leading zero' refs/tags/v1.2.3-01 "$valid_oid" "$zero_oid" origin
expect_fail 'ref and annotated tag name mismatch' refs/tags/v1.2.6 "$valid_oid" "$zero_oid" origin
git -C "$TMP_DIR" tag -a v1.2.6 -m 'Nested tag' v1.2.3 2>/dev/null
nested_oid=$(git -C "$TMP_DIR" rev-parse v1.2.6)
expect_fail 'tag points to another tag' refs/tags/v1.2.6 "$nested_oid" "$zero_oid" origin
expect_fail 'existing remote release tag' refs/tags/v1.2.3 "$valid_oid" "$valid_oid" origin

git -C "$TMP_DIR" switch -qc side
printf 'side\n' > "$TMP_DIR/side.txt"
git -C "$TMP_DIR" add side.txt
git -C "$TMP_DIR" commit -qm 'side'
git -C "$TMP_DIR" tag -a v2.0.0-rc.1 -m 'Release candidate'
side_oid=$(git -C "$TMP_DIR" rev-parse v2.0.0-rc.1)
expect_fail 'release outside master' refs/tags/v2.0.0-rc.1 "$side_oid" "$zero_oid" origin

# GitHub Actions checks out tags in detached-HEAD mode. Ensure release
# validation can use the remote-tracking default branch without a local one.
git -C "$TMP_DIR" update-ref refs/remotes/origin/master refs/heads/master
git -C "$TMP_DIR" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
git -C "$TMP_DIR" branch -D master >/dev/null
expect_pass 'remote-tracking release branch' refs/tags/v1.2.3 "$valid_oid" "$zero_oid" origin

echo 'hooks.sh: release hook tests passed'
