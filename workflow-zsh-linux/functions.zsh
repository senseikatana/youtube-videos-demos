#!/usr/bin/env zsh
# ==============================================================================
# 🧠 DOJO FUNCTIONS - CARGA DE MÓDULOS
# ==============================================================================

# Directorio base:
#   1. Respeta $DOJO_FUNCTIONS_DIR si ya lo tenías exportado.
#   2. Si este archivo se hizo `source` desde un repo clonado (tiene una carpeta
#      `functions/` hermana), usa esa carpeta — funciona con cualquier ruta.
#   3. Por defecto: ~/.zsh/functions (instalación clásica en tu $HOME).
_dojo_self="${(%):-%x}"
[[ -f "$_dojo_self" ]] || _dojo_self="${_dojo_self/#\~/$HOME}"
if [[ -n "$DOJO_FUNCTIONS_DIR" ]]; then
    :
elif [[ -f "$_dojo_self" && -d "$(dirname "$_dojo_self")/functions" ]]; then
    _dojo_dir="$(dirname "$_dojo_self")/functions"
    export DOJO_FUNCTIONS_DIR="${_dojo_dir:a}"
else
    export DOJO_FUNCTIONS_DIR="$HOME/.zsh/functions"
fi

# Colores por defecto (si no están definidos)
: ${C_GREEN:='\e[1;32m'}
: ${C_RESET:='\e[0m'}

# ==============================================================================
# 📦 MÓDULOS DISPONIBLES
# ==============================================================================
# core          - Funciones núcleo (colores, helpers)
# git           - Git (useGit: push, commit, release, flow, tags, passthrough git)
# github        - GitHub CLI (useGh: pr, issue, repo, gist, mirror + passthrough gh)
# docker        - Docker (useDocker: exec, logs, ip, clean + comandos) + alias
# package-managers - usePm unificado (npm, pnpm, yarn, bun) + alias
# utils         - Utilidades (killport, extract, verifyhash, passgen, sysinfo, cleanup) + alias
# system        - Sistema (chx, schx, chxr, useFiles) + alias
# pkg           - Paquetes y actualizaciones Arch (usePkg) + alias
# pkg-apt       - Paquetes y actualizaciones Debian/Ubuntu (usePkgApt) + alias
# systemd       - Servicios systemd (useSysd) + alias
# zinit         - Gestor de plugins zinit (useZinit) + alias
# nodeclean     - Limpieza de node_modules (useNmk) + alias
# lazy          - Lanzador de lazy tools (useLazy) + alias
# media         - Descarga de medios (useDownload: video, music, playlist) + alias
# virtmanager   - Gestión de VMs + alias
# init-docs     - Generar documentación + alias
# create-web    - Creación de proyectos web + alias
# navigation    - Navegación rápida + Yazi (yz) + alias
# ==============================================================================

# Cargar módulos en orden
for module in \
    core \
    git \
    github \
    docker \
    package-managers \
    utils \
    system \
    pkg \
    pkg-apt \
    systemd \
    zinit \
    nodeclean \
    lazy \
    media \
    virtmanager \
    init-docs \
    create-web \
    navigation
do
    if [[ -f "$DOJO_FUNCTIONS_DIR/$module.zsh" ]]; then
        source "$DOJO_FUNCTIONS_DIR/$module.zsh"
    else
        echo "⚠️  Módulo no encontrado: $module.zsh"
    fi
done

