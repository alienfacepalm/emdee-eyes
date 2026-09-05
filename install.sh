#!/bin/sh
# Installs emdee-eyes: checks/installs the glow dependency, then symlinks
# bin/emdee-eyes into ~/.local/bin so edits here take effect immediately
# everywhere the command is used. Works on macOS and Linux; on Windows, use
# install.ps1 instead (this script also runs fine under Git Bash/WSL, but
# symlinks and PATH setup are more reliable from install.ps1 there).
set -eu

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="${HOME}/.local/bin"
TARGET="${BIN_DIR}/emdee-eyes"

# Tries, in order, whatever package manager is actually present: the
# system's native one first (apt/dnf/yum/pacman/zypper/apk on Linux), then
# Homebrew/Linuxbrew as a portable fallback that works the same everywhere.
install_glow() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "installing glow via apt..."
        if [ ! -f /etc/apt/sources.list.d/charm.list ]; then
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
            sudo apt-get update
        fi
        sudo apt-get install -y glow
    elif command -v dnf >/dev/null 2>&1; then
        echo "installing glow via dnf..."
        sudo dnf install -y https://repo.charm.sh/yum/charm.repo 2>/dev/null || true
        sudo dnf install -y glow
    elif command -v yum >/dev/null 2>&1; then
        echo "installing glow via yum..."
        sudo yum install -y glow
    elif command -v pacman >/dev/null 2>&1; then
        echo "installing glow via pacman..."
        sudo pacman -Sy --noconfirm glow
    elif command -v apk >/dev/null 2>&1; then
        echo "installing glow via apk..."
        sudo apk add glow
    elif command -v brew >/dev/null 2>&1; then
        echo "installing glow via Homebrew..."
        brew install glow
    else
        echo "install.sh: glow not found and no supported package manager" >&2
        echo "(apt/dnf/yum/pacman/apk/brew) is available." >&2
        echo "Install glow yourself: https://github.com/charmbracelet/glow" >&2
        exit 1
    fi
}

if ! command -v glow >/dev/null 2>&1; then
    install_glow
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

if [ -d "$PROJECT_DIR/.git" ]; then
    git -C "$PROJECT_DIR" config core.hooksPath .githooks
    echo "git hooks: core.hooksPath set to .githooks (runs the test suite before commit/push)"
fi

echo "done. try: emdee-eyes --help"
