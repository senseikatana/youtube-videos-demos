#!/usr/bin/env zsh
# ==============================================
# 🌍 NAVEGACIÓN Y ALIAS DE DIRECTORIOS
# ==============================================

# Directorios del usuario: XDG si existe; fallback portable en $HOME.
# Personalizable: export DOJO_PROJECTS_DIR="$HOME/mis-proyectos"
_dojo_user_dirs() {
    if command -v xdg-user-dir &>/dev/null; then
        DOJO_DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
        DOJO_DOWNLOADS="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"
        DOJO_DOCUMENTS="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documents")"
        DOJO_MUSIC="$(xdg-user-dir MUSIC 2>/dev/null || echo "$HOME/Music")"
        DOJO_PICTURES="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
        DOJO_VIDEOS="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"
    else
        DOJO_DESKTOP="$HOME/Desktop"
        DOJO_DOWNLOADS="$HOME/Downloads"
        DOJO_DOCUMENTS="$HOME/Documents"
        DOJO_MUSIC="$HOME/Music"
        DOJO_PICTURES="$HOME/Pictures"
        DOJO_VIDEOS="$HOME/Videos"
    fi
    DOJO_PROJECTS="${DOJO_PROJECTS_DIR:-$HOME/projects}"
    DOJO_ZSH_CONF="${DOJO_ZSH_CONF_DIR:-$HOME/.zsh}"
}

on_go() {
    local dest="$1"
    _dojo_user_dirs

    # Sin destino → menú gum de accesos rápidos
    if [[ -z "$dest" ]]; then
        if command -v gum &>/dev/null; then
            dest=$(gum choose \
                "proj · $DOJO_PROJECTS" \
                "conf · $DOJO_ZSH_CONF" \
                "conf-fn · $DOJO_ZSH_CONF/functions" \
                "down · $DOJO_DOWNLOADS" \
                "desk · $DOJO_DESKTOP" \
                "doc · $DOJO_DOCUMENTS" \
                "music · $DOJO_MUSIC" \
                "pics · $DOJO_PICTURES" \
                "vids · $DOJO_VIDEOS" \
                --header " 🧭 GO · Accesos rápidos ")
            [[ -z "$dest" ]] && return 0
            dest="${dest%% · *}"
        else
            echo "Uso: useGo <proj|conf|conf-fn|down|desk|doc|music|pics|vids>"
            return 0
        fi
    fi

    case "$dest" in
        proj|projects) cd "$DOJO_PROJECTS" ;;
        conf|config) cd "$DOJO_ZSH_CONF" ;;
        conf-fn|config-fn) cd "$DOJO_ZSH_CONF/functions" ;;
        down|downloads) cd "$DOJO_DOWNLOADS" ;;
        desk|desktop) cd "$DOJO_DESKTOP" ;;
        doc|documents) cd "$DOJO_DOCUMENTS" ;;
        music) cd "$DOJO_MUSIC" ;;
        pics|pictures) cd "$DOJO_PICTURES" ;;
        vids|videos) cd "$DOJO_VIDEOS" ;;
        *) echo "❌ Destino no válido. Opciones: proj, conf, conf-fn, down, desk, doc, music, pics, vids" ;;
    esac
}

on_lsproj() {
    _dojo_user_dirs
    echo "${C_CYAN}📂 Proyectos en ${C_BLUE}$DOJO_PROJECTS${C_RESET}"
    [[ -d "$DOJO_PROJECTS" ]] || { echo "${C_YELLOW}⚠️ No existe: $DOJO_PROJECTS${C_RESET}"; return 1; }
    ls -la "$DOJO_PROJECTS" | grep "^d" | awk '{print $9}' | while read -r dir; do
        if [[ -d "$DOJO_PROJECTS/$dir/.git" ]]; then
            echo "  ${C_GREEN}●${C_RESET} $dir (git)"
        else
            echo "  ○ $dir"
        fi
    done
}

# Navegación con Yazi (cd al directorio de salida)
on_yzcd() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
