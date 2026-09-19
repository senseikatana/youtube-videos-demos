#!/usr/bin/env zsh
# ==============================================================================
# 📦 PKG - Paquetes y actualizaciones del sistema (paru + flatpak + snap)
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}


# ==============================================================================
# 📦 PKG - Helpers
# ==============================================================================
_pkg_help() {
    echo "${C_CYAN}Uso: usePkg <comando> | usePkg -h${C_RESET}"
    echo "${C_CYAN}Actualizaciones:${C_RESET}"
    echo "  u, update   : Actualiza todo (paru → flatpak → snap), confirmando cada paso"
    echo "  sys         : Solo repositorios + AUR (paru -Syu)"
    echo "  f, flatpak  : Solo Flatpak"
    echo "  s, snap     : Solo Snap"
    echo "  check       : Muestra actualizaciones pendientes"
    echo "  c, clean    : Limpia caché de pacman y huérfanos"
    echo "${C_CYAN}Paquetes:${C_RESET}"
    echo "  i, install  : Instalar paquete(s) con paru"
    echo "  r, remove   : Eliminar paquete(s) con paru"
    echo "  k, keys     : Actualizar llaves de pacman"
    echo "  conf        : Editar pacman.conf"
    echo "Sin argumentos abre el menú interactivo."
    echo "Para limpieza general del sistema usa ${C_CYAN}useCleanup${C_RESET}."
}

# Verifica que un comando exista; $2 = hint de instalación (opcional)
_pkg_require() {
    if ! command -v "$1" &>/dev/null; then
        echo "${C_RED}❌ Error: $1 no está instalado.${C_RESET}"
        [[ -n "$2" ]] && echo "📦 Instala con: ${C_YELLOW}$2${C_RESET}"
        return 1
    fi
}

_pkg_keys() {
    echo "${C_YELLOW}🔑 Actualizando llaves...${C_RESET}"
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
    sudo pacman -Sy archlinux-keyring
}

_pkg_conf() {
    sudo "${EDITOR:-nano}" /etc/pacman.conf
}

_pkg_sys() {
    _pkg_require paru "sudo pacman -S paru" || return 1
    echo "${C_CYAN}🚀 Actualizando repositorios y AUR (paru -Syu)...${C_RESET}"
    paru -Syu
}

_pkg_flatpak() {
    _pkg_require flatpak || return 1
    echo "${C_CYAN}🧩 Actualizando Flatpak...${C_RESET}"
    flatpak update
}

_pkg_snap() {
    _pkg_require snap || return 1
    echo "${C_CYAN}🗂️  Actualizando Snap...${C_RESET}"
    sudo snap refresh
}

_pkg_check() {
    _pkg_require paru "sudo pacman -S paru" || return 1
    echo "${C_CYAN}🔍 Buscando actualizaciones pendientes...${C_RESET}"
    local updates
    updates=$(paru -Qu 2>/dev/null)
    if [[ -z "$updates" ]]; then
        echo "${C_GREEN}✅ Todo actualizado.${C_RESET}"
        return 0
    fi
    echo "$updates"
    echo "${C_YELLOW}📌 $(echo "$updates" | wc -l) paquetes pendientes. Ejecuta ${C_RESET}usePkg sys${C_YELLOW} para actualizar.${C_RESET}"
}

# Limpieza de caché de paquetes (compartida con on_cleanup en utils.zsh)
_pkg_paccache() {
    echo "${C_YELLOW}🧹 Limpiando caché de paquetes (se conservan 2 versiones)...${C_RESET}"
    sudo paccache -rk2 && sudo paccache -ruk0
}

_pkg_clean() {
    _pkg_paccache

    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null)
    if [[ -n "$orphans" ]]; then
        echo "${C_YELLOW}🗑️  Huérfanos encontrados:${C_RESET}"
        echo "$orphans"
        if _git_ask_yes_no "¿Eliminar huérfanos?"; then
            sudo pacman -Rns -- ${(f)orphans}
        fi
    else
        echo "${C_GREEN}✨ No hay huérfanos.${C_RESET}"
    fi
}

_pkg_all() {
    local failed=0
    echo "${C_CYAN}🚀 Actualización completa: paru → flatpak → snap${C_RESET}"

    if _pkg_require paru "sudo pacman -S paru" && _git_ask_yes_no "¿Actualizar sistema + AUR (paru -Syu)?"; then
        _pkg_sys || failed=1
    fi
    if command -v flatpak &>/dev/null && _git_ask_yes_no "¿Actualizar Flatpak?"; then
        _pkg_flatpak || failed=1
    fi
    if command -v snap &>/dev/null && _git_ask_yes_no "¿Actualizar Snap?"; then
        _pkg_snap || failed=1
    fi

    if [[ $failed -eq 0 ]]; then
        echo "${C_GREEN}✅ Actualización completa finalizada.${C_RESET}"
    else
        echo "${C_YELLOW}⚠️  La actualización terminó con errores. Revisa la salida de arriba.${C_RESET}"
        return 1
    fi
}

# Instalar/eliminar desde el menú (pide nombre(s) de paquete)
_pkg_menu_install() {
    local input
    if command -v gum &>/dev/null; then
        input=$(gum input --placeholder "paquete1 paquete2 ..." --header " 📥 Instalar con paru ")
    else
        print -n "📥 Paquete(s) a instalar: "
        read -r input
    fi
    [[ -z "$input" ]] && { echo "${C_RED}❌ No se especificó ningún paquete${C_RESET}"; return 1; }
    echo "${C_CYAN}📦 Instalando: $input${C_RESET}"
    paru -S ${(z)input}
}

_pkg_menu_remove() {
    local input
    if command -v gum &>/dev/null; then
        input=$(gum input --placeholder "paquete1 paquete2 ..." --header " 🗑️  Eliminar con paru ")
    else
        print -n "🗑️  Paquete(s) a eliminar: "
        read -r input
    fi
    [[ -z "$input" ]] && { echo "${C_RED}❌ No se especificó ningún paquete${C_RESET}"; return 1; }
    echo "${C_CYAN}🗑️  Eliminando: $input${C_RESET}"
    paru -Rns ${(z)input}
}

_pkg_menu() {
    local opt
    if command -v gum &>/dev/null; then
        opt=$(gum choose \
            "🚀 Actualizar todo (paru + flatpak + snap)" \
            "📦 Solo sistema + AUR (paru)" \
            "🧩 Solo Flatpak" \
            "🗂️  Solo Snap" \
            "🔍 Ver actualizaciones pendientes" \
            "🧹 Limpiar caché y huérfanos" \
            "📥 Instalar paquete(s)" \
            "🗑️  Eliminar paquete(s)" \
            "🔑 Actualizar llaves de pacman" \
            "⚙️  Editar pacman.conf" \
            --header " 📦 PKG · Paquetes y actualizaciones ")
        case "$opt" in
            *"Actualizar todo"*) _pkg_all ;;
            *paru*)              _pkg_sys ;;
            *Flatpak*)           _pkg_flatpak ;;
            *Snap*)              _pkg_snap ;;
            *pendientes*)        _pkg_check ;;
            *Limpiar*)           _pkg_clean ;;
            *Instalar*)          _pkg_menu_install ;;
            *Eliminar*)          _pkg_menu_remove ;;
            *llaves*)            _pkg_keys ;;
            *pacman.conf*)       _pkg_conf ;;
        esac
    else
        echo "${C_CYAN}📦 PKG — Paquetes y actualizaciones${C_RESET}"
        echo "  1)  Actualizar todo (paru + flatpak + snap)"
        echo "  2)  Solo sistema + AUR (paru)"
        echo "  3)  Solo Flatpak"
        echo "  4)  Solo Snap"
        echo "  5)  Ver actualizaciones pendientes"
        echo "  6)  Limpiar caché y huérfanos"
        echo "  7)  Instalar paquete(s)"
        echo "  8)  Eliminar paquete(s)"
        echo "  9)  Actualizar llaves de pacman"
        echo "  10) Editar pacman.conf"
        print -n "Elige una opción [1-10]: "
        read -r opt
        case "$opt" in
            1)  _pkg_all ;;
            2)  _pkg_sys ;;
            3)  _pkg_flatpak ;;
            4)  _pkg_snap ;;
            5)  _pkg_check ;;
            6)  _pkg_clean ;;
            7)  _pkg_menu_install ;;
            8)  _pkg_menu_remove ;;
            9)  _pkg_keys ;;
            10) _pkg_conf ;;
            *) echo "${C_RED}❌ Opción inválida${C_RESET}"; return 1 ;;
        esac
    fi
}


# ==============================================================================
# 📦 PKG - Comando principal
# ==============================================================================
on_pkg() {
    case "$1" in
        u|update)     _pkg_all ;;
        sys|system)   _pkg_sys ;;
        f|flatpak)    _pkg_flatpak ;;
        s|snap)       _pkg_snap ;;
        check|status) _pkg_check ;;
        c|clean)      _pkg_clean ;;
        i|install)
            _pkg_require paru "sudo pacman -S paru" || return 1
            shift
            [[ -z "$1" ]] && { echo "${C_RED}❌ Error: Paquete no especificado${C_RESET}"; return 1; }
            echo "${C_CYAN}📦 Instalando: $@${C_RESET}"
            paru -S "$@"
            ;;
        r|remove)
            _pkg_require paru "sudo pacman -S paru" || return 1
            shift
            [[ -z "$1" ]] && { echo "${C_RED}❌ Error: Paquete no especificado${C_RESET}"; return 1; }
            echo "${C_CYAN}🗑️ Eliminando: $@${C_RESET}"
            paru -Rns "$@"
            ;;
        k|keys)
            _pkg_keys
            ;;
        conf)
            _pkg_conf
            ;;
        -h|--help|help)
            _pkg_help
            ;;
        "")
            _pkg_menu
            ;;
        *)
            echo "${C_RED}❌ Comando no reconocido: $1${C_RESET}"
            _pkg_help
            return 1
            ;;
    esac
}
