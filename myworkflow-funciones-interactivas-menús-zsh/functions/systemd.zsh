#!/usr/bin/env zsh
# ==============================================================================
# ⚙️ SYSTEMD - useSysd (servicios de sistema y usuario)
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

_sysd_help() {
    echo "${C_CYAN}Uso: useSysd <acción> [unidad]  ·  acciones con 'u' = nivel --user${C_RESET}"
    echo "  s|start   t|status   x|stop   r|restart"
    echo "  e|enable (--now)     d|disable"
    echo "  us|ut|ux|ur|ue|ud    mismas acciones a nivel usuario"
    echo "Ejemplos: useSysd t nginx · useSysd ut pipewire · useSysd e docker"
}

# Pide el nombre de la unidad (salida: solo el valor)
_sysd_ask_unit() {
    if command -v gum &>/dev/null; then
        gum input --placeholder "nombre-de-unidad (ej: nginx.service)" --header " ⚙️ systemctl · unidad "
    else
        printf "Unidad: " >&2
        local u
        read -r u
        echo "$u"
    fi
}

_sysd_exec() {
    local scope="$1" verb="$2" unit="$3"
    if [[ -n "$scope" ]]; then
        systemctl $scope ${=verb} "$unit"
    elif [[ "$verb" == status ]]; then
        systemctl status "$unit"
    else
        sudo systemctl ${=verb} "$unit"
    fi
}

on_sysd() {
    local action="$1" unit="$2"

    if [[ -z "$action" || "$action" == "-h" || "$action" == "--help" ]]; then
        if [[ -z "$action" ]] && command -v gum &>/dev/null; then
            action=$(gum choose \
                "t · status (sistema)" \
                "s · start (sistema)" \
                "x · stop (sistema)" \
                "r · restart (sistema)" \
                "e · enable --now (sistema)" \
                "d · disable (sistema)" \
                "ut · status (usuario)" \
                "us · start (usuario)" \
                "ux · stop (usuario)" \
                "ur · restart (usuario)" \
                "ue · enable --now (usuario)" \
                "ud · disable (usuario)" \
                --header " ⚙️ SYSTEMD · Elige acción ")
            [[ -z "$action" ]] && return 0
            action="${action%% · *}"
        else
            _sysd_help
            [[ -z "$action" ]] && return 0
            return 0
        fi
    fi

    local scope="" verb=""
    case "$action" in
        s|start)  verb="start" ;;
        x|stop)   verb="stop" ;;
        r|restart) verb="restart" ;;
        t|status) verb="status" ;;
        e|enable) verb="enable --now" ;;
        d|disable) verb="disable" ;;
        us) verb="start"; scope="--user" ;;
        ut) verb="status"; scope="--user" ;;
        ux) verb="stop"; scope="--user" ;;
        ur) verb="restart"; scope="--user" ;;
        ue) verb="enable --now"; scope="--user" ;;
        ud) verb="disable"; scope="--user" ;;
        *)
            echo "${C_RED}❌ Acción no reconocida: $action${C_RESET}"
            _sysd_help
            return 1
            ;;
    esac

    [[ -z "$unit" ]] && { unit=$(_sysd_ask_unit); [[ -z "$unit" ]] && return 1; }
    _sysd_exec "$scope" "$verb" "$unit"
}
