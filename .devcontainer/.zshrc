# ZDOTDIR entrypoint for devcontainer.
#
# REQUIRED: This directory is set as ZDOTDIR in devcontainer.json.
# When zsh starts, it reads $ZDOTDIR/.zshrc instead of ~/.zshrc,
# which lets us intercept startup and route through .zsh-entrypoint.
# Without this, zsh would read ~/.zshrc directly and we'd have no
# devcontainer-specific entrypoint.

source "$HOME/m/.devcontainer/.zsh-entrypoint"
