#!/usr/bin/env zsh
# ==============================================================================
# 🧹 NODE CLEANER - useNmk (limpiar node_modules sin romper nada)
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

_nmk_help() {
    echo "${C_CYAN}Uso: useNmk <cmd> [dir]${C_RESET}"
    echo "  ls [dir]     Lista node_modules con su tamaño"
    echo "  rm [dir]     Elimina node_modules del proyecto (pide confirmación)"
    echo "  sweep        Escanea ~/Proyectos y eliges cuáles eliminar con gum"
    echo "  locks [dir]  Elimina lockfiles y limpia caché de npm (opt-in)"
    echo "Solo toca node_modules y lockfiles — nunca tu código."
    echo "Para restaurar: usePm i en el proyecto."
}

# Lista node_modules bajo un directorio (tamaño + ruta), ordenado por peso
_nmk_find() {
    local dir="$1"
    find "$dir" -name node_modules -type d -prune -exec du -sh {} + 2>/dev/null | sort -hr
}

_nmk_ls() {
    local dir="${1:-.}"
    local found
    found=$(_nmk_find "$dir")
    if [[ -z "$found" ]]; then
        echo "${C_GREEN}✨ Sin node_modules en $dir${C_RESET}"
        return 0
    fi
    echo "$found"
    echo "${C_CYAN}$(echo "$found" | wc -l) node_modules encontrados en $dir${C_RESET}"
}

_nmk_rm() {
    local dir="${1:-.}"
    local found
    found=$(_nmk_find "$dir")
    if [[ -z "$found" ]]; then
        echo "${C_GREEN}✨ Nada que limpiar en $dir${C_RESET}"
        return 0
    fi
    echo "${C_YELLOW}🗑️  Se eliminarán:${C_RESET}"
    echo "$found"
    if _git_ask_yes_no "¿Confirmas la eliminación?"; then
        local -a targets
        targets=("${(f)$(echo "$found" | awk '{print $2}')}")
        rm -rf "${targets[@]}"
        echo "${C_GREEN}✅ node_modules eliminados. Restaura con: usePm i${C_RESET}"
    else
        echo "⏭️  Cancelado."
    fi
}

_nmk_sweep() {
    local base="${1:-$HOME/Proyectos}"
    [[ -d "$base" ]] || { echo "${C_RED}❌ No existe $base${C_RESET}"; return 1; }
    local found
    found=$(_nmk_find "$base")
    if [[ -z "$found" ]]; then
        echo "${C_GREEN}✨ Todos tus proyectos están limpios${C_RESET}"
        return 0
    fi
    echo "${C_YELLOW}📦 node_modules en $base:${C_RESET}"
    echo "$found"
    echo ""

    if command -v gum &>/dev/null; then
        local sel
        sel=$(echo "$found" | awk '{print $2}' | gum choose --no-limit \
            --header " 🧹 Marca con espacio, confirma con enter " \
            --placeholder "Selecciona node_modules a eliminar...")
        [[ -z "$sel" ]] && { echo "⏭️  Cancelado."; return 0; }
        local -a dels
        dels=("${(f)sel}")
        if _git_ask_yes_no "¿Eliminar ${#dels[@]} node_modules?"; then
            rm -rf "${dels[@]}"
            echo "${C_GREEN}✅ ${#dels[@]} node_modules eliminados${C_RESET}"
        fi
    else
        echo "${C_YELLOW}Ejecuta: useNmk rm <proyecto> en cada uno (instala gum para selección múltiple)${C_RESET}"
    fi
}

_nmk_locks() {
    local dir="${1:-.}"
    local -a locks=(package-lock.json yarn.lock pnpm-lock.yaml bun.lockb bun.lock)
    local -a existing
    for f in $locks; do
        [[ -f "$dir/$f" ]] && existing+=("$dir/$f")
    done

    if [[ ${#existing[@]} -eq 0 ]]; then
        echo "${C_GREEN}✨ Sin lockfiles en $dir${C_RESET}"
    else
        echo "${C_YELLOW}🗑️  Se eliminarán los lockfiles:${C_RESET}"
        printf '  %s\n' "${existing[@]}"
        echo "${C_YELLOW}⚠️  Sin lockfile, la próxima instalación puede resolver versiones distintas.${C_RESET}"
        _git_ask_yes_no "¿Confirmas?" || { echo "⏭️  Cancelado."; return 0; }
        rm -f "${existing[@]}"
        echo "${C_GREEN}✅ Lockfiles eliminados${C_RESET}"
    fi

    if _git_ask_yes_no "¿Limpiar también la caché de npm?"; then
        npm cache clean --force
        echo "${C_GREEN}✅ Caché de npm limpia${C_RESET}"
    fi
}

on_nmk() {
    case "$1" in
        ls|list)   shift; _nmk_ls "${1:-.}" ;;
        rm|clean)  shift; _nmk_rm "${1:-.}" ;;
        sweep)     shift; _nmk_sweep "$1" ;;
        locks)     shift; _nmk_locks "${1:-.}" ;;
        -h|--help|help) _nmk_help ;;
        "")
            local opt
            if command -v gum &>/dev/null; then
                opt=$(gum choose \
                    "sweep · escanear ~/Proyectos y elegir" \
                    "ls · node_modules aquí (tamaños)" \
                    "rm · limpiar proyecto actual" \
                    "locks · lockfiles + caché npm" \
                    --header " 🧹 NODE CLEANER · Elige acción ")
                [[ -z "$opt" ]] && return 0
                on_nmk "${opt%% · *}"
            else
                _nmk_help
            fi
            ;;
        *)
            echo "${C_RED}❌ Comando no reconocido: $1${C_RESET}"
            _nmk_help
            return 1
            ;;
    esac
}
