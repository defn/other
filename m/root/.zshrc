# defn shell environment
#
# This is the standard zsh config, sourced by both:
#   - Direct zsh login (zsh -l)
#   - Devcontainer entrypoint chain (.zsh_devcontainer → here)

export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/bin:$HOME/m/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

export MISE_EXPERIMENTAL=1
# Skip config-file discovery inside the artifact-fs FUSE mount. Env var is
# the only working route: jdx/mise#4758 -- ignored_config_paths in
# .miserc.toml / config.toml is silently dropped.
export MISE_IGNORED_CONFIG_PATHS="$HOME/afs"
export HISTSIZE=100000
export SAVEHIST=100000

eval "$(mise activate zsh)"

export STARSHIP_CONFIG="$HOME/.config/starship.toml"
eval "$(starship init zsh)"

export GIT_EXTERNAL_DIFF="difft"

gs() { git status -sb "$@"; }
k() { kubectl "$@"; }

# vi/vim -- open files in the IDE when inside VS Code, otherwise use real vi.
vi() {
    if [[ -n ${VSCODE_GIT_ASKPASS_MAIN-} ]]; then
        local code="${VSCODE_GIT_ASKPASS_MAIN%/extensions/*}/bin/code"
        if [[ ! -x "$code" ]]; then
            code="${VSCODE_GIT_ASKPASS_MAIN%/extensions/*}/bin/remote-cli/code"
        fi
        if [[ -x "$code" ]]; then
            "$code" "$@"
            return $?
        fi
    fi
    command vi "$@"
}
alias vim=vi

# m() -- mise task runner shorthand.
# Usage: m <task> [args...]   → mise run <task> -- [args...]
#        m                    → mise run default
m() {
    local task=default
    if [[ $# -gt 0 && $1 != --* ]]; then
        task=$1; shift
    fi
    if [[ -z "$(git rev-parse --show-cdup 2>/dev/null)" && -d m ]]; then
        (cd m && MISE_RAW=1 MISE_QUIET=true mise run "$task" -- "$@")
    else
        MISE_RAW=1 MISE_QUIET=true mise run "$task" -- "$@"
    fi
}

# code() -- Find the right VS Code binary depending on context.
# VSCODE_GIT_ASKPASS_MAIN is set by VS Code in its integrated terminal,
# and its path reveals which VS Code variant launched us.
code() {
    case "${VSCODE_GIT_ASKPASS_MAIN-}" in
    /Applications/Visual*)
        exec "${VSCODE_GIT_ASKPASS_MAIN%%extensions/*}"/bin/code "$@"
        ;;
    */.vscode-server/*)
        exec "${VSCODE_GIT_ASKPASS_MAIN%%extensions/*}"/bin/remote-cli/code-server "$@"
        ;;
    *code-server*)
        exec "${VSCODE_GIT_ASKPASS_MAIN%%extensions/*}"/bin/remote-cli/code-server "$@"
        ;;
    esac
    local c="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    if [[ -x "$c" ]]; then
        exec "$c" "$@"
    fi
    exec code-server "$@"
}
