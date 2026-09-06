#!/usr/bin/env zsh

# 🌐 CREATE WEB - Scaffold web projects with any package manager

# Muestra el panel de ayuda
show_help() {
    print -P "%F{cyan}Usage: create-web [framework] [project_name] [package_manager]%f\n"
    print -P "🛠️  Frameworks:"
    print -P "   Vite:        vite(v), react(r), vue, svelte(s), solid, qwik, preact, lit, vanilla"
    print -P "   Meta:        astro(a), next(n), %F{cyan}nuxt(NU)%f, %F{cyan}sveltekit(SK)%f, %F{cyan}remix(RX)%f, angular(ng)"
    print -P "📦 Managers:   bun, pnpm, npm, yarn, %F{cyan}nub%f"
    print -P "📂 Location:   Created in %F{cyan}$(pwd)%f (Current directory)"
    print -P "💡 Tip:        Use %F{cyan}.%f as project name to scaffold in the current directory"
}

# Construye el comando según el gestor y framework
# Imprime el comando en stdout (una línea por elemento del array)
build_scaffold_command() {
    local pm="$1"
    local proj="$2"
    local fw="$3"

    local pkg_name=""
    local template=""
    local -a cmd

    # 1. Casos con comandos dedicados fuera del patrón standard `create-*`
    case "$fw" in
        nuxt|NU)
            case "$pm" in
                npm)  cmd=(npx nuxi@latest init "$proj") ;;
                nub)  cmd=(nubx nuxi@latest init "$proj") ;;
                yarn) cmd=(yarn dlx nuxi@latest init "$proj") ;;
                pnpm) cmd=(pnpm dlx nuxi@latest init "$proj") ;;
                bun)  cmd=(bunx nuxi@latest init "$proj") ;;
                *)    return 1 ;;
            esac
            printf '%s\n' "${cmd[@]}"
            return 0
            ;;
        angular|ng)
            case "$pm" in
                npm)  cmd=(npx @angular/cli@latest new "$proj") ;;
                nub)  cmd=(nubx @angular/cli@latest new "$proj") ;;
                yarn) cmd=(yarn dlx @angular/cli@latest new "$proj") ;;
                pnpm) cmd=(pnpm dlx @angular/cli@latest new "$proj") ;;
                bun)  cmd=(bunx @angular/cli@latest new "$proj") ;;
                *)    return 1 ;;
            esac
            printf '%s\n' "${cmd[@]}"
            return 0
            ;;
    esac

    # 2. Mapeo para los que sí usan paquetes `create-*`
    case "$fw" in
        # --- Vite-based (templates de create-vite) ---
        vite|v)          pkg_name="vite"       ;;
        react|r)         pkg_name="vite";  template="react"   ;;
        vue)             pkg_name="vite";  template="vue"     ;;
        svelte|s)        pkg_name="vite";  template="svelte"  ;;
        solid)           pkg_name="vite";  template="solid"   ;;
        qwik)            pkg_name="vite";  template="qwik"    ;;
        preact)          pkg_name="vite";  template="preact"  ;;
        lit)             pkg_name="vite";  template="lit"     ;;
        vanilla)         pkg_name="vite";  template="vanilla" ;;
        # --- Meta-frameworks con create-* válido ---
        astro|a)         pkg_name="astro"      ;;
        next|n|nextjs)   pkg_name="next-app"   ;;
        sveltekit|SK)    pkg_name="svelte"     ;;
        remix|RX)        pkg_name="remix"      ;;
        *)               return 1 ;;
    esac

    # Construir comando base para scaffolds estándar
    case "$pm" in
        npm)   cmd=(npm create "${pkg_name}@latest" "$proj") ;;
        nub)   cmd=(nubx "${pkg_name}@latest" "$proj")       ;;
        yarn)  cmd=(yarn create "$pkg_name" "$proj")         ;;
        pnpm)  cmd=(pnpm create "$pkg_name" "$proj")         ;;
        bun)   cmd=(bun create "$pkg_name" "$proj")          ;;
        *)     return 1 ;;
    esac

    # Flags para plantillas Vite
    if [[ -n "$template" ]]; then
        if [[ "$pm" == "npm" || "$pm" == "nub" ]]; then
            cmd+=(-- --template "$template")
        else
            cmd+=(--template "$template")
        fi
    fi

    printf '%s\n' "${cmd[@]}"
}


# Entrypoint
on_create-web() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        return 0
    fi

    local fw="$1"
    local proj="$2"
    local pm="$3"

    # Sin argumentos: mostrar help
    if [[ -z "$fw" ]]; then
        show_help
        echo ""
    fi

    # Prompts interactivos para campos faltantes
    if command -v gum &>/dev/null; then
        [[ -z "$fw" ]]   && fw=$(gum choose \
            "vite" "react" "vue" "svelte" "solid" "qwik" "preact" "lit" "vanilla" \
            "astro" "next" "nuxt" "sveltekit" "remix" "angular" \
            --header "Select framework:")
        [[ -z "$proj" ]] && proj=$(gum input --placeholder "my-awesome-app (or . for current dir)" --prompt "Project name: ")
        [[ -z "$pm" ]]   && pm=$(gum choose "bun" "pnpm" "npm" "yarn" "nub" --header "Select package manager:")
    else
        [[ -z "$fw" ]]   && read "fw?🛠️  Framework (vite/react/vue/svelte/solid/qwik/preact/lit/vanilla/astro/next/nuxt/sveltekit/remix/angular): "
        [[ -z "$proj" ]] && read "proj?🎯 Project name (. = current dir): "
        if [[ -z "$pm" ]]; then
            read "pm?📦 Package manager (bun/pnpm/npm/yarn/nub) [bun]: "
            pm=${pm:-bun}
        fi
    fi

    if [[ -z "$fw" || -z "$proj" ]]; then
        print -P "%F{red}❌ Error: Framework y nombre de proyecto requeridos.%f"
        return 1
    fi

    local target_dir
    if [[ "$proj" == "." ]]; then
        target_dir="$(pwd)"
    else
        target_dir="$(pwd)/$proj"
        if [[ -d "$target_dir" ]]; then
            print -P "%F{red}❌ Error: '$target_dir' ya existe.%f"
            return 1
        fi
    fi

    # Construir comando de scaffolding
    local cmd_output
    cmd_output=$(build_scaffold_command "$pm" "$proj" "$fw") || {
        print -P "%F{red}❌ Error: Framework '$fw' no soportado.%f"
        return 1
    }

    # Reconstruir array desde la salida
    local -a scaffold_cmd
    while IFS= read -r line; do
        scaffold_cmd+=("$line")
    done <<< "$cmd_output"

    print -P "🚀 Generando proyecto en %F{cyan}$target_dir%f..."
    "${scaffold_cmd[@]}" || return 1

    if [[ "$proj" != "." ]]; then
        cd "$target_dir" || return 1
    fi

    print -P "📦 Instalando dependencias..."
    "$pm" install || return 1

    print -P "%F{green}✅ Proyecto creado exitosamente!%f"
    if [[ "$proj" == "." ]]; then
        print "📂 Ubicación: $(pwd)"
    else
        print "📂 cd $target_dir"
    fi
    print "🚀 $pm run dev"
}
