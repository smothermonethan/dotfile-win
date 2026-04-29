#!/usr/bin/env bash
# =============================================================================
# setup-dotfiles.sh
# Christian Lempa dotfiles + xcad color theme installer
# Targets: Ubuntu (KASM hackbox container / any Ubuntu Focal+)
# Usage: bash setup-dotfiles.sh
# =============================================================================

set -euo pipefail

# ── Colors for script output ──────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}${BOLD}[ERR]${RESET}   $*" >&2; exit 1; }

echo -e "\n${BOLD}${CYAN}"
echo "  ██╗  ██╗ ██████╗ █████╗ ██████╗      ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
echo "  ╚██╗██╔╝██╔════╝██╔══██╗██╔══██╗    ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
echo "   ╚███╔╝ ██║     ███████║██║  ██║    ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
echo "   ██╔██╗ ██║     ██╔══██║██║  ██║    ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
echo "  ██╔╝ ██╗╚██████╗██║  ██║██████╔╝    ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
echo "  ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝     ╚═════╝  ╚═════╝   ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
echo -e "${RESET}\n  Christian Lempa dotfiles + xcad color theme\n"

# ── Detect if root or normal user ─────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  SUDO=""
  HOME_DIR="/root"
else
  SUDO="sudo"
  HOME_DIR="$HOME"
fi

# ── Helper: run apt without interactive prompts ───────────────────────────────
apt_install() {
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

# =============================================================================
# STEP 1 — System update & core dependencies
# =============================================================================
info "Updating package lists..."
$SUDO apt-get update -qq

info "Installing core dependencies..."
apt_install \
  curl wget git unzip zip \
  zsh \
  neofetch \
  fzf bat ripgrep fd-find htop tree \
  nmap netcat dnsutils whois \
  openvpn \
  direnv \
  fontconfig \
  terminator \
  xclip xsel

success "Core packages installed"

# =============================================================================
# STEP 2 — Hack Nerd Font v3
# =============================================================================
info "Installing Hack Nerd Font v3..."
FONT_DIR="/usr/local/share/fonts/HackNerdFont"
if [[ ! -d "$FONT_DIR" ]]; then
  $SUDO mkdir -p "$FONT_DIR"
  wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Hack.zip -O /tmp/Hack.zip
  $SUDO unzip -q /tmp/Hack.zip -d "$FONT_DIR"
  rm /tmp/Hack.zip
  $SUDO fc-cache -fv > /dev/null 2>&1
  success "Hack Nerd Font installed"
else
  warn "Hack Nerd Font already installed, skipping"
fi

# =============================================================================
# STEP 3 — Starship prompt
# =============================================================================
info "Installing Starship..."
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
  success "Starship installed"
else
  warn "Starship already installed, skipping"
fi

# =============================================================================
# STEP 4 — eza (modern ls)
# =============================================================================
info "Installing eza..."
if ! command -v eza &>/dev/null; then
  wget -q https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz \
    -O /tmp/eza.tar.gz
  tar -xzf /tmp/eza.tar.gz -C /tmp
  $SUDO mv /tmp/eza /usr/local/bin/eza
  rm -f /tmp/eza.tar.gz
  success "eza installed"
else
  warn "eza already installed, skipping"
fi

# =============================================================================
# STEP 5 — zoxide (smarter cd)
# =============================================================================
info "Installing zoxide..."
if ! command -v zoxide &>/dev/null; then
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  success "zoxide installed"
else
  warn "zoxide already installed, skipping"
fi

# =============================================================================
# STEP 6 — oh-my-zsh + plugins
# =============================================================================
info "Installing Oh My Zsh..."
if [[ ! -d "$HOME_DIR/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed"
else
  warn "Oh My Zsh already installed, skipping"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME_DIR/.oh-my-zsh/custom}"

info "Installing zsh-autosuggestions..."
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

info "Installing zsh-syntax-highlighting..."
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

info "Installing zsh-completions..."
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-completions \
    "$ZSH_CUSTOM/plugins/zsh-completions"
fi

success "Zsh plugins installed"

# =============================================================================
# STEP 7 — helix editor
# =============================================================================
info "Installing Helix editor..."
if ! command -v hx &>/dev/null; then
  $SUDO add-apt-repository -y ppa:maveonair/helix-editor > /dev/null 2>&1 || true
  $SUDO apt-get update -qq
  apt_install helix || warn "Helix not available via PPA on this Ubuntu version, skipping"
fi

# =============================================================================
# STEP 8 — Write dotfiles
# =============================================================================
info "Writing dotfiles..."

# ── Directory structure ───────────────────────────────────────────────────────
mkdir -p \
  "$HOME_DIR/.zsh" \
  "$HOME_DIR/.config/starship" \
  "$HOME_DIR/.config/neofetch" \
  "$HOME_DIR/.config/helix/themes" \
  "$HOME_DIR/.config/terminator" \
  "$HOME_DIR/.warp/themes" \
  "$HOME_DIR/.warp/workflows"

# ── .zshenv ───────────────────────────────────────────────────────────────────
cat > "$HOME_DIR/.zshenv" << 'EOF'
# Added locations to path variable
export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin

# NVM directory
export NVM_DIR="$HOME/.nvm"

export EDITOR=vim
export KUBE_EDITOR=vim
EOF

# ── .zshrc ────────────────────────────────────────────────────────────────────
cat > "$HOME_DIR/.zshrc" << 'EOF'
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""  # Using Starship instead

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  fzf
  direnv
)

source $ZSH/oh-my-zsh.sh

# Source extras
[[ -f ~/.zsh/aliases.zsh   ]] && source ~/.zsh/aliases.zsh
[[ -f ~/.zsh/functions.zsh ]] && source ~/.zsh/functions.zsh

# Load Starship
eval "$(starship init zsh)"

# Load Direnv
eval "$(direnv hook zsh)"

# Load zoxide
eval "$(zoxide init zsh)"

# PATH additions
export PATH="$HOME/.local/bin:$PATH"

# Fixes SSH Remote issues with ghostty/kasm
if [[ -n "$SSH_CONNECTION" ]]; then
    export TERM=xterm-256color
fi

# neofetch on new shell (comment out if you don't want it)
neofetch
EOF

# ── .zsh/aliases.zsh ─────────────────────────────────────────────────────────
cat > "$HOME_DIR/.zsh/aliases.zsh" << 'EOF'
# Navigation
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first -l"
alias la="eza --icons --group-directories-first -la"
alias lt="eza --icons --group-directories-first --tree"

# Tools
alias cat="batcat"
alias fd="fdfind"
alias grep="rg"

# Git
alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline --graph"

# System
alias update="sudo apt-get update && sudo apt-get upgrade -y"
alias ports="ss -tulnp"
alias myip="curl -s https://ipinfo.io/ip"

# HTB / Hacking
alias vpn="sudo openvpn"
EOF

# ── .zsh/functions.zsh ───────────────────────────────────────────────────────
cat > "$HOME_DIR/.zsh/functions.zsh" << 'EOF'
# Colormap — show all 256 terminal colors
function colormap() {
  for i in {0..255}; do
    print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}
  done
}

# mkcd — make dir and cd into it
function mkcd() {
  mkdir -p "$1" && cd "$1"
}

# extract — extract any archive
function extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1"   ;;
      *.tar.gz)  tar xzf "$1"   ;;
      *.tar.xz)  tar xJf "$1"   ;;
      *.zip)     unzip "$1"     ;;
      *.gz)      gunzip "$1"    ;;
      *.7z)      7z x "$1"      ;;
      *)         echo "Unknown archive format: $1" ;;
    esac
  else
    echo "'$1' is not a file"
  fi
}
EOF

# ── Starship config ───────────────────────────────────────────────────────────
cat > "$HOME_DIR/.config/starship.toml" << 'EOF'
# ~/.config/starship.toml

add_newline = false
command_timeout = 100
format = """
$os$username$hostname$kubernetes$directory$git_branch$git_status
 
"""

# Drop ugly default prompt characters
[character]
success_symbol = ''
error_symbol = ''

[os]
format = '[$symbol](bold white) '
disabled = false

[os.symbols]
Windows = ' '
Arch = '󰣇'
Ubuntu = ''
Macos = '󰀵'

[username]
style_user = 'white bold'
style_root = 'black bold'
format = '[$user]($style) '
disabled = false
show_always = true

[hostname]
ssh_only = false
format = 'on [$hostname](bold yellow) '
disabled = false

[directory]
truncation_length = 1
truncation_symbol = '…/'
home_symbol = '󰋜 ~'
read_only_style = '197'
read_only = '  '
format = 'at [$path]($style)[$read_only]($read_only_style) '

[git_branch]
symbol = ' '
format = 'via [$symbol$branch]($style)'
truncation_symbol = '…/'
style = 'bold green'

[git_status]
format = '([ \( $all_status$ahead_behind\)]($style) )'
style = 'bold green'
conflicted = '[ confliced=${count}](red) '
up_to_date = '[󰘽 up-to-date](green) '
untracked = '[󰋗 untracked=${count}](red) '
ahead = ' ahead=${count}'
diverged = ' ahead=${ahead_count}  behind=${behind_count}'
behind = ' behind=${count}'
stashed = '[ stashed=${count}](green) '
modified = '[󰛿 modified=${count}](yellow) '
staged = '[󰐗 staged=${count}](green) '
renamed = '[󱍸 renamed=${count}](yellow) '
deleted = '[󰍶 deleted=${count}](red) '

[kubernetes]
format = 'via [󱃾 $context\($namespace\)](bold purple) '
disabled = false

[vagrant]
disabled = true

[docker_context]
disabled = true

[helm]
disabled = true

[python]
disabled = false

[nodejs]
disabled = true

[ruby]
disabled = true

[terraform]
disabled = true
EOF

# ── Neofetch config ───────────────────────────────────────────────────────────
cat > "$HOME_DIR/.config/neofetch/config.conf" << 'EOF'
print_info() {
    info title
    info underline
    info "OS"           distro
    info "Host"         model
    info "Kernel"       kernel
    info "Uptime"       uptime
    info "Packages"     packages
    info "Shell"        shell
    info "Resolution"   resolution
    info "DE"           de
    info "WM"           wm
    info "WM Theme"     wm_theme
    info "Theme"        theme
    info "Icons"        icons
    info "Terminal"     term
    info "Terminal Font" term_font
    info "CPU"          cpu
    info "GPU"          gpu
    info "Memory"       memory
}

# Neofetch options
image_backend="ascii"
ascii_distro="auto"
ascii_colors=(4 5 6 7 1 2 3)
colors=(4 6 1 8 8 6)
bold="on"
underline_enabled="on"
underline_char="-"
EOF

# ── Helix config ──────────────────────────────────────────────────────────────
cat > "$HOME_DIR/.config/helix/config.toml" << 'EOF'
theme = "christian"

[editor]
line-number = "absolute"
mouse = true

[editor.statusline]
left = ["mode", "spinner"]
center = ["file-name"]
right = ["diagnostics", "selections", "position", "file-encoding", "file-line-ending", "file-type"]
separator = "│"

[keys.normal]
"del" = "delete_selection"
"C-c" = ":clipboard-yank"

[editor.indent-guides]
render = false
character = ""
EOF

# ── Helix theme (christian) ───────────────────────────────────────────────────
cat > "$HOME_DIR/.config/helix/themes/christian.toml" << 'EOF'
# xcad color scheme for Helix
"ui.background"           = { bg = "#1A1A1A" }
"ui.text"                 = { fg = "#F1F1F1" }
"ui.cursor"               = { fg = "#1A1A1A", bg = "#FFFFFF" }
"ui.cursor.primary"       = { fg = "#1A1A1A", bg = "#28B9FF" }
"ui.selection"            = { bg = "#2B4FFF" }
"ui.linenr"               = { fg = "#666666" }
"ui.linenr.selected"      = { fg = "#F1F1F1", modifiers = ["bold"] }
"ui.statusline"           = { fg = "#F1F1F1", bg = "#121212" }
"ui.statusline.inactive"  = { fg = "#666666", bg = "#121212" }
"ui.popup"                = { bg = "#121212" }
"ui.menu"                 = { bg = "#121212" }
"ui.menu.selected"        = { fg = "#1A1A1A", bg = "#28B9FF" }
"ui.help"                 = { bg = "#121212", fg = "#F1F1F1" }
"ui.virtual.whitespace"   = "#666666"
"ui.virtual.indent-guide" = "#666666"
"comment"                 = { fg = "#666666", modifiers = ["italic"] }
"string"                  = { fg = "#28B9FF" }
"constant"                = { fg = "#A52AFF" }
"constant.numeric"        = { fg = "#2B4FFF" }
"type"                    = { fg = "#7129FF" }
"type.builtin"            = { fg = "#905AFF" }
"function"                = { fg = "#28B9FF" }
"function.builtin"        = { fg = "#5AC8FF" }
"keyword"                 = { fg = "#A52AFF", modifiers = ["bold"] }
"keyword.control"         = { fg = "#BA5AFF" }
"operator"                = { fg = "#2883FF" }
"variable"                = { fg = "#F1F1F1" }
"variable.builtin"        = { fg = "#5EA2FF" }
"namespace"               = { fg = "#3D2AFF" }
"tag"                     = { fg = "#2B4FFF" }
"attribute"               = { fg = "#28B9FF" }
"diagnostic.error"        = { underline = { color = "#A52AFF", style = "curl" } }
"diagnostic.warning"      = { underline = { color = "#3D2AFF", style = "curl" } }
"diagnostic.info"         = { underline = { color = "#2883FF", style = "curl" } }
"markup.heading"          = { fg = "#A52AFF", modifiers = ["bold"] }
"markup.bold"             = { modifiers = ["bold"] }
"markup.italic"           = { modifiers = ["italic"] }
"markup.link.url"         = { fg = "#28B9FF", modifiers = ["underlined"] }
"markup.raw"              = { fg = "#28B9FF" }
"diff.plus"               = { fg = "#7129FF" }
"diff.minus"              = { fg = "#A52AFF" }
"diff.delta"              = { fg = "#3D2AFF" }
EOF

# ── Terminator config (xcad colors) ──────────────────────────────────────────
mkdir -p "$HOME_DIR/.config/terminator"
cat > "$HOME_DIR/.config/terminator/config" << 'EOF'
[global_config]
  use_system_font = False
  title_hide_sizetext = True

[keybindings]

[profiles]
  [[default]]
    use_system_font = False
    font = Hack Nerd Font Mono 14
    background_color  = "#1a1a1a"
    foreground_color  = "#f1f1f1"
    cursor_color      = "#ffffff"
    # palette: black red green yellow blue magenta cyan white (normal then bright)
    palette = "#121212:#a52aff:#7129ff:#3d2aff:#2b4fff:#2883ff:#28b9ff:#f1f1f1:#666666:#ba5aff:#905aff:#685aff:#5c78ff:#5ea2ff:#5ac8ff:#ffffff"
    background_darkness = 0.95
    background_type = transparent
    scrollback_lines = 5000
    show_titlebar = False
    copy_on_selection = True

[layouts]
  [[default]]
    [[[window0]]]
      type = Window
      parent = ""
    [[[child1]]]
      type = Terminal
      parent = window0
      profile = default

[plugins]
EOF

# ── Warp theme (xcad2k-dark) ──────────────────────────────────────────────────
cat > "$HOME_DIR/.warp/themes/xcad2k-dark.yml" << 'EOF'
---
accent: '#28b9ff'
background: '#1a1a1a'
details: darker
foreground: '#f1f1f1'
# Tab bar — the 6 colors shown when you right-click a tab to assign a color.
# These are permanent and saved per-tab in your session.
tab_bar:
  background: '#121212'
  tab_colors:
    - '#080e6d'
    - '#14a8d7'
    - '#0d4f10'
    - '#142fd7'
    - '#a711a6'
    - '#a70bf9'
terminal_colors:
  bright:
    black:   '#666666'
    blue:    '#5c78ff'
    cyan:    '#5ac8ff'
    green:   '#905aff'
    magenta: '#5ea2ff'
    red:     '#ba5aff'
    white:   '#ffffff'
    yellow:  '#685aff'
  normal:
    black:   '#121212'
    blue:    '#2b4fff'
    cyan:    '#28b9ff'
    green:   '#7129ff'
    magenta: '#2883ff'
    red:     '#a52aff'
    white:   '#f1f1f1'
    yellow:  '#3d2aff'
EOF

# ── Warp keybindings ─────────────────────────────────────────────────────────
cat > "$HOME_DIR/.warp/keybindings.yaml" << 'EOF'
---
"editor_view:add_cursor_above": alt-cmd-up
EOF

# ── Warp workflows (from Christian Lempa dotfiles) ────────────────────────────
cat > "$HOME_DIR/.warp/workflows/create-certificate-private-key.yml" << 'EOF'
---
name: Create Certificate Private Key
command: openssl genrsa -out {{name}}.key {{bits}}
description: Generate a new RSA private key
arguments:
  - name: name
    description: Name of the key file (without extension)
    default_value: server
  - name: bits
    description: Key size in bits
    default_value: "4096"
tags:
  - openssl
  - certificate
  - security
EOF

cat > "$HOME_DIR/.warp/workflows/create-certificate-signing-request.yml" << 'EOF'
---
name: Create Certificate Signing Request (CSR)
command: openssl req -new -key {{key}} -out {{name}}.csr
description: Generate a Certificate Signing Request from an existing private key
arguments:
  - name: key
    description: Path to the private key file
    default_value: server.key
  - name: name
    description: Name of the CSR file (without extension)
    default_value: server
tags:
  - openssl
  - certificate
  - security
EOF

cat > "$HOME_DIR/.warp/workflows/switch-to-a-different-namespace.yml" << 'EOF'
---
name: Switch Kubernetes Namespace
command: kubectl config set-context --current --namespace={{namespace}}
description: Switch to a different Kubernetes namespace in the current context
arguments:
  - name: namespace
    description: Target namespace
    default_value: default
tags:
  - kubernetes
  - kubectl
EOF

# ── .hushlogin (suppress login banner) ───────────────────────────────────────
touch "$HOME_DIR/.hushlogin"

success "All dotfiles written"

# =============================================================================
# STEP 9 — .bashrc patches (xcad aliases + tools) for bash users / KASM
# =============================================================================
info "Patching .bashrc with xcad aliases and tool hooks..."

BASHRC="$HOME_DIR/.bashrc"

patch_bashrc() {
  local marker="$1"
  local block="$2"
  if ! grep -qF "$marker" "$BASHRC" 2>/dev/null; then
    echo -e "\n$block" >> "$BASHRC"
    success "Patched .bashrc: $marker"
  else
    warn ".bashrc already has: $marker"
  fi
}

patch_bashrc "# xcad aliases" \
'# xcad aliases
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first -l"
alias la="eza --icons --group-directories-first -la"
alias lt="eza --icons --group-directories-first --tree"
alias cat="batcat"
alias fd="fdfind"
alias grep="rg"
alias g="git"
alias gs="git status"
alias update="sudo apt-get update && sudo apt-get upgrade -y"
alias ports="ss -tulnp"
alias myip="curl -s https://ipinfo.io/ip"'

patch_bashrc "starship init bash" \
'# Starship prompt
eval "$(starship init bash)"'

patch_bashrc "zoxide init bash" \
'# zoxide (smarter cd)
export PATH="$HOME/.local/bin:$PATH"
eval "$(zoxide init bash)"'

patch_bashrc "direnv hook bash" \
'# direnv
eval "$(direnv hook bash)"'

patch_bashrc "neofetch" \
'# Show system info on shell start
neofetch'

# =============================================================================
# STEP 10 — Set default shell to zsh
# =============================================================================
info "Setting default shell to zsh..."
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  if [[ $EUID -eq 0 ]]; then
    chsh -s "$ZSH_PATH" root
  else
    $SUDO chsh -s "$ZSH_PATH" "$USER"
  fi
  success "Default shell set to zsh"
else
  warn "zsh is already the default shell"
fi

# =============================================================================
# STEP 11 — XFCE/GTK dark theme (if running in a desktop environment)
# =============================================================================
if command -v xfconf-query &>/dev/null; then
  info "Applying XFCE dark theme settings..."

  # Install Numix Dark if available
  $SUDO apt-get install -y numix-gtk-theme numix-icon-theme 2>/dev/null || true

  xfconf-query -c xsettings -p /Net/ThemeName          -s "Numix-Dark" 2>/dev/null || true
  xfconf-query -c xsettings -p /Net/IconThemeName       -s "Numix"      2>/dev/null || true
  xfconf-query -c xfce4-terminal -p /ColorForeground    -s "#F1F1F1"    2>/dev/null || true
  xfconf-query -c xfce4-terminal -p /ColorBackground    -s "#1A1A1A"    2>/dev/null || true
  xfconf-query -c xfce4-terminal -p /FontName           -s "Hack Nerd Font Mono 14" 2>/dev/null || true
  success "XFCE theme applied"
else
  warn "XFCE not detected, skipping GTK theme"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  ✓  Setup complete!${RESET}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${CYAN}Next steps:${RESET}"
echo -e "  1. Start a new shell:   ${BOLD}zsh${RESET}  or  ${BOLD}bash${RESET}"
echo -e "  2. Or fully reload:     ${BOLD}exec zsh${RESET}"
echo -e "  3. Warp themes live in: ${BOLD}~/.warp/themes/${RESET}"
echo -e "  4. Terminator config:   ${BOLD}~/.config/terminator/config${RESET}"
echo -e "  5. Starship config:     ${BOLD}~/.config/starship.toml${RESET}"
echo ""
