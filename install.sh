#!/usr/bin/env bash

if [ -z "$HOME" ]; then
  echo "Could not locate \$HOME dir"
  exit 1
fi

# Determine OS
OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
    echo "This script requires macOS"
    exit 1
fi

install_homebrew() {
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew already installed"
    fi
}

install_packages() {
    echo "Installing packages..."
    brew install stow fzf eza zoxide starship lazygit zsh-autosuggestions
    brew install --cask raycast zed nikitabobko/tap/aerospace font-jetbrains-mono
}

stow_dotfiles() {
    DOTFILES=$HOME/git/dotfiles

    if [ ! -d "$DOTFILES" ]; then
      git clone git@github.com:shanegerhardt/dotfiles.git "$DOTFILES"
      cd "$DOTFILES" || exit
    else
      cd "$DOTFILES" || exit
      git pull origin main
    fi

    echo "Linking dotfiles with stow..."
    stow aerospace ghostty git starship zed zsh
}


main() {
    install_homebrew
    install_packages
    stow_dotfiles
    echo "Setup complete."
}

main "$@"
