#!/usr/bin/env zsh
# ==============================================================================
# 📄 INIT-DOCS - Generar documentación básica del proyecto
# ==============================================================================

on_initdocs() {
    local repo_name=$(basename "$PWD")
    local author_name=$(git config user.name 2>/dev/null || echo "Tu Nombre")
    local current_year=$(date +%Y)
    local repo_name_lower=$(echo "$repo_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    local has_package_json=false
    
    if [[ -f "package.json" ]]; then
        has_package_json=true
        echo "📦 package.json detectado. Se actualizarán solo los campos necesarios."
    fi
    
    _overwrite_file() {
        local file="$1"
        local content="$2"
        if [[ -f "$file" ]]; then
            echo -n "⚠️  El archivo $file ya existe. ¿Sobrescribir? (s/N): "
            read -k 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                echo "$content" > "$file"
                echo "✅ $file sobrescrito"
                return 0
            else
                echo "⏭️  $file conservado"
                return 1
            fi
        else
            echo "$content" > "$file"
            echo "✅ $file creado"
            return 0
        fi
    }

    local gitignore_content="# Dependencias
node_modules/
.pnpm-store/
.yarn/
bun.lockb

# Carpetas y archivos ocultos del sistema
.*
!.gitignore
!.env.example
!.prettierrc
!.eslintrc.json

# Compilaciones y logs
dist/
build/
*.log
npm-debug.log*
yarn-debug.log*
pnpm-debug.log*
bun-debug.log*

# Archivos de entorno
.env
.env.local
.env.*.local

# Cache
.cache/
.parcel-cache/
.next/
.nuxt/
.output/
coverage/

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
"
    _overwrite_file ".gitignore" "$gitignore_content"

    local license_content="MIT License

Copyright (c) $current_year $author_name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the \"Software\"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"
    _overwrite_file "LICENSE" "$license_content"

    local readme_content="# $repo_name

## 🚀 Descripción

Proyecto **$repo_name**.

## 📦 Instalación

\`\`\`bash
# Con Bun
bun install

# Con npm
npm install
\`\`\`

## 🛠️ Desarrollo

\`\`\`bash
# Iniciar en modo desarrollo
bun run dev

# Build para producción
bun run build

# Ejecutar tests
bun run test
\`\`\`

## 📄 Licencia

MIT © $current_year $author_name
"
    _overwrite_file "README.md" "$readme_content"

    if [[ "$has_package_json" == true ]]; then
        echo "📝 Actualizando package.json..."
        local tmp_file=$(mktemp)
        
        if command -v jq &>/dev/null; then
            jq --arg name "$repo_name_lower" \
               --arg author "$author_name" \
               --arg year "$current_year" \
               '.name = $name | .author = $author | .version = "0.1.0" | 
                .description = "Proyecto \($name)" |
                .scripts += {"dev": "bun run dev", "build": "bun run build", "test": "bun run test"}' \
               package.json > "$tmp_file" 2>/dev/null
            
            if [[ $? -eq 0 ]]; then
                mv "$tmp_file" package.json
                echo "✅ package.json actualizado"
            else
                echo "⚠️  Error al actualizar package.json."
                echo -n "¿Deseas sobrescribirlo completamente? (s/N): "
                read -k 1 -r
                echo
                if [[ $REPLY =~ ^[Ss]$ ]]; then
                    _overwrite_file "package.json" "$(_generate_package_json)"
                else
                    echo "⏭️  package.json conservado"
                fi
                rm -f "$tmp_file"
            fi
        else
            echo "⚠️  jq no está instalado. No se puede actualizar package.json."
            echo -n "¿Deseas sobrescribirlo completamente? (s/N): "
            read -k 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                _overwrite_file "package.json" "$(_generate_package_json)"
            else
                echo "⏭️  package.json conservado"
            fi
        fi
    else
        _overwrite_file "package.json" "$(_generate_package_json)"
    fi

    echo ""
    echo "🎉 ¡Documentación generada/actualizada!"
    echo ""
    echo "📁 Archivos creados/actualizados:"
    echo "   ├── .gitignore   - Archivos ignorados por Git"
    echo "   ├── LICENSE      - MIT License"
    echo "   ├── README.md    - Documentación del proyecto"
    echo "   └── package.json - Dependencias y scripts"
    echo ""
    echo "💡 Comandos disponibles:"
    echo "   bun run dev      - Iniciar desarrollo"
    echo "   bun run build    - Build para producción"
    echo "   bun run test     - Ejecutar tests"
}

_generate_package_json() {
    local repo_name_lower=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    local author_name=$(git config user.name 2>/dev/null || echo "Tu Nombre")
    
    cat << EOF
{
  "name": "$repo_name_lower",
  "version": "0.1.0",
  "description": "Proyecto $repo_name_lower",
  "type": "module",
  "scripts": {
    "dev": "bun run dev",
    "build": "bun run build",
    "test": "bun run test"
  },
  "author": "$author_name",
  "license": "MIT"
}
EOF
}



