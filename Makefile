SHELL := /bin/bash
.DEFAULT_GOAL := install

DOTFILES := $(HOME)/git/dotfiles
BREWFILE := $(DOTFILES)/Brewfile

UNAME_S := $(shell uname -s)

.PHONY: install check-os brew stow packages

check-os:
	@if [[ "$(UNAME_S)" != "Darwin" ]]; then \
		echo "This setup requires macOS"; \
		exit 1; \
	fi

brew: check-os
	@if ! command -v brew &>/dev/null; then \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "Homebrew already installed"; \
	fi

stow: brew
	@brew install stow
	@echo "Linking dotfiles with stow..."
	@cd "$(DOTFILES)" && stow --dotfiles aerospace borders intellij ghostty git starship zed zsh

packages: brew
	@if [[ ! -f "$(BREWFILE)" ]]; then \
		echo "Brewfile not found at $(BREWFILE)"; \
		exit 1; \
	fi
	@echo "Installing packages from Brewfile..."
	@brew bundle --file="$(BREWFILE)"

install: brew stow packages
	@echo "Setup complete."
