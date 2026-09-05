#!/bin/sh
# Runs the sh-implementation (bin/emdee-eyes) test suite: unit tests
# (stubbed glow), regression tests (stubbed glow, specific past-bug and
# edge-case coverage), then e2e tests (real glow, real example files).
#
# This only covers the POSIX sh implementation. See tests/run.ps1 for the
# PowerShell implementation's equivalent suite (bin/emdee-eyes.ps1), and
# tests/verify.sh to run whichever of the two this machine can.
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)

if ! command -v bats >/dev/null 2>&1; then
    echo "run.sh: bats not found — install it with: brew install bats-core" >&2
    exit 1
fi

echo "== unit tests =="
bats "$DIR/unit"

echo
echo "== regression tests =="
bats "$DIR/regression"

echo
echo "== e2e tests =="
bats "$DIR/e2e"
