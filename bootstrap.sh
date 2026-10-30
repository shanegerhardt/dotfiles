#!/usr/bin/env bash
set -euo pipefail

if [ -z "${HOME:-}" ]; then
    echo "HOME not set"
    exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This setup requires macOS"
    exit 1
fi

# /usr/bin/git exists on stock macOS even without the Command Line Tools, so
# checking for the binary proves nothing -- ask xcode-select instead.
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install || true
    echo "Re-run this script once the installer has finished."
    exit 1
fi

DOTFILES="${DOTFILES:-$HOME/git/dotfiles}"

if [ ! -d "$DOTFILES" ]; then
    echo "Cloning dotfiles into $DOTFILES..."
    git clone https://github.com/shanegerhardt/dotfiles.git "$DOTFILES"
else
    echo "Updating existing dotfiles at $DOTFILES..."
    cd "$DOTFILES"
    if ! git pull --ff-only; then
        echo
        echo "Could not fast-forward $DOTFILES."
        echo "The branch has diverged or local changes are in the way."
        echo "Resolve it manually, then re-run this script."
        exit 1
    fi
fi

cd "$DOTFILES"

if [ ! -f "install.sh" ]; then
    echo "install.sh not found in $DOTFILES"
    exit 1
fi

# Fresh-machine setup: the `all` target does the full install plus the
# interactive YubiKey extraction. If the key isn't plugged in, that last step
# skips gracefully (non-fatal) and prints how to finish later.
echo "Running install.sh all..."
./install.sh all
