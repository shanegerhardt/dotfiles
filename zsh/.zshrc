# File system
alias ls='eza --grid --color=auto --git --no-filesize --icons=always --no-time --no-user --no-permissions'
alias ff="fzf --preview 'bat --style=numbers --color=always {}' --print0 | xargs -0 -o nvim"
alias cd='z'

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
