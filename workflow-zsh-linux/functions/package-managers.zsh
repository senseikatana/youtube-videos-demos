#!/usr/bin/env zsh
# ==============================================================================
# 📦 PACKAGE MANAGERS - usePm (npm · pnpm · yarn · bun)
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

_pm_help() {
    echo "${C_CYAN}Uso: usePm [npm|pnpm|yarn|bun] <cmd> [args]${C_RESET}"
    echo "Sin <pm> se detecta por el lockfile del proyecto."
    echo "${C_CYAN}Atajos directos (fuerzan el gestor):${C_RESET} usePmNpm · usePmPnpm · usePmYarn · usePmBun"
    echo "Cualquier comando no tabulado pasa directo al gestor (opciones nativas)."
    echo "${C_CYAN}Comandos:${C_RESET}"
    echo "  i, install        Instala dependencias"
    echo "  a, add            Añade paquete(s)"
    echo "  ad                Añade como dev (-D)"
    echo "  ag                Añade global (-g)"
    echo "  rm, remove        Elimina paquete(s)"
    echo "  r, run            Ejecuta script (usePm r build)"
    echo "  dev|build|start|test   Scripts frecuentes"
    echo "  up, update        Actualiza dependencias"
    echo "  ls, list          Lista dependencias"
    echo "  out, outdated     Muestra desactualizados"
    echo "  ci                Instala con lockfile congelado"
    echo "  init              Inicializa proyecto"
    echo "  x                 Binario remoto (npx/dlx/bunx)"
}

# Detecta el gestor por lockfile del proyecto actual
_pm_detect() {
    if [[ -f bun.lockb || -f bun.lock ]]; then echo bun
    elif [[ -f pnpm-lock.yaml ]]; then echo pnpm
    elif [[ -f yarn.lock ]]; then echo yarn
    elif [[ -f package-lock.json ]]; then echo npm
    else return 1
    fi
}

# Pide gestor manualmente (salida por stdout)
_pm_pick() {
    if command -v gum &>/dev/null; then
        gum choose npm pnpm yarn bun --header " 📦 ¿Qué gestor usa este proyecto? "
    else
        print -n "Gestor (npm/pnpm/yarn/bun): " >&2
        local p
        read -r p
        echo "$p"
    fi
}

# Menú de comandos (salida por stdout); $1 = pm para el header
_pm_cmd_menu() {
    local pm="$1"
    local -a cmds=(i add ad ag rm run dev build start test up ls outdated ci init x)
    if command -v gum &>/dev/null; then
        gum choose "${cmds[@]}" --header " 📦 usePm $pm · comando "
    else
        echo "Comandos: ${cmds[*]}" >&2
        printf "Comando: " >&2
        local c
        read -r c
        echo "$c"
    fi
}

# Ejecuta <cmd> del gestor <pm>; resto de args pasan al final
_pm_run() {
    local pm="$1" cmd="$2"
    shift 2

    case "$cmd" in
        i|install)
            case "$pm" in
                npm) npm install "$@" ;;
                pnpm) pnpm install "$@" ;;
                yarn) yarn install "$@" ;;
                bun) bun install "$@" ;;
            esac ;;
        a|add)
            case "$pm" in
                npm) npm install "$@" ;;
                *) "$pm" add "$@" ;;
            esac ;;
        ad)
            case "$pm" in
                npm) npm install -D "$@" ;;
                pnpm) pnpm add -D "$@" ;;
                yarn) yarn add -D "$@" ;;
                bun) bun add -d "$@" ;;
            esac ;;
        ag)
            case "$pm" in
                npm) npm install -g "$@" ;;
                pnpm) pnpm add -g "$@" ;;
                yarn) yarn global add "$@" ;;
                bun) bun add -g "$@" ;;
            esac ;;
        rm|remove)
            case "$pm" in
                npm) npm uninstall "$@" ;;
                *) "$pm" remove "$@" ;;
            esac ;;
        r|run)              "$pm" run "$@" ;;
        dev|build|start|test) "$pm" run "$cmd" ;;
        up|update)
            case "$pm" in
                yarn) yarn upgrade "$@" ;;
                *) "$pm" update "$@" ;;
            esac ;;
        ls|list)
            case "$pm" in
                npm|pnpm) "$pm" ls "$@" ;;
                yarn) yarn list "$@" ;;
                bun) bun pm ls "$@" ;;
            esac ;;
        out|outdated)
            case "$pm" in
                bun) bun outdated ;;
                *) "$pm" outdated "$@" ;;
            esac ;;
        ci)
            case "$pm" in
                npm) npm ci ;;
                pnpm) pnpm install --frozen-lockfile ;;
                yarn) yarn install --frozen-lockfile ;;
                bun) bun install --frozen-lockfile ;;
            esac ;;
        init)
            case "$pm" in
                npm) npm init -y ;;
                yarn) yarn init -y ;;
                *) "$pm" init ;;
            esac ;;
        x)
            case "$pm" in
                npm|yarn) npx "$@" ;;
                pnpm) pnpm dlx "$@" ;;
                bun) bunx "$@" ;;
            esac ;;
        *)
            # Comando nativo del gestor no tabulado → passthrough directo
            "$pm" "$cmd" "$@"
            ;;
    esac
}

on_pm() {
    local pm
    case "$1" in
        npm|pnpm|yarn|bun) pm="$1"; shift ;;
        -h|--help|help)    _pm_help; return 0 ;;
        "")
            if command -v gum &>/dev/null; then
                pm=$(_pm_pick)
                [[ -z "$pm" ]] && return 0
            else
                pm=$(_pm_detect) || pm=$(_pm_pick)
                [[ -z "$pm" ]] && { echo "${C_RED}❌ Sin gestor no hay nada que hacer${C_RESET}"; return 1; }
            fi
            ;;
        *) pm="" ;;
    esac

    # Si no se indicó gestor, detectar por lockfile (o pedir)
    if [[ -z "$pm" ]]; then
        pm=$(_pm_detect)
        if [[ -z "$pm" ]]; then
            pm=$(_pm_pick)
            [[ -z "$pm" ]] && { echo "${C_RED}❌ No hay lockfile y no elegiste gestor. Usa: usePm <pm> <cmd>${C_RESET}"; return 1; }
        fi
    fi

    _pm_exec "$pm" "$@"
}

# Ejecuta <cmd> con el gestor ya resuelto (compartido por usePm y los atajos por gestor)
_pm_exec() {
    local pm="$1"; shift

    # Sin comando → menú de comandos
    if [[ $# -eq 0 ]]; then
        local cmd
        cmd=$(_pm_cmd_menu "$pm")
        [[ -z "$cmd" ]] && return 0
        set -- "$cmd"
    fi

    local cmd="$1"
    shift

    [[ "$cmd" == -h || "$cmd" == --help || "$cmd" == help ]] && { _pm_help; return 0; }

    # Comandos que necesitan nombres de paquete
    if [[ "$cmd" == (a|add|ad|ag|rm|remove) && $# -eq 0 ]]; then
        local input
        if command -v gum &>/dev/null; then
            input=$(gum input --placeholder "paquete1 paquete2 ..." --header " 📦 $pm $cmd ")
        else
            printf "Paquete(s): " >&2
            read -r input
        fi
        [[ -z "$input" ]] && { echo "${C_RED}❌ No se especificó ningún paquete${C_RESET}"; return 1; }
        set -- ${(z)input}
    fi

    echo "${C_CYAN}📦 [$pm] $cmd${C_RESET} $*"
    _pm_run "$pm" "$cmd" "$@"
}

# ==============================================
# 📦 PACKAGE MANAGERS - Atajos por gestor
# ==============================================
# Para cuando cambias de gestor en el mismo proyecto (ej: Nuxt bun → pnpm).
# Fuerzan el gestor sin autodetección; comando no tabulado → passthrough nativo.
on_pm_npm()  { _pm_exec npm "$@" }
on_pm_pnpm() { _pm_exec pnpm "$@" }
on_pm_yarn() { _pm_exec yarn "$@" }
on_pm_bun()  { _pm_exec bun "$@" }
