#!/bin/bash
# ==============================================================================
# install.sh — Setup completo: Sway + Zsh + Oh My Zsh
# Adaptado para Void Linux (xbps + runit)
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
command -v xbps-install &>/dev/null || error "Este script requer xbps (Void Linux)."

# Atalho para instalação
xi() { sudo xbps-install -y "$@"; }

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
sudo xbps-install -Syu

# ------------------------------------------------------------------------------
# Nota: Void Linux não tem AUR. Pacotes exclusivos do AUR (yay, nwg-look,
# python-pywal, ps_mem, onefetch) precisam ser compilados manualmente ou
# substituídos — veja os comentários abaixo.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 1. Pacotes do SWAY
# ------------------------------------------------------------------------------
info "Instalando pacotes do Sway..."

SWAY_PKGS=(
    # Core Sway
    sway
    swaybg
    swayidle
    swaylock

    # Waybar
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
    # cliphist — não está nos repos oficiais; compile do source se necessário:
    # https://github.com/sentriz/cliphist

    # Áudio
    pipewire
    wireplumber
    pavucontrol
    pamixer

    # Brilho
    brightnessctl

    # Rede / Bluetooth
    network-manager-applet
    blueman

    # Gestos touchpad
    libinput

    # Portal Wayland
    xdg-desktop-portal
    xdg-desktop-portal-wlr

    # Temas / cursor / GTK
    adwaita-icon-theme
    # nwg-look — não está nos repos; instale via flatpak ou compile manualmente

    # Fontes
    noto-fonts-ttf
    nerd-fonts

    # Misc utilitários de sistema
    playerctl
)

xi "${SWAY_PKGS[@]}"
success "Pacotes do Sway instalados."

# pipewire-pulse no Void é fornecido pelo próprio pacote pipewire
# Ative o serviço pipewire manualmente (ver seção de serviços abaixo)

# python-pywal — não está nos repos oficiais do Void
# Instale via pip após garantir python3:
if command -v pip3 &>/dev/null || xi python3-pip; then
    pip3 install pywal --break-system-packages 2>/dev/null || \
    pip3 install pywal || \
    warn "pywal não instalado. Rode manualmente: pip3 install pywal"
fi

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
    # onefetch — não está nos repos; instale via cargo:
    # cargo install onefetch

    # Git extras
    git
    # github-cli está disponível como "gh" no Void
    gh

    # Compilador C
    gcc

    # Disco
    util-linux
)

xi "${CLI_PKGS[@]}"
success "Ferramentas CLI instaladas."

# ps_mem — não está nos repos oficiais; instale via pip
pip3 install ps_mem --break-system-packages 2>/dev/null || \
    warn "ps_mem não instalado. Rode manualmente: pip3 install ps_mem"

# onefetch via cargo (opcional)
if command -v cargo &>/dev/null; then
    info "Instalando onefetch via cargo..."
    cargo install onefetch && success "onefetch instalado." || warn "Falha ao instalar onefetch."
else
    warn "cargo não encontrado. Instale rust/cargo e rode: cargo install onefetch"
fi

# ------------------------------------------------------------------------------
# 3. Serviços runit (Void usa runit, não systemd)
# ------------------------------------------------------------------------------
info "Ativando serviços via runit..."

enable_service() {
    local svc="$1"
    if [[ -d "/etc/sv/$svc" ]]; then
        sudo ln -sf "/etc/sv/$svc" /var/service/ 2>/dev/null && \
            success "Serviço $svc ativado." || \
            warn "Serviço $svc já estava ativo ou falhou."
    else
        warn "Serviço $svc não encontrado em /etc/sv/. Verifique se o pacote está instalado."
    fi
}

enable_service dbus
enable_service NetworkManager
enable_service bluetoothd
enable_service tlp

# Inicia NetworkManager e bluetoothd imediatamente (sem precisar reiniciar)
info "Iniciando NetworkManager..."
sudo sv start NetworkManager && success "NetworkManager iniciado." || warn "Falha ao iniciar NetworkManager."

info "Iniciando bluetoothd..."
sudo sv start bluetoothd && success "bluetoothd iniciado." || warn "Falha ao iniciar bluetoothd."

# pipewire: no Void é iniciado pelo usuário via D-Bus / autostart no Sway
# Adicione ao sway/config: exec pipewire & exec wireplumber

# ------------------------------------------------------------------------------
# 4. Oh My Zsh
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

install_omz_plugin k \
    https://github.com/supercrabtree/k

success "Plugins Oh My Zsh instalados."

# ------------------------------------------------------------------------------
# 5. Escrever ~/.zshrc
# ------------------------------------------------------------------------------
info "Escrevendo ~/.zshrc..."

ZSHRC="$HOME/.zshrc"

[[ -f "$ZSHRC" ]] && cp "$ZSHRC" "${ZSHRC}.bak.$(date +%s)" && \
    warn "Backup do .zshrc antigo salvo em ${ZSHRC}.bak.*"

cat > "$ZSHRC" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(
    git
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

# xbps (substitui pacman/yay)
alias si="sudo xbps-install -y"      # instalar
alias sr="sudo xbps-remove -Ry"      # remover
alias up="sudo xbps-install -Syu"    # atualizar tudo
alias l="xbps-query -Rs"             # buscar pacote

alias py="python3"
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

mf() {
    local file
    file=$(fd --type f | fzf --preview 'bat --style=numbers --color=always {}')
    if [[ -n "$file" ]]; then
        micro "$file"
    fi
}

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
# 6. Tornar Zsh o shell padrão
# ------------------------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"

if [[ "$SHELL" == "$ZSH_PATH" ]]; then
    warn "Zsh já é o shell padrão."
else
    info "Tornando zsh o shell padrão..."
    grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
    chsh -s "$ZSH_PATH"
    success "Shell padrão alterado para $ZSH_PATH (efetivo no próximo login)."
fi

# ------------------------------------------------------------------------------
# 7. libinput-gestures — adicionar usuário ao grupo input
# ------------------------------------------------------------------------------
# libinput-gestures não está nos repos do Void; instale do source:
# https://github.com/bulletmark/libinput-gestures
# Por ora, apenas adiciona o usuário ao grupo input:
info "Adicionando $USER ao grupo input..."
sudo usermod -aG input "$USER"
success "Usuário adicionado ao grupo input (efetivo após logout)."

if command -v libinput-gestures-setup &>/dev/null; then
    info "Escrevendo ~/.config/libinput-gestures.conf..."
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/libinput-gestures.conf" << 'GESTURES'
gesture swipe left  3 swaymsg workspace next
gesture swipe right 3 swaymsg workspace prev
GESTURES
    libinput-gestures-setup autostart start || true
    success "libinput-gestures configurado."
fi

# ------------------------------------------------------------------------------
# 8. Dotfiles — copiar sway/ e waybar/ do repo para ~/.config/
# ------------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

copy_dotfiles() {
    local src="$REPO_DIR/$1"
    local dest="$HOME/.config/$1"

    if [[ ! -d "$src" ]]; then
        warn "Pasta $1/ não encontrada no repo ($src), pulando."
        return
    fi

    info "Copiando $1/ → $dest ..."

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
# 9. Limite de bateria via TLP
# ------------------------------------------------------------------------------
info "Configurando limite de carga da bateria..."

xi tlp

TLP_CONF="/etc/tlp.conf"

[[ -f "$TLP_CONF" ]] && sudo cp "$TLP_CONF" "${TLP_CONF}.bak.$(date +%s)" && \
    warn "Backup de $TLP_CONF salvo."

sudo tee -a "$TLP_CONF" > /dev/null << 'TLPCONF'

# ── Charge thresholds (adicionado pelo install.sh) ────────────────────────────
START_CHARGE_THRESH_BAT0=79
STOP_CHARGE_THRESH_BAT0=80
START_CHARGE_THRESH_BAT1=79
STOP_CHARGE_THRESH_BAT1=80
TLPCONF

# No Void, TLP é gerenciado pelo runit (já ativado acima)
# Aplica thresholds imediatamente se o kernel suportar
if ls /sys/class/power_supply/BAT*/charge_control_start_threshold &>/dev/null 2>&1; then
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
echo -e "     • Grupo input ter efeito"
echo -e "  2. Rode ${YELLOW}wal -i ~/Pictures/wallBingo.png${NC} para gerar cores do pywal"
echo -e "  3. Reinicie o Sway: ${YELLOW}swaymsg reload${NC}"
echo -e "  4. Autentique o GitHub CLI: ${YELLOW}gh auth login${NC}"
echo -e "  5. Verifique o limite de bateria: ${YELLOW}sudo tlp-stat -b${NC}"
echo ""
echo -e "  ${YELLOW}Pacotes sem equivalente nos repos oficiais do Void:${NC}"
echo -e "  • cliphist    → https://github.com/sentriz/cliphist"
echo -e "  • nwg-look    → flatpak install nwg-look  (ou compile)"
echo -e "  • onefetch    → cargo install onefetch"
echo -e "  • ps_mem      → pip3 install ps_mem"
echo -e "  • libinput-gestures → https://github.com/bulletmark/libinput-gestures"
echo ""
