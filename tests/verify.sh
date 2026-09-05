#!/bin/sh
# Runs every test suite this machine is set up to run — tests/run.sh (bats,
# for bin/emdee-eyes) and/or tests/run.ps1 (Pester, for bin/emdee-eyes.ps1)
# — and fails if either suite fails, or if neither could run at all. This
# is what .githooks/pre-commit and .githooks/pre-push call; run it by hand
# any time you want the same check they'll do.
set -u
DIR=$(cd "$(dirname "$0")/.." && pwd)

ran_any=0
failed=0

if command -v bats >/dev/null 2>&1; then
    ran_any=1
    "$DIR/tests/run.sh" || failed=1
else
    echo "verify.sh: bats not found — skipping the sh-implementation suite (install with: brew install bats-core)" >&2
fi

pwsh_cmd=""
if command -v pwsh >/dev/null 2>&1; then
    pwsh_cmd=pwsh
elif command -v powershell >/dev/null 2>&1; then
    pwsh_cmd=powershell
fi

if [ -n "$pwsh_cmd" ]; then
    ran_any=1
    "$pwsh_cmd" -NoProfile -File "$DIR/tests/run.ps1" || failed=1
else
    echo "verify.sh: pwsh/powershell not found — skipping the PowerShell-implementation suite" >&2
fi

if [ "$ran_any" -eq 0 ]; then
    echo "verify.sh: no test runner found on this machine — install bats-core and/or PowerShell (pwsh) to verify" >&2
    exit 1
fi

exit "$failed"
