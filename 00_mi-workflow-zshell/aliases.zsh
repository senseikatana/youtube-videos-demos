#!/usr/bin/env zsh
# ==============================================
# 📋 ALIASES - Todos los aliases del Dojo
# ==============================================

# ==============================================
# 🌐 CREATE WEB
# ==============================================
alias useWeb='on_create-web'

# ==============================================
# 🐳 DOCKER
# ==============================================
alias useDocker='on_docker'

# ==============================================
# 📥 DOWNLOAD
# ==============================================
alias useDownload='on_download'

# ==============================================
# 🗂️ FILES - Commands
# ==============================================
alias cp='cp -iv'
alias df='duf'
alias du='dust'
alias find='fd'
alias grep='rg'
alias la='eza --color=always --icons --group-directories-first -lha'
alias ls='eza --color=always --icons --group-directories-first -lh'
alias lsa='eza --color=always --icons -a'
alias lsf='eza --color=always --icons --git -l'
alias lsg='eza --color=always --icons --git --group-directories-first -lh'
alias mkd='mkdir -pv'
alias mv='mv -iv'
alias ncdu='gdu'
alias open='xdg-open'
alias rm='rm -i'

# ==============================================
# 🗂️ FILES - Calling functions
# ==============================================
alias chx='on_chx'
alias chxr='on_chxr'
alias extract='on_extract'
alias schx='on_schx'
alias useFiles='on_files'
alias verifyhash='on_verifyhash'

# ==============================================
# 🔀 GIT
# ==============================================
alias useGit='on_git'
alias useGitInit='git init; on_initdocs; gh_repo_new'
alias log='on_git log'
alias status='on_git status'
alias push='git push'
alias cou='git switch'

# ==============================================
# 🐙 GITHUB CLI
# ==============================================
alias useGh='on_gh'

# ==============================================
# 🦥 LAZY TOOLS
# ==============================================
alias useLazy='on_lazy'

# ==============================================
# 🧭 NAVIGATION
# ==============================================
alias useGo='on_go'
alias useConfZsh='fresh ~/.zshrc'
alias lsproj='on_lsproj'
alias yz='on_yzcd'

# ==============================================
# 🧹 NODE CLEANER
# ==============================================
alias useNmk='on_nmk'

# ==============================================
# 📦 PACKAGE MANAGERS
# ==============================================
alias usePm='on_pm'
alias usePmBun='on_pm_bun'
alias usePmNpm='on_pm_npm'
alias usePmPnpm='on_pm_pnpm'
alias usePmYarn='on_pm_yarn'

# ==============================================
# 📦 PKG - Paquetes y actualizaciones
# ==============================================
alias usePkg='on_pkg'
alias usePkgApt='on_pkg_apt'

# ==============================================
# ⚙️ SYSTEM - Calling functions
# ==============================================
alias useCleanup='on_cleanup'
alias useInfoSys='on_info'
alias useKillport='on_killport'
alias usePassgen='on_passgen'

# ==============================================
# 🌍 SYSTEM - Commands
# ==============================================
alias cls='clear'
alias h='history'
alias myip='curl ifconfig.me'
alias ports='netstat -tulanp'
alias prc='htop'
alias psg='ps aux | grep -i'
alias weather='curl wttr.in'

# ==============================================
# ⚙️ SYSTEMD
# ==============================================
alias useSysd='on_sysd'

# ==============================================
# 💻 VIRTUAL MACHINES
# ==============================================
alias useVM='on_virtmanager'

# ==============================================
# 🧩 ZINIT
# ==============================================
alias useZinit='on_zinit'

# ==============================================
# 🔄 RELOAD
# ==============================================
alias reload-fs='source ~/.zsh/functions.zsh && echo "🔄 Funciones recargadas"'
alias reload-zs='source ~/.zshrc && echo "🔄 ZSH recargado"'
alias reload='reload-zs && reload-fs && echo "🔄 Configuración completa recargada"'
