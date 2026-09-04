#!/bin/sh
# Installs emdee-eyes: checks/installs the glow dependency, then symlinks
# bin/emdee-eyes into ~/.local/bin so edits here take effect immediately
# everywhere the command is used.
set -eu

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="${HOME}/.local/bin"
TARGET="${BIN_DIR}/emdee-eyes"

if ! command -v glow >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "installing glow via Homebrew..."
        brew install glow
    else
        echo "install.sh: glow not found and Homebrew is not available." >&2
        echo "Install glow yourself: https://github.com/charmbracelet/glow" >&2
        exit 1
    fi
fi

mkdir -p "$BIN_DIR"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$PROJECT_DIR/bin/emdee-eyes" ]; then
        echo "already linked: $TARGET"
    else
        echo "install.sh: $TARGET already exists and isn't this project's link." >&2
        echo "Remove or back it up, then re-run install.sh." >&2
        exit 1
    fi
else
    ln -s "$PROJECT_DIR/bin/emdee-eyes" "$TARGET"
    echo "linked $TARGET -> $PROJECT_DIR/bin/emdee-eyes"
fi

case ":$PATH:" in
    *":$BIN_DIR:"*)
        echo "$BIN_DIR is already on PATH"
        ;;
    *)
        echo "warning: $BIN_DIR is not on your PATH — add it in ~/.zshrc:" >&2
        echo '  export PATH="$HOME/.local/bin:$PATH"' >&2
        ;;
esac

echo "done. try: emdee-eyes --help"
