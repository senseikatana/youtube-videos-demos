# 🥋 Zsh Dojo — Workflow modular de terminal

> Un `.zshrc` organizado en **módulos por dominio** con **funciones-dispatcher** que abren **menús interactivos** (`gum`) para hacerlo todo en 1 o 2 pasos: git, archivos, paquetes, updates, navegación y más. En Arch/BigLinux y también Debian/Ubuntu.

🎬 *[Video explicando el workflow](URL-DEL-VIDEO)* — si llegaste desde YouTube, ¡bienvenido!

## ✨ Características

- **Un comando = un menú**: cada dominio tiene una función `use*` que sin argumentos abre un menú `gum` (con fallback a menú numerado si no tienes gum).
- **Módulos por dominio**: cada archivo de `functions/` es autocontenido y se registra en un solo sitio (`functions.zsh`).
- **Portátil**: cero rutas hardcodeadas (`$HOME`/`$USER`); el mismo config sirve en Arch y Debian/Ubuntu (`usePkg` / `usePkgApt` detectan el backend).
- **Seguro por diseño**: confirmaciones antes de acciones destructivas, papelera en vez de `rm` ciego, sin `--noconfirm` en los flujos interactivos.
- **Automatizable**: los mismos subcomandos funcionan en scripts y automatizaciones diarias.

## 📁 Estructura

```
.
├── .zshrc                  # aliases por categorías (Calling functions / Commands)
├── functions.zsh           # cargador: registra y sourcea los módulos
└── functions/
    ├── core.zsh            # colores y helpers (confirmaciones gum, check repo)
    ├── git.zsh             # useGit — commit/push/release + CRUD de gh releases + passthrough git
    ├── github.zsh          # useGh — PRs, issues, repos, gists + passthrough gh
    ├── docker.zsh          # useDocker — exec, logs, imágenes, compose, prune
    ├── package-managers.zsh# usePm + usePmNpm/Pnpm/Yarn/Bun — unificada y por gestor
    ├── utils.zsh           # useCleanup, killport, extract, passgen, info
    ├── system.zsh          # useFiles — CRUD e inspección de archivos + chmod helpers
    ├── pkg.zsh             # usePkg — updates Arch (paru + flatpak + snap)
    ├── pkg-apt.zsh         # usePkgApt — updates Debian/Ubuntu (apt + flatpak + snap)
    ├── systemd.zsh         # useSysd — servicios de sistema y usuario
    ├── zinit.zsh           # useZinit — gestor de plugins
    ├── nodeclean.zsh       # useNmk — node_modules: tamaños, papelera, sweep
    ├── lazy.zsh            # useLazy — lanzador de TUIs (lazygit, lazydocker...)
    ├── media.zsh           # useDownload — yt-dlp con modos video/music/playlist
    ├── virtmanager.zsh     # useVM — VMs QEMU/KVM
    ├── init-docs.zsh       # generación de documentación de proyectos
    ├── create-web.zsh      # useWeb — scaffolding de proyectos (15 frameworks)
    └── navigation.zsh      # useGo — accesos rápidos con menú + yazi (yz)
```

## 🚀 Catálogo de comandos

| Comando | Qué hace | Ejemplo |
|---|---|---|
| `useGit` | Git con menú: commit/push/release + CRUD de releases + passthrough | `useGit release create` |
| `useGh` | GitHub CLI: PRs, issues, repos, gists (+ cualquier comando gh directo) | `useGh pr list` |
| `useFiles` | Archivos: crear/renombrar/mover/copiar/borrar + tamaños, contenido, árbol | `useFiles size` |
| `useGo` | Accesos rápidos a carpetas con menú | `useGo proj` |
| `usePkg` | Updates Arch: paru + flatpak + snap, check y limpieza | `usePkg u` |
| `usePkgApt` | Igual pero para Debian/Ubuntu (apt) | `usePkgApt u` |
| `usePm` | Paquetes JS: detecta gestor por lockfile | `usePm i` |
| `usePmBun` / `usePmPnpm` / `usePmYarn` / `usePmNpm` | Fuerzan un gestor concreto (+ passthrough nativo) | `usePmBun add zod` |
| `useNmk` | node_modules: tamaños, papelera, barrido de proyectos | `useNmk sweep` |
| `useSysd` | systemd: start/stop/status/enable (sistema y usuario) | `useSysd t nginx` |
| `useDocker` | Docker y compose con menú | `useDocker logs` |
| `useWeb` | Scaffolding de proyectos web (framework + gestor) | `useWeb astro` |
| `useDownload` | yt-dlp: video / music / playlist | `useDownload music URL` |
| `useLazy` | Lanza lazygit, lazydocker, lazysql... | `useLazy` |
| `useZinit` | Plugins de zinit | `useZinit all` |
| `useCleanup` | Limpieza: caché de paquetes, journal, tmp, papelera | `useCleanup` |
| `yz` | yazi con cambio de directorio al salir | `yz` |
| `useVM` | Máquinas virtuales QEMU/KVM | `useVM full` |

> El patrón siempre es el mismo: **sin argumentos → menú gum; con subcomando → directo; cualquier otra cosa → passthrough a la herramienta real.**

## 📦 Requisitos

- **zsh** (probado con 5.9)
- **gum** — los menús (opcional: hay fallback numérico) · [charm.sh/gum](https://github.com/charmbracelet/gum)
- **fzf** — selección de archivos
- Recomendados: `eza`, `bat`, `fd`, `duf`, `dust`, `trash-cli`, `yt-dlp`
- En Arch: `paru` o `yay` · En Debian/Ubuntu: `apt`

## ⚡ Instalación

```bash
git clone https://github.com/TU-USUARIO/zsh-dojo.git
```

En tu `~/.zshrc`:

```zsh
# Aliases (los que uses — la lista completa está en la descripción del vídeo)
alias useGit='on_git'
alias useFiles='on_files'
alias usePkg='on_pkg'

# Cargar los módulos (el cargador detecta su propia carpeta)
source ~/ruta/a/zsh-dojo/functions.zsh
```

Recarga con `source ~/.zshrc` y listo. Cada módulo es independiente: copia solo los que uses.

## 🎬 Vídeo

Explicación completa del workflow en YouTube: *(añade el enlace cuando publique)*

## 📄 Licencia

MIT
