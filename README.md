# dotfiles

macOS dotfiles, linked with [GNU Stow](https://www.gnu.org/software/stow/).

## New machine — `bootstrap.sh`

Run before the repo exists on the machine. It verifies macOS, installs the
Xcode Command Line Tools (needed for git), clones this repo to `~/git/dotfiles`,
then runs `./install.sh all`:

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/shanegerhardt/dotfiles/main/bootstrap.sh)"
```

## Everyday use — `install.sh`

Run from inside the repo once it's cloned. Re-runnable and idempotent:

```shell
cd ~/git/dotfiles && git pull && ./install.sh
```

`./install.sh` with no argument does a full setup: Homebrew + Brewfile, stow all
packages, and generate the machine-local git config. Subcommands:

| Command                 | What it does                                                        |
| ----------------------- | ------------------------------------------------------------------- |
| `./install.sh`          | Full setup (packages + stow + gitlocal) — unattended, re-runnable   |
| `./install.sh all`      | Everything above **plus** the interactive YubiKey step              |
| `./install.sh stow`     | Symlink every package into `~`                                      |
| `./install.sh restow`   | Re-link after adding/removing files in a package                    |
| `./install.sh unstow`   | Remove all symlinks                                                  |
| `./install.sh check`    | Dry run — show what stow would do, touching nothing                 |
| `./install.sh adopt`    | Pull the machine's existing files into the repo (review after!)     |
| `./install.sh packages` | Install Homebrew + everything in the Brewfile                       |
| `./install.sh gitlocal` | (Re)write `~/.gitconfig.local` with this machine's Homebrew paths   |
| `./install.sh yubikey`  | Extract the resident SSH keys from a plugged-in YubiKey into `~/.ssh` |
| `./install.sh list`     | List the stow packages                                              |

## How it's organized

- Each top-level directory is a stow package (`git`, `ssh`, `zsh`, ...). Files
  use the `dot-` prefix convention (`dot-gitconfig` → `~/.gitconfig`) via stow's
  `--dotfiles` flag; see [`.stowrc`](.stowrc).
- `git/dot-gitconfig` holds only portable config. The one machine-specific
  piece — the paths to Homebrew's OpenSSH, which differ on Apple Silicon vs
  Intel — is generated into `~/.gitconfig.local` by `./install.sh gitlocal` and
  pulled in with an `[include]`. It lives outside the repo, so nothing
  machine-specific is ever committed.
