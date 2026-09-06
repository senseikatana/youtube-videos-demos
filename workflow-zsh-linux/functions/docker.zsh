#!/usr/bin/env zsh
# ==============================================
# 🐳 DOCKER UTILITIES
# ==============================================

dexec() {
    if [[ $# -gt 0 ]]; then
        docker exec -it "$@"
        return $?
    fi
    
    local container
    if command -v fzf &>/dev/null; then
        container=$(docker ps --format "{{.ID}} | {{.Names}} | {{.Image}}" | fzf | awk '{print $1}')
    elif command -v gum &>/dev/null; then
        container=$(docker ps --format "{{.Names}}" | gum choose)
    else
        echo "❌ Error: fzf or gum required."
        return 1
    fi
    
    [[ -z "$container" ]] && return 0
    
    local shell="bash"
    if command -v gum &>/dev/null; then
        shell=$(gum choose "bash" "sh" "zsh" --header "Select shell:")
    fi
    
    docker exec -it "$container" "$shell" || docker exec -it "$container" sh
}

dlogs() {
    if [[ $# -gt 0 ]]; then
        docker logs -f "$@"
        return $?
    fi
    
    local container
    if command -v fzf &>/dev/null; then
        container=$(docker ps -a --format "{{.ID}} | {{.Names}}" | fzf | awk '{print $1}')
    else
        echo "❌ Error: fzf required for interactive selection."
        return 1
    fi
    
    [[ -z "$container" ]] && return 0
    docker logs -f "$container"
}

dclean() {
    echo "${C_YELLOW}🧹 Docker Cleanup${C_RESET}"
    echo -n "⚠️  ¿Eliminar todo lo no usado? (y/N): "
    read -k 1 confirm
    echo
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        docker system prune -a --volumes --force
        echo "✅ Limpieza completada."
    else
        echo "🛑 Cancelado."
    fi
}

dips() {
    echo "${C_CYAN}📊 Docker Container IPs${C_RESET}"
    printf "%-25s %-20s %-15s\n" "NAME" "IP ADDRESS" "PORTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    docker ps --format "{{.Names}}" | while read -r name; do
        local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null)
        local ports=$(docker port "$name" 2>/dev/null | head -1 | awk '{print $3}')
        printf "%-25s %-20s %-15s\n" "$name" "${ip:-N/A}" "${ports:-None}"
    done
}


# ==============================================
# 🐳 DOCKER - DISPATCHER (useDocker)
# ==============================================
_docker_help() {
    echo "${C_CYAN}Uso: useDocker <comando> [args]${C_RESET}"
    echo "${C_CYAN}Funciones interactivas:${C_RESET}"
    echo "  ex, exec      Shell en un contenedor (menú de selección)"
    echo "  lg, logs      Logs de un contenedor"
    echo "  ip            IPs y puertos de los contenedores"
    echo "  cl, clean     Limpieza completa (con confirmación)"
    echo "${C_CYAN}Comandos docker / compose:${C_RESET}"
    echo "  p, ps | pa          Contenedores activos / todos"
    echo "  i, images           Listar imágenes"
    echo "  ri | rm             Borrar imagen / borrar contenedor"
    echo "  b, build | r, run   Construir / ejecutar (-it --rm)"
    echo "  s, stop             Parar contenedor"
    echo "  up | dn, down | cp  compose up -d / down / ps"
    echo "  pn, prune           system prune -a --volumes (pide confirmación)"
}

on_docker() {
    local cmd="$1"
    [[ $# -gt 0 ]] && shift

    case "$cmd" in
        ex|exec)    dexec "$@" ;;
        lg|logs)    dlogs "$@" ;;
        ip)         dips ;;
        cl|clean)   dclean ;;
        p|ps)       docker ps "$@" ;;
        pa)         docker ps -a "$@" ;;
        i|images)   docker images "$@" ;;
        ri)         docker rmi "$@" ;;
        rm)         docker rm "$@" ;;
        b|build)    docker build "$@" ;;
        r|run)      docker run -it --rm "$@" ;;
        s|stop)     docker stop "$@" ;;
        up)         docker-compose up -d "$@" ;;
        dn|down)    docker-compose down "$@" ;;
        cp)         docker-compose ps "$@" ;;
        pn|prune)
            if _git_ask_yes_no "⚠️  ¿docker system prune -a --volumes? Borra TODO lo no usado."; then
                docker system prune -a --volumes --force
            else
                echo "🛑 Cancelado."
            fi ;;
        -h|--help|help) _docker_help ;;
        "")
            local opt
            if command -v gum &>/dev/null; then
                opt=$(gum choose \
                    "ps · contenedores activos" \
                    "pa · todos los contenedores" \
                    "exec · shell en un contenedor" \
                    "logs · logs de un contenedor" \
                    "ip · IPs y puertos" \
                    "images · listar imágenes" \
                    "build · construir imagen" \
                    "run · ejecutar contenedor" \
                    "stop · parar contenedor" \
                    "up · compose up -d" \
                    "down · compose down" \
                    "clean · limpiar lo no usado" \
                    "prune · system prune -a (peligroso)" \
                    --header " 🐳 DOCKER · Elige comando ")
                [[ -z "$opt" ]] && return 0
                on_docker "${opt%% · *}"
            else
                _docker_help
            fi ;;
        *)
            echo "${C_RED}❌ Comando no reconocido: $cmd${C_RESET}"
            _docker_help
            return 1 ;;
    esac
}



