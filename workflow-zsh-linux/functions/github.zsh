#!/usr/bin/env zsh
# ==============================================================================
# 🐙 GITHUB CLI - Funciones para gh
# ==============================================================================

: ${C_GREEN:='\e[1;32m'}
: ${C_YELLOW:='\e[1;33m'}
: ${C_CYAN:='\e[1;36m'}
: ${C_RED:='\e[1;31m'}
: ${C_RESET:='\e[0m'}

_gh_check() {
    if ! command -v gh &>/dev/null; then
        echo "${C_RED}❌ Error: GitHub CLI (gh) no está instalado.${C_RESET}"
        echo "📦 Instala con: ${C_YELLOW}sudo pacman -S github-cli${C_RESET}"
        return 1
    fi
    return 0
}

# ==============================================================================
# 🔁 SINCRONIZACIÓN GITHUB -> GITLAB
# ==============================================================================

function git_mirroring() {
    local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
    # Usuario de GitHub (se puede sobreescribir con export GITHUB_USER=tu-usuario)
    local gh_user="${GITHUB_USER:-$USER}"

    if [[ -z "$repo_name" ]]; then
        echo "❌ No estás en un repositorio git."
        return 1
    fi

    echo "🔄 Sincronizando repositorio: $repo_name"

    # 3. Configurar los remotes para el push dual
    echo "⚙️ Configurando remotes locales..."
    git remote remove origin 2>/dev/null
    git remote remove all 2>/dev/null

    # Configuramos origin con fetch de github y push dual
    git remote add origin "git@github.com:${gh_user}/$repo_name.git"
    git remote set-url --add --push origin "git@github.com:${gh_user}/$repo_name.git"

    echo "${C_GREEN}🚀 ¡Sincronización lista! Ahora puedes hacer 'git push' sin problemas.${C_RESET}"
}

function gh_repo_new() {
    _gh_check || return 1

    local repo_name="$1"
    local is_private=false
    local in_git_repo=false

    # Detectar si ya estamos en un repo git local
    git rev-parse --show-toplevel &>/dev/null && in_git_repo=true

    if [[ -z "$repo_name" ]]; then
        if [[ "$in_git_repo" == true ]]; then
            repo_name=$(basename "$(git rev-parse --show-toplevel)")
        fi
        echo -n "📦 Nombre del repositorio [$repo_name]: "
        read -r input_name
        [[ -n "$input_name" ]] && repo_name="$input_name"
    fi

    [[ -z "$repo_name" ]] && { echo "❌ Cancelado."; return 1; }

    echo -n "🔒 ¿Repositorio privado? (s/N): "
    read -k 1 -r
    echo
    [[ $REPLY =~ ^[Ss]$ ]] && is_private=true

    local visibility="public"
    [[ "$is_private" == true ]] && visibility="private"

    if [[ "$in_git_repo" == true ]]; then
        # Repo local ya existe: crear en GitHub y pushear
        echo "🚀 Creando repositorio ${C_CYAN}$repo_name${C_RESET} (${C_YELLOW}$visibility${C_RESET}) y sincronizando..."
        gh repo create "$repo_name" --"$visibility" --source=. --remote=origin --push
    else
        # No hay repo local: crear y clonar
        echo "🚀 Creando repositorio ${C_CYAN}$repo_name${C_RESET} (${C_YELLOW}$visibility${C_RESET})..."
        gh repo create "$repo_name" --"$visibility" --clone
    fi

    if [[ $? -eq 0 ]]; then
        echo "${C_GREEN}✅ Repositorio creado y sincronizado.${C_RESET}"
        if [[ "$in_git_repo" == true ]]; then
            echo "🔗 Remote: $(git remote get-url origin)"
        fi
    else
        echo "${C_RED}❌ Error al crear el repositorio.${C_RESET}"
    fi
}

function gh_repo_sync() {
    _gh_check || return 1
    echo "🔄 Sincronizando fork con upstream..."
    gh repo sync
    if [[ $? -eq 0 ]]; then
        echo "${C_GREEN}✅ Fork sincronizado.${C_RESET}"
    else
        echo "${C_RED}❌ Error al sincronizar.${C_RESET}"
    fi
}


function gh_pr() {
    _gh_check || return 1
    
    local action="$1"
    shift 2>/dev/null
    
    if [[ -z "$action" ]]; then
        echo "${C_CYAN}🐙 Pull Requests${C_RESET}"
        echo "  ${C_GREEN}create${C_RESET}  - Crear PR"
        echo "  ${C_GREEN}list${C_RESET}    - Listar PRs"
        echo "  ${C_GREEN}checkout${C_RESET} - Checkout PR localmente"
        echo "  ${C_GREEN}merge${C_RESET}   - Fusionar PR"
        echo "  ${C_GREEN}view${C_RESET}    - Ver PR"
        echo -n "🔍 Acción: "
        read -r action
        [[ -z "$action" ]] && return
    fi
    
    case "$action" in
        create)
            local title="$1"
            local body="$2"
            if [[ -z "$title" ]]; then
                echo -n "📝 Título del PR: "
                read -r title
            fi
            if [[ -z "$body" ]]; then
                echo -n "📝 Descripción (opcional): "
                read -r body
            fi
            echo "🚀 Creando PR..."
            gh pr create --title "$title" --body "$body"
            ;;
        list)
            gh pr list
            ;;
        checkout)
            local pr_number="$1"
            if [[ -z "$pr_number" ]]; then
                echo "📋 PRs disponibles:"
                gh pr list --limit 10
                echo -n "🔢 Número del PR: "
                read -r pr_number
            fi
            [[ -n "$pr_number" ]] && gh pr checkout "$pr_number"
            ;;
        merge)
            local pr_number="$1"
            if [[ -z "$pr_number" ]]; then
                echo "📋 PRs disponibles:"
                gh pr list --limit 10
                echo -n "🔢 Número del PR: "
                read -r pr_number
            fi
            [[ -n "$pr_number" ]] && gh pr merge "$pr_number"
            ;;
        view)
            local pr_number="$1"
            if [[ -z "$pr_number" ]]; then
                echo "📋 PRs disponibles:"
                gh pr list --limit 10
                echo -n "🔢 Número del PR: "
                read -r pr_number
            fi
            [[ -n "$pr_number" ]] && gh pr view "$pr_number"
            ;;
        help|-h|--help)
            echo "Comandos: create, list, checkout, merge, view"
            ;;
        *)
            echo "❌ '$action' no reconocido. Usa 'gh-pr help'"
            return 1
            ;;
    esac
}


function gh_issue() {
    _gh_check || return 1
    
    local action="$1"
    shift 2>/dev/null
    
    if [[ -z "$action" ]]; then
        echo "${C_CYAN}🐛 Issues${C_RESET}"
        echo "  ${C_GREEN}create${C_RESET}  - Crear issue"
        echo "  ${C_GREEN}list${C_RESET}    - Listar issues"
        echo "  ${C_GREEN}view${C_RESET}    - Ver issue"
        echo "  ${C_GREEN}close${C_RESET}   - Cerrar issue"
        echo -n "🔍 Acción: "
        read -r action
        [[ -z "$action" ]] && return
    fi
    
    case "$action" in
        create)
            local title="$1"
            local body="$2"
            if [[ -z "$title" ]]; then
                echo -n "📝 Título del issue: "
                read -r title
            fi
            if [[ -z "$body" ]]; then
                echo -n "📝 Descripción: "
                read -r body
            fi
            echo "🚀 Creando issue..."
            gh issue create --title "$title" --body "$body"
            ;;
        list)
            gh issue list
            ;;
        view)
            local issue_number="$1"
            if [[ -z "$issue_number" ]]; then
                echo "📋 Issues disponibles:"
                gh issue list --limit 10
                echo -n "🔢 Número del issue: "
                read -r issue_number
            fi
            [[ -n "$issue_number" ]] && gh issue view "$issue_number"
            ;;
        close)
            local issue_number="$1"
            if [[ -z "$issue_number" ]]; then
                echo "📋 Issues disponibles:"
                gh issue list --limit 10
                echo -n "🔢 Número del issue: "
                read -r issue_number
            fi
            [[ -n "$issue_number" ]] && gh issue close "$issue_number"
            ;;
        help|-h|--help)
            echo "Comandos: create, list, view, close"
            ;;
        *)
            echo "❌ '$action' no reconocido. Usa 'gh-issue help'"
            return 1
            ;;
    esac
}



function gh_repo_list() {
    _gh_check || return 1
    local limit="${1:-30}"
    echo "📋 Listando repositorios (últimos $limit)..."
    gh repo list --limit "$limit"
}

function gh_repo_clone() {
    _gh_check || return 1
    local repo="$1"
    if [[ -z "$repo" ]]; then
        echo -n "📦 Usuario/repositorio (ej: usuario/repo): "
        read -r repo
    fi
    [[ -z "$repo" ]] && { echo "❌ Cancelado."; return 1; }
    echo "📥 Clonando ${C_CYAN}$repo${C_RESET}..."
    gh repo clone "$repo"
}


# ==============================================================================
# GITHUB GISTS (Usa 'gh')
# ==============================================================================

# Listar gists (opcional pasar límite: gh-gist-list 20)
function gh_gist_list() {
  local limit="${1:-10}"
  gh gist list --limit "$limit"
}

function gh_gist_view() {
  local id="$1"
  local file="$2"
  local output="$3"

  if [ -z "$id" ]; then
    echo "Uso: gh-gist-view <ID> [nombre_archivo] [salida_archivo]"
    return 1
  fi

  if [ -n "$file" ] && [ -n "$output" ]; then
    gh gist view "$id" --filename "$file" --raw > "$output"
    echo "✔ Archivo '$file' guardado como '$output'"
  elif [ -n "$file" ]; then
    gh gist view "$id" --filename "$file"
  else
    gh gist view "$id"
  fi
}


# Crear un gist
# Uso: gh-gist-create <archivo1> [archivo2...] [-p para público] [-d "descripción"]
# Ejemplo: gh-gist-create lambda.ts -d "Mi helper de AWS"
function gh_gist_new() {
  if [ "$#" -eq 0 ]; then
    echo "Uso: gh-gist-create <archivos...> [-p|--public] [-d|--desc \"texto\"]"
    return 1
  fi
  gh gist create "$@"
}


# Editar un gist (archivo o metadatos)
# Uso: gh-gist-edit <ID> [-a nuevo_archivo.ts]
function gh_gist_edit() {
  local id="$1"
  shift
  if [ -z "$id" ]; then
    echo "Uso: gh-gist-edit <ID> [opciones gh]"
    return 1
  fi
  gh gist edit "$id" "$@"
}


# ==============================================
# 🐙 GH - DISPATCHER (useGh)
# ==============================================
_gh_show_help() {
  echo "${C_CYAN}Uso: useGh <subcomando> [args]${C_RESET}"
  echo "${C_CYAN}Funciones:${C_RESET}"
  echo "  pr                 Pull requests (create, list, checkout, merge, view)"
  echo "  issue              Issues (create, list, view, close)"
  echo "  repo-new, rn       Crear repositorio"
  echo "  repo-clone, rc     Clonar repositorio"
  echo "  repo-list, rl      Listar repositorios"
  echo "  repo-sync, rs      Sincronizar fork con upstream"
  echo "  gist-new, gn       Crear gist"
  echo "  gist-edit, ge      Editar gist"
  echo "  gist-list, gl      Listar gists"
  echo "  gist-view, gv      Ver gist"
  echo "  mirror             Remotos duales GitHub/GitLab"
  echo "${C_CYAN}Passthrough:${C_RESET} cualquier otra cosa va directa a gh"
  echo "  (api, auth, browse, release, run, secret, workflow...)"
}

on_gh() {
  local cmd="$1"
  [[ $# -gt 0 ]] && shift

  case "$cmd" in
    pr)            gh_pr "$@" ;;
    issue)         gh_issue "$@" ;;
    repo-new|rn)   gh_repo_new "$@" ;;
    repo-clone|rc) gh_repo_clone "$@" ;;
    repo-list|rl)  gh_repo_list "$@" ;;
    repo-sync|rs)  gh_repo_sync "$@" ;;
    gist-new|gn)   gh_gist_new "$@" ;;
    gist-edit|ge)  gh_gist_edit "$@" ;;
    gist-list|gl)  gh_gist_list "$@" ;;
    gist-view|gv)  gh_gist_view "$@" ;;
    mirror)        git_mirroring "$@" ;;
    -h|--help|help) _gh_show_help ;;
    "")
      local opt
      if command -v gum &>/dev/null; then
        opt=$(gum choose \
          "pr · pull requests" \
          "issue · issues" \
          "repo-new · crear repositorio" \
          "repo-clone · clonar repositorio" \
          "repo-list · listar repositorios" \
          "repo-sync · sincronizar fork" \
          "gist-new · crear gist" \
          "gist-edit · editar gist" \
          "gist-list · listar gists" \
          "gist-view · ver gist" \
          "mirror · remotos duales" \
          --header " 🐙 GH · Elige subcomando ")
        [[ -z "$opt" ]] && return 0
        on_gh "${opt%% · *}"
      else
        _gh_show_help
        printf "Subcomando: " >&2
        read -r opt
        [[ -z "$opt" ]] && return 0
        on_gh "$opt"
      fi
      ;;
    *)
      command gh "$cmd" "$@"
      ;;
  esac
}

