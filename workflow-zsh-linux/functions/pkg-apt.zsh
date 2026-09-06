#!/usr/bin/env zsh
# ==============================================================================
# 📦 PKG (Debian / Ubuntu) - Paquetes y actualizaciones (apt + flatpak + snap)
# ==============================================================================
# Port del módulo pkg.zsh (Arch/BigLinux) para sistemas con apt.
# AUTOCONTENIDO: solo necesita zsh (gum es opcional, hay fallback).
#
# Convive con pkg.zsh (Arch): función on_pkg_apt + helpers _apt_* (sin choques).
# Alias: alias usePkgApt='on_pkg_apt'   (en máquinas Arch: usePkg='on_pkg')
#
# Subcomandos: u | sys | f | s | check | c | i | r | k | conf

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

# ==============================================================================
# 📦 PKG - Helpers
# ==============================================================================
_apt_help() {
    echo "${C_CYAN}Uso: usePkgApt <comando> | usePkgApt -h${C_RESET}"
    echo "${C_CYAN}Actualizaciones:${C_RESET}"
    echo "  u, update   : Actualiza todo (apt → flatpak → snap), confirmando cada paso"
    echo "  sys         : Solo apt update + upgrade"
    echo "  f, flatpak  : Solo Flatpak"
    echo "  s, snap     : Solo Snap"
    echo "  check       : Muestra actualizaciones pendientes"
    echo "  c, clean    : Autoremove (huérfanos) + limpia caché de .deb"
    echo "${C_CYAN}Paquetes:${C_RESET}"
    echo "  i, install  : Instalar paquete(s) con apt"
    echo "  r, remove   : Eliminar paquete(s) con apt purge"
    echo "  k, keys     : Info de llaves (en apt se gestionan con keyrings)"
    echo "  conf        : Editar sources de apt"
    echo "Sin argumentos abre el menú interactivo."
}

# Confirmación con gum y fallback a read (s/N)
_apt_ask() {
    if command -v gum &>/dev/null; then
        gum confirm "$1" && return 0 || return 1
    else
        local r
        printf "%s (s/N): " "$1" >&2
        read -r r
        [[ "$r" =~ ^[sSyY]$ ]]
    fi
}

# Verifica que un comando exista; $2 = hint de instalación (opcional)
_apt_require() {
    if ! command -v "$1" &>/dev/null; then
        echo "${C_RED}❌ Error: $1 no está instalado.${C_RESET}"
        [[ -n "$2" ]] && echo "📦 Instala con: ${C_YELLOW}$2${C_RESET}"
        return 1
    fi
}

_apt_sys() {
    echo "${C_CYAN}🚀 Actualizando repositorios (apt update)...${C_RESET}"
    sudo apt update || return 1
    echo "${C_CYAN}⬆️  Aplicando actualizaciones (apt upgrade)...${C_RESET}"
    sudo apt upgrade
}

_apt_flatpak() {
    _apt_require flatpak || return 1
    echo "${C_CYAN}🧩 Actualizando Flatpak...${C_RESET}"
    flatpak update
}

_apt_snap() {
    _apt_require snap || return 1
    echo "${C_CYAN}🗂️  Actualizando Snap...${C_RESET}"
    sudo snap refresh
}

_apt_check() {
    echo "${C_CYAN}🔍 Buscando actualizaciones pendientes...${C_RESET}"
    local updates
    updates=$(apt list --upgradable 2>/dev/null | grep "/")
    if [[ -z "$updates" ]]; then
        echo "${C_GREEN}✅ Todo actualizado.${C_RESET}"
        return 0
    fi
    echo "$updates"
    echo "${C_YELLOW}📌 $(echo "$updates" | wc -l) paquetes pendientes. Ejecuta ${C_RESET}usePkgApt sys${C_YELLOW} para actualizar.${C_RESET}"
}

_apt_clean() {
    echo "${C_YELLOW}🧹 Eliminando huérfanos (apt autoremove --purge)...${C_RESET}"
    sudo apt autoremove --purge
    echo "${C_YELLOW}🧹 Limpiando caché de paquetes (.deb)...${C_RESET}"
    sudo apt clean
    echo "${C_GREEN}✅ Limpieza completada.${C_RESET}"
}

_apt_all() {
    local failed=0
    echo "${C_CYAN}🚀 Actualización completa: apt → flatpak → snap${C_RESET}"

    if _apt_require apt && _apt_ask "¿Actualizar sistema (apt update + upgrade)?"; then
        _apt_sys || failed=1
    fi
    if command -v flatpak &>/dev/null && _apt_ask "¿Actualizar Flatpak?"; then
        _apt_flatpak || failed=1
    fi
    if command -v snap &>/dev/null && _apt_ask "¿Actualizar Snap?"; then
        _apt_snap || failed=1
    fi

    if [[ $failed -eq 0 ]]; then
        echo "${C_GREEN}✅ Actualización completa finalizada.${C_RESET}"
    else
        echo "${C_YELLOW}⚠️  La actualización terminó con errores. Revisa la salida de arriba.${C_RESET}"
        return 1
    fi
}

_apt_keys() {
    echo "${C_YELLOW}ℹ️  En Debian/Ubuntu las llaves se gestionan con paquetes keyring${C_RESET}"
    echo "   (debian-archive-keyring, ubuntu-keyring) y apt las trae solo."
    echo "   Llaves de terceros: revisa /etc/apt/trusted.gpg.d/ y los repos en sources."
}

_apt_conf() {
    local f="/etc/apt/sources.list"
    if [[ ! -f "$f" ]]; then
        f=$(print /etc/apt/sources.list.d/*(.N) 2>/dev/null | head -1)
    fi
    [[ -z "$f" ]] && { echo "${C_RED}❌ No encontré ningún archivo de sources de apt${C_RESET}"; return 1; }
    sudo "${EDITOR:-nano}" "$f"
}

# Instalar/eliminar desde el menú (pide nombre(s) de paquete)
_apt_menu_install() {
    local input
    if command -v gum &>/dev/null; then
        input=$(gum input --placeholder "paquete1 paquete2 ..." --header " 📥 Instalar con apt ")
    else
        printf "📥 Paquete(s) a instalar: " >&2
        read -r input
    fi
    [[ -z "$input" ]] && { echo "${C_RED}❌ No se especificó ningún paquete${C_RESET}"; return 1; }
    echo "${C_CYAN}📦 Instalando: $input${C_RESET}"
    sudo apt install ${(z)input}
}

_apt_menu_remove() {
    local input
    if command -v gum &>/dev/null; then
        input=$(gum input --placeholder "paquete1 paquete2 ..." --header " 🗑️  Eliminar con apt purge ")
    else
        printf "🗑️  Paquete(s) a eliminar: " >&2
        read -r input
    fi
    [[ -z "$input" ]] && { echo "${C_RED}❌ No se especificó ningún paquete${C_RESET}"; return 1; }
    echo "${C_CYAN}🗑️  Eliminando: $input${C_RESET}"
    sudo apt purge ${(z)input}
}

_apt_menu() {
    local opt
    if command -v gum &>/dev/null; then
        opt=$(gum choose \
            "🚀 Actualizar todo (apt + flatpak + snap)" \
            "📦 Solo sistema (apt update + upgrade)" \
            "🧩 Solo Flatpak" \
            "🗂️  Solo Snap" \
            "🔍 Ver actualizaciones pendientes" \
            "🧹 Limpiar huérfanos y caché" \
            "📥 Instalar paquete(s)" \
            "🗑️  Eliminar paquete(s)" \
            "🔑 Info de llaves" \
            "⚙️  Editar sources de apt" \
            --header " 📦 PKG · Paquetes y actualizaciones (Debian/Ubuntu) ")
        case "$opt" in
            *"Actualizar todo"*) _apt_all ;;
            *sistema*)           _apt_sys ;;
            *Flatpak*)           _apt_flatpak ;;
            *Snap*)              _apt_snap ;;
            *pendientes*)        _apt_check ;;
            *Limpiar*)           _apt_clean ;;
            *Instalar*)          _apt_menu_install ;;
            *Eliminar*)          _apt_menu_remove ;;
            *llaves*)            _apt_keys ;;
            *sources*)           _apt_conf ;;
        esac
    else
        echo "${C_CYAN}📦 PKG — Paquetes y actualizaciones (Debian/Ubuntu)${C_RESET}"
        echo "  1)  Actualizar todo (apt + flatpak + snap)"
        echo "  2)  Solo sistema (apt update + upgrade)"
        echo "  3)  Solo Flatpak"
        echo "  4)  Solo Snap"
        echo "  5)  Ver actualizaciones pendientes"
        echo "  6)  Limpiar huérfanos y caché"
        echo "  7)  Instalar paquete(s)"
        echo "  8)  Eliminar paquete(s)"
        echo "  9)  Info de llaves"
        echo "  10) Editar sources de apt"
        printf "Elige una opción [1-10]: "
        read -r opt
        case "$opt" in
            1)  _apt_all ;;
            2)  _apt_sys ;;
            3)  _apt_flatpak ;;
            4)  _apt_snap ;;
            5)  _apt_check ;;
            6)  _apt_clean ;;
            7)  _apt_menu_install ;;
            8)  _apt_menu_remove ;;
            9)  _apt_keys ;;
            10) _apt_conf ;;
            *) echo "${C_RED}❌ Opción inválida${C_RESET}"; return 1 ;;
        esac
    fi
}

# ==============================================================================
# 📦 PKG - Comando principal
# ==============================================================================
on_pkg_apt() {
    case "$1" in
        u|update)     _apt_all ;;
        sys|system)   _apt_sys ;;
        f|flatpak)    _apt_flatpak ;;
        s|snap)       _apt_snap ;;
        check|status) _apt_check ;;
        c|clean)      _apt_clean ;;
        i|install)
            shift
            [[ -z "$1" ]] && { echo "${C_RED}❌ Error: Paquete no especificado${C_RESET}"; return 1; }
            echo "${C_CYAN}📦 Instalando: $@${C_RESET}"
            sudo apt install "$@"
            ;;
        r|remove)
            shift
            [[ -z "$1" ]] && { echo "${C_RED}❌ Error: Paquete no especificado${C_RESET}"; return 1; }
            echo "${C_CYAN}🗑️ Eliminando: $@${C_RESET}"
            sudo apt purge "$@"
            ;;
        k|keys)
            _apt_keys
            ;;
        conf)
            _apt_conf
            ;;
        -h|--help|help)
            _apt_help
            ;;
        "")
            _apt_menu
            ;;
        *)
            echo "${C_RED}❌ Comando no reconocido: $1${C_RESET}"
            _apt_help
            return 1
            ;;
    esac
}
