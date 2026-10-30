#!/usr/bin/env bash
#
# dotfiles installer. Replaces the old Makefile with something friendlier for
# the interactive bits (YubiKey extraction, git signing setup).
#
# Usage:
#   ./install.sh            Full setup: packages + stow + git machine-local config
#   ./install.sh all        Everything above PLUS the interactive YubiKey step
#   ./install.sh stow       Symlink every package into ~ with GNU Stow
#   ./install.sh restow     Re-link (use after adding/removing files in a package)
#   ./install.sh unstow     Remove all symlinks
#   ./install.sh check      Dry run: show what stow would do, touching nothing
#   ./install.sh adopt      Pull the machine's existing files into the repo (review after!)
#   ./install.sh packages   Install Homebrew + everything in the Brewfile
#   ./install.sh gitlocal   (Re)write ~/.gitconfig.local with this machine's paths
#   ./install.sh yubikey    Extract the resident SSH keys from a plugged-in YubiKey
#   ./install.sh list       List the stow packages
#
set -euo pipefail

# Resolve the repo root from this script's own location, so it works from any cwd.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="$DOTFILES/Brewfile"

# Keep these in sync with the non-core (tapped) entries in the Brewfile.
# Homebrew refuses tapped formulae/casks until each is explicitly trusted; trust
# is granted per item, not per tap, so a tap can't sneak in anything else later.
TRUSTED_FORMULAE=(felixkratz/formulae/borders)
TRUSTED_CASKS=(nikitabobko/tap/aerospace)

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "this setup requires macOS"
}

# Homebrew is not on PATH immediately after a fresh install, so resolve it
# absolutely and load its environment before anything that needs it.
load_brew() {
  local prefix
  if [[ "$(uname -m)" == "arm64" ]]; then prefix=/opt/homebrew; else prefix=/usr/local; fi
  local brew
  brew="$(command -v brew 2>/dev/null || echo "$prefix/bin/brew")"
  [[ -x "$brew" ]] || die "Homebrew not found at $brew (run './install.sh packages' first)"
  eval "$("$brew" shellenv)"
}

# ---------------------------------------------------------------------------
# stow packages
# ---------------------------------------------------------------------------
# Common stow options (--target, --dotfiles, --ignore) live in .stowrc, which
# stow reads from the repo root, so they apply to manual `stow` calls too.

# Every top-level directory that isn't hidden is a stow package.
packages_list() {
  find "$DOTFILES" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -exec basename {} \; | sort
}

ensure_stow() {
  load_brew
  command -v stow >/dev/null || { log "Installing stow..."; brew install stow; }
}

cmd_list() { packages_list; }

cmd_stow() {
  ensure_stow
  local pkgs; pkgs=$(packages_list)
  log "Linking: $(echo "$pkgs" | tr '\n' ' ')"
  cd "$DOTFILES" && stow $pkgs
}

cmd_restow() {
  ensure_stow
  cd "$DOTFILES" && stow -R $(packages_list)
}

cmd_unstow() {
  ensure_stow
  cd "$DOTFILES" && stow -D $(packages_list)
}

cmd_check() {
  ensure_stow
  cd "$DOTFILES" && stow --simulate --verbose $(packages_list)
}

# Escape hatch for stow conflicts: overwrites REPO contents with the files
# already on this machine. Review the diff it prints afterwards.
cmd_adopt() {
  ensure_stow
  warn "This replaces files in $DOTFILES with the versions already on this machine."
  read -r -p "Continue? [y/N] " a
  [[ "$a" == "y" ]] || die "aborted"
  cd "$DOTFILES" && stow --adopt $(packages_list)
  echo "--- review these changes ---"
  git -C "$DOTFILES" diff --stat
}

# ---------------------------------------------------------------------------
# homebrew packages
# ---------------------------------------------------------------------------

install_homebrew() {
  require_macos
  local prefix brew
  if [[ "$(uname -m)" == "arm64" ]]; then prefix=/opt/homebrew; else prefix=/usr/local; fi
  brew="$(command -v brew 2>/dev/null || echo "$prefix/bin/brew")"
  if [[ ! -x "$brew" ]]; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    log "Homebrew already installed"
  fi
  load_brew
  ensure_shell_path
}

# The Homebrew installer only *prints* the shellenv line; it doesn't add it to
# your shell profile. Our managed ~/.zshrc calls brew, so a fresh-machine login
# shell must have brew on PATH. Append the line once (idempotent) if it's not
# already there. ~/.zprofile stays a real file -- NOT stow-managed -- because
# other installers (Homebrew, OrbStack) append to it too.
ensure_shell_path() {
  local zprofile="$HOME/.zprofile" prefix brew
  if [[ "$(uname -m)" == "arm64" ]]; then prefix=/opt/homebrew; else prefix=/usr/local; fi
  brew="$(command -v brew 2>/dev/null || echo "$prefix/bin/brew")"
  if [[ -f "$zprofile" ]] && grep -q 'brew shellenv' "$zprofile"; then
    return 0
  fi
  log "Adding Homebrew to ~/.zprofile (so new shells find brew)..."
  { echo ''; echo '# Homebrew on PATH (added by install.sh)'; echo "eval \"\$($brew shellenv)\""; } >> "$zprofile"
}

# brew bundle fails hard on tapped items until they're trusted.
trust_taps() {
  log "Trusting third-party taps..."
  local f c
  for f in "${TRUSTED_FORMULAE[@]}"; do brew trust --formula "$f"; done
  for c in "${TRUSTED_CASKS[@]}"; do brew trust --cask "$c"; done
}

cmd_packages() {
  install_homebrew
  trust_taps
  [[ -f "$BREWFILE" ]] || die "Brewfile not found at $BREWFILE"
  log "Installing packages from Brewfile..."
  brew bundle --file="$BREWFILE"
}

# ---------------------------------------------------------------------------
# git machine-local config
# ---------------------------------------------------------------------------

# The committed ~/.gitconfig includes ~/.gitconfig.local. The only
# machine-specific bits are the paths to Homebrew's OpenSSH, which differ
# between Apple Silicon and Intel -- so we resolve and write them here rather
# than hardcoding them in the committed config. This file lives OUTSIDE any
# stow-managed path (~/.config/git is a symlink into the repo), so writing it
# here never leaks a machine path back into version control.
cmd_gitlocal() {
  load_brew
  local ssh_prefix out
  ssh_prefix="$(brew --prefix openssh 2>/dev/null || true)"
  [[ -n "$ssh_prefix" && -x "$ssh_prefix/bin/ssh" ]] || \
    die "brew openssh not found -- run './install.sh packages' first"
  out="$HOME/.gitconfig.local"
  cat > "$out" <<EOF
# Generated by install.sh -- machine-specific paths. Do not edit by hand.
# Regenerate with: ./install.sh gitlocal
[core]
	sshCommand = $ssh_prefix/bin/ssh
[gpg "ssh"]
	program = $ssh_prefix/bin/ssh-keygen
EOF
  log "Wrote $out (ssh: $ssh_prefix/bin/ssh)"
}

# ---------------------------------------------------------------------------
# yubikey resident-key extraction
# ---------------------------------------------------------------------------

# Pulls the FIDO2 resident ("discoverable") SSH keys off a plugged-in YubiKey
# into ~/.ssh. These key-handle files require the physical key to use, so they
# are deliberately NOT tracked in this repo -- run this once per machine.
cmd_yubikey() {
  load_brew
  local keygen
  keygen="$(brew --prefix openssh 2>/dev/null)/bin/ssh-keygen"
  [[ -x "$keygen" ]] || die "brew openssh not found -- run './install.sh packages' first"
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  log "Extracting resident SSH keys from the YubiKey (touch + PIN when prompted)..."
  if ( cd "$HOME/.ssh" && "$keygen" -K ); then
    log "Extracted resident keys into ~/.ssh:"
    ls -1 "$HOME"/.ssh/id_*_sk_rk_* 2>/dev/null || true
    log "If the private key handle lacks 600 perms: chmod 600 ~/.ssh/id_*_sk_rk_*"
  else
    # Non-fatal on purpose: the YubiKey is optional at setup time, so a missing
    # key (or a cancelled prompt) must not fail `all`/bootstrap. Everything else
    # is already done -- just tell the user how to finish later.
    warn "No keys extracted -- YubiKey not detected or prompt cancelled."
    warn "Plug in the key and run './install.sh yubikey' when ready."
  fi
}

# ---------------------------------------------------------------------------
# full install
# ---------------------------------------------------------------------------

# Default target. Deliberately unattended and idempotent: no hardware, no
# prompts, safe to re-run anytime (this is the everyday `git pull && ./install.sh`).
# The interactive YubiKey step is left out on purpose -- run `yubikey` or `all`
# for that. We only *hint* about it, and only when no resident keys are present.
cmd_install() {
  cmd_packages
  cmd_stow
  cmd_gitlocal
  log "Setup complete."
  if ! ls "$HOME"/.ssh/id_*_sk_rk_* >/dev/null 2>&1; then
    log "No YubiKey keys found. When ready, plug it in and run: ./install.sh yubikey"
  fi
}

# Opt-in "do everything" target for a fresh machine, including the interactive
# YubiKey extraction. Routine re-runs should use the default target instead.
cmd_all() {
  cmd_install
  cmd_yubikey
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------

main() {
  local cmd="${1:-install}"
  case "$cmd" in
    install|all|packages|stow|restow|unstow|check|adopt|list|gitlocal|yubikey)
      "cmd_$cmd" ;;
    -h|--help|help)
      # Print the comment header (after the shebang) up to the first code line.
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}" ;;
    *)
      die "unknown command: $cmd (try './install.sh help')" ;;
  esac
}

main "$@"
