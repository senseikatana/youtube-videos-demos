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
# 🔐 AUTH · Autenticación
# ==============================================
_gh_auth() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "status · estado de autenticación" \
        "login · iniciar sesión" \
        "logout · cerrar sesión" \
        "token · mostrar token" \
        "switch · cambiar cuenta" \
        "setup-git · configurar git con gh" \
        --header " 🔐 AUTH · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔐 AUTH" >&2
      echo "1) Status" >&2
      echo "2) Login" >&2
      echo "3) Logout" >&2
      echo "4) Token" >&2
      echo "5) Switch" >&2
      echo "6) Setup-git" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="status" ;; 2) choice="login" ;; 3) choice="logout" ;;
        4) choice="token" ;; 5) choice="switch" ;; 6) choice="setup-git" ;;
        *) continue ;;
      esac
    fi
    gh auth "$choice"
    echo "" >&2
  done
}

# ==============================================
# 🔀 PR · Pull Requests
# ==============================================
_gh_pr() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar PRs" \
        "view · ver PR" \
        "create · crear PR" \
        "checkout · checkout de PR" \
        "merge · mergear PR" \
        "close · cerrar PR" \
        "reopen · reabrir PR" \
        "diff · ver diff de PR" \
        "ready · marcar como ready" \
        "review · revisar PR" \
        "comment · comentar PR" \
        "checks · ver checks/CI" \
        "edit · editar PR" \
        "status · estado de PRs" \
        --header " 🔀 PR · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔀 PR" >&2
      echo "1) List" >&2
      echo "2) View" >&2
      echo "3) Create" >&2
      echo "4) Checkout" >&2
      echo "5) Merge" >&2
      echo "6) Close" >&2
      echo "7) Reopen" >&2
      echo "8) Diff" >&2
      echo "9) Ready" >&2
      echo "10) Review" >&2
      echo "11) Comment" >&2
      echo "12) Checks" >&2
      echo "13) Edit" >&2
      echo "14) Status" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="view" ;; 3) choice="create" ;;
        4) choice="checkout" ;; 5) choice="merge" ;; 6) choice="close" ;;
        7) choice="reopen" ;; 8) choice="diff" ;; 9) choice="ready" ;;
        10) choice="review" ;; 11) choice="comment" ;; 12) choice="checks" ;;
        13) choice="edit" ;; 14) choice="status" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)
        local limit
        if command -v gum &>/dev/null; then
          limit=$(gum input --placeholder "límite (default: 30)")
        else
          echo -n "Límite (30): " >&2; read -r limit
        fi
        gh pr list --limit "${limit:-30}"
        ;;
      view)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de PR")
        else
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr view "$num"
        ;;
      create)
        gh pr create
        ;;
      checkout)
        local num
        if command -v gum &>/dev/null; then
          num=$(gh pr list --limit 20 | gum filter --header "Selecciona PR" | awk '{print $1}')
        else
          gh pr list --limit 20 >&2
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr checkout "$num"
        ;;
      merge)
        local num
        if command -v gum &>/dev/null; then
          num=$(gh pr list --state open --limit 20 | gum filter --header "Selecciona PR a merge" | awk '{print $1}')
        else
          gh pr list --state open --limit 20 >&2
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr merge "$num"
        ;;
      close)
        local num
        if command -v gum &>/dev/null; then
          num=$(gh pr list --state open --limit 20 | gum filter --header "Selecciona PR a cerrar" | awk '{print $1}')
        else
          gh pr list --state open --limit 20 >&2
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr close "$num"
        ;;
      reopen)
        local num
        if command -v gum &>/dev/null; then
          num=$(gh pr list --state closed --limit 20 | gum filter --header "Selecciona PR a reabrir" | awk '{print $1}')
        else
          gh pr list --state closed --limit 20 >&2
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr reopen "$num"
        ;;
      diff)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de PR")
        else
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr diff "$num"
        ;;
      ready)
        local num
        if command -v gum &>/dev/null; then
          num=$(gh pr list --state open --limit 20 --json number,title | gum filter --header "Selecciona PR" | awk '{print $1}')
        else
          gh pr list --state open --limit 20 >&2
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr ready "$num"
        ;;
      review)
        local num action
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de PR")
          [[ -z "$num" ]] && continue
          action=$(gum choose "approve · aprobar" "request-changes · solicitar cambios" "comment · comentar" --header "Tipo de review")
          [[ -z "$action" ]] && continue
          action="${action%% · *}"
        else
          echo -n "PR #: " >&2; read -r num
          [[ -z "$num" ]] && continue
          echo "1) Approve  2) Request-changes  3) Comment" >&2
          echo -n "Opción: " >&2; read -r action
          case "$action" in
            1) action="approve" ;; 2) action="request-changes" ;; 3) action="comment" ;;
            *) continue ;;
          esac
        fi
        gh pr review "$num" "--$action"
        ;;
      comment)
        local num body
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de PR")
          [[ -z "$num" ]] && continue
          body=$(gum write --placeholder "comentario")
        else
          echo -n "PR #: " >&2; read -r num
          [[ -z "$num" ]] && continue
          echo -n "Comentario: " >&2; read -r body
        fi
        [[ -z "$body" ]] && continue
        gh pr comment "$num" --body "$body"
        ;;
      checks)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de PR (vacío = actual)")
        else
          echo -n "PR #: " >&2; read -r num
        fi
        gh pr checks ${num:+"$num"}
        ;;
      edit)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de PR")
        else
          echo -n "PR #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh pr edit "$num"
        ;;
      status)
        gh pr status
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🐛 ISSUE · Issues
# ==============================================
_gh_issue() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar issues" \
        "view · ver issue" \
        "create · crear issue" \
        "close · cerrar issue" \
        "reopen · reabrir issue" \
        "comment · comentar issue" \
        "edit · editar issue" \
        "pin · fijar issue" \
        "unpin · desfijar issue" \
        "status · estado de issues" \
        --header " 🐛 ISSUE · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🐛 ISSUE" >&2
      echo "1) List" >&2
      echo "2) View" >&2
      echo "3) Create" >&2
      echo "4) Close" >&2
      echo "5) Reopen" >&2
      echo "6) Comment" >&2
      echo "7) Edit" >&2
      echo "8) Pin" >&2
      echo "9) Unpin" >&2
      echo "10) Status" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="view" ;; 3) choice="create" ;;
        4) choice="close" ;; 5) choice="reopen" ;; 6) choice="comment" ;;
        7) choice="edit" ;; 8) choice="pin" ;; 9) choice="unpin" ;;
        10) choice="status" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)
        local limit
        if command -v gum &>/dev/null; then
          limit=$(gum input --placeholder "límite (default: 30)")
        else
          echo -n "Límite (30): " >&2; read -r limit
        fi
        gh issue list --limit "${limit:-30}"
        ;;
      view)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de issue")
        else
          echo -n "Issue #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh issue view "$num"
        ;;
      create)
        gh issue create
        ;;
      close)
        local num
        if command -v gum &>/dev/null; then
          num=$(gh issue list --state open --limit 20 | gum filter --header "Selecciona issue a cerrar" | awk '{print $1}')
        else
          gh issue list --state open --limit 20 >&2
          echo -n "Issue #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh issue close "$num"
        ;;
      reopen)
        local num
        if command -v gum &>/dev/null; then
          num=$(gh issue list --state closed --limit 20 | gum filter --header "Selecciona issue a reabrir" | awk '{print $1}')
        else
          gh issue list --state closed --limit 20 >&2
          echo -n "Issue #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh issue reopen "$num"
        ;;
      comment)
        local num body
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de issue")
          [[ -z "$num" ]] && continue
          body=$(gum write --placeholder "comentario")
        else
          echo -n "Issue #: " >&2; read -r num
          [[ -z "$num" ]] && continue
          echo -n "Comentario: " >&2; read -r body
        fi
        [[ -z "$body" ]] && continue
        gh issue comment "$num" --body "$body"
        ;;
      edit)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de issue")
        else
          echo -n "Issue #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh issue edit "$num"
        ;;
      pin)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de issue")
        else
          echo -n "Issue #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh issue pin "$num"
        ;;
      unpin)
        local num
        if command -v gum &>/dev/null; then
          num=$(gum input --placeholder "número de issue")
        else
          echo -n "Issue #: " >&2; read -r num
        fi
        [[ -z "$num" ]] && continue
        gh issue unpin "$num"
        ;;
      status)
        gh issue status
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 📦 REPO · Repositorios
# ==============================================
_gh_repo() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "new · crear repositorio" \
        "clone · clonar repositorio" \
        "list · listar repositorios" \
        "view · ver repositorio" \
        "fork · hacer fork" \
        "sync · sincronizar fork" \
        "edit · editar repositorio" \
        "delete · eliminar repositorio" \
        "archive · archivar repositorio" \
        "deploy-key · gestionar deploy keys" \
        --header " 📦 REPO · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "📦 REPO" >&2
      echo "1) New" >&2
      echo "2) Clone" >&2
      echo "3) List" >&2
      echo "4) View" >&2
      echo "5) Fork" >&2
      echo "6) Sync" >&2
      echo "7) Edit" >&2
      echo "8) Delete" >&2
      echo "9) Archive" >&2
      echo "10) Deploy-key" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="new" ;; 2) choice="clone" ;; 3) choice="list" ;;
        4) choice="view" ;; 5) choice="fork" ;; 6) choice="sync" ;;
        7) choice="edit" ;; 8) choice="delete" ;; 9) choice="archive" ;;
        10) choice="deploy-key" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      new)
        gh_repo_new
        ;;
      clone)
        local repo
        if command -v gum &>/dev/null; then
          repo=$(gum input --placeholder "owner/repo")
        else
          echo -n "owner/repo: " >&2; read -r repo
        fi
        [[ -z "$repo" ]] && continue
        gh repo clone "$repo"
        ;;
      list)
        local limit
        if command -v gum &>/dev/null; then
          limit=$(gum input --placeholder "límite (default: 30)")
        else
          echo -n "Límite (30): " >&2; read -r limit
        fi
        gh repo list --limit "${limit:-30}"
        ;;
      view)
        local repo
        if command -v gum &>/dev/null; then
          repo=$(gum input --placeholder "owner/repo (vacío = actual)")
        else
          echo -n "owner/repo (vacío = actual): " >&2; read -r repo
        fi
        gh repo view ${repo:+"$repo"}
        ;;
      fork)
        local repo
        if command -v gum &>/dev/null; then
          repo=$(gum input --placeholder "owner/repo")
        else
          echo -n "owner/repo: " >&2; read -r repo
        fi
        [[ -z "$repo" ]] && continue
        gh repo fork "$repo"
        ;;
      sync)
        gh_repo_sync
        ;;
      edit)
        gh repo edit
        ;;
      delete)
        local repo
        if command -v gum &>/dev/null; then
          repo=$(gum input --placeholder "owner/repo")
        else
          echo -n "owner/repo: " >&2; read -r repo
        fi
        [[ -z "$repo" ]] && continue
        echo -e "${C_YELLOW}⚠️ Esto eliminará '$repo' PERMANENTEMENTE.${C_RESET}" >&2
        gh repo delete "$repo"
        ;;
      archive)
        local repo
        if command -v gum &>/dev/null; then
          repo=$(gum input --placeholder "owner/repo")
        else
          echo -n "owner/repo: " >&2; read -r repo
        fi
        [[ -z "$repo" ]] && continue
        gh repo archive "$repo"
        ;;
      deploy-key)
        echo "Subcomandos: list, create, delete" >&2
        gh repo deploy-key "$@"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🏷️ RELEASE · Releases
# ==============================================
_gh_release() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar releases" \
        "view · ver release" \
        "create · crear release" \
        "edit · editar release" \
        "delete · eliminar release" \
        "download · descargar assets" \
        "upload · subir assets" \
        --header " 🏷️ RELEASE · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🏷️ RELEASE" >&2
      echo "1) List" >&2
      echo "2) View" >&2
      echo "3) Create" >&2
      echo "4) Edit" >&2
      echo "5) Delete" >&2
      echo "6) Download" >&2
      echo "7) Upload" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="view" ;; 3) choice="create" ;;
        4) choice="edit" ;; 5) choice="delete" ;; 6) choice="download" ;;
        7) choice="upload" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)
        local limit
        if command -v gum &>/dev/null; then
          limit=$(gum input --placeholder "límite (default: 10)")
        else
          echo -n "Límite (10): " >&2; read -r limit
        fi
        gh release list --limit "${limit:-10}"
        ;;
      view)
        local tag
        if command -v gum &>/dev/null; then
          tag=$(gh release list --limit 20 | gum filter --header "Selecciona release" | awk '{print $1}')
        else
          gh release list --limit 20 >&2
          echo -n "Tag: " >&2; read -r tag
        fi
        [[ -z "$tag" ]] && continue
        gh release view "$tag"
        ;;
      create)
        gh release create
        ;;
      edit)
        local tag
        if command -v gum &>/dev/null; then
          tag=$(gum input --placeholder "tag del release")
        else
          echo -n "Tag: " >&2; read -r tag
        fi
        [[ -z "$tag" ]] && continue
        gh release edit "$tag"
        ;;
      delete)
        local tag
        if command -v gum &>/dev/null; then
          tag=$(gh release list --limit 20 | gum filter --header "Selecciona release a eliminar" | awk '{print $1}')
        else
          gh release list --limit 20 >&2
          echo -n "Tag: " >&2; read -r tag
        fi
        [[ -z "$tag" ]] && continue
        echo -e "${C_YELLOW}⚠️ Eliminar release '$tag'${C_RESET}" >&2
        gh release delete "$tag"
        ;;
      download)
        local tag
        if command -v gum &>/dev/null; then
          tag=$(gh release list --limit 20 | gum filter --header "Selecciona release" | awk '{print $1}')
        else
          gh release list --limit 20 >&2
          echo -n "Tag: " >&2; read -r tag
        fi
        [[ -z "$tag" ]] && continue
        gh release download "$tag"
        ;;
      upload)
        local tag
        if command -v gum &>/dev/null; then
          tag=$(gum input --placeholder "tag del release")
        else
          echo -n "Tag: " >&2; read -r tag
        fi
        [[ -z "$tag" ]] && continue
        gh release upload "$tag"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 📝 GIST · Gists
# ==============================================
_gh_gist() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "new · crear gist" \
        "list · listar gists" \
        "view · ver gist" \
        "edit · editar gist" \
        "delete · eliminar gist" \
        "clone · clonar gist" \
        "fork · hacer fork de gist" \
        --header " 📝 GIST · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "📝 GIST" >&2
      echo "1) New" >&2
      echo "2) List" >&2
      echo "3) View" >&2
      echo "4) Edit" >&2
      echo "5) Delete" >&2
      echo "6) Clone" >&2
      echo "7) Fork" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="new" ;; 2) choice="list" ;; 3) choice="view" ;;
        4) choice="edit" ;; 5) choice="delete" ;; 6) choice="clone" ;;
        7) choice="fork" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      new)     gh gist create ;;
      list)
        local limit
        if command -v gum &>/dev/null; then
          limit=$(gum input --placeholder "límite (default: 10)")
        else
          echo -n "Límite (10): " >&2; read -r limit
        fi
        gh gist list --limit "${limit:-10}"
        ;;
      view)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh gist list --limit 20 | gum filter --header "Selecciona gist" | awk '{print $1}')
        else
          gh gist list --limit 20 >&2
          echo -n "ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh gist view "$id"
        ;;
      edit)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh gist list --limit 20 | gum filter --header "Selecciona gist" | awk '{print $1}')
        else
          gh gist list --limit 20 >&2
          echo -n "ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh gist edit "$id"
        ;;
      delete)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh gist list --limit 20 | gum filter --header "Selecciona gist a eliminar" | awk '{print $1}')
        else
          gh gist list --limit 20 >&2
          echo -n "ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        echo -e "${C_YELLOW}⚠️ Eliminar gist '$id'${C_RESET}" >&2
        gh gist delete "$id"
        ;;
      clone)
        local id
        if command -v gum &>/dev/null; then
          id=$(gum input --placeholder "ID del gist")
        else
          echo -n "ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh gist clone "$id"
        ;;
      fork)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh gist list --limit 20 | gum filter --header "Selecciona gist" | awk '{print $1}')
        else
          gh gist list --limit 20 >&2
          echo -n "ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh gist fork "$id"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# ⚡ WORKFLOW · GitHub Actions Workflows
# ==============================================
_gh_workflow() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar workflows" \
        "view · ver workflow" \
        "run · ejecutar workflow" \
        "enable · habilitar workflow" \
        "disable · deshabilitar workflow" \
        --header " ⚡ WORKFLOW · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "⚡ WORKFLOW" >&2
      echo "1) List" >&2
      echo "2) View" >&2
      echo "3) Run" >&2
      echo "4) Enable" >&2
      echo "5) Disable" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="view" ;; 3) choice="run" ;;
        4) choice="enable" ;; 5) choice="disable" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)    gh workflow list ;;
      view)
        local wf
        if command -v gum &>/dev/null; then
          wf=$(gh workflow list | gum filter --header "Selecciona workflow" | awk '{print $1}')
        else
          gh workflow list >&2
          echo -n "ID o nombre: " >&2; read -r wf
        fi
        [[ -z "$wf" ]] && continue
        gh workflow view "$wf"
        ;;
      run)
        local wf
        if command -v gum &>/dev/null; then
          wf=$(gh workflow list | gum filter --header "Selecciona workflow" | awk '{print $1}')
        else
          gh workflow list >&2
          echo -n "ID o nombre: " >&2; read -r wf
        fi
        [[ -z "$wf" ]] && continue
        gh workflow run "$wf"
        ;;
      enable)
        local wf
        if command -v gum &>/dev/null; then
          wf=$(gh workflow list | gum filter --header "Selecciona workflow" | awk '{print $1}')
        else
          gh workflow list >&2
          echo -n "ID o nombre: " >&2; read -r wf
        fi
        [[ -z "$wf" ]] && continue
        gh workflow enable "$wf"
        ;;
      disable)
        local wf
        if command -v gum &>/dev/null; then
          wf=$(gh workflow list | gum filter --header "Selecciona workflow" | awk '{print $1}')
        else
          gh workflow list >&2
          echo -n "ID o nombre: " >&2; read -r wf
        fi
        [[ -z "$wf" ]] && continue
        gh workflow disable "$wf"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🏃 RUN · Workflow Runs
# ==============================================
_gh_run() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar runs" \
        "view · ver run" \
        "watch · observar run en vivo" \
        "rerun · re-ejecutar run" \
        "cancel · cancelar run" \
        "download · descargar logs" \
        --header " 🏃 RUN · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🏃 RUN" >&2
      echo "1) List" >&2
      echo "2) View" >&2
      echo "3) Watch" >&2
      echo "4) Rerun" >&2
      echo "5) Cancel" >&2
      echo "6) Download" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="view" ;; 3) choice="watch" ;;
        4) choice="rerun" ;; 5) choice="cancel" ;; 6) choice="download" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)    gh run list ;;
      view)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh run list --limit 20 | gum filter --header "Selecciona run" | awk '{print $1}')
        else
          gh run list --limit 20 >&2
          echo -n "Run ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh run view "$id"
        ;;
      watch)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh run list --limit 10 | gum filter --header "Selecciona run a observar" | awk '{print $1}')
        else
          gh run list --limit 10 >&2
          echo -n "Run ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh run watch "$id"
        ;;
      rerun)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh run list --limit 20 --status failure | gum filter --header "Selecciona run a re-ejecutar" | awk '{print $1}')
        else
          gh run list --limit 20 >&2
          echo -n "Run ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh run rerun "$id"
        ;;
      cancel)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh run list --limit 10 --status in_progress | gum filter --header "Selecciona run a cancelar" | awk '{print $1}')
        else
          gh run list --limit 10 >&2
          echo -n "Run ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh run cancel "$id"
        ;;
      download)
        local id
        if command -v gum &>/dev/null; then
          id=$(gh run list --limit 20 | gum filter --header "Selecciona run" | awk '{print $1}')
        else
          gh run list --limit 20 >&2
          echo -n "Run ID: " >&2; read -r id
        fi
        [[ -z "$id" ]] && continue
        gh run download "$id"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🔍 SEARCH · Búsqueda
# ==============================================
_gh_search() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "repos · buscar repositorios" \
        "issues · buscar issues" \
        "prs · buscar pull requests" \
        "code · buscar código" \
        "users · buscar usuarios" \
        --header " 🔍 SEARCH · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔍 SEARCH" >&2
      echo "1) Repos" >&2
      echo "2) Issues" >&2
      echo "3) PRs" >&2
      echo "4) Code" >&2
      echo "5) Users" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="repos" ;; 2) choice="issues" ;; 3) choice="prs" ;;
        4) choice="code" ;; 5) choice="users" ;;
        *) continue ;;
      esac
    fi

    local query
    if command -v gum &>/dev/null; then
      query=$(gum input --placeholder "término de búsqueda")
    else
      echo -n "Buscar: " >&2; read -r query
    fi
    [[ -z "$query" ]] && continue
    gh search "$choice" "$query"
    echo "" >&2
  done
}

# ==============================================
# 🏷️ LABEL · Etiquetas
# ==============================================
_gh_label() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar etiquetas" \
        "create · crear etiqueta" \
        "edit · editar etiqueta" \
        "delete · eliminar etiqueta" \
        "clone · clonar etiquetas de otro repo" \
        --header " 🏷️ LABEL · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🏷️ LABEL" >&2
      echo "1) List" >&2
      echo "2) Create" >&2
      echo "3) Edit" >&2
      echo "4) Delete" >&2
      echo "5) Clone" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="create" ;; 3) choice="edit" ;;
        4) choice="delete" ;; 5) choice="clone" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)   gh label list ;;
      create) gh label create ;;
      edit)   gh label edit ;;
      delete)
        local name
        if command -v gum &>/dev/null; then
          name=$(gh label list | gum filter --header "Selecciona etiqueta a eliminar" | awk '{print $1}')
        else
          gh label list >&2
          echo -n "Nombre: " >&2; read -r name
        fi
        [[ -z "$name" ]] && continue
        gh label delete "$name"
        ;;
      clone)
        local repo
        if command -v gum &>/dev/null; then
          repo=$(gum input --placeholder "owner/repo fuente")
        else
          echo -n "owner/repo fuente: " >&2; read -r repo
        fi
        [[ -z "$repo" ]] && continue
        gh label clone "$repo"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🔑 SECRET · GitHub Secrets
# ==============================================
_gh_secret() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar secrets" \
        "set · crear/actualizar secret" \
        "delete · eliminar secret" \
        --header " 🔑 SECRET · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔑 SECRET" >&2
      echo "1) List" >&2
      echo "2) Set" >&2
      echo "3) Delete" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="set" ;; 3) choice="delete" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)   gh secret list ;;
      set)    gh secret set ;;
      delete)
        local name
        if command -v gum &>/dev/null; then
          name=$(gh secret list | gum filter --header "Selecciona secret a eliminar" | awk '{print $1}')
        else
          gh secret list >&2
          echo -n "Nombre: " >&2; read -r name
        fi
        [[ -z "$name" ]] && continue
        gh secret delete "$name"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 📊 VARIABLE · GitHub Variables
# ==============================================
_gh_variable() {
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar variables" \
        "set · crear/actualizar variable" \
        "delete · eliminar variable" \
        --header " 📊 VARIABLE · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "📊 VARIABLE" >&2
      echo "1) List" >&2
      echo "2) Set" >&2
      echo "3) Delete" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="set" ;; 3) choice="delete" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)   gh variable list ;;
      set)    gh variable set ;;
      delete)
        local name
        if command -v gum &>/dev/null; then
          name=$(gh variable list | gum filter --header "Selecciona variable a eliminar" | awk '{print $1}')
        else
          gh variable list >&2
          echo -n "Nombre: " >&2; read -r name
        fi
        [[ -z "$name" ]] && continue
        gh variable delete "$name"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🐙 GH - DISPATCHER (useGh)
# ==============================================
_gh_show_help() {
  cat <<EOF
 ${C_CYAN}Uso:${C_RESET} useGh <comando> [args]

 ${C_YELLOW}Submenús interactivos (sin args = gum menu, con args = passthrough):${C_RESET}
  auth           status / login / logout / token / switch / setup-git
  pr             list / view / create / checkout / merge / close / reopen / diff / ready / review / comment / checks / edit / status
  issue          list / view / create / close / reopen / comment / edit / pin / unpin / status
  repo           new / clone / list / view / fork / sync / edit / delete / archive / deploy-key
  release        list / view / create / edit / delete / download / upload
  gist           new / list / view / edit / delete / clone / fork
  workflow       list / view / run / enable / disable
  run            list / view / watch / rerun / cancel / download
  search         repos / issues / prs / code / users
  label          list / create / edit / delete / clone
  secret         list / set / delete
  variable       list / set / delete

 ${C_YELLOW}Aliases legacy:${C_RESET}
  repo-new, rn / repo-clone, rc / repo-list, rl / repo-sync, rs
  gist-new, gn / gist-edit, ge / gist-list, gl / gist-view, gv
  mirror · remotos duales GitHub/GitLab

 ${C_CYAN}Passthrough:${C_RESET} cualquier otro comando va directo a gh
  (api, browse, codespace, discussion, org, project, config, extension...)
EOF
}

on_gh() {
  local cmd="$1"
  [[ $# -gt 0 ]] && shift

  case "$cmd" in
    auth)          if [[ $# -gt 0 ]]; then gh auth "$@"; else _gh_auth; fi ;;
    pr)            if [[ $# -gt 0 ]]; then gh pr "$@"; else _gh_pr; fi ;;
    issue)         if [[ $# -gt 0 ]]; then gh issue "$@"; else _gh_issue; fi ;;
    repo)          if [[ $# -gt 0 ]]; then gh repo "$@"; else _gh_repo; fi ;;
    release)       if [[ $# -gt 0 ]]; then gh release "$@"; else _gh_release; fi ;;
    gist)          if [[ $# -gt 0 ]]; then gh gist "$@"; else _gh_gist; fi ;;
    workflow)      if [[ $# -gt 0 ]]; then gh workflow "$@"; else _gh_workflow; fi ;;
    run)           if [[ $# -gt 0 ]]; then gh run "$@"; else _gh_run; fi ;;
    search)        if [[ $# -gt 0 ]]; then gh search "$@"; else _gh_search; fi ;;
    label)         if [[ $# -gt 0 ]]; then gh label "$@"; else _gh_label; fi ;;
    secret)        if [[ $# -gt 0 ]]; then gh secret "$@"; else _gh_secret; fi ;;
    variable)      if [[ $# -gt 0 ]]; then gh variable "$@"; else _gh_variable; fi ;;
    # Legacy aliases
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
          "auth · login/status/token/switch/setup-git" \
          "pr · list/view/create/checkout/merge/close/review/diff" \
          "issue · list/view/create/close/comment/edit/status" \
          "repo · new/clone/list/view/fork/sync/edit/delete" \
          "release · list/view/create/edit/delete/download" \
          "gist · new/list/view/edit/delete/clone/fork" \
          "workflow · list/view/run/enable/disable" \
          "run · list/view/watch/rerun/cancel/logs" \
          "search · repos/issues/prs/code/users" \
          "label · list/create/edit/delete/clone" \
          "secret · list/set/delete" \
          "variable · list/set/delete" \
          "browse · abrir en navegador" \
          "status · dashboard de notificaciones" \
          --header " 🐙 GH · Esc=salir ")
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

