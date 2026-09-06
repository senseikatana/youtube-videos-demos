#!/usr/bin/env zsh
# ==============================================================================
# 🧩 ZINIT - useZinit (gestor de plugins)
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

_zinit_help() {
    echo "${C_CYAN}Uso: useZinit <cmd>${C_RESET}"
    echo "  self        Self-update de zinit"
    echo "  up          update de plugins"
    echo "  all         self-update + update --all"
    echo "  clean       delete --clean (plugins sin usar)"
    echo "  ls          listar plugins"
    echo "  times       tiempos de carga"
    echo "  cclear      limpiar completiones huérfanas"
    echo "  creinstall  reinstalar completiones (-q .)"
}

on_zinit() {
    case "$1" in
        self)          zinit self-update ;;
        up)            zinit update ;;
        all)           zinit self-update --no-pager && zinit update --all ;;
        clean|cl)      zinit delete --clean ;;
        ls|list)       zinit ls ;;
        times|t)       zinit times ;;
        cclear|cc)     zinit cclear ;;
        creinstall|cri) zinit creinstall -q . ;;
        -h|--help|help) _zinit_help ;;
        "")
            local opt
            if command -v gum &>/dev/null; then
                opt=$(gum choose \
                    "all · self-update + update --all" \
                    "self · self-update de zinit" \
                    "up · update de plugins" \
                    "clean · borrar plugins sin usar" \
                    "ls · listar plugins" \
                    "times · tiempos de carga" \
                    "cclear · limpiar completiones" \
                    "creinstall · reinstalar completiones" \
                    --header " 🧩 ZINIT · Elige acción ")
                [[ -z "$opt" ]] && return 0
                on_zinit "${opt%% · *}"
            else
                _zinit_help
            fi
            ;;
        *)
            echo "${C_RED}❌ Comando no reconocido: $1${C_RESET}"
            _zinit_help
            return 1
            ;;
    esac
}
