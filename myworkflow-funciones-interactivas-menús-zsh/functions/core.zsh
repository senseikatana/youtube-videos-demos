#!/usr/bin/env zsh
# ==============================================
# 🧠 FUNCIONES NÚCLEO DEL DOJO
# ==============================================

# --- Colores ANSI ---
export C_RED='\e[1;31m'
export C_GREEN='\e[1;32m'
export C_BLUE='\e[1;34m'
export C_CYAN='\e[1;36m'
export C_YELLOW='\e[1;33m'
export C_PURPLE='\e[1;35m'
export C_RESET='\e[0m'

# --- Funciones auxiliares de Git ---
_git_check_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        print -P "%F{red}❌ No estás dentro de un repositorio Git.%f"
        return 1
    fi
    return 0
}

_git_current_branch() {
    git branch --show-current 2>/dev/null || echo "detached"
}

_git_list_branches() {
    git branch --format="%(refname:short)" | while read -r branch; do
        echo "  $branch"
    done
}

_git_ask_yes_no() {
    local prompt="$1"
    local response
    if command -v gum &>/dev/null; then
        gum confirm "$prompt" && return 0 || return 1
    else
        print -n "$prompt (y/N): "
        read -r response
        [[ "$response" =~ ^[yY]$ ]] && return 0 || return 1
    fi
}

_show_help() {
    local cmd="$1"
    if [[ "$cmd" == "-h" || "$cmd" == "--help" ]]; then
        return 0
    fi
    return 1
}


# ==============================================
# 💾 SYNC
# ==============================================
sync-zsh() {
    local src="$HOME/.zsh"
    local dst="$HOME/Proyectos/snippets-codes-vault/05_shell_configs/.zsh"
    local vault="$HOME/Proyectos/snippets-codes-vault"

    rsync -av --delete --exclude='.zcode' "$src/" "$dst/"

    (cd "$vault" && git add . && git commit -m "chore: sync .zsh configs" && git push)
}







