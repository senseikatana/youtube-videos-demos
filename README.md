---
title: Senseikatana — Canal de YouTube
channel: Senseikatana
url: https://www.youtube.com/@Senseikatana
description: Workflows, terminal y desarrollo — cada vídeo con su código.
topics: [zsh, linux, dotfiles, terminal, productividad]
---

# Youtube Senseikatana Channel

> **Código, terminal y workflows — cada vídeo con su repo.**

Este es el monorepo privado del canal [**Senseikatana**](https://www.youtube.com/@Senseikatana): aquí vive todo lo que se publica — guiones, código y material de cada vídeo — organizado en una carpeta por proyecto.

## 📺 Sobre el canal

En Senseikatana enseño **cómo trabajar mejor con la terminal**: workflows reales de productividad, dotfiles comentados, automatizaciones y herramientas CLI — siempre con el mismo principio:

> **Cada vídeo va acompañado de su código completo y reproducible.**

Nada de "esto lo dejamos como ejercicio": lo que ves en pantalla es lo que puedes clonar.

## 🗂️ Índice de vídeos

| Proyecto | Tema | Vídeo | Estado |
|---|---|---|---|
| [`workflow-zsh-linux/`](workflow-zsh-linux/) | Zsh Dojo — terminal con menús interactivos | *(pendiente)* | 🎥 En producción |

> Cada proyecto se añade aquí al empezar su guion y se marca: 📝 idea → 🎥 en producción → ✅ publicado.

## 📁 Estructura del monorepo

```
yt-videos-channel/
├── workflow-zsh-linux/     # Vídeo 1: Zsh Dojo (config zsh modular con menús gum)
│   ├── functions/          #   módulos zsh (uno por dominio)
│   ├── functions.zsh       #   cargador de módulos
│   ├── README.md           #   documentación pública del vídeo
│   └── guion-*.md          #   guion del vídeo (privado, gitignoreado)
├── package.json            # tooling común del monorepo
└── LICENSE                 # MIT
```

**Convención:** una carpeta por vídeo, con el código ejecutable dentro y su fila en el índice de arriba.

## 🔁 Flujo de producción

1. **📝 Idea** — se crea la carpeta del proyecto y su fila en el índice.
2. **🎬 Guion** — `guion-video-<tema>.md` con títulos, descripción y tiempos (privado, gitignoreado).
3. **💻 Código** — lo que se enseña en el vídeo, listo para clonar.
4. **🎥 Grabación y edición.**
5. **🚀 Publicación** — vídeo en YouTube + código en `main`, y la fila del índice pasa a ✅.

Trabajo en la rama `dev` y muevo a `main` al publicar cada vídeo.

## 🧰 Stack del canal

![zsh](https://img.shields.io/badge/shell-zsh-4EAA25?logo=gnu-bash&logoColor=white)
![gum](https://img.shields.io/badge/men%C3%BAs-gum-FF5C57)
![fzf](https://img.shields.io/badge/fuzzy-fzf-2B6CB0)
![bun](https://img.shields.io/badge/runtime-bun-FBF0DF?logo=bun&logoColor=black)
![gh](https://img.shields.io/badge/CLI-github%20cli-181717?logo=github)

`zsh` · `gum` · `fzf` · `eza` · `bat` · `fd` · `bun` · `gh` · `yt-dlp`

## 📄 Licencia y privacidad

- Código de los vídeos: **MIT**.
- Los guiones y configuraciones personales están **gitignoreados** — lo que se publica es siempre el código reproducible.

## 📺 Sígueme

- ▶️ [YouTube — @Senseikatana](https://www.youtube.com/@Senseikatana)
- 🐙 [GitHub — senseikatana](https://github.com/senseikatana)

*Arigato por pasar por el Dojo* 🥋
