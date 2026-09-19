#!/usr/bin/env zsh
# ==============================================================================
# ⚙️ SYSTEM UTILITIES - Utilidades del sistema
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}


# Función para dar permisos de ejecución
on_chx() {
    if [ $# -eq 0 ]; then
        echo "Uso: chx archivo1 [archivo2 ...]"
        echo "Ejemplos:"
        echo "  chx script.sh        → chmod +x en un archivo"
        echo "  chx *.sh             → chmod +x en todos los .sh"
        echo "  schx script.sh       → sudo chmod +x en un archivo"
        return 1
    fi
    chmod +x "$@"
    echo "✅ Permisos de ejecución aplicados a: $*"
}

# Versión con sudo
on_schx() {
    if [ $# -eq 0 ]; then
        echo "Uso: schx archivo1 [archivo2 ...]"
        return 1
    fi
    sudo chmod +x "$@"
    echo "✅ Permisos de ejecución (sudo) aplicados a: $*"
}


# Versión para directorios recursivo
on_chxr() {
    if [ $# -eq 0 ]; then
        echo "Uso: chxr directorio"
        echo "Ejemplo: chxr ./scripts  → chmod +x recursivo en todos los archivos"
        return 1
    fi
    find "$@" -type f -exec chmod +x {} \;
    echo "✅ Permisos de ejecución recursivos aplicados en: $*"
}


# ==============================================
# 🗂️ FILES - Centro de operaciones (useFiles)
# ==============================================
_files_help() {
    echo "${C_CYAN}Uso: useFiles <acción> [args]${C_RESET}"
    echo "${C_CYAN}Inspección:${C_RESET}"
    echo "  size         Tamaño de un archivo/carpeta (o resumen del directorio)"
    echo "  cat          Contenido del archivo (bat si existe)"
    echo "  info         file + stat del elemento"
    echo "  tree         Árbol del directorio (eza --tree)"
    echo "  disk         Uso de discos (duf)"
    echo "  find         Buscar con fd"
    echo "  count        Líneas/palabras/caracteres (wc)"
    echo "${C_CYAN}Acciones:${C_RESET}"
    echo "  mkdir        Crear carpeta(s)"
    echo "  touch        Crear archivo vacío"
    echo "  rename       Renombrar (picker → nuevo nombre)"
    echo "  move         Mover (picker → destino)"
    echo "  copy         Copiar (picker → destino, -r)"
    echo "  del          Eliminar (papelera si existe; si no rm con confirmación)"
    echo "Sin argumentos abre el menú interactivo."
}

# Elige archivo(s); multi="multi" permite selección múltiple; salida por stdout (una ruta por línea)
_files_pick() {
    local mode="${1:-single}" sel
    if command -v fzf &>/dev/null; then
        if [[ "$mode" == "multi" ]]; then
            sel=$(fzf -m --height 40%)
        else
            sel=$(fzf --height 40%)
        fi
    elif command -v gum &>/dev/null; then
        if [[ "$mode" == "multi" ]]; then
            sel=$(ls -A | gum choose --no-limit --header " 🗂️ Selecciona (espacio para marcar) ")
        else
            sel=$(ls -A | gum choose --header " 🗂️ Selecciona ")
        fi
    else
        ls -A >&2
        printf "Ruta: " >&2
        read -r sel
    fi
    [[ -z "$sel" ]] && return 1
    print -l -- ${(f)sel}
}

_files_size() {
    if [[ -n "$1" ]]; then
        du -sh "$1"
        return 0
    fi
    echo "${C_CYAN}📊 Tamaños en $(pwd):${C_RESET}"
    du -sh .[!.]*(N) *(N) 2>/dev/null | sort -hr
}

_files_cat() {
    local f="$1"
    [[ -z "$f" ]] && { f=$(_files_pick) || return 1; }
    [[ -f "$f" ]] || { echo "${C_RED}❌ No es un archivo: $f${C_RESET}"; return 1; }
    if command -v bat &>/dev/null; then
        bat --style=plain "$f"
    else
        cat -n "$f"
    fi
}

_files_info() {
    local item="$1"
    [[ -z "$item" ]] && { item=$(_files_pick) || return 1; }
    file "$item"
    stat -c '%n | %s bytes | %A | modificado: %y' "$item"
}

_files_tree() {
    local dir="${1:-.}"
    if command -v eza &>/dev/null; then
        eza --tree --icons --level 3 "$dir"
    elif command -v tree &>/dev/null; then
        tree "$dir"
    else
        ls -la "$dir"
    fi
}

_files_find() {
    local pattern="$1"
    if [[ -z "$pattern" ]]; then
        if command -v gum &>/dev/null; then
            pattern=$(gum input --placeholder "patrón (ej: *.conf)" --header " 🔍 Buscar con fd ")
        else
            printf "Patrón: " >&2
            read -r pattern
        fi
    fi
    [[ -z "$pattern" ]] && return 0
    if command -v fd &>/dev/null; then
        fd "$pattern"
    else
        find . -name "*$pattern*"
    fi
}

_files_count() {
    local f="$1"
    [[ -z "$f" ]] && { f=$(_files_pick) || return 1; }
    [[ -f "$f" ]] || { echo "${C_RED}❌ No es un archivo: $f${C_RESET}"; return 1; }
    wc "$f"
}

_files_mkdir() {
    local name="$1"
    if [[ -z "$name" ]]; then
        if command -v gum &>/dev/null; then
            name=$(gum input --placeholder "nombre-carpeta (puedes anidar a/b)" --header " 📁 mkdir -p ")
        else
            printf "Nombre de carpeta: " >&2
            read -r name
        fi
    fi
    [[ -z "$name" ]] && return 1
    mkdir -p ${(z)name}
    echo "${C_GREEN}✅ Carpeta(s) creada(s): $name${C_RESET}"
}

_files_touch() {
    local name="$1"
    if [[ -z "$name" ]]; then
        if command -v gum &>/dev/null; then
            name=$(gum input --placeholder "nombre-archivo.ext" --header " 📄 touch ")
        else
            printf "Nombre de archivo: " >&2
            read -r name
        fi
    fi
    [[ -z "$name" ]] && return 1
    touch ${(z)name}
    echo "${C_GREEN}✅ Archivo(s) creado(s): $name${C_RESET}"
}

_files_rename() {
    local src="$1" dst="$2"
    [[ -z "$src" ]] && { src=$(_files_pick) || return 1; }
    if [[ -z "$dst" ]]; then
        if command -v gum &>/dev/null; then
            dst=$(gum input --value "$src" --header " ✏️ Nuevo nombre para $src ")
        else
            printf "Nuevo nombre [$src]: " >&2
            read -r dst
            [[ -z "$dst" ]] && dst="$src"
        fi
    fi
    [[ -z "$dst" || "$dst" == "$src" ]] && return 0
    mv -iv -- "$src" "$dst"
}

_files_move() {
    local src="$1" dst="$2"
    [[ -z "$src" ]] && { src=$(_files_pick) || return 1; }
    if [[ -z "$dst" ]]; then
        if command -v gum &>/dev/null; then
            dst=$(gum input --placeholder "ruta/destino (acaba en / si es carpeta)" --header " 📦 Mover $src a ")
        else
            printf "Destino: " >&2
            read -r dst
        fi
    fi
    [[ -z "$dst" ]] && return 0
    [[ -d "$dst" ]] && dst="$dst/${src:t}"
    mv -iv -- "$src" "$dst"
}

_files_copy() {
    local src="$1" dst="$2"
    [[ -z "$src" ]] && { src=$(_files_pick) || return 1; }
    if [[ -z "$dst" ]]; then
        if command -v gum &>/dev/null; then
            dst=$(gum input --placeholder "ruta-o-nuevo-nombre" --header " 📄 Copiar $src a ")
        else
            printf "Destino: " >&2
            read -r dst
        fi
    fi
    [[ -z "$dst" ]] && return 0
    [[ -d "$dst" ]] && dst="$dst/${src:t}"
    cp -rv -- "$src" "$dst"
}

_files_del() {
    local -a targets
    if [[ $# -gt 0 ]]; then
        targets=("$@")
    else
        local picked
        picked=$(_files_pick multi) || return 1
        targets=("${(f)picked}")
    fi
    [[ ${#targets[@]} -eq 0 ]] && return 1

    echo "${C_YELLOW}🗑️  Se enviará a la papelera (o se eliminará):${C_RESET}"
    printf '  %s\n' "${targets[@]}"
    _git_ask_yes_no "¿Confirmas?" || { echo "⏭️ Cancelado."; return 0; }

    if command -v trash-put &>/dev/null; then
        trash-put -- "${targets[@]}" && echo "${C_GREEN}✅ A la papelera.${C_RESET}"
    elif command -v gio &>/dev/null; then
        gio trash -- "${targets[@]}" && echo "${C_GREEN}✅ A la papelera (gio).${C_RESET}"
    else
        rm -i -- "${targets[@]}"
    fi
}

on_files() {
    local action="$1"
    [[ $# -gt 0 ]] && shift

    case "$action" in
        mkdir|md)      _files_mkdir "$@" ;;
        touch|new)     _files_touch "$@" ;;
        rename|ren)    _files_rename "$@" ;;
        move|mv)       _files_move "$@" ;;
        copy|cp)       _files_copy "$@" ;;
        del|rm|trash)  _files_del "$@" ;;
        size|du)       _files_size "$1" ;;
        cat|view)      _files_cat "$1" ;;
        info|stat)     _files_info "$1" ;;
        tree)          _files_tree "$1" ;;
        disk|df)       duf ;;
        find|search)   _files_find "$1" ;;
        count|wc)      _files_count "$1" ;;
        -h|--help|help)
            _files_help
            ;;
        "")
            local opt
            if command -v gum &>/dev/null; then
                opt=$(gum choose \
                    "size · tamaños (pesos)" \
                    "cat · ver contenido" \
                    "info · file + stat" \
                    "tree · árbol del directorio" \
                    "disk · uso de discos (duf)" \
                    "find · buscar con fd" \
                    "count · contar líneas/palabras" \
                    "mkdir · crear carpeta" \
                    "touch · crear archivo" \
                    "rename · renombrar" \
                    "move · mover" \
                    "copy · copiar" \
                    "del · eliminar (papelera)" \
                    --header " 🗂️ FILES · ¿Qué hacemos? ")
                [[ -z "$opt" ]] && return 0
                on_files "${opt%% · *}"
            else
                _files_help
            fi
            ;;
        *)
            echo "${C_RED}❌ Acción no reconocida: $action${C_RESET}"
            _files_help
            return 1
            ;;
    esac
}
