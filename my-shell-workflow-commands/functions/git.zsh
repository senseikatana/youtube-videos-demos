#!/usr/bin/env zsh

# ==============================================
# 🎨 CONFIGURACIÓN
# ==============================================
C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
C_BLUE=$'\033[0;34m'; C_CYAN=$'\033[0;36m'; C_RESET=$'\033[0m'

# ==============================================
# 🔧 HELPERS BÁSICOS
# ==============================================
_git_check_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null || {
    echo -e "${C_RED}❌ No estás en un repositorio git.${C_RESET}" >&2
    return 1
  }
}

# Como _git_check_repo, pero ofrece inicializar el repo si no existe
_git_ensure_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null && return 0

  echo -e "${C_YELLOW}📁 No estás en un repositorio git.${C_RESET}" >&2
  local opt n
  if command -v gum &>/dev/null; then
    opt=$(gum choose \
      "init · git init simple" \
      "init completo · git init + docs + repo en GitHub (como useGitInit)" \
      --header " 📁 ¿Inicializamos? ")
    [[ -z "$opt" ]] && return 1
  else
    echo "  1) init simple   2) init completo (docs + GitHub)" >&2
    printf "Opción [1]: " >&2
    read -r n
    [[ "$n" == 2 ]] && opt="init completo" || opt="init"
  fi

  case "$opt" in
    init\ completo*)
      git init >/dev/null
      echo -e "${C_GREEN}✅ Repositorio inicializado.${C_RESET}" >&2
      _confirm "📚 ¿Generar documentación (initdocs)?" && on_initdocs
      _confirm "🐙 ¿Crear repo en GitHub (gh_repo_new)?" && gh_repo_new
      ;;
    *)
      git init >/dev/null
      echo -e "${C_GREEN}✅ Repositorio inicializado. Sigue con el add/commit.${C_RESET}" >&2
      ;;
  esac

  git rev-parse --is-inside-work-tree &>/dev/null
}

_git_current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null
}

_confirm() {
  local prompt="${1:-¿Continuar?} (s/N): "
  local reply
  echo -n "$prompt" >&2
  read -k 1 reply 2>/dev/null || read -n 1 reply
  echo >&2
  [[ "$reply" =~ ^[SsYy]$ ]]
}

_show_help() {
  cat <<EOF
 ${C_CYAN}Uso:${C_RESET} useGit <comando> [args]

 ${C_YELLOW}Flujos interactivos:${C_RESET}
  push, p        Commit + Push automático
  commit, c      Solo commit local
  release, r     Tag SemVer + release en GitHub (CRUD: create/list/view/edit/delete/open)
  merge, m       Merge entre ramas (--strategy=ours|theirs)
  switch, sw     Cambiar de rama (auto-stash)
  flow, f        Menú interactivo rápido
  clean, cl      Limpiar archivos innecesarios (node_modules, dist…)
  submodule, sub Gestión de submódulos (añadir, borrar, arreglar rotos)
  remote, rem    Configurar remotos (SSH/gh)
  tag, t         Menú de tags (create/list/delete/rename/edit)

 ${C_YELLOW}Submenús interactivos (sin args = gum menu, con args = passthrough):${C_RESET}
  branch, b      list / list-all (-a) / create / delete-local / delete-remote / rename
  status, s      short (-sb) / long / porcelain / ignored
  log, l         graph / full / stat / author / last N
  diff, d        working / staged / stat / compact / branches
  stash, sta     push / list / pop / apply / show / drop / clear
  reset, rs      soft / mixed / hard / to-commit
  restore        file / unstage / from-branch (--source)
  rebase, rb     onto / interactive (-i) / abort / continue / skip
  checkout, co   branch / create (-b) / file / detach
  pull, pl       default / rebase / ff-only / prune / all
  fetch, ft      default / all / prune / tags / remote
  show           latest / pick / hash / stat / files
  sync           default / fetch-all / prune

 ${C_CYAN}Ejemplos:${C_RESET}
  useGit push              useGit tag               useGit branch -a
  useGit stash list        useGit log --author=yo   useGit branch (→ submenú)
  useGit fetch --all       useGit reset --hard HEAD  useGit show abc123
EOF
}

# Generates a commit message following Conventional Commits v1.0.0
_detect_commit_type() {
  local diff staged_files
  diff=$(git diff --staged)
  staged_files=(${(f)"$(git diff --cached --name-only)"})

  [[ ${#staged_files[@]} -eq 0 ]] && { echo "chore: update staged files"; return 0; }

  # 1. IA Prompt (Ollama / llama3)
  if command -v ollama &>/dev/null && ollama list 2>/dev/null | grep -q "llama3"; then
    local prompt commit_candidate
    prompt="Generate a Git commit message strictly adhering to Conventional Commits v1.0.0.
Format: <type>[optional scope]: <description>
Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
Append '!' after type/scope ONLY if there is a breaking change.
Keep the description imperative, lowercase, and without a trailing period.
Respond ONLY with the single line commit header.
Diff:
 $diff"

    if command -v timeout &>/dev/null; then
      commit_candidate=$(echo "$diff" | timeout 15 ollama run llama3 "$prompt" 2>/dev/null | head -n 1)
    else
      commit_candidate=$(echo "$diff" | ollama run llama3 "$prompt" 2>/dev/null | head -n 1)
    fi

    commit_candidate=$(echo "$commit_candidate" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Validacion estricta segun especificacion Conventional Commits v1.0.0
    if [[ "$commit_candidate" =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9_/-]+\))?!?:[[:space:]][^[:upper:]].+[^.]$ ]]; then
      echo "$commit_candidate"
      return 0
    fi
  fi

  # 2. Fallback determinista
  local commit_type="chore"
  local scope="${staged_files[1]%/*}"
  scope="${scope##*/}"
  [[ -z "$scope" || "$scope" == "." ]] && scope=""

  for file in "${staged_files[@]}"; do
    case "$file" in
      *test*|*spec*|__tests__/*) commit_type="test"; break ;;
      docs/*|*.md|*.rst|*.txt|CHANGELOG*) commit_type="docs"; break ;;
      .github/*|.gitlab-ci*|Jenkinsfile|Dockerfile*|.dockerignore) commit_type="ci"; break ;;
      package*.json|*.lock|Cargo.toml|go.mod|Makefile|*.config.*|tsconfig*.json) commit_type="build"; break ;;
      *.css|*.scss|*.less|*.styl) commit_type="style"; break ;;
      src/*|lib/*|app/*|components/*|pages/*|features/*)
        if [[ "$file" =~ (fix|bug|patch|issue) ]]; then
          commit_type="fix"
        else
          commit_type="feat"
        fi
        break ;;
      *)
        if [[ "$file" =~ (fix|bug|patch|issue) ]]; then
          commit_type="fix"
          break
        fi ;;
    esac
  done

  local action_desc
  case "$commit_type" in
    feat) action_desc="add changes to" ;;
    fix) action_desc="fix issue in" ;;
    docs) action_desc="update documentation in" ;;
    test) action_desc="add test coverage for" ;;
    style) action_desc="adjust formatting in" ;;
    refactor) action_desc="refactor modules in" ;;
    perf) action_desc="improve performance in" ;;
    build) action_desc="update dependencies or build settings in" ;;
    ci) action_desc="update pipeline configuration in" ;;
    *) action_desc="update" ;;
  esac

  local target_summary
  if [[ ${#staged_files[@]} -eq 1 ]]; then
    target_summary="${staged_files[1]##*/}"
  else
    target_summary="${#staged_files[@]} files"
  fi

  local formatted_scope=""
  [[ -n "$scope" ]] && formatted_scope="($scope)"

  echo "${commit_type}${formatted_scope}: ${action_desc} ${target_summary}"
}

# ==============================================
# 📦 STAGING Y MENSAJE (DRY)
# ==============================================
_stage_and_get_message() {
  local auto_add="$1"
  local current_branch
  current_branch="$(_git_current_branch)"
  
  echo -e "📊 Estado en ${C_BLUE}${current_branch:-sin-rama}${C_RESET}:" >&2
  git status -sb >&2
  
  local unstaged untracked
  unstaged=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  
  if [[ $unstaged -gt 0 || $untracked -gt 0 ]]; then
    local add_mode
    if [[ "$auto_add" == "true" ]]; then
      add_mode="add ."
    elif command -v gum &>/dev/null; then
      add_mode=$(gum choose \
        "add . · directorio actual" \
        "add -A · todo el repo" \
        "add · elegir archivos" \
        "nada · ya está en staging" \
        --header " 📦 ¿Qué añadimos al staging? ")
    else
      echo "  1) add .   2) add -A   3) elegir archivos   4) nada" >&2
      printf "Opción [1]: " >&2
      read -r add_mode
      case "$add_mode" in
        2) add_mode="add -A" ;; 3) add_mode="add · elegir" ;; 4) add_mode="nada" ;; *) add_mode="add ." ;;
      esac
    fi

    case "$add_mode" in
      "add ."*) git add . ;;
      "add -A"*) git add -A ;;
      "add ·"*)
        local sel
        if command -v gum &>/dev/null; then
          sel=$(git status --porcelain | cut -c4- | gum choose --no-limit \
            --header " 📦 Marca con espacio, confirma con enter ")
        else
          git status --short >&2
          printf "Archivos a añadir: " >&2
          read -r sel
        fi
        [[ -z "$sel" ]] && { echo "🛑 Nada seleccionado." >&2; return 1; }
        git add -- ${(f)sel}
        ;;
      *) ;; # nada / ya en staging
    esac
  fi
  
  local staged
  staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [[ $staged -eq 0 ]]; then
    echo "✅ No hay cambios para commitear." >&2
    return 1
  fi
  
  local commit_msg
  commit_msg=$(_detect_commit_type)
  echo -e "\n📦 Archivos a commitear:" >&2
  git diff --cached --stat >&2
  echo -e "\n💬 Mensaje sugerido: ${C_GREEN}$commit_msg${C_RESET}" >&2
  
  if _confirm "✏️  ¿Modificar mensaje?"; then
    echo -n "📝 Nuevo mensaje: " >&2
    read -r user_msg
    [[ -n "$user_msg" ]] && commit_msg="$user_msg"
  fi
  
  echo "$commit_msg"
}

# ==============================================
# 🚀 FUNCIONES DE ACCIÓN
# ==============================================
_action_commit() {
  _git_ensure_repo || return 1
  local commit_msg
  commit_msg=$(_stage_and_get_message "false") || return 0
  git commit -m "$commit_msg" && echo "✅ Commit realizado." >&2
}

_action_push() {
  _git_ensure_repo || return 1
  local current_branch commit_msg
  current_branch="$(_git_current_branch)"
  commit_msg=$(_stage_and_get_message "true") || return 0
  
  echo -e "\n⚠️  ¿Commit + Push a ${C_BLUE}$current_branch${C_RESET}?" >&2
  _confirm "Confirmar" || { echo "🛑 Cancelado." >&2; return 1; }
  
  echo -e "📝 Commit: ${C_YELLOW}$commit_msg${C_RESET}" >&2
   git commit -m "$commit_msg" || { echo "❌ Error en commit." >&2; return 1; }
  
  echo -e "🚀 Push a ${C_BLUE}$current_branch${C_RESET}..." >&2
  git push origin "$current_branch" && {
    echo "✅ ¡Todo listo!" >&2
    git log --oneline --decorate --graph -1 >&2
  } || { echo "❌ Error en push. ¿Falta el remote? Prueba useGitInit o useGh repo-new." >&2; return 1; }
}

# ==============================================
# 🏷️ HELPERS DE TAGS Y RELEASES (CRUD Y SEMVER)
# ==============================================

_list_recent_tags() {
  local last_tags
  last_tags=$(git tag --sort=-v:refname | head -n 5)
  
  if [[ -n "$last_tags" ]]; then
    echo -e "${C_CYAN}🏷️  Últimas releases:${C_RESET}" >&2
    while read -r tag; do
      local date commit_hash msg
      date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
      commit_hash=$(git rev-list -n 1 "$tag" 2>/dev/null | cut -c1-7)
      msg=$(git tag -l --format='%(contents:subject)' "$tag" 2>/dev/null)
      printf "  ${C_GREEN}%-10s${C_RESET} %s ${C_BLUE}%s${C_RESET} \"%s\"\n" "$tag" "$date" "$commit_hash" "$msg" >&2
    done <<< "$last_tags"
    echo "" >&2
  else
    echo -e "${C_YELLOW}⚠️  No hay tags previos. Empezando desde cero.${C_RESET}\n" >&2
  fi
}

_tag_exists() {
  git rev-parse "refs/tags/$1" &>/dev/null
}

# Explica si será Major, Minor o Patch basado en Conventional Commits
_get_next_version() {
  local major minor patch
  local latest_tag commit_range

  latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)
  if [[ "$latest_tag" =~ v?([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    major=${match[1]}; minor=${match[2]}; patch=${match[3]}
  else
    major=0; minor=0; patch=0
  fi

  if [[ -n "$latest_tag" ]]; then
    commit_range="${latest_tag}..HEAD"
  else
    commit_range="HEAD"
  fi

  local commits bump_level="patch" reason="Solo fixes o chores"

  if [[ "$latest_tag" == "v0.0.0" ]]; then
    bump_level="minor"
    reason="Primer release del repositorio"
  else
    commits=$(git log "$commit_range" --pretty=format:"%s%n%b" 2>/dev/null)
    if [[ -n "$commits" ]]; then
      while IFS= read -r line; do
        local lower_line="${line:l}"
        # Breaking change = Major
        if [[ "$lower_line" == *"breaking change"* ]] || [[ "$line" =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9_/-]+\))?!: ]]; then
          bump_level="major"
          reason="Detectado '!' o 'BREAKING CHANGE'"
          break
        fi
        # Feature = Minor
        if [[ "$line" =~ ^(feat|docs)(\([a-zA-Z0-9_/-]+\))?: ]]; then
          if [[ "$bump_level" != "major" ]]; then
            bump_level="minor"
            reason="Detectado commit tipo 'feat' o 'docs'"
          fi
        fi
      done <<< "$commits"
    fi
  fi

  case "$bump_level" in
    major) ((major++)); minor=0; patch=0 ;;
    minor) ((minor++)); patch=0 ;;
    patch) ((patch++)) ;;
  esac

  echo "v${major}.${minor}.${patch}|${bump_level}|${reason}"
}

_tag_delete() {
  local all_tags=()
  all_tags=("${(f)$(git tag 2>/dev/null)}")

  if [[ ${#all_tags[@]} -eq 0 ]]; then
    echo -e "${C_YELLOW}⚠️  No hay tags en este repositorio.${C_RESET}" >&2
    return 1
  fi

  echo -e "${C_CYAN}🏷️  Tags disponibles:${C_RESET}" >&2
  local i=1
  for t in "${all_tags[@]}"; do
    printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$t" >&2
    ((i++))
  done
  echo "" >&2

  echo -n "🗑️  Ingresa los números a borrar (ej: 1 3 5) o 'all' para todas: " >&2
  read -r selection

  local tags_to_delete=()
  if [[ "$selection" == "all" ]]; then
    tags_to_delete=("${all_tags[@]}")
  else
    for num in "${=selection}"; do
      if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#all_tags[@]} )); then
        tags_to_delete+=("${all_tags[$num]}")
      fi
    done
  fi

  if [[ ${#tags_to_delete[@]} -eq 0 ]]; then
    echo "⚠️ No se seleccionaron tags válidos. Cancelado." >&2
    return 1
  fi

  echo -e "\n${C_YELLOW}⚠️  Se borrarán los siguientes tags LOCAL y REMOTAMENTE:${C_RESET}" >&2
  for t in "${tags_to_delete[@]}"; do
    echo "  - $t" >&2
  done
  echo "" >&2

  _confirm "¿Confirmar borrado?" || return 1

  local deleted=0
  for t in "${tags_to_delete[@]}"; do
    if git tag -d "$t" &>/dev/null; then
      git push origin ":refs/tags/$t" 2>/dev/null
      ((deleted++))
    else
      echo -e "${C_RED}❌ Falló al borrar '$t'.${C_RESET}" >&2
    fi
  done

  echo -e "${C_GREEN}✅ $deleted tag(s) borrado(s) exitosamente.${C_RESET}" >&2
}

_tag_rename() {
  local old_tag="$1" new_tag="$2"
  
  # Si no hay argumentos, listar y preguntar
  if [[ -z "$old_tag" ]]; then
    local all_tags=("${(f)$(git tag 2>/dev/null)}")
    [[ ${#all_tags[@]} -eq 0 ]] && { echo "No hay tags." >&2; return 1; }
    
    echo "Tags:" >&2
    for i in {1..${#all_tags[@]}}; do echo "  [$i] ${all_tags[$i]}" >&2; done
    echo -n "Número del tag a renombrar: " >&2
    read -r num
    [[ "$num" =~ ^[0-9]+$ ]] && (( num <= ${#all_tags[@]} )) && old_tag="${all_tags[$num]}"
  fi
  [[ -z "$new_tag" ]] && { echo -n "🏷️  Nuevo nombre: " >&2; read -r new_tag; }
  [[ -z "$old_tag" || -z "$new_tag" ]] && return 1
  
  if ! _tag_exists "$old_tag"; then
    echo -e "${C_RED}❌ El tag '$old_tag' no existe.${C_RESET}" >&2
    return 1
  fi
  if _tag_exists "$new_tag"; then
    echo -e "${C_RED}❌ El tag '$new_tag' ya existe.${C_RESET}" >&2
    return 1
  fi
  
  _confirm "¿Renombrar '$old_tag' → '$new_tag' local y remotamente?" || return 1
  
  local commit msg
  commit=$(git rev-list -n 1 "$old_tag")
  msg=$(git tag -l --format='%(contents)' "$old_tag")
  [[ -z "$msg" ]] && msg="$new_tag"
  
  git tag -d "$old_tag" || return 1
  git push origin ":refs/tags/$old_tag" 2>/dev/null
  
  git tag -a "$new_tag" -m "$msg" "$commit" || return 1
  git push origin "$new_tag" || return 1
  
  echo -e "${C_GREEN}✅ Tag renombrado y sincronizado: '$old_tag' → '$new_tag'${C_RESET}" >&2
}

_tag_edit() {
  local tag="$1" new_msg="$2"
  
  if [[ -z "$tag" ]]; then
    local all_tags=("${(f)$(git tag 2>/dev/null)}")
    [[ ${#all_tags[@]} -eq 0 ]] && { echo "No hay tags." >&2; return 1; }
    echo "Tags:" >&2
    for i in {1..${#all_tags[@]}}; do echo "  [$i] ${all_tags[$i]}" >&2; done
    echo -n "Número del tag a editar: " >&2
    read -r num
    [[ "$num" =~ ^[0-9]+$ ]] && (( num <= ${#all_tags[@]} )) && tag="${all_tags[$num]}"
  fi
  
  if ! _tag_exists "$tag"; then
    echo -e "${C_RED}❌ El tag '$tag' no existe.${C_RESET}" >&2
    return 1
  fi
  
  local current_msg
  current_msg=$(git tag -l --format='%(contents)' "$tag")
  echo -e "💬 Mensaje actual: ${C_CYAN}$current_msg${C_RESET}" >&2
  
  if [[ -z "$new_msg" ]]; then
    echo -n "📝 Nuevo mensaje: " >&2
    read -r new_msg
  fi
  [[ -z "$new_msg" ]] && { echo "⚠️ Mensaje vacío. Cancelado." >&2; return 1; }
  
  _confirm "¿Actualizar mensaje del tag '$tag'?" || return 1
  
  local commit
  commit=$(git rev-list -n 1 "$tag")
  
  git tag -d "$tag" || return 1
  git push origin ":refs/tags/$tag" 2>/dev/null
  
  git tag -a "$tag" -m "$new_msg" "$commit" || return 1
  git push origin "$tag" || return 1
  
  echo -e "${C_GREEN}✅ Mensaje del tag '$tag' actualizado en local y remoto.${C_RESET}" >&2
}

_tag_menu() {
  _git_check_repo || return 1
  while true; do
    echo -e "\n${C_CYAN}⚡ GESTIÓN DE TAGS Y RELEASES${C_RESET}" >&2
    echo "1) 🚀 Crear release automática (Calcula SemVer y sube)" >&2
    echo "2) 📋 Listar últimas releases" >&2
    echo "3) 🗑️  Borrar tags (Selección múltiple)" >&2
    echo "4) ✏️  Renombrar tag" >&2
    echo "5) 💬 Editar mensaje de tag" >&2
    echo "q) 👉 Volver" >&2
    echo -n "Selecciona: " >&2
    read -k 1 opt
    echo >&2
    
    case "$opt" in
      1) _action_release; break ;;
      2) _list_recent_tags ;;
      3) _tag_delete ;;
      4) _tag_rename ;;
      5) _tag_edit ;;
      q|Q) break ;;
      *) echo "❌ Opción inválida." >&2 ;;
    esac
  done
}

# Calcula la versión para un nivel de bump específico (patch/minor/major)
_bump_version() {
  local level="$1"
  local major minor patch
  local latest_tag

  latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)
  if [[ "$latest_tag" =~ v?([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    major=${match[1]}; minor=${match[2]}; patch=${match[3]}
  else
    major=0; minor=0; patch=0
  fi

  case "$level" in
    major) echo "v$(( major + 1 )).0.0" ;;
    minor) echo "v${major}.$(( minor + 1 )).0" ;;
    patch) echo "v${major}.${minor}.$(( patch + 1 ))" ;;
  esac
}

# ==============================================
# 🚀 ACCIÓN PRINCIPAL DE RELEASE
# ==============================================
_action_release() {
  _git_check_repo || return 1
  _list_recent_tags

  local tag_name="$1"
  local tag_msg="$2"
  local version_info bump_level reason

  if [[ -z "$tag_name" ]]; then
    version_info=$(_get_next_version)
    tag_name="${version_info%%|*}"
    reason="${version_info##*|}"
    bump_level=$(echo "$version_info" | cut -d'|' -f2)

    echo -e "🤖 Análisis SemVer:" >&2
    echo -e "   - Cálculo: ${C_YELLOW}$tag_name${C_RESET}" >&2
    echo -e "   - Nivel: ${C_BLUE}$bump_level${C_RESET}" >&2
    echo -e "   - Motivo: $reason\n" >&2

    # Elegir nivel de bump
    echo -e "📊 Tipo de versión:" >&2
    echo -e "  ${C_GREEN}[1]${C_RESET} Patch  (fixes)     → ${C_YELLOW}$(_bump_version patch)${C_RESET}" >&2
    echo -e "  ${C_GREEN}[2]${C_RESET} Minor  (features)  → ${C_YELLOW}$(_bump_version minor)${C_RESET}" >&2
    echo -e "  ${C_GREEN}[3]${C_RESET} Major  (breaking)   → ${C_YELLOW}$(_bump_version major)${C_RESET}" >&2
    echo -e "  ${C_GREEN}[4]${C_RESET} Manual (escribir)" >&2
    echo -n "🔢 Opción [Enter = $bump_level]: " >&2
    read -k 1 -r choice
    echo >&2

    case "$choice" in
      1) tag_name=$(_bump_version patch) ;;
      2) tag_name=$(_bump_version minor) ;;
      3) tag_name=$(_bump_version major) ;;
      4)
        echo -n "📝 Versión (ej: v1.5.0): " >&2
        read -r tag_name
        ;;
      *) ;; # Enter = usar la calculada automáticamente
    esac
  fi
  
  # Hacemos commit y push de los cambios pendientes
  _action_push || return 1
  
  if _tag_exists "$tag_name"; then
    echo -e "${C_YELLOW}ℹ️  El tag '$tag_name' ya existe.${C_RESET}" >&2
    if _confirm "¿Publicar el release en GitHub para este tag?"; then
      _release_publish "$tag_name"
    fi
    return 0
  fi

  if [[ -z "$tag_msg" ]]; then
    tag_msg="$tag_name"
    echo -n "💬 Mensaje para el tag [$tag_name]: " >&2
    read -r user_msg
    [[ -n "$user_msg" ]] && tag_msg="$user_msg"
  fi

  git tag -a "$tag_name" -m "$tag_msg"
  git push origin "$tag_name"
  echo -e "${C_GREEN}✅ Tag '$tag_name' creado y subido.${C_RESET}" >&2

  # Release en GitHub (con aviso claro si gh no está disponible)
  _release_publish "$tag_name" || \
    echo -e "${C_YELLOW}⚠️  El tag '$tag_name' sí quedó creado y subido.${C_RESET}" >&2
  return 0
}

# ==============================================
# 🚀 RELEASE - PUBLICACIÓN EN GITHUB
# ==============================================
_release_require_gh() {
  if ! command -v gh &>/dev/null; then
    echo -e "${C_RED}❌ gh no está instalado — sin él no hay release en GitHub.${C_RESET}" >&2
    echo -e "📦 Instala con: ${C_YELLOW}sudo pacman -S github-cli${C_RESET} o ${C_YELLOW}sudo apt install gh${C_RESET}" >&2
    return 1
  fi
}

# Menú de notas (elegir cada vez); deja el resultado en el array global RELEASE_NOTES_FLAGS
_release_notes_menu() {
  local src
  local -a opts=("Automáticas de GitHub (commits)")
  [[ -f README.md ]] && opts+=("README.md")
  [[ -f CHANGELOG.md ]] && opts+=("CHANGELOG.md")
  opts+=("Escribir las notas")

  if command -v gum &>/dev/null; then
    src=$(gum choose "${opts[@]}" --header " 📝 Notas del release ")
  else
    local i=1 n
    for o in "${opts[@]}"; do echo "  $i) $o" >&2; ((i++)); done
    printf "Opción [1]: " >&2
    read -r n
    src="${opts[${n:-1}]}"
  fi
  [[ -z "$src" ]] && src="${opts[1]}"

  case "$src" in
    Automáticas*) RELEASE_NOTES_FLAGS=(--generate-notes) ;;
    README*)      RELEASE_NOTES_FLAGS=(--notes "$(cat README.md)") ;;
    CHANGELOG*)   RELEASE_NOTES_FLAGS=(--notes "$(cat CHANGELOG.md)") ;;
    Escribir*)
      local notes
      if command -v gum &>/dev/null; then
        notes=$(gum write --header " 📝 Notas del release (Ctrl+D para guardar) ")
      else
        "${EDITOR:-nano}" .git-release-notes.tmp
        notes=$(cat .git-release-notes.tmp 2>/dev/null)
        rm -f .git-release-notes.tmp
      fi
      RELEASE_NOTES_FLAGS=(--notes "${notes:-Release $1}")
      ;;
  esac
}

# Publica el release de GitHub para un tag ya creado y subido
_release_publish() {
  local tag_name="$1"
  if ! _release_require_gh; then
    return 1
  fi

  local release_type
  echo -e "\n📦 Tipo de release:" >&2
  echo -e "  ${C_GREEN}[1]${C_RESET} Release (latest)" >&2
  echo -e "  ${C_GREEN}[2]${C_RESET} Pre-release" >&2
  echo -e "  ${C_GREEN}[3]${C_RESET} Draft" >&2
  echo -n "🔢 Opción [1]: " >&2
  read -k 1 release_type
  echo >&2

  local -a gh_flags=(--title "$tag_name")
  case "$release_type" in
    2) gh_flags+=(--prerelease) ;;
    3) gh_flags+=(--draft) ;;
    *) gh_flags+=(--latest) ;;
  esac

  _release_notes_menu "$tag_name"
  gh_flags+=("${RELEASE_NOTES_FLAGS[@]}")

  echo -e "\n📦 Creando release en GitHub..." >&2
  if gh release create "$tag_name" "${gh_flags[@]}"; then
    echo -e "${C_GREEN}✅ Release '$tag_name' publicado en GitHub.${C_RESET}" >&2
  else
    echo -e "${C_YELLOW}⚠️  Falló la publicación. Reintenta con: useGit release create $tag_name${C_RESET}" >&2
    return 1
  fi
}

# ==============================================
# 🚀 RELEASE - CRUD (useGit release)
# ==============================================
_release_pick() {
  local list tag
  list=$(gh release list 2>/dev/null) || { echo -e "${C_RED}❌ No pude listar releases (¿repo y gh ok?).${C_RESET}" >&2; return 1; }
  [[ -z "$list" ]] && { echo -e "${C_YELLOW}ℹ️  No hay releases publicados.${C_RESET}" >&2; return 1; }

  if command -v gum &>/dev/null; then
    tag=$(echo "$list" | gum choose | awk '{print $1}')
  else
    echo "$list" >&2
    printf "Tag del release: " >&2
    read -r tag
  fi
  [[ -z "$tag" ]] && return 1
  echo "$tag"
}

_release_list() {
  _git_check_repo || return 1
  gh release list
}

_release_view() {
  _git_check_repo || return 1
  if [[ -n "$1" ]]; then gh release view "$1"; else gh release view; fi
}

_release_open() {
  _git_check_repo || return 1
  if [[ -n "$1" ]]; then gh release view "$1" --web; else gh release view --web; fi
}

_release_edit() {
  _git_check_repo || return 1
  local tag="$1"
  [[ -z "$tag" ]] && { tag=$(_release_pick) || return 1; }

  local what
  if command -v gum &>/dev/null; then
    what=$(gum choose "Título" "Notas" "Alternar pre-release" "Abrir en navegador" \
        --header " ✏️ Editar release $tag ")
  else
    echo "1) Título  2) Notas  3) Alternar pre-release  4) Abrir en navegador" >&2
    printf "Opción: " >&2
    read -r what
    case "$what" in
      1) what="Título" ;; 2) what="Notas" ;; 3) what="Alternar pre-release" ;; 4) what="Abrir en navegador" ;;
    esac
  fi
  [[ -z "$what" ]] && return 0

  case "$what" in
    Título)
      local title
      if command -v gum &>/dev/null; then
        title=$(gum input --header " ✏️ Nuevo título " --placeholder "$tag")
      else
        printf "Nuevo título: " >&2
        read -r title
      fi
      [[ -z "$title" ]] && return 0
      gh release edit "$tag" --title "$title"
      ;;
    Notas)
      local notes
      if command -v gum &>/dev/null; then
        notes=$(gum write --header " ✏️ Notas (Ctrl+D para guardar) ")
      else
        "${EDITOR:-nano}" .git-release-notes.tmp
        notes=$(cat .git-release-notes.tmp 2>/dev/null)
        rm -f .git-release-notes.tmp
      fi
      [[ -z "$notes" ]] && return 0
      gh release edit "$tag" --notes "$notes"
      ;;
    "Alternar pre-release")
      if [[ $(gh release view "$tag" --json isPrerelease -q .isPrerelease 2>/dev/null) == "true" ]]; then
        gh release edit "$tag" --latest
      else
        gh release edit "$tag" --prerelease
      fi
      ;;
    "Abrir en navegador")
      gh release view "$tag" --web
      ;;
  esac
}

_release_delete() {
  _git_check_repo || return 1
  local tag="$1"
  [[ -z "$tag" ]] && { tag=$(_release_pick) || return 1; }

  _confirm "¿Eliminar el release '$tag' en GitHub?" || { echo "🛑 Cancelado." >&2; return 0; }
  gh release delete "$tag" --yes || return 1
  echo -e "${C_GREEN}✅ Release '$tag' eliminado de GitHub.${C_RESET}" >&2

  if _confirm "¿Borrar también el tag (local y remoto)?"; then
    git tag -d "$tag" 2>/dev/null
    git push origin ":refs/tags/$tag" && \
      echo -e "${C_GREEN}✅ Tag '$tag' eliminado local y en remoto.${C_RESET}" >&2
  fi
}

_release_router() {
  local sub="$1"
  [[ $# -gt 0 ]] && shift

  case "$sub" in
    create|new)    _action_release "$@" ;;
    list|ls)       _release_list ;;
    view|show)     _release_view "$@" ;;
    open|web)      _release_open "$@" ;;
    edit)          _release_edit "$@" ;;
    delete|del|rm) _release_delete "$@" ;;
    -h|--help|help)
      echo -e "${C_CYAN}Uso: useGit release [create|list|view|open|edit|delete] [tag]${C_RESET}" >&2
      echo "  create = tag SemVer + release en GitHub (las dos cosas)" >&2
      echo "  sin argumentos abre el menú" >&2
      ;;
    "")
      local opt
      if command -v gum &>/dev/null; then
        opt=$(gum choose \
          "create · crear tag + release en GitHub" \
          "list · listar releases" \
          "view · ver un release" \
          "edit · editar release" \
          "delete · borrar release (y opcionalmente el tag)" \
          "open · abrir en el navegador" \
          --header " 🚀 RELEASE · Elige acción ")
        [[ -z "$opt" ]] && return 0
        _release_router "${opt%% · *}"
      else
        _release_router help
      fi
      ;;
    *)
      echo -e "${C_RED}❌ Subcomando no reconocido: $sub${C_RESET}" >&2
      _release_router help
      return 1
      ;;
  esac
}

# ==============================================
# 🧹 LIMPIEZA DE ARCHIVOS
# ==============================================
_action_clean() {
  _git_check_repo || return 1
  
  echo -e "${C_CYAN}🧹 Buscando archivos y carpetas innecesarias...${C_RESET}" >&2
  
  local trash_patterns=(
    "node_modules"
    ".DS_Store"
    "Thumbs.db"
    "__pycache__"
    "*.pyc"
    ".idea"
    "*.log"
    "dist"
    "build"
  )
  
  local found_trash=""
  
  for pattern in "${trash_patterns[@]}"; do
    local matches
    matches=$(find . -name "$pattern" -not -path "*/.git/*" 2>/dev/null)
    [[ -n "$matches" ]] && found_trash+="$matches\n"
  done
  
  if [[ -z "$found_trash" ]]; then
    echo -e "${C_GREEN}✅ No se encontraron archivos innecesarios. El repositorio está limpio.${C_RESET}" >&2
    return 0
  fi
  
  local total_items
  total_items=$(echo "$found_trash" | grep -c '^')
  echo -e "${C_YELLOW}⚠️  Se encontraron $total_items elementos innecesarios:${C_RESET}" >&2
  echo "$found_trash" | sed 's/^/  🗑️  /' >&2
  echo "" >&2
  
  _confirm "¿Eliminar todos estos archivos y carpetas?" || { echo "🛑 Cancelado." >&2; return 1; }
  
  for pattern in "${trash_patterns[@]}"; do
    find . -name "$pattern" -not -path "*/.git/*" -exec rm -rf {} + 2>/dev/null
  done
  
  echo -e "${C_GREEN}✅ Limpieza completada.${C_RESET}" >&2
}

# ==============================================
# 📦 GESTIÓN DE SUBMÓDULOS
# ==============================================
_action_submodule() {
  _git_check_repo || return 1
  local sub_action="$1"
  
  if [[ -z "$sub_action" ]]; then
    echo -e "${C_CYAN}📦 GESTIÓN DE SUBMÓDULOS${C_RESET}" >&2
    echo "1) Añadir submódulo" >&2
    echo "2) Eliminar submódulo" >&2
    echo "3) Arreglar submódulos rotos (limpiar .git anidados)" >&2
    echo "q) Cancelar" >&2
    echo -n "Selecciona: " >&2
    read -k 1 sub_action
    echo >&2
  fi

  case "$sub_action" in
    1|add)
      local sub_url sub_path
      echo -n "🌐 URL del repositorio: " >&2
      read -r sub_url
      [[ -z "$sub_url" ]] && return 1
      
      echo -n "📂 Ruta local (ej: src/lib): " >&2
      read -r sub_path
      [[ -z "$sub_path" ]] && sub_path="."
      
      git submodule add "$sub_url" "$sub_path" && echo -e "${C_GREEN}✅ Submódulo añadido.${C_RESET}" >&2
      ;;
    2|delete|remove)
      if [[ ! -f ".gitmodules" ]]; then
        echo -e "${C_RED}❌ No hay archivo .gitmodules (no hay submódulos registrados).${C_RESET}" >&2
        return 1
      fi
      
      local submodules=()
      submodules=("${(f)$(git config -f .gitmodules --get-regexp path | awk '{print $2}')}")
      
      if [[ ${#submodules[@]} -eq 0 ]]; then
        echo -e "${C_RED}❌ No hay submódulos registrados.${C_RESET}" >&2
        return 1
      fi
      
      echo -e "${C_CYAN}📦 Submódulos disponibles:${C_RESET}" >&2
      local i=1
      for s in "${submodules[@]}"; do
        printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$s" >&2
        ((i++))
      done
      echo "" >&2
      
      echo -n "🗑️  Ingresa el número a eliminar: " >&2
      read -r sel_num
      
      if [[ "$sel_num" =~ ^[0-9]+$ ]] && (( sel_num >= 1 && sel_num <= ${#submodules[@]} )); then
        local target_sub="${submodules[$sel_num]}"
        _confirm "⚠️ ¿Eliminar '$target_sub' completamente?" || return 1
        
        git submodule deinit -f "$target_sub"
        git rm -f "$target_sub"
        rm -rf ".git/modules/$target_sub"
        
        _confirm "🚀 ¿Hacer commit de los cambios?" && git commit -m "chore: remove submodule $target_sub"
        echo -e "${C_GREEN}✅ Submódulo '$target_sub' eliminado.${C_RESET}" >&2
      else
        echo "❌ Opción inválida." >&2
      fi
      ;;
    3|fix)
      echo -e "${C_CYAN}🔧 Buscando .git anidados que causan submódulos rotos...${C_RESET}" >&2
      local git_dirs
      git_dirs=$(find . -mindepth 2 -name ".git" -type d 2>/dev/null)
      
      if [[ -z "$git_dirs" ]]; then
        echo -e "${C_GREEN}✅ No hay carpetas .git anidadas.${C_RESET}" >&2
        return 0
      fi
      
      echo -e "${C_YELLOW}⚠️  Encontrados:${C_RESET}" >&2
      echo "$git_dirs" | sed 's|/\.git||' >&2
      echo "" >&2
      
      _confirm "¿Eliminar estos .git y arreglar el index de git?" || return 1
      
      echo "$git_dirs" | while read -r gdir; do
        local dir_path="${gdir%/.git}"
        rm -rf "$gdir"
        # Sacar del index (donde figura como gitlink/submodule) y volver a añadir como archivos normales
        git rm --cached "$dir_path" 2>/dev/null
        git add "$dir_path"
      done
      
      echo -e "${C_GREEN}✅ Submódulos rotos arreglados. Archivos re-añadidos al index.${C_RESET}" >&2
      _confirm "🚀 ¿Hacer commit de estos cambios?" && git commit -m "fix: remove broken nested submodules"
      ;;
    q|Q) echo "👋 Cancelado." >&2 ;;
    *) echo "❌ Opción inválida." >&2; return 1 ;;
  esac
}

# ==============================================
# 🔀 OTRAS ACCIONES
# ==============================================
_action_merge() {
  _git_check_repo || return 1
  local target="$1" source="$2" strategy=""
  
  for arg in "$@"; do
    [[ "$arg" =~ ^--strategy=(ours|theirs)$ ]] && strategy="${arg#*=}"
  done

  [[ -z "$target" ]] && { echo -n "🌿 Rama destino: " >&2; read -r target; }
  [[ -z "$source" ]] && { echo -n "🌿 Rama fuente: " >&2; read -r source; }
  [[ -z "$target" || -z "$source" ]] && { echo "❌ Ambas ramas son necesarias." >&2; return 1; }

  git show-ref --verify --quiet "refs/heads/$source" || { echo "❌ Rama '$source' no existe." >&2; return 1; }
  
  if ! git show-ref --verify --quiet "refs/heads/$target"; then
    _confirm "⚠️ Rama '$target' no existe. ¿Crearla desde '$source'?" || return 1
    git branch "$target" "$source"
  fi

  local current
  current="$(_git_current_branch)"
  git checkout "$target" || return 1
  
  echo "🔀 Mergeando '$source' en '$target'..." >&2
  if ! git merge "$source"; then
    if [[ -n "$strategy" ]]; then
      git checkout --"$strategy" . && git add . && git merge --continue
    else
      echo "⚠️ Conflictos. Resuelve manualmente o usa --strategy=ours|theirs" >&2
      return 1
    fi
  fi

  _confirm "🚀 ¿Subir cambios a remoto?" && git push origin "$target"
  [[ "$current" != "$target" ]] && _confirm "🔄 ¿Volver a '$current'?" && git checkout "$current"
  echo "✅ Merge completado." >&2
}

_action_switch() {
  _git_check_repo || return 1
  local dest="$1"
  [[ -z "$dest" ]] && { echo -n "🌿 Rama destino: " >&2; read -r dest; }
  [[ -z "$dest" ]] && return 1

  if ! git diff --quiet; then
    _confirm "⚠️ Cambios sin commitear. ¿Stashear?" && git stash push -m "auto-stash"
  fi

  git checkout "$dest" || return 1
  git stash list | grep -q "auto-stash" && git stash pop
  echo "✅ Cambiado a '$dest'." >&2
}

_action_flow() {
  _git_check_repo || return 1
  
  echo -e "${C_CYAN}⚡ GITFLOW RÁPIDO${C_RESET}"
  echo "1) Commit + Push"
  echo "2) Solo Commit"
  echo "3) Release con tag"
  echo "4) Cambiar rama"
  echo "5) Pull + Rebase"
  echo "q) Salir"
  echo ""
  echo -n "Selecciona una opción: " >&2
  read -k 1 action >&2
  echo >&2
  
  case "$action" in
    1) _action_push ;;
    2) _action_commit ;;
    3) _action_release ;;
    4) _action_switch ;;
    5) 
      _confirm "🔄 ¿Pull con rebase?" && git pull --rebase || git pull
      ;;
    q|Q) echo "👋 ¡Hasta luego!" >&2 ;;
    *) echo "❌ Opción inválida" >&2 ;;
  esac
}

_action_remote() {
  _git_check_repo || return 1
  local action="$1"
  shift 2>/dev/null || true

  case "$action" in
    setup|init)
      local repo_name gh_user
      repo_name="${1:-$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)}"
      gh_user="$2"

      [[ -z "$gh_user" ]] && { echo -n "👤 Usuario GitHub: " >&2; read -r gh_user; }
      [[ -z "$repo_name" ]] && { echo -n "📦 Nombre del repositorio: " >&2; read -r repo_name; }

      # Verificar si el repo ya existe en GitHub
      if gh repo view "$gh_user/$repo_name" &>/dev/null; then
        # Repo ya existe: solo configurar remote y push
        local remote_url="git@github.com:$gh_user/$repo_name.git"
        if git remote get-url origin &>/dev/null; then
          echo -e "ℹ️  El remote 'origin' ya existe: $(git remote get-url origin)" >&2
          _confirm "¿Actualizar a $remote_url?" || return 1
          git remote set-url origin "$remote_url"
        else
          git remote add origin "$remote_url"
        fi
        echo -e "${C_GREEN}✅ Remote 'origin' configurado: $remote_url${C_RESET}" >&2
        git remote -v >&2
        _confirm "🚀 ¿Hacer push a origin?" && git push -u origin HEAD
      else
        # Repo no existe: crear en GitHub, configurar remote y push
        local is_private=false
        echo -n "🔒 ¿Repositorio privado? (s/N): " >&2
        read -k 1 -r
        echo >&2
        [[ $REPLY =~ ^[Ss]$ ]] && is_private=true

        local visibility="public"
        [[ "$is_private" == true ]] && visibility="private"

        echo -e "🚀 Creando repositorio ${C_CYAN}$repo_name${C_RESET} (${C_YELLOW}$visibility${C_RESET}) en GitHub..." >&2
        gh repo create "$repo_name" --"$visibility" --source=. --remote=origin --push

        if [[ $? -eq 0 ]]; then
          echo -e "${C_GREEN}✅ Repositorio creado y sincronizado.${C_RESET}" >&2
          echo "🔗 Remote: $(git remote get-url origin)" >&2
        else
          echo -e "${C_RED}❌ Error al crear el repositorio.${C_RESET}" >&2
          return 1
        fi
      fi
      ;;
    *)
      echo "Uso: on-git remote setup [nombre-repo] [usuario-github]" >&2
      echo "   Si no se pasan argumentos, se piden interactivamente." >&2
      ;;
  esac
}

# ==============================================
# 🌿 BRANCH · Gestión de ramas
# ==============================================
_action_branch() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "list · listar ramas locales" \
        "list-all · listar locales + remotas (-a)" \
        "create · crear nueva rama" \
        "delete-local · borrar ramas locales (lote)" \
        "delete-remote · borrar ramas remotas (lote)" \
        "rename · renombrar rama" \
        --header " 🌿 BRANCH · Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🌿 BRANCH" >&2
      echo "1) Listar ramas locales" >&2
      echo "2) Listar todas (local + remoto)" >&2
      echo "3) Crear rama" >&2
      echo "4) Borrar ramas locales (lote)" >&2
      echo "5) Borrar ramas remotas (lote)" >&2
      echo "6) Renombrar rama" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="list" ;; 2) choice="list-all" ;; 3) choice="create" ;;
        4) choice="delete-local" ;; 5) choice="delete-remote" ;; 6) choice="rename" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      list)
        git branch
        ;;
      list-all)
        git branch -a
        ;;
      create)
        local name
        if command -v gum &>/dev/null; then
          name=$(gum input --placeholder "nombre-de-la-rama")
        else
          echo -n "Nombre de la rama: " >&2; read -r name
        fi
        [[ -z "$name" ]] && continue
        git branch "$name" && echo "✅ Rama '$name' creada." >&2
        ;;
      delete-local)
        local branches nums to_delete=()
        branches=(${(f)"$(git branch --format='%(refname:short)')"})
        [[ ${#branches[@]} -eq 0 ]] && { echo "❌ No hay ramas locales." >&2; continue; }
        if command -v gum &>/dev/null; then
          local selection
          selection=$(printf '%s\n' "${branches[@]}" | gum choose --no-limit --header "Space=marcar, Enter=confirmar, Esc=volver")
          [[ -z "$selection" ]] && continue
          to_delete=(${(f)"$selection"})
        else
          echo -e "${C_CYAN}🌿 Ramas locales:${C_RESET}" >&2
          local i=1; for b in "${branches[@]}"; do printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$b" >&2; ((i++)); done
          echo -n "🗑️ Números (ej: 1 3 5) o 'all': " >&2
          read -r -A nums
          if [[ "${nums[1]}" == "all" ]]; then
            to_delete=("${branches[@]}")
          else
            for num in "${nums[@]}"; do
              [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#branches[@]} )) && to_delete+=("${branches[$num]}")
            done
          fi
        fi
        [[ ${#to_delete[@]} -eq 0 ]] && { echo "⚠️ No se seleccionaron ramas." >&2; continue; }
        echo -e "\n${C_YELLOW}🗑️ Se borrarán ${#to_delete[@]} ramas locales:${C_RESET}" >&2
        for b in "${to_delete[@]}"; do echo "  - $b" >&2; done
        _confirm "¿Confirmar borrado?" || continue
        local ok=0 fail=0
        for b in "${to_delete[@]}"; do
          if git branch -d "$b" 2>&1; then ((ok++)); else ((fail++)); fi
        done
        echo "✅ $ok borradas, $fail fallidas." >&2
        ;;
      delete-remote)
        local remotes nums to_delete=()
        remotes=(${(f)"$(git branch -r --format='%(refname:short)' 2>/dev/null | grep -v 'HEAD')"})
        [[ ${#remotes[@]} -eq 0 ]] && { echo "❌ No hay ramas remotas." >&2; continue; }
<<<<<<< HEAD
        if command -v gum &>/dev/null; then
          local selection
          selection=$(printf '%s\n' "${remotes[@]}" | gum choose --no-limit --header "Space=marcar, Enter=confirmar, Esc=volver")
          [[ -z "$selection" ]] && continue
          to_delete=(${(f)"$selection"})
        else
          echo -e "${C_CYAN}🌿 Ramas remotas:${C_RESET}" >&2
          local i=1; for r in "${remotes[@]}"; do printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$r" >&2; ((i++)); done
          echo -n "🗑️ Números (ej: 1 3 5) o 'all': " >&2
          read -r -A nums
          if [[ "${nums[1]}" == "all" ]]; then
            to_delete=("${remotes[@]}")
          else
            for num in "${nums[@]}"; do
              [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#remotes[@]} )) && to_delete+=("${remotes[$num]}")
            done
          fi
=======
        echo -e "${C_CYAN}🌿 Ramas remotas:${C_RESET}" >&2
        local i=1; for r in "${remotes[@]}"; do printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$r" >&2; ((i++)); done
        echo -n "🗑️ Números (ej: 1 3 5) o 'all': " >&2
        read -r -A nums
        if [[ "${nums[1]}" == "all" ]]; then
          to_delete=("${remotes[@]}")
        else
          for num in "${nums[@]}"; do
            [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#remotes[@]} )) && to_delete+=("${remotes[$num]}")
          done
>>>>>>> dev
        fi
        [[ ${#to_delete[@]} -eq 0 ]] && { echo "⚠️ No se seleccionaron ramas." >&2; continue; }
        echo -e "\n${C_YELLOW}🗑️ Se borrarán ${#to_delete[@]} ramas remotas:${C_RESET}" >&2
        for r in "${to_delete[@]}"; do echo "  - $r" >&2; done
        _confirm "¿Confirmar borrado?" || continue
        local ok=0 fail=0
        for r in "${to_delete[@]}"; do
          local remote="${r%%/*}" branch="${r#*/}"
          echo "  → git push $remote :$branch" >&2
          if git push "$remote" ":$branch" 2>&1; then ((ok++)); else ((fail++)); fi
        done
<<<<<<< HEAD
=======
        git fetch --prune 2>/dev/null
>>>>>>> dev
        echo "✅ $ok borradas remotamente, $fail fallidas." >&2
        ;;
      rename)
        local branches old_name new_name
        branches=(${(f)"$(git branch --format='%(refname:short)')"})
        if command -v gum &>/dev/null; then
          old_name=$(printf '%s\n' "${branches[@]}" | gum choose --header "Selecciona rama a renombrar")
          [[ -z "$old_name" ]] && continue
          new_name=$(gum input --placeholder "nuevo-nombre" --value "$old_name")
        else
          local i=1; for b in "${branches[@]}"; do echo "$i) $b" >&2; ((i++)); done
          echo -n "Número: " >&2; read -r idx; old_name="${branches[$idx]}"
          echo -n "Nuevo nombre: " >&2; read -r new_name
        fi
        [[ -z "$new_name" ]] && continue
        git branch -m "$old_name" "$new_name" && echo "✅ '$old_name' → '$new_name'" >&2
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
<<<<<<< HEAD
# 📊 STATUS · Estado del repo
# ==============================================
_action_status() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "short · formato corto (-sb)" \
        "long · formato completo" \
        "porcelain · porcelain machine-readable" \
        "ignored · mostrar ignorados (--ignored)" \

        --header " 📊 STATUS · Elige formato Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "📊 STATUS" >&2
      echo "1) Formato corto (-sb)" >&2
      echo "2) Formato completo" >&2
      echo "3) Porcelain" >&2
      echo "4) Ignorados" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="short" ;; 2) choice="long" ;; 3) choice="porcelain" ;; 4) choice="ignored" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      short)    git status -sb ;;
      long)     git status ;;
      porcelain) git status --porcelain ;;
      ignored)  git status --ignored ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 📜 LOG · Historial de commits
# ==============================================
_action_log() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "graph · oneline + grafo decorado" \
        "full · log completo" \
        "stat · con estadísticas de cambios" \
        "author · filtrar por autor" \
        "last · últimos N commits" \

        --header " 📜 LOG · Elige formato Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "📜 LOG" >&2
      echo "1) Oneline graph" >&2
      echo "2) Log completo" >&2
      echo "3) Con estadísticas" >&2
      echo "4) Por autor" >&2
      echo "5) Últimos N" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="graph" ;; 2) choice="full" ;; 3) choice="stat" ;;
        4) choice="author" ;; 5) choice="last" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      graph)  git log --oneline --decorate --graph ;;
      full)   git log ;;
      stat)   git log --stat ;;
      author)
        local author
        if command -v gum &>/dev/null; then
          author=$(gum input --placeholder "nombre o email del autor")
        else
          echo -n "Autor: " >&2; read -r author
        fi
        [[ -z "$author" ]] && continue
        git log --oneline --author="$author"
        ;;
      last)
        local n
        if command -v gum &>/dev/null; then
          n=$(gum input --placeholder "número de commits (ej: 10)")
        else
          echo -n "Nº commits: " >&2; read -r n
        fi
        [[ -z "$n" ]] && continue
        git log --oneline -n "$n"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
=======
>>>>>>> dev
# 🔍 DIFF · Diferencias
# ==============================================
_action_diff() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "working · árbol de trabajo" \
        "staged · cambios en staging (--staged)" \
        "stat · resumen de cambios (--stat)" \
        "compact · staged + stat" \
        "branches · comparar dos ramas" \

        --header " 🔍 DIFF · Elige modo Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔍 DIFF" >&2
      echo "1) Working tree" >&2
      echo "2) Staged" >&2
      echo "3) Stat" >&2
      echo "4) Compact (staged + stat)" >&2
      echo "5) Entre ramas" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="working" ;; 2) choice="staged" ;; 3) choice="stat" ;;
        4) choice="compact" ;; 5) choice="branches" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      working)  git diff ;;
      staged)   git diff --staged ;;
      stat)     git diff --stat ;;
      compact)  git diff --stat --staged ;;
      branches)
        local branches b1 b2
        branches=(${(f)"$(git branch --format='%(refname:short)')"})
        if command -v gum &>/dev/null; then
          b1=$(printf '%s\n' "${branches[@]}" | gum choose --header "Rama 1 (base)")
          [[ -z "$b1" ]] && continue
          b2=$(printf '%s\n' "${branches[@]}" | gum choose --header "Rama 2 (comparar)")
          [[ -z "$b2" ]] && continue
        else
          local i=1; for b in "${branches[@]}"; do echo "$i) $b" >&2; ((i++)); done
          echo -n "Rama 1 (nº): " >&2; read -r idx; b1="${branches[$idx]}"
          echo -n "Rama 2 (nº): " >&2; read -r idx; b2="${branches[$idx]}"
        fi
        [[ -z "$b1" || -z "$b2" ]] && continue
        git diff "$b1".."$b2"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 📦 STASH · Cambios guardados
# ==============================================
_action_stash() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "push · guardar cambios" \
        "list · listar stashes" \
        "pop · aplicar y eliminar último" \
        "apply · aplicar sin eliminar" \
        "show · ver contenido de un stash" \
        "drop · eliminar stashes (lote)" \
        "clear · borrar todos los stashes" \

        --header " 📦 STASH · Elige acción Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "📦 STASH" >&2
      echo "1) Push (guardar)" >&2
      echo "2) List" >&2
      echo "3) Pop" >&2
      echo "4) Apply" >&2
      echo "5) Show" >&2
      echo "6) Drop (lote)" >&2
      echo "7) Clear" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="push" ;; 2) choice="list" ;; 3) choice="pop" ;;
        4) choice="apply" ;; 5) choice="show" ;; 6) choice="drop" ;; 7) choice="clear" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      push)
        local msg
        if command -v gum &>/dev/null; then
          msg=$(gum input --placeholder "mensaje del stash (opcional)")
        else
          echo -n "Mensaje (opcional): " >&2; read -r msg
        fi
        if [[ -n "$msg" ]]; then
          git stash push -m "$msg"
        else
          git stash push
        fi
        echo "✅ Cambios stasheados." >&2
        ;;
      list)   git stash list ;;
      pop)    git stash pop ;;
      apply)
        local stash_list stash
        stash_list=(${(f)"$(git stash list 2>/dev/null)"})
        [[ ${#stash_list[@]} -eq 0 ]] && { echo "❌ No hay stashes." >&2; continue; }
        if command -v gum &>/dev/null; then
          stash=$(printf '%s\n' "${stash_list[@]}" | gum choose --header "Selecciona stash")
        else
          local i=1; for s in "${stash_list[@]}"; do echo "$i) $s" >&2; ((i++)); done
          echo -n "Número: " >&2; read -r idx; stash="${stash_list[$idx]}"
        fi
        [[ -z "$stash" ]] && continue
        local stash_ref="${stash%%:*}"
        git stash apply "$stash_ref"
        ;;
      show)
        local stash_list stash
        stash_list=(${(f)"$(git stash list 2>/dev/null)"})
        [[ ${#stash_list[@]} -eq 0 ]] && { echo "❌ No hay stashes." >&2; continue; }
        if command -v gum &>/dev/null; then
          stash=$(printf '%s\n' "${stash_list[@]}" | gum choose --header "Selecciona stash")
        else
          local i=1; for s in "${stash_list[@]}"; do echo "$i) $s" >&2; ((i++)); done
          echo -n "Número: " >&2; read -r idx; stash="${stash_list[$idx]}"
        fi
        [[ -z "$stash" ]] && continue
        local stash_ref="${stash%%:*}"
        git stash show -p "$stash_ref"
        ;;
      drop)
        local stash_list nums to_delete=()
        stash_list=(${(f)"$(git stash list 2>/dev/null)"})
        [[ ${#stash_list[@]} -eq 0 ]] && { echo "❌ No hay stashes." >&2; continue; }
        if command -v gum &>/dev/null; then
          local selection
          selection=$(printf '%s\n' "${stash_list[@]}" | gum choose --no-limit --header "Space=marcar, Enter=confirmar, Esc=volver")
          [[ -z "$selection" ]] && continue
          to_delete=(${(f)"$selection"})
        else
          echo -e "${C_CYAN}📦 Stashes:${C_RESET}" >&2
          local i=1; for s in "${stash_list[@]}"; do printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$s" >&2; ((i++)); done
          echo -n "🗑️ Números (ej: 1 3 5) o 'all': " >&2
          read -r -A nums
          if [[ "${nums[1]}" == "all" ]]; then
            to_delete=("${stash_list[@]}")
          else
            for num in "${nums[@]}"; do
              [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#stash_list[@]} )) && to_delete+=("${stash_list[$num]}")
            done
          fi
        fi
        [[ ${#to_delete[@]} -eq 0 ]] && { echo "⚠️ No se seleccionaron stashes." >&2; continue; }
        echo -e "\n${C_YELLOW}🗑️ Se borrarán ${#to_delete[@]} stashes:${C_RESET}" >&2
        for s in "${to_delete[@]}"; do echo "  - ${s%%:*}" >&2; done
        _confirm "¿Confirmar borrado?" || continue
        local ok=0
        for s in "${to_delete[@]}"; do
          git stash drop "${s%%:*}" 2>&1 && ((ok++))
        done
        echo "✅ $ok stashes borrados." >&2
        ;;
      clear)
        _confirm "🗑️ ¿Borrar TODOS los stashes?" || continue
        git stash clear && echo "✅ Todos los stashes borrados." >&2
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# ↩️ RESET · Deshacer commits
# ==============================================
_action_reset() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "soft · deshacer commit, mantener staged (--soft)" \
        "mixed · deshacer commit, desestagear (--mixed)" \
        "hard · deshacer todo, perder cambios (--hard)" \
        "to-commit · resetear a commit específico" \

        --header " ↩️ RESET · Elige modo Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "↩️ RESET" >&2
      echo "1) Soft" >&2
      echo "2) Mixed" >&2
      echo "3) Hard" >&2
      echo "4) To commit" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="soft" ;; 2) choice="mixed" ;; 3) choice="hard" ;; 4) choice="to-commit" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      soft)
        local commit
        if command -v gum &>/dev/null; then
          commit=$(gum input --placeholder "commit (default: HEAD~1)")
        else
          echo -n "Commit (HEAD~1): " >&2; read -r commit
        fi
        git reset --soft "${commit:-HEAD~1}" && echo "✅ Reset soft a ${commit:-HEAD~1}" >&2
        ;;
      mixed)
        local commit
        if command -v gum &>/dev/null; then
          commit=$(gum input --placeholder "commit (default: HEAD~1)")
        else
          echo -n "Commit (HEAD~1): " >&2; read -r commit
        fi
        git reset --mixed "${commit:-HEAD~1}" && echo "✅ Reset mixed a ${commit:-HEAD~1}" >&2
        ;;
      hard)
        _confirm "⚠️ Esto PERDERÁ todos los cambios sin commitear. ¿Continuar?" || continue
        local commit
        if command -v gum &>/dev/null; then
          commit=$(gum input --placeholder "commit (default: HEAD~1)")
        else
          echo -n "Commit (HEAD~1): " >&2; read -r commit
        fi
        git reset --hard "${commit:-HEAD~1}" && echo "✅ Reset hard a ${commit:-HEAD~1}" >&2
        ;;
      to-commit)
        local commit
        if command -v gum &>/dev/null; then
          commit=$(gum input --placeholder "hash o referencia del commit")
        else
          echo -n "Commit: " >&2; read -r commit
        fi
        [[ -z "$commit" ]] && continue
        _confirm "⚠️ Resetear a '$commit'?" || continue
        git reset "$commit" && echo "✅ Reset a $commit" >&2
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🔄 RESTORE · Restaurar archivos
# ==============================================
_action_restore() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "file · restaurar archivos del working tree (lote)" \
        "unstage · desestagear archivos (lote)" \
        "from-branch · restaurar desde otra rama (--source)" \

        --header " 🔄 RESTORE · Elige acción Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔄 RESTORE" >&2
      echo "1) Restaurar archivos (lote)" >&2
      echo "2) Desestagear (lote)" >&2
      echo "3) Desde otra rama" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="file" ;; 2) choice="unstage" ;; 3) choice="from-branch" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      file)
        local files nums to_restore=()
        files=(${(f)"$(git status --porcelain 2>/dev/null | cut -c4-)"})
        [[ ${#files[@]} -eq 0 ]] && { echo "❌ No hay archivos modificados." >&2; continue; }
        if command -v gum &>/dev/null; then
          local selection
          selection=$(printf '%s\n' "${files[@]}" | gum choose --no-limit --header "Space=marcar, Enter=confirmar, Esc=volver")
          [[ -z "$selection" ]] && continue
          to_restore=(${(f)"$selection"})
        else
          echo -e "${C_CYAN}📄 Archivos modificados:${C_RESET}" >&2
          local i=1; for f in "${files[@]}"; do printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$f" >&2; ((i++)); done
          echo -n "🔄 Números (ej: 1 3 5) o 'all': " >&2
          read -r -A nums
          if [[ "${nums[1]}" == "all" ]]; then
            to_restore=("${files[@]}")
          else
            for num in "${nums[@]}"; do
              [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#files[@]} )) && to_restore+=("${files[$num]}")
            done
          fi
        fi
        [[ ${#to_restore[@]} -eq 0 ]] && { echo "⚠️ No se seleccionaron archivos." >&2; continue; }
        local ok=0
        for f in "${to_restore[@]}"; do git restore "$f" 2>&1 && ((ok++)); done
        echo "✅ $ok archivos restaurados." >&2
        ;;
      unstage)
        local files nums to_unstage=()
        files=(${(f)"$(git diff --cached --name-only 2>/dev/null)"})
        [[ ${#files[@]} -eq 0 ]] && { echo "❌ No hay archivos en staging." >&2; continue; }
        if command -v gum &>/dev/null; then
          local selection
          selection=$(printf '%s\n' "${files[@]}" | gum choose --no-limit --header "Space=marcar, Enter=confirmar, Esc=volver")
          [[ -z "$selection" ]] && continue
          to_unstage=(${(f)"$selection"})
        else
          echo -e "${C_CYAN}📄 Archivos en staging:${C_RESET}" >&2
          local i=1; for f in "${files[@]}"; do printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$f" >&2; ((i++)); done
          echo -n "🔄 Números (ej: 1 3 5) o 'all': " >&2
          read -r -A nums
          if [[ "${nums[1]}" == "all" ]]; then
            to_unstage=("${files[@]}")
          else
            for num in "${nums[@]}"; do
              [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#files[@]} )) && to_unstage+=("${files[$num]}")
            done
          fi
        fi
        [[ ${#to_unstage[@]} -eq 0 ]] && { echo "⚠️ No se seleccionaron archivos." >&2; continue; }
        local ok=0
        for f in "${to_unstage[@]}"; do git restore --staged "$f" 2>&1 && ((ok++)); done
        echo "✅ $ok archivos desestageados." >&2
        ;;
      from-branch)
        local branches source files
        branches=(${(f)"$(git branch --format='%(refname:short)')"})
        if command -v gum &>/dev/null; then
          source=$(printf '%s\n' "${branches[@]}" | gum choose --header "Rama fuente")
          [[ -z "$source" ]] && continue
          files=(${(f)"$(git diff "$source" --name-only 2>/dev/null)"})
          [[ ${#files[@]} -eq 0 ]] && { echo "❌ No hay diferencias con '$source'." >&2; continue; }
          local selected
          selected=$(printf '%s\n' "${files[@]}" | gum choose --no-limit --header "Archivos a restaurar desde '$source'")
        else
          local i=1; for b in "${branches[@]}"; do echo "$i) $b" >&2; ((i++)); done
          echo -n "Rama fuente (nº): " >&2; read -r idx; source="${branches[$idx]}"
          [[ -z "$source" ]] && continue
          echo -n "Archivo: " >&2; read -r selected
        fi
        [[ -z "$selected" ]] && continue
        echo "$selected" | while read -r f; do git restore --source="$source" "$f"; done
        echo "✅ Archivos restaurados desde '$source'." >&2
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🔀 REBASE · Rebase interactivo
# ==============================================
_action_rebase() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "onto · rebase onto otra rama" \
        "interactive · rebase interactivo (-i)" \
        "abort · abortar rebase en curso" \
        "continue · continuar rebase" \
        "skip · saltar commit conflictivo" \

        --header " 🔀 REBASE · Elige acción Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔀 REBASE" >&2
      echo "1) Onto rama" >&2
      echo "2) Interactivo (-i)" >&2
      echo "3) Abort" >&2
      echo "4) Continue" >&2
      echo "5) Skip" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="onto" ;; 2) choice="interactive" ;; 3) choice="abort" ;;
        4) choice="continue" ;; 5) choice="skip" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      onto)
        local branches target
        branches=(${(f)"$(git branch --format='%(refname:short)')"})
        if command -v gum &>/dev/null; then
          target=$(printf '%s\n' "${branches[@]}" | gum choose --header "Rebase onto rama")
        else
          local i=1; for b in "${branches[@]}"; do echo "$i) $b" >&2; ((i++)); done
          echo -n "Rama (nº): " >&2; read -r idx; target="${branches[$idx]}"
        fi
        [[ -z "$target" ]] && continue
        git rebase "$target" && echo "✅ Rebase onto '$target' completado." >&2
        ;;
      interactive)
        local commit
        if command -v gum &>/dev/null; then
          commit=$(gum input --placeholder "commit base (ej: HEAD~5)")
        else
          echo -n "Commit base: " >&2; read -r commit
        fi
        [[ -z "$commit" ]] && continue
        git rebase -i "$commit"
        ;;
      abort)
        git rebase --abort && echo "✅ Rebase abortado." >&2
        ;;
      continue)
        git rebase --continue
        ;;
      skip)
        git rebase --skip && echo "✅ Commit saltado." >&2
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🔀 CHECKOUT · Cambiar rama o archivo
# ==============================================
_action_checkout() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "branch · cambiar de rama" \
        "create · crear y cambiar a nueva rama (-b)" \
        "file · restaurar archivos desde HEAD (lote)" \
        "detach · detach HEAD en commit" \

        --header " 🔀 CHECKOUT · Elige acción Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔀 CHECKOUT" >&2
      echo "1) Cambiar rama" >&2
      echo "2) Crear + cambiar (-b)" >&2
      echo "3) Restaurar archivos (lote)" >&2
      echo "4) Detach HEAD" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="branch" ;; 2) choice="create" ;; 3) choice="file" ;; 4) choice="detach" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      branch)
        local branches target
        branches=(${(f)"$(git branch --format='%(refname:short)')"})
        if command -v gum &>/dev/null; then
          target=$(printf '%s\n' "${branches[@]}" | gum choose --header "Selecciona rama")
        else
          local i=1; for b in "${branches[@]}"; do echo "$i) $b" >&2; ((i++)); done
          echo -n "Rama (nº): " >&2; read -r idx; target="${branches[$idx]}"
        fi
        [[ -z "$target" ]] && continue
        git checkout "$target"
        ;;
      create)
        local name
        if command -v gum &>/dev/null; then
          name=$(gum input --placeholder "nombre-de-la-nueva-rama")
        else
          echo -n "Nombre: " >&2; read -r name
        fi
        [[ -z "$name" ]] && continue
        git checkout -b "$name" && echo "✅ Creada y cambiado a '$name'." >&2
        ;;
      file)
        local files nums to_restore=()
        files=(${(f)"$(git status --porcelain 2>/dev/null | cut -c4-)"})
        [[ ${#files[@]} -eq 0 ]] && { echo "❌ No hay archivos modificados." >&2; continue; }
        if command -v gum &>/dev/null; then
          local selection
          selection=$(printf '%s\n' "${files[@]}" | gum choose --no-limit --header "Space=marcar, Enter=confirmar, Esc=volver")
          [[ -z "$selection" ]] && continue
          to_restore=(${(f)"$selection"})
        else
          echo -e "${C_CYAN}📄 Archivos modificados:${C_RESET}" >&2
          local i=1; for f in "${files[@]}"; do printf "  ${C_GREEN}[%d]${C_RESET} %s\n" "$i" "$f" >&2; ((i++)); done
          echo -n "🔄 Números (ej: 1 3 5) o 'all': " >&2
          read -r -A nums
          if [[ "${nums[1]}" == "all" ]]; then
            to_restore=("${files[@]}")
          else
            for num in "${nums[@]}"; do
              [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#files[@]} )) && to_restore+=("${files[$num]}")
            done
          fi
        fi
        [[ ${#to_restore[@]} -eq 0 ]] && { echo "⚠️ No se seleccionaron archivos." >&2; continue; }
        local ok=0
        for f in "${to_restore[@]}"; do git checkout -- "$f" 2>&1 && ((ok++)); done
        echo "✅ $ok archivos restaurados." >&2
        ;;
      detach)
        local commit
        if command -v gum &>/dev/null; then
          commit=$(gum input --placeholder "commit hash o referencia")
        else
          echo -n "Commit: " >&2; read -r commit
        fi
        [[ -z "$commit" ]] && continue
        git checkout "$commit"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# ⬇️ PULL · Traer y fusionar
# ==============================================
_action_pull() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "default · pull normal" \
        "rebase · pull con rebase (--rebase)" \
        "ff-only · solo fast-forward (--ff-only)" \
        "prune · pull + limpiar refs obsoletos (--prune)" \
        "all · pull todos los remotos (--all)" \

        --header " ⬇️ PULL · Elige modo Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "⬇️ PULL" >&2
      echo "1) Default" >&2
      echo "2) Rebase" >&2
      echo "3) FF-only" >&2
      echo "4) Prune" >&2
      echo "5) All remotes" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="default" ;; 2) choice="rebase" ;; 3) choice="ff-only" ;;
        4) choice="prune" ;; 5) choice="all" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      default)  git pull ;;
      rebase)   git pull --rebase ;;
      ff-only)  git pull --ff-only ;;
      prune)    git pull --prune ;;
      all)      git pull --all ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 📥 FETCH · Traer cambios remotos
# ==============================================
_action_fetch() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "default · fetch origin" \
        "all · fetch todos los remotos (--all)" \
        "prune · fetch + limpiar refs obsoletas (--prune)" \
        "tags · fetch todas las tags (--tags)" \
        "remote · fetch remoto específico" \

        --header " 📥 FETCH · Elige modo Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "📥 FETCH" >&2
      echo "1) Default (origin)" >&2
      echo "2) All remotes" >&2
      echo "3) Prune" >&2
      echo "4) Tags" >&2
      echo "5) Remoto específico" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="default" ;; 2) choice="all" ;; 3) choice="prune" ;;
        4) choice="tags" ;; 5) choice="remote" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      default)  git fetch ;;
      all)      git fetch --all ;;
      prune)    git fetch --prune ;;
      tags)     git fetch --tags ;;
      remote)
        local remotes remote
        remotes=(${(f)"$(git remote 2>/dev/null)"})
        [[ ${#remotes[@]} -eq 0 ]] && { echo "❌ No hay remotos configurados." >&2; continue; }
        if command -v gum &>/dev/null; then
          remote=$(printf '%s\n' "${remotes[@]}" | gum choose --header "Selecciona remoto")
        else
          local i=1; for r in "${remotes[@]}"; do echo "$i) $r" >&2; ((i++)); done
          echo -n "Remoto (nº): " >&2; read -r idx; remote="${remotes[$idx]}"
        fi
        [[ -z "$remote" ]] && continue
        git fetch "$remote"
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 👁️ SHOW · Ver un commit
# ==============================================
_action_show() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "latest · ver último commit" \
        "pick · elegir commit del historial" \
        "hash · introducir hash manualmente" \
        "stat · último commit con stat" \
        "files · solo nombres de archivos (--name-only)" \

        --header " 👁️ SHOW · Elige opción Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "👁️ SHOW" >&2
      echo "1) Último commit" >&2
      echo "2) Elegir del historial" >&2
      echo "3) Hash manual" >&2
      echo "4) Último + stat" >&2
      echo "5) Solo archivos" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="latest" ;; 2) choice="pick" ;; 3) choice="hash" ;;
        4) choice="stat" ;; 5) choice="files" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      latest)  git show ;;
      pick)
        local commit
        if command -v gum &>/dev/null; then
          commit=$(git log --oneline -20 | gum choose --header "Selecciona commit" | awk '{print $1}')
        else
          git log --oneline -20 >&2
          echo -n "Hash: " >&2; read -r commit
        fi
        [[ -z "$commit" ]] && continue
        git show "$commit"
        ;;
      hash)
        local commit
        if command -v gum &>/dev/null; then
          commit=$(gum input --placeholder "hash del commit")
        else
          echo -n "Hash: " >&2; read -r commit
        fi
        [[ -z "$commit" ]] && continue
        git show "$commit"
        ;;
      stat)   git show --stat ;;
      files)  git show --name-only ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🔄 SYNC · Sincronizar con remoto
# ==============================================
_action_sync() {
  _git_check_repo || return 1
  while true; do
    local choice
    if command -v gum &>/dev/null; then
      choice=$(gum choose \
        "default · remote update + pull --rebase" \
        "fetch-all · fetch all + pull --rebase" \
        "prune · fetch --prune + pull --rebase" \

        --header " 🔄 SYNC · Elige modo Esc=salir ")
      [[ -z "$choice" ]] && return 0
      choice="${choice%% · *}"
    else
      echo "" >&2
      echo "🔄 SYNC" >&2
      echo "1) Default (remote update + pull --rebase)" >&2
      echo "2) Fetch all + pull --rebase" >&2
      echo "3) Prune + pull --rebase" >&2
      echo "q) Salir" >&2
      echo -n "Opción: " >&2; read -r choice
      [[ "$choice" == "q" || "$choice" == "Q" ]] && return 0
      case "$choice" in
        1) choice="default" ;; 2) choice="fetch-all" ;; 3) choice="prune" ;;
        *) continue ;;
      esac
    fi

    case "$choice" in
      default)
        git remote update && git pull --rebase
        ;;
      fetch-all)
        git fetch --all && git pull --rebase
        ;;
      prune)
        git fetch --prune && git pull --rebase
        ;;
    esac
    echo "" >&2
  done
}

# ==============================================
# 🎯 DISPATCHER PRINCIPAL
# ==============================================
function on_git() {
  if [[ $# -eq 0 ]]; then
    local opt
    if command -v gum &>/dev/null; then
      opt=$(gum choose \
        "push · commit + push automático" \
        "commit · solo commit local" \
        "release · tag SemVer + GitHub release (CRUD)" \
        "merge · merge entre ramas (--strategy=ours|theirs)" \
        "switch · cambiar de rama (auto-stash)" \
        "flow · menú interactivo rápido" \
        "clean · limpiar innecesarios (node_modules, dist…)" \
        "submodule · add/delete/fix submódulos" \
        "remote · configurar remotos (SSH/gh)" \
        "tag · menú de tags (create/list/delete/rename/edit)" \
        "branch · list/create/delete local/delete remoto/rename" \
<<<<<<< HEAD
        "status · short (-sb) / long / porcelain / ignored" \
        "log · graph / full / stat / author / last N" \
=======
>>>>>>> dev
        "diff · working / staged / stat / branches" \
        "stash · push/list/pop/apply/show/drop/clear" \
        "reset · soft / mixed / hard / to-commit" \
        "restore · file / unstage / from-branch" \
        "rebase · onto / interactive (-i) / abort / continue / skip" \
        "checkout · branch / create (-b) / file / detach" \
        "pull · default / rebase / ff-only / prune / all" \
        "fetch · default / all / prune / tags / remoto" \
        "show · latest / pick / hash / stat / files" \
        "sync · remote update / fetch all / prune + rebase" \
        --header " 🔀 GIT · Elige subcomando ")
      [[ -z "$opt" ]] && return 0
      on_git "${opt%% · *}"
      return
    else
      _show_help
      printf "Comando: " >&2
      read -r opt
      [[ -z "$opt" ]] && return 0
      on_git "$opt"
      return
    fi
  fi

  local cmd="$1"
  shift

  case "$cmd" in
    push|p)      _action_push "$@" ;;
    commit|c)    _action_commit "$@" ;;
    release|r)   _release_router "$@" ;;
    merge|m)     _action_merge "$@" ;;
    switch|sw)   _action_switch "$@" ;;
    flow|f)      _action_flow "$@" ;;
    clean|cl)    _action_clean "$@" ;;
    submodule|sub) _action_submodule "$@" ;;
    remote|rem)  _action_remote "$@" ;;
    t|tag)       if [[ $# -gt 0 ]]; then command git tag "$@"; else _tag_menu; fi ;;
<<<<<<< HEAD
    s|status)    if [[ $# -gt 0 ]]; then command git status "$@"; else _action_status; fi ;;
    b|branch)    if [[ $# -gt 0 ]]; then command git branch "$@"; else _action_branch; fi ;;
    l|log)       if [[ $# -gt 0 ]]; then command git log "$@"; else _action_log; fi ;;
=======
    s|status)    command git status "$@" ;;
    b|branch)    _action_branch "$@" ;;
    l|log)       command git log --oneline --decorate --graph "$@" ;;
>>>>>>> dev
    d|diff)      if [[ $# -gt 0 ]]; then command git diff "$@"; else _action_diff; fi ;;
    ft|fetch)    if [[ $# -gt 0 ]]; then command git fetch "$@"; else _action_fetch; fi ;;
    co|checkout) if [[ $# -gt 0 ]]; then command git checkout "$@"; else _action_checkout; fi ;;
    pl|pull)     if [[ $# -gt 0 ]]; then command git pull "$@"; else _action_pull; fi ;;
    sta|stash)   if [[ $# -gt 0 ]]; then command git stash "$@"; else _action_stash; fi ;;
    rs|reset)    if [[ $# -gt 0 ]]; then command git reset "$@"; else _action_reset; fi ;;
    restore)     if [[ $# -gt 0 ]]; then command git restore "$@"; else _action_restore; fi ;;
    rb|rebase)   if [[ $# -gt 0 ]]; then command git rebase "$@"; else _action_rebase; fi ;;
    show)        if [[ $# -gt 0 ]]; then command git show "$@"; else _action_show; fi ;;
    sync)        if [[ $# -gt 0 ]]; then command git remote update && command git pull --rebase "$@"; else _action_sync; fi ;;
    help|-h|--help) _show_help ;;
    *)
      echo -e "${C_RED}❌ Subcomando desconocido: $cmd${C_RESET}" >&2
      _show_help
      return 1
      ;;
  esac
}
