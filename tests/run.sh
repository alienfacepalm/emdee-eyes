#!/bin/sh
# Runs the full emdee-eyes test suite: unit tests (stubbed glow), then
# e2e tests (real glow, real example files).
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)

if ! command -v bats >/dev/null 2>&1; then
    echo "run.sh: bats not found — install it with: brew install bats-core" >&2
    exit 1
fi

echo "== unit tests =="
bats "$DIR/unit"

echo
echo "== e2e tests =="
bats "$DIR/e2e"
