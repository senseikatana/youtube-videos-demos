# 🎬 Guion — Vídeo workflow zsh (Zsh Dojo)

> Archivo privado (no va en el repo público). Duración objetivo: **12-15 min**.

---

## 🏷️ Títulos (elige uno)

1. **Mi terminal hace TODO por mí: workflow zsh con menús interactivos** ⭐ (recomendado: beneficio claro + curiosidad)
2. Construí un centro de mando en zsh: git, archivos y updates en 1 comando
3. Deja de memorizar comandos: así organicé mi .zshrc como un PRO
4. Tu .zshrc es un caos — mira cómo lo convertí en módulos con menús
5. Zsh Dojo: git, archivos y updates con MENÚS en la terminal (gum)

---

## 📝 Descripción YouTube (copiar y pegar)

```
¿Y si tu terminal te preguntara qué quieres hacer en vez de obligarte a memorizar
100 comandos? En este vídeo te enseño mi workflow completo en zsh: un .zshrc
organizado en módulos por dominio, con funciones que abren MENÚS INTERACTIVOS
(gum) para git, archivos, paquetes, updates y más — en 1 o 2 pasos.

Todo el código está anonimizado y publicado en GitHub (repo en la descripción),
listo para que lo clones y lo adaptes.

⏱️ CAPÍTULOS
00:00 — Tu terminal, con menús (demo rápida)
00:30 — La idea: módulos por dominio + un cargador
02:00 — Navegación con menú (useGo) y yazi (yz)
03:00 — Archivos en 1-2 pasos: crear, renombrar, papelera (useFiles)
05:00 — Git: commit con mensaje IA, releases y CRUD en GitHub (useGit / useGh)
07:30 — Updates del sistema en Arch Y Debian (usePkg / usePkgApt)
09:00 — Paquetes JS: npm/pnpm/yarn/bun unificados (usePm)
10:00 — Limpieza de node_modules sin romper nada (useNmk)
11:00 — La automatización diaria que actualiza mi PC sola
12:00 — Instalación: clona el repo y adáptalo
13:30 — Cierre

🛠️ REQUISITOS
zsh 5.9 · gum (charm.sh/gum) · fzf · eza · bat · fd · duf
Arch: paru · Debian/Ubuntu: apt

📁 REPO CON TODO EL CÓDIGO
👉 https://github.com/TU-USUARIO/zsh-dojo

Si te sirvió, deja un 👍 y suscríbete — subo más contenido de productividad
en terminal y desarrollo.

#zsh #linux #dotfiles #terminal #gum #archlinux #productividad #cli
```

---

## 🎥 Guion detallado

### 0:00-0:30 — HOOK (grabar al final, cuando domines las demos)
- En cámara/voz: *"¿Cuántos comandos de terminal has olvidado? Yo también. Por eso mi terminal me pregunta qué quiero hacer."*
- Demo relámpago en pantalla: teclear `useFiles` → menú gum aparece → elegir `rename` → renombrar un archivo. Cortar.
- Frase de cierre del hook: *"Esto no es un plugin: son ~15 archivos de zsh que puedes copiar. Vamos a verlo."*

### 0:30-2:00 — LA IDEA
- Mostrar la **estructura de carpetas** (`ls` sobre el repo / editor): `functions/` con un módulo por dominio, `functions.zsh` como cargador (bucle `for module in ...`).
- Punto clave que decir: *"cada módulo es autocontenido: si quieres solo git, copias solo git.zsh"*.
- Mostrar un fragmento del dispatcher (`case` → menú gum → passthrough). Consejo: zoom al código, 30 s máximo.

### 2:00-3:00 — NAVEGACIÓN
- `useGo` (menú de accesos rápidos), `useGo proj` (directo).
- `yz` (yazi) — decir: *"para explorar, yazi; para acciones puntuales, useFiles — cada herramienta su trabajo"*.

### 3:00-5:00 — ARCHIVOS (useFiles)
- `useFiles` (menú completo), luego demos directas:
  - `useFiles size` (mapa de pesos del directorio) ← visualmente potente
  - `useFiles rename` (picker fzf → gum input)
  - `useFiles del` (selección múltiple → papelera, NO rm ciego)
- Frase: *"borrar va a la papelera, no al vacío"*.

### 5:00-7:30 — GIT (la estrella)
- `useGit` (menú), `useGit commit` → mensaje Conventional Commits generado solo (menciona que usa Ollama si está, fallback determinista).
- `useGit release create` → SemVer automático + **tag + release en GitHub juntos**, notas a elegir.
- `useGit release delete` → borra release y opcionalmente el tag.
- `useGh pr list` (passthrough de gh).

### 7:30-9:00 — SISTEMA (usePkg / useCleanup)
- `usePkg check` (pendientes), `usePkg` (menú).
- Mencionar: *"mismo config en Arch y Debian — usePkgApt para apt"*.
- `useCleanup` (menú de limpieza; caché de paquetes conserva 2 versiones).

### 9:00-10:00 — JS (usePm)
- `usePm i` detecta gestor por lockfile; `usePmBun add zod` fuerza bun; `usePmPnpm store prune` (passthrough nativo).
- Contexto: *"con Nuxt cambio de bun a pnpm en la misma carpeta"*

### 10:00-11:00 — LIMPIEZA (useNmk)
- `useNmk sweep` → escanea ~/Proyectos → tamaños → selección múltiple → papelera. *"Sin romper nada: solo node_modules"*

### 11:00-12:00 — AUTOMATIZACIÓN (feature estrella)
- Mostrar la sección Automations del programa (no cron): *"una tarea diaria a las 9:00 que revisa updates con usePkg y los aplica solo si el PC está encendido — con límites: sin --force, sin reinicios, y si algo falla me lo reporta"*. Screenshot/screencast del historial de corridas.

### 12:00-13:30 — INSTALACIÓN
- `git clone` del repo → pegar 2 líneas en .zshrc → `reload` → menú aparece.
- *"Cada módulo es independiente: usa solo lo que necesites."*

### 13:30-fin — CTA
- Repo en descripción, like, suscripción, comentario: *"¿qué le añadirías a tu Dojo?"*

---

## 💡 Tips de grabación
- Aumenta el tamaño de fuente de la terminal (16-18pt) y usa un tema de alto contraste.
- Prepara un repo de demo con cambios pendientes para que `useGit commit` tenga chicha.
- Ensaya el hook 3 veces; si los primeros 30 s no enganchan, nadie ve las demos.
- Graba la pantalla a 1080p mínimo; los menús gum se ven pequeños.
- Etiquetas sugeridas: zsh, terminal, dotfiles, linux, gum, arch linux, productividad, cli, workflow, developer.
