#!/usr/bin/env zsh
# ==============================================================================
# ⬇️ MEDIA DOWNLOADERS
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_BLUE:='\e[1;34m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

on_download() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "${C_CYAN}Uso: useDownload <video|music|playlist> <url> [destino]${C_RESET}"
        echo "  video (v)    - Descargar video en MP4"
        echo "  music (m)    - Descargar audio en MP3"
        echo "  playlist (p) - Descargar playlist completa"
        echo "Sin argumentos abre el menú interactivo."
        return 0
    fi

    if ! command -v yt-dlp &>/dev/null; then
        echo "${C_RED}❌ Error: yt-dlp no está instalado.${C_RESET}"
        if command -v pacman &>/dev/null; then
            echo "📦 Instala con: ${C_YELLOW}sudo pacman -S yt-dlp${C_RESET}"
        else
            echo "📦 Instala con: ${C_YELLOW}sudo apt install yt-dlp${C_RESET}"
        fi
        return 1
    fi

    local mode="$1" url="$2" dir="$3"

    # Sin modo o sin URL → menú interactivo (gum)
    if [[ -z "$mode" || -z "$url" ]]; then
        if command -v gum &>/dev/null; then
            if [[ -z "$mode" ]]; then
                mode=$(gum choose "video" "music" "playlist" --header " ⬇️ DOWNLOAD · Elige modo ")
                [[ -z "$mode" ]] && return 0
            fi
            if [[ -z "$url" ]]; then
                url=$(gum input --placeholder "https://enlace-a-descargar" --header " ⬇️ $mode · URL ")
                [[ -z "$url" ]] && return 0
            fi
        else
            echo "${C_RED}❌ Error: URL requerida${C_RESET}"
            echo "Uso: useDownload <video|music|playlist> <url> [destino]"
            return 1
        fi
    fi

    local args=()
    case "$mode" in
        video|v) 
            dir="${dir:-$HOME/Vídeos/youtube-videos}"
            args=(-f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
                --merge-output-format mp4 --embed-thumbnail --add-metadata \
                -o "$dir/%(title)s.%(ext)s") 
            ;;
        music|m|audio|a) 
            dir="${dir:-$HOME/Música}"
            args=(-x --audio-format mp3 --audio-quality 0 \
                --embed-thumbnail --add-metadata \
                -o "$dir/%(title)s.%(ext)s") 
            ;;
        playlist|p) 
            dir="${dir:-$HOME/Vídeos/youtube-playlists}"
            args=(--yes-playlist \
                -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
                --merge-output-format mp4 --embed-thumbnail --add-metadata \
                -o "$dir/%(playlist_title)s/%(title)s.%(ext)s")
            ;;
        *)
            echo "${C_RED}❌ Error: Modo inválido. Usa: video, music o playlist${C_RESET}"
            return 1 
            ;;
    esac

    mkdir -p "$dir"
    echo "${C_CYAN}⬇️ Descargando en: ${C_BLUE}$dir${C_RESET}"
    
    local final_cmd=(yt-dlp "${args[@]}")
    local cookies="$HOME/.config/yt-dlp/cookies.txt"
    [[ -f "$cookies" ]] && final_cmd+=(--cookies "$cookies")
    
    "${final_cmd[@]}" "$url" && \
        echo "${C_GREEN}✅ Descarga completada!${C_RESET}" || \
        echo "${C_RED}❌ Error en la descarga${C_RESET}"
}



