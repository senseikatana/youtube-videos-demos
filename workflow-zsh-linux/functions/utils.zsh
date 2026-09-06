#!/usr/bin/env zsh
# ==============================================================================
# 🛠️ UTILIDADES DE SISTEMA
# ==============================================================================

: ${C_RED:='\e[1;31m'}
: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_BLUE:='\e[1;34m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RESET:='\e[0m'}

# ==============================================
# 🔌 KILLPORT
# ==============================================
on_killport() {
    local port="$1"
    
    if [[ -z "$port" ]]; then
        echo "${C_RED}❌ Error: Puerto requerido (ej: killport 8080)${C_RESET}"
        return 1
    fi
    
    local pid_output=$(lsof -t -i:"$port" 2>/dev/null)
    if [[ -z "$pid_output" ]]; then
        echo "${C_YELLOW}⚠️ No hay procesos escuchando en el puerto $port${C_RESET}"
        return 0
    fi
    
    local -a pids
    pids=(${(f)pid_output})
    
    echo "${C_CYAN}📋 Procesos en el puerto $port:${C_RESET}"
    for pid in "${pids[@]}"; do
        local comm=$(ps -p "$pid" -o comm= 2>/dev/null)
        echo "  - PID: ${C_YELLOW}$pid${C_RESET} ($comm)"
    done
    
    echo -n "⚠️  ¿Matar estos procesos? (s/N): "
    read -k 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        kill -9 "${pids[@]}" 2>/dev/null
        echo "${C_GREEN}✅ Procesos terminados.${C_RESET}"
    else
        echo "⏭️ Cancelado."
    fi
}

# --- Alias ---


# ==============================================
# 🗜️ EXTRACT
# ==============================================
on_extract() {
    if [[ -z "$1" ]]; then
        echo "${C_RED}❌ Error: Archivo requerido (ej: extract archivo.tar.gz)${C_RESET}"
        return 1
    fi
    
    if [[ ! -f "$1" ]]; then
        echo "${C_RED}❌ Error: Archivo '$1' no existe${C_RESET}"
        return 1
    fi
    
    echo "${C_CYAN}📦 Extrayendo $1...${C_RESET}"
    
    case "$1" in
        *.tar.bz2|*.tbz2)  tar xvjf "$1" ;;
        *.tar.gz|*.tgz)    tar xvzf "$1" ;;
        *.tar.xz)          tar xvJf "$1" ;;
        *.tar)             tar xvf "$1"  ;;
        *.bz2)             bunzip2 "$1"  ;;
        *.rar)             unrar x "$1"  ;;
        *.gz)              gunzip "$1"   ;;
        *.zip)             unzip "$1"    ;;
        *.Z)               uncompress "$1" ;;
        *.7z)              7z x "$1"     ;;
        *)                 echo "${C_RED}❌ Error: Formato no soportado${C_RESET}"; return 1 ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        echo "${C_GREEN}✅ Extracción completada.${C_RESET}"
    else
        echo "${C_RED}❌ Error al extraer.${C_RESET}"
    fi
}

# --- Alias ---


# ==============================================
# 🔐 VERIFYHASH
# ==============================================
on_verifyhash() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then 
        echo "${C_CYAN}Uso: verifyhash calc <archivo> [algoritmo]${C_RESET}"
        echo "     verifyhash comp <archivo> <hash_esperado> [algoritmo]"
        echo "Algoritmos: md5, sha1, sha256 (default), sha512"
        return 0 
    fi

    local action="$1" file="$2" expected="$3" algo="${4:-sha256}"

    _calc_hash() {
        local target="$1" hash_algo="$2"
        local cmd="${hash_algo:l}sum"
        if ! command -v "$cmd" &>/dev/null; then
            cmd="sha256sum"
        fi
        $cmd "$target" 2>/dev/null | awk '{print $1}'
    }

    if [[ ! -f "$file" ]]; then
        echo "${C_RED}❌ Error: Archivo '$file' no existe${C_RESET}"
        return 1
    fi

    case "$action" in
        calculate|calc|c)
            algo="${expected:-sha256}"
            local result=$(_calc_hash "$file" "$algo")
            echo "${C_BLUE}📊 Hash ($algo):${C_RESET}"
            echo "$result"
            ;;
        compare|comp)
            if [[ -z "$expected" ]]; then
                echo "${C_RED}❌ Error: Hash esperado requerido${C_RESET}"
                return 1
            fi
            local result=$(_calc_hash "$file" "$algo")
            if [[ "${result:l}" == "${expected:l}" ]]; then
                echo "${C_GREEN}✅ ¡VERIFICACIÓN EXITOSA! Los hashes coinciden.${C_RESET}"
            else
                echo "${C_RED}❌ ¡LOS HASHES NO COINCIDEN!${C_RESET}"
                echo "Esperado:   ${C_YELLOW}$expected${C_RESET}"
                echo "Calculado:  ${C_RED}$result${C_RESET}"
                return 1
            fi
            ;;
        *)
            echo "${C_RED}❌ Acción inválida. Usa 'calc' o 'comp'${C_RESET}"
            return 1
            ;;
    esac
}

# --- Alias ---


# ==============================================
# 🔑 PASSGEN
# ==============================================
on_passgen() {
    local -a WORDS=(
        "agua" "arbol" "arena" "barco" "brisa" "cielo" "cueva" "disco" "duna"
        "fuego" "gato" "globo" "hoja" "humo" "isla" "lago" "lluvia" "luna"
        "mapa" "monte" "nieve" "nube" "onda" "papel" "piedra" "pino" "pluma"
        "rayo" "rio" "roca" "selva" "sol" "suelo" "tierra" "torre" "viento"
        "vuelo" "valle" "verde" "vida" "azul" "rojo" "claro" "oscuro" "fuerte"
        "suave" "rapido" "lento" "alto" "bajo" "acid" "apex" "atom" "bark"
        "beam" "bolt" "brisk" "calm" "clay" "coal" "dawn" "deep" "dusk"
        "echo" "fade" "flow" "flux" "glen" "glow" "halo" "haze" "iron"
        "jade" "lava" "leaf" "lime" "mist" "neon" "nova" "opal" "path"
        "pure" "rain" "reef" "rift" "rust" "sand" "shadow" "silk" "silt"
        "snow" "star" "surf" "tide" "vale" "vast" "wave" "wild" "wind" "zinc"
    )
    
    local type="secure" length="" count="" words_count=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -S) type="secure" ;;
            -M) type="matricula" ;;
            -A) type="alphanumeric" ;;
            -N) type="numeric" ;;
            -X) type="memorable" ;;
            -h) 
                echo "${C_CYAN}Uso: passgen [longitud] [cantidad] [palabras] [-S|-M|-A|-N|-X]${C_RESET}"
                echo "  -S  Segura (default)  -M  Matrícula  -A  Alfanumérica"
                echo "  -N  Numérica          -X  Memorable"
                return 0
                ;;
            *) 
                if [[ -z "$length" ]]; then
                    length="$1"
                elif [[ -z "$count" ]]; then
                    count="$1"
                else
                    words_count="$1"
                fi
                ;;
        esac
        shift
    done

    [[ -z "$length" ]] && length=$(( type == "numeric" ? 6 : 16 ))
    [[ -z "$count" ]] && count=1
    [[ -z "$words_count" ]] && words_count=$(( type == "memorable" ? 4 : 1 ))

    for (( i=0; i<count; i++ )); do
        case "$type" in
            matricula)
                local cons="BCDFGHJKLMNPQRSTVWXYZ" digs="0123456789"
                local res=""
                for (( j=0; j<4; j++ )); do
                    res+="${digs[$(( RANDOM % 10 + 1 ))]}"
                done
                for (( j=0; j<3; j++ )); do
                    res+="${cons[$(( RANDOM % 21 + 1 ))]}"
                done
                echo "$res"
                ;;
            secure|alphanumeric|numeric)
                local low="abcdefghijklmnopqrstuvwxyz"
                local up="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                local num="0123456789"
                local sym='!@#$%^&*()_+-=[]{}|;:,.<>?'
                local pool=""
                
                [[ "$type" == "numeric" ]] && pool="$num" || pool="${low}${up}${num}"
                [[ "$type" == "secure" ]] && pool+="$sym"
                
                local plen=${#pool} pwd="" has_low=0 has_up=0 has_num=0 has_sym=0
                
                while true; do
                    pwd="" has_low=0 has_up=0 has_num=0 has_sym=0
                    for (( j=0; j<length; j++ )); do
                        local ch="${pool[$(( RANDOM % plen + 1 ))]}"
                        pwd+="$ch"
                        [[ "$ch" == [a-z] ]] && has_low=1
                        [[ "$ch" == [A-Z] ]] && has_up=1
                        [[ "$ch" == [0-9] ]] && has_num=1
                        [[ "$ch" == [^a-zA-Z0-9] ]] && has_sym=1
                    done
                    
                    if [[ "$type" == "numeric" ]] || \
                       { [[ "$type" == "alphanumeric" ]] && (( has_low && has_up && has_num )); } || \
                       { [[ "$type" == "secure" ]] && (( has_low && has_up && has_num && has_sym )); }; then
                        echo "$pwd"
                        break
                    fi
                done
                ;;
            memorable)
                local -a selected=()
                local -A picked
                local wlen=${#WORDS[@]}
                
                while (( ${#selected[@]} < words_count )); do
                    local w="${WORDS[$(( RANDOM % wlen + 1 ))]}"
                    if [[ -z "${picked[$w]}" ]]; then
                        picked[$w]=1
                        selected+=("$w")
                    fi
                done
                echo ${(j:-:)selected}
                ;;
        esac
    done
}


# ==============================================
# 📊 SYSINFO
# ==============================================
on_info() {
    echo "${C_CYAN}📊 System Information${C_RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🐧 OS: $(uname -s) $(uname -r)"
    echo "💻 Host: $(hostname)"
    echo "👤 User: $(whoami)"
    echo "📂 Shell: $SHELL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "${C_YELLOW}💾 Memory:${C_RESET}"
    free -h | grep -E "Mem|Swap"
    echo ""
    
    echo "${C_YELLOW}💿 Disk:${C_RESET}"
    df -h | grep -E "Filesystem|/dev/sd|/dev/nvme" | head -4
    echo ""
    
    echo "${C_YELLOW}📦 Packages:${C_RESET}"
    echo "  Pacman: $(pacman -Qq 2>/dev/null | wc -l) packages"
    command -v flatpak &>/dev/null && echo "  Flatpak: $(flatpak list --app 2>/dev/null | wc -l) apps"
}

# ==============================================
# 🧹 CLEANUP
# ==============================================
# Limpieza de caché de paquetes según la distro
# (Arch: paccache conserva 2 versiones · Debian/Ubuntu: autoremove + clean)
_cleanup_pkg_cache() {
    if command -v paccache &>/dev/null; then
        _pkg_paccache
    elif command -v apt &>/dev/null; then
        echo "${C_YELLOW}🧹 Eliminando huérfanos (apt autoremove --purge)...${C_RESET}"
        sudo apt autoremove --purge
        echo "${C_YELLOW}🧹 Limpiando caché de paquetes (.deb)...${C_RESET}"
        sudo apt clean
    else
        echo "${C_RED}❌ Sin gestor de paquetes soportado (paccache/apt)${C_RESET}"
        return 1
    fi
}

on_cleanup() {
    local choice
    if command -v gum &>/dev/null; then
        choice=$(gum choose \
            "1) Clear package cache" \
            "2) Clear journal logs" \
            "3) Clear temporary files" \
            "4) Clear trash" \
            "5) All" \
            --header " 🧹 System Cleanup " | cut -d')' -f1)
    else
        echo "${C_YELLOW}🧹 System Cleanup${C_RESET}"
        echo "1) Clear package cache"
        echo "2) Clear journal logs"
        echo "3) Clear temporary files"
        echo "4) Clear trash"
        echo "5) All"
        echo -n "Selecciona: "
        read -k 1 choice
        echo
    fi

    case "$choice" in
        1) _cleanup_pkg_cache ;;
        2) sudo journalctl --vacuum-time=3d ;;
        3) sudo rm -rf /tmp/* ;;
        4) rm -rf ~/.local/share/Trash/* ;;
        5)
            _cleanup_pkg_cache
            sudo journalctl --vacuum-time=3d
            sudo rm -rf /tmp/*
            rm -rf ~/.local/share/Trash/*
            echo "${C_GREEN}✅ Todo limpio!${C_RESET}"
            ;;
        *) echo "${C_RED}❌ Opción inválida${C_RESET}" ;;
    esac
}

# --- Alias ---


