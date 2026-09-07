#!/usr/bin/env zsh
# ==============================================
# 🌍 NAVEGACIÓN Y ALIAS DE DIRECTORIOS
# ==============================================

on_go() {
    local dest="$1"

    # Sin destino → menú gum de accesos rápidos
    if [[ -z "$dest" ]]; then
        if command -v gum &>/dev/null; then
            dest=$(gum choose \
                "proj · ~/Proyectos" \
                "snippets · ~/Proyectos/snippets-codes-vault" \
                "conf · ~/.zsh" \
                "conf-fn · ~/.zsh/functions" \
                "down · ~/Descargas" \
                "desk · ~/Escritorio" \
                "doc · ~/Documentos" \
                "music · ~/Música" \
                "pics · ~/Imágenes" \
                "vids · ~/Videos" \
                --header " 🧭 GO · Accesos rápidos ")
            [[ -z "$dest" ]] && return 0
            dest="${dest%% · *}"
        else
            echo "Uso: useGo <proj|proj-gh|proj-gl|snippets|conf|conf-fn|down|desk|doc|music|pics|vids>"
            return 0
        fi
    fi

    case "$dest" in
        proj|projects) cd ~/Proyectos ;;
        conf|config) cd ~/.zsh ;;
        conf-fn|config-fn) cd ~/.zsh/functions/;;
        down|downloads) cd ~/Descargas ;;
        desk|desktop) cd ~/Escritorio ;;
        doc|documents) cd ~/Documentos ;;
        music) cd ~/Música ;;
        pics|pictures) cd ~/Imágenes ;;
        vids|videos) cd ~/Videos ;;
        snippets) cd ~/Proyectos/snippets-codes-vault ;;
        *) echo "❌ Destino no válido. Opciones: proj, conf, down, desk, doc, music, pics, vids, snippets" ;;
    esac
}

on_lsproj() {
    echo "${C_CYAN}📂 Proyectos en ${C_BLUE}~/Proyectos${C_RESET}"
    ls -la ~/Proyectos | grep "^d" | awk '{print $9}' | while read -r dir; do
        if [[ -d "$HOME/Proyectos/$dir/.git" ]]; then
            echo "  ${C_GREEN}●${C_RESET} $dir (git)"
        else
            echo "  ○ $dir"
        fi
    done
}

# Navegación con Yazi (cd al directorio de salida) — migrado desde yazi.zsh
on_yzcd() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}



