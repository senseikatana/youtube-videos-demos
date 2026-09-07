#!/usr/bin/env zsh
# ==============================================================================
# 🦥 LAZY TOOLS - useLazy (lanza la TUI que quieras)
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

# Herramientas disponibles (nombre binario)
_LAZY_TOOLS=(lazygit lazydocker lazynpm lazysql lazycli lazyllama lazyprune lazyrsync sshub)

on_lazy() {
    local tool="$1"
    shift 2>/dev/null

    if [[ -z "$tool" ]]; then
        if command -v gum &>/dev/null; then
            tool=$(gum choose "${_LAZY_TOOLS[@]}" --header " 🦥 LAZY TOOLS · Elige herramienta ")
        else
            echo "${C_CYAN}🦥 Herramientas: ${_LAZY_TOOLS[*]}${C_RESET}"
            printf "Herramienta: " >&2
            read -r tool
        fi
        [[ -z "$tool" ]] && return 0
    fi

    if (( ${_LAZY_TOOLS[(Ie)$tool]} )); then
        command "$tool" "$@"
    else
        echo "${C_RED}❌ Herramienta no reconocida: $tool${C_RESET}"
        echo "Disponibles: ${_LAZY_TOOLS[*]}"
        return 1
    fi
}
