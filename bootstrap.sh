#!/usr/bin/env bash
set -euo pipefail

[ -z "${HOME:-}" ] && { echo "HOME not set"; exit 1; }
[[ "$(uname -s)" != "Darwin" ]] && { echo "This setup requires macOS"; exit 1; }
command -v git >/dev/null || { echo "Git is required"; exit 1; }

DOTFILES="$HOME/git/dotfiles"

if [ ! -d "$DOTFILES" ]; then
    echo "Cloning dotfiles into $DOTFILES..."
    git clone https://github.com/shanegerhardt/dotfiles.git "$DOTFILES"
else
    echo "Updating existing dotfiles at $DOTFILES..."
    cd "$DOTFILES"
    git pull --ff-only
fi

cd "$DOTFILES"
[ -f "Makefile" ] || { echo "Makefile not found"; exit 1; }

echo "Running Makefile install..."
make install
