#!/bin/bash
# ==============================================================================
# install.sh — Setup completo: Sway + Zsh + Oh My Zsh
# Testado em Arch Linux / Manjaro
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERRO]${NC} $*"; exit 1; }

# ------------------------------------------------------------------------------
# 0. Verificações iniciais
# ------------------------------------------------------------------------------
[[ $EUID -eq 0 ]] && error "Não rode como root. O script usa sudo quando necessário."
command -v pacman &>/dev/null || error "Este script requer pacman (Arch Linux / Manjaro)."

# ------------------------------------------------------------------------------
# 0.1 Configuração do Git
# ------------------------------------------------------------------------------
echo -e "${CYAN}Configuração do Git${NC}"
echo -e "Deixe em branco para pular.\n"

read -rp "  Nome (ex: Fulano): " GIT_NAME
read -rp "  Email (ex: fulano@email.com): " GIT_EMAIL

if [[ -n "$GIT_NAME" ]]; then
    git config --global user.name "$GIT_NAME"
    success "git user.name = \"$GIT_NAME\""
fi
if [[ -n "$GIT_EMAIL" ]]; then
    git config --global user.email "$GIT_EMAIL"
    success "git user.email = \"$GIT_EMAIL\""
fi
echo ""

info "Atualizando sistema..."
sudo pacman -Syu --noconfirm

# Instala yay se não estiver presente
if ! command -v yay &>/dev/null; then
    info "Instalando yay (AUR helper)..."
    sudo pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
    success "yay instalado."
fi

# ------------------------------------------------------------------------------
# 1. Pacotes do SWAY (lidos do seu config)
# ------------------------------------------------------------------------------
info "Instalando pacotes do Sway..."

SWAY_PKGS=(
    # Core Sway
    sway
    swaybg
    swayidle
    swaylock
    swaynag

    # Waybar (statusbar)
    waybar

    # Terminal
    foot

    # Launcher / menus
    rofi
    fuzzel

    # Notificações
    mako

    # Screenshot
    grim
    slurp

    # Clipboard
    wl-clipboard
    cliphist

    # Áudio
    pipewire
    pipewire-pulse
    wireplumber
    pavucontrol
    pamixer

    # Brilho
    brightnessctl

    # Rede / Bluetooth
    network-manager-applet
    blueman

    # Gestos touchpad
    libinput-gestures

    # Portal Wayland
    xdg-desktop-portal-wlr
    xdg-desktop-portal

    # Temas / cursor / GTK
    xsettingsd
    adwaita-icon-theme
    nwg-look

    # Fontes
    noto-fonts
    ttf-nerd-fonts-symbols

    # Pywal (colors-sway)
    python-pywal

    # Misc utilitários de sistema
    playerctl
)

yay -S --noconfirm --needed "${SWAY_PKGS[@]}"
success "Pacotes do Sway instalados."

# ------------------------------------------------------------------------------
# 2. Pacotes da linha de comando / Zsh
# ------------------------------------------------------------------------------
info "Instalando ferramentas de linha de comando..."

CLI_PKGS=(
    # Shell
    zsh

    # Editor
    neovim
    micro

    # File manager
    yazi

    # Listagem moderna
    eza

    # Busca
    fd
    fzf
    bat

    # Tmux
    tmux

    # Fetch
    fastfetch
    onefetch

    # Git extras
    git
    github-cli

    # Docker (plugin zsh)
    docker
    docker-compose

    # Compilador C (função com())
    gcc

    # Memória
    ps_mem

    # Disco (já usa df nativo, mas útil)
    util-linux
)

yay -S --noconfirm --needed "${CLI_PKGS[@]}"
success "Ferramentas CLI instaladas."

# ------------------------------------------------------------------------------
# 3. Oh My Zsh
# ------------------------------------------------------------------------------
info "Instalando Oh My Zsh..."

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    warn "Oh My Zsh já está instalado, pulando."
else
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "Oh My Zsh instalado."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Plugins externos
install_omz_plugin() {
    local name="$1" repo="$2"
    local dest="$ZSH_CUSTOM/plugins/$name"
    if [[ -d "$dest" ]]; then
        warn "Plugin $name já existe, atualizando..."
        git -C "$dest" pull --quiet
    else
        info "Clonando plugin $name..."
        git clone --depth=1 "$repo" "$dest"
    fi
}

install_omz_plugin zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions

install_omz_plugin zsh-completions \
    https://github.com/zsh-users/zsh-completions

install_omz_plugin zsh-z \
    https://github.com/agkozak/zsh-z

# Plugin "k" (ls estendido para git)
install_omz_plugin k \
    https://github.com/supercrabtree/k

success "Plugins Oh My Zsh instalados."

# ------------------------------------------------------------------------------
# 4. Escrever ~/.zshrc
# ------------------------------------------------------------------------------
info "Escrevendo ~/.zshrc..."

ZSHRC="$HOME/.zshrc"

# Faz backup se já existir
[[ -f "$ZSHRC" ]] && cp "$ZSHRC" "${ZSHRC}.bak.$(date +%s)" && \
    warn "Backup do .zshrc antigo salvo em ${ZSHRC}.bak.*"

cat > "$ZSHRC" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(
    git
    docker
    zsh-autosuggestions
    zsh-completions
    k
    zsh-z
)

source $ZSH/oh-my-zsh.sh

zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

bindkey -s '^f' "tmux-sessionizer\n"

# ── Aliases ───────────────────────────────────────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first'
alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias gitp='git push -f origin'
alias v='nvim'
alias m='micro'
alias c='clear'
alias q='exit'
alias w='micro'
alias f='yazi'
alias fs="fastfetch"
alias of="onefetch"
alias t="tmux"
alias theme="nwg-look"
alias si="sudo pacman -S"
alias g="yay -S"
alias l="yay -Ss"
alias up="yay -Syu"
alias py="python3"
alias su="sudo pacman -Syu"
alias disk='df -h | awk "NR==1 || (\$1 ~ /nvme0n1/ && \$6 != \"\")"'
alias mem='sudo ps_mem | tail -8'

# ── Funções ───────────────────────────────────────────────────────────────────
gpush() {
    git add .
    git commit -m "$*"
    git push
}

com() {
    gcc "$1.c" -o "$1"
}

# Abrir arquivos com fzf + preview
mf() {
    local file
    file=$(fd --type f | fzf --preview 'bat --style=numbers --color=always {}')
    if [[ -n "$file" ]]; then
        micro "$file"
    fi
}

# Navegar entre diretórios com fzf
ff() {
    local dir
    dir=$(fd --type d --hidden --exclude .git | fzf)
    if [[ -n "$dir" ]]; then
        cd "$dir"
    fi
}

export PATH="$HOME/.local/bin:$PATH"
EOF

success ".zshrc escrito."

# ------------------------------------------------------------------------------
# 5. Tornar Zsh o shell padrão
# ------------------------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"

if [[ "$SHELL" == "$ZSH_PATH" ]]; then
    warn "Zsh já é o shell padrão."
else
    info "Tornando zsh o shell padrão..."
    # Garante que zsh está em /etc/shells
    grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
    chsh -s "$ZSH_PATH"
    success "Shell padrão alterado para $ZSH_PATH (efetivo no próximo login)."
fi

# ------------------------------------------------------------------------------
# 6. Docker — habilitar serviço e adicionar usuário ao grupo
# ------------------------------------------------------------------------------
if command -v docker &>/dev/null; then
    info "Habilitando Docker..."
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    warn "Faça logout/login para que as permissões do Docker tenham efeito."
fi

# ------------------------------------------------------------------------------
# 7. libinput-gestures — adicionar usuário ao grupo input
# ------------------------------------------------------------------------------
if command -v libinput-gestures-setup &>/dev/null; then
    info "Configurando libinput-gestures..."
    sudo gpasswd -a "$USER" input

    info "Escrevendo ~/.config/libinput-gestures.conf..."
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/libinput-gestures.conf" << 'GESTURES'
gesture swipe left  3 swaymsg workspace next
gesture swipe right 3 swaymsg workspace prev
GESTURES
    success "libinput-gestures.conf escrito."

    libinput-gestures-setup autostart start || true
fi

# ------------------------------------------------------------------------------
# 8. Dotfiles — copiar sway/ e waybar/ do repo para ~/.config/
# ------------------------------------------------------------------------------
# O script assume que está na raiz do repo (onde ficam sway/ e waybar/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

copy_dotfiles() {
    local src="$REPO_DIR/$1"
    local dest="$HOME/.config/$1"

    if [[ ! -d "$src" ]]; then
        warn "Pasta $1/ não encontrada no repo ($src), pulando."
        return
    fi

    info "Copiando $1/ → $dest ..."

    # Backup se já existir
    if [[ -d "$dest" ]]; then
        local backup="${dest}.bak.$(date +%s)"
        cp -r "$dest" "$backup"
        warn "Backup de $dest salvo em $backup"
    fi

    mkdir -p "$dest"
    cp -r "$src/." "$dest/"
    success "$1/ copiado para $dest"
}

copy_dotfiles sway
copy_dotfiles waybar
copy_dotfiles rofi

# ------------------------------------------------------------------------------
# 9. Limite de bateria via TLP (charge thresholds)
# ------------------------------------------------------------------------------
info "Configurando limite de carga da bateria..."

yay -S --noconfirm --needed tlp

# Detecta suporte nativo a thresholds no kernel
BATTERY_DRIVER=""
if ls /sys/class/power_supply/BAT*/charge_control_start_threshold &>/dev/null 2>&1; then
    BATTERY_DRIVER="native"
fi

TLP_CONF="/etc/tlp.conf"

# Faz backup do tlp.conf se já existir
[[ -f "$TLP_CONF" ]] && sudo cp "$TLP_CONF" "${TLP_CONF}.bak.$(date +%s)" && \
    warn "Backup de $TLP_CONF salvo."

# Aplica os thresholds via tlp.conf
sudo tee -a "$TLP_CONF" > /dev/null << 'TLPCONF'

# ── Charge thresholds (adicionado pelo install.sh) ────────────────────────────
# Começa a carregar em 79%, para de carregar em 80%
START_CHARGE_THRESH_BAT0=79
STOP_CHARGE_THRESH_BAT0=80
START_CHARGE_THRESH_BAT1=79
STOP_CHARGE_THRESH_BAT1=80
TLPCONF

sudo systemctl enable --now tlp
sudo tlp start

# Aplica os thresholds imediatamente via sysfs (sem precisar reiniciar)
if [[ "$BATTERY_DRIVER" == "native" ]]; then
    for bat in /sys/class/power_supply/BAT*; do
        echo 79 | sudo tee "$bat/charge_control_start_threshold" > /dev/null
        echo 80 | sudo tee "$bat/charge_control_stop_threshold"  > /dev/null
    done
    success "Thresholds aplicados imediatamente via sysfs."
else
    warn "Thresholds não aplicados via sysfs. Terão efeito após reiniciar."
fi

success "Limite de bateria configurado: carrega de 79% até 80%."

# ------------------------------------------------------------------------------
# Resumo
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Instalação concluída!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Próximos passos:${NC}"
echo -e "  1. Faça ${YELLOW}logout e login${NC} para:"
echo -e "     • Zsh virar o shell padrão"
echo -e "     • Grupos docker/input terem efeito"
echo -e "  2. Rode ${YELLOW}wal -i ~/Pictures/wallBingo.png${NC} para gerar cores do pywal"
echo -e "  3. Reinicie o Sway: ${YELLOW}swaymsg reload${NC}"
echo -e "  4. Autentique o GitHub CLI: ${YELLOW}gh auth login${NC}"
echo -e "  5. Verifique o limite de bateria: ${YELLOW}sudo tlp-stat -b${NC}"
echo ""
