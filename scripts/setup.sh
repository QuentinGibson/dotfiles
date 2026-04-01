#!/usr/bin/env bash
# =============================================================================
# WSL2 Ubuntu 24.04 LTS - Dev Environment Setup
# Installs: Python, Bun, Node.js (nvm), Claude Code, pnpm,
#           Lua, Rust, Neovim + providers + kickstart config,
#           PHP 8.2, Java 17, Composer, tmux, lazygit, gh CLI,
#           zsh, Oh My Zsh, Powerlevel10k
# Dotfiles: https://github.com/QuentinGibson/dotfiles
# =============================================================================

set -euo pipefail

DOTFILES_REPO="https://github.com/QuentinGibson/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
TMPDIR_BUILD="$(mktemp -d)"
LOG_FILE="/tmp/devsetup-$(date +%s).log"
TOTAL_STEPS=23
CURRENT_STEP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

cleanup() { rm -rf "$TMPDIR_BUILD"; }
trap cleanup EXIT

# Helper: fetch latest GitHub release tag for a repo (owner/repo)
latest_github_release() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>>"$LOG_FILE" \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

# Helper: ensure a line exists in a file, appending it if missing
ensure_line() {
  local file="$1" line="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Helper: ensure a pattern exists in a file (uses grep regex), appending line if missing
ensure_pattern() {
  local file="$1" pattern="$2" line="$3"
  grep -q "$pattern" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# ── Output helpers ─────────────────────────────────────────────────────────────

_bar() {
  local filled=$(( 28 * CURRENT_STEP / TOTAL_STEPS ))
  local empty=$(( 28 - filled ))
  local b=""
  for ((i=0; i<filled; i++)); do b+="${GREEN}█${NC}"; done
  for ((i=0; i<empty; i++)); do b+="${BLUE}░${NC}"; done
  printf "  ${BLUE}[${NC}%b${BLUE}]${NC}  ${BOLD}%3d%%${NC}  ${BLUE}%d / %d${NC}\n" \
    "$b" "$(( 100 * CURRENT_STEP / TOTAL_STEPS ))" "$CURRENT_STEP" "$TOTAL_STEPS"
}

step() {
  CURRENT_STEP=$(( CURRENT_STEP + 1 ))
  echo ""
  _bar
  echo -e "  ${CYAN}▸${NC}  $1"
}

ok()   { echo -e "  ${GREEN}✓${NC}  $1"; }
skip() { echo -e "  ${YELLOW}↩${NC}  $1  ${BLUE}(already installed)${NC}"; }
warn() { echo -e "  ${YELLOW}!${NC}  $1"; }
fail() { echo -e "  ${RED}✗${NC}  $1"; exit 1; }

# ── Header ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${BLUE}  ╭──────────────────────────────────────────────────╮${NC}"
echo -e "${BOLD}${BLUE}  │${NC}  🚀  dev environment setup · WSL2 Ubuntu 24.04  ${BOLD}${BLUE}│${NC}"
echo -e "${BOLD}${BLUE}  ╰──────────────────────────────────────────────────╯${NC}"
echo ""
echo -e "  ${BLUE}logs →${NC} $LOG_FILE"
echo -e "  grab a coffee. this'll take a few minutes ☕"
echo ""

# =============================================================================
# 1. System packages
# =============================================================================
step "system packages — the boring-but-necessary stuff"

_base_pkgs=(
  git curl wget unzip tar
  build-essential autoconf automake pkg-config
  libevent-dev libncurses-dev bison byacc
  zsh stow fontconfig
  python3 python3-venv python3-dev python3-full pipx python3-pynvim
  lua5.4 luarocks
  perl cpanminus libterm-readline-gnu-perl
  ruby ruby-dev
  openjdk-17-jdk
  ripgrep fd-find fzf
  xclip xsel
  ca-certificates gnupg lsb-release software-properties-common
)

_missing=()
for _p in "${_base_pkgs[@]}"; do
  dpkg -s "$_p" &>/dev/null || _missing+=("$_p")
done

if [ ${#_missing[@]} -gt 0 ]; then
  ok "installing ${#_missing[@]} missing package(s): ${_missing[*]}"
  sudo apt-get update -qq >> "$LOG_FILE" 2>&1
  sudo apt-get install -y "${_missing[@]}" >> "$LOG_FILE" 2>&1
  ok "base packages ready"
else
  skip "all base packages"
fi

# =============================================================================
# 2. PHP 8.2
# =============================================================================
step "PHP 8.2 — for the Laravel enjoyers in the room 🐘"

_php_pkgs=(php8.2 php8.2-cli php8.2-mbstring php8.2-xml php8.2-curl php8.2-zip php8.2-xdebug)

_missing=()
for _p in "${_php_pkgs[@]}"; do
  dpkg -s "$_p" &>/dev/null || _missing+=("$_p")
done

if [ ${#_missing[@]} -gt 0 ]; then
  ok "installing ${#_missing[@]} missing PHP package(s): ${_missing[*]}"
  sudo add-apt-repository -y ppa:ondrej/php >> "$LOG_FILE" 2>&1
  sudo apt-get update -qq >> "$LOG_FILE" 2>&1
  sudo apt-get install -y "${_missing[@]}" >> "$LOG_FILE" 2>&1
  ok "PHP $(php --version | head -1 | awk '{print $2}') ready"
else
  skip "PHP $(php --version | head -1 | awk '{print $2}') — all packages present"
fi

# =============================================================================
# 3. Python
# =============================================================================
step "Python — everybody's favourite scripting snake 🐍"

export PATH="$HOME/.local/bin:$PATH"

if ! command -v python &>/dev/null; then
  sudo apt-get install -y python-is-python3 >> "$LOG_FILE" 2>&1
fi

pipx ensurepath --force >> "$LOG_FILE" 2>&1

for tool in black ruff mypy ipython; do
  if pipx list 2>/dev/null | grep -q "$tool"; then
    pipx upgrade "$tool" >> "$LOG_FILE" 2>&1 || true
  else
    pipx install "$tool" >> "$LOG_FILE" 2>&1
  fi
done

ok "Python $(python3 --version) + black, ruff, mypy, ipython"

# =============================================================================
# 4. Bun
# =============================================================================
step "Bun — JavaScript runtime speedrun 🧅"

if command -v bun &>/dev/null; then
  skip "Bun $(bun --version)"
  bun upgrade >> "$LOG_FILE" 2>&1
else
  curl -fsSL https://bun.sh/install 2>>"$LOG_FILE" | bash >> "$LOG_FILE" 2>&1
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  ok "Bun $(bun --version 2>/dev/null || echo 'installed') ready"
fi

# =============================================================================
# 5. Node.js via nvm
# =============================================================================
step "Node.js — JavaScript, but make it a server 🟢"

export NVM_DIR="$HOME/.nvm"

if [ -d "$NVM_DIR" ]; then
  skip "nvm — updating to latest"
  (
    cd "$NVM_DIR"
    git fetch --tags --quiet >> "$LOG_FILE" 2>&1
    LATEST_NVM=$(git describe --abbrev=0 --tags)
    git checkout "$LATEST_NVM" --quiet >> "$LOG_FILE" 2>&1
  )
else
  NVM_VERSION=$(latest_github_release "nvm-sh/nvm")
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
    2>>"$LOG_FILE" | bash >> "$LOG_FILE" 2>&1
fi

\. "$NVM_DIR/nvm.sh"
nvm install --lts >> "$LOG_FILE" 2>&1
nvm use --lts >> "$LOG_FILE" 2>&1
nvm alias default 'lts/*' >> "$LOG_FILE" 2>&1
export PATH="$(nvm which current | xargs dirname):$PATH"

# Persist nvm in .zshrc
NVM_LINES='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
grep -qF 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null || echo "$NVM_LINES" >> "$HOME/.zshrc"

ok "Node.js $(node --version) / npm $(npm --version)"

# =============================================================================
# 6. pnpm
# =============================================================================
step "pnpm — the superior package manager (fight me) 📦"

if command -v pnpm &>/dev/null; then
  skip "pnpm $(pnpm --version)"
  npm update -g pnpm >> "$LOG_FILE" 2>&1
else
  npm install -g pnpm >> "$LOG_FILE" 2>&1
fi

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
pnpm setup --force >> "$LOG_FILE" 2>&1 || true

PNPM_LINES='export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"'
grep -qF 'PNPM_HOME' "$HOME/.zshrc" 2>/dev/null || echo "$PNPM_LINES" >> "$HOME/.zshrc"

ok "pnpm $(pnpm --version) ready"

# =============================================================================
# 7. Claude Code
# =============================================================================
step "Claude Code — installing your AI pair programmer 🤖"

if command -v claude &>/dev/null; then
  skip "Claude Code"
  npm update -g @anthropic-ai/claude-code >> "$LOG_FILE" 2>&1
else
  npm install -g @anthropic-ai/claude-code >> "$LOG_FILE" 2>&1
fi

if ! command -v claude &>/dev/null; then
  NPM_GLOBAL_BIN="$(npm root -g)/../bin"
  export PATH="$NPM_GLOBAL_BIN:$PATH"
fi

ok "Claude Code $(claude --version 2>/dev/null || echo 'installed — restart shell to verify')"

# =============================================================================
# 8. GitHub CLI
# =============================================================================
step "GitHub CLI — pushing to main at 3am, we see you 🐙"

if command -v gh &>/dev/null; then
  skip "gh $(gh --version | head -1)"
else
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    2>>"$LOG_FILE" \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >> "$LOG_FILE" 2>&1
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >> "$LOG_FILE" 2>&1
  sudo apt-get update -qq >> "$LOG_FILE" 2>&1
  sudo apt-get install -y gh >> "$LOG_FILE" 2>&1
  ok "gh $(gh --version | head -1)"
fi

# =============================================================================
# 9. Rust
# =============================================================================
step "Rust — compiling. this is fine. we're all fine. 🦀"

if command -v rustc &>/dev/null; then
  skip "Rust $(rustc --version)"
  rustup update stable >> "$LOG_FILE" 2>&1
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs 2>>"$LOG_FILE" \
    | sh -s -- -y --no-modify-path >> "$LOG_FILE" 2>&1
fi

source "$HOME/.cargo/env" 2>/dev/null || export PATH="$HOME/.cargo/bin:$PATH"
ensure_line "$HOME/.zshrc" '. "$HOME/.cargo/env"'

ok "Rust $(rustc --version) ready"

# =============================================================================
# 10. Neovim
# =============================================================================
step "Neovim — vim, but it actually slaps ✨"

if command -v nvim &>/dev/null; then
  skip "Neovim $(nvim --version | head -1)"
else
  sudo add-apt-repository -y ppa:neovim-ppa/unstable >> "$LOG_FILE" 2>&1
  sudo apt-get update -qq >> "$LOG_FILE" 2>&1
  sudo apt-get install -y neovim >> "$LOG_FILE" 2>&1
  ok "Neovim $(nvim --version | head -1) ready"
fi

# =============================================================================
# 11. Composer
# =============================================================================
step "Composer — PHP's package manager (therapy not included) 🎼"

if command -v composer &>/dev/null; then
  skip "Composer $(composer --version | head -1)"
  composer self-update >> "$LOG_FILE" 2>&1
else
  EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" >> "$LOG_FILE" 2>&1
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
  if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    fail "Composer installer checksum mismatch — aborting"
  fi
  php composer-setup.php --quiet >> "$LOG_FILE" 2>&1
  rm -f composer-setup.php
  sudo mv composer.phar /usr/local/bin/composer
  ok "Composer $(composer --version | head -1) installed"
fi

# =============================================================================
# 12. tmux
# =============================================================================
step "tmux — windows within windows within windows 🪟"

TMUX_VERSION=$(latest_github_release "tmux/tmux")
TMUX_VERSION_CLEAN="${TMUX_VERSION#v}"

_build_tmux=false
if command -v tmux &>/dev/null; then
  INSTALLED_TMUX=$(tmux -V | awk '{print $2}')
  if [ "$INSTALLED_TMUX" = "$TMUX_VERSION_CLEAN" ]; then
    skip "tmux $INSTALLED_TMUX"
  else
    warn "tmux $INSTALLED_TMUX → upgrading to $TMUX_VERSION_CLEAN"
    _build_tmux=true
  fi
else
  _build_tmux=true
fi

if [ "$_build_tmux" = "true" ]; then
  TMUX_TAR="tmux-${TMUX_VERSION_CLEAN}.tar.gz"
  TMUX_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/${TMUX_TAR}"
  curl -fsSL "$TMUX_URL" -o "$TMPDIR_BUILD/$TMUX_TAR" >> "$LOG_FILE" 2>&1
  tar -xzf "$TMPDIR_BUILD/$TMUX_TAR" -C "$TMPDIR_BUILD" >> "$LOG_FILE" 2>&1
  pushd "$TMPDIR_BUILD/tmux-${TMUX_VERSION_CLEAN}" > /dev/null
    ./configure --prefix=/usr/local >> "$LOG_FILE" 2>&1
    make -j"$(nproc)" >> "$LOG_FILE" 2>&1
    sudo make install >> "$LOG_FILE" 2>&1
  popd > /dev/null
  ok "tmux $(tmux -V) built from source"
fi

# =============================================================================
# 13. lazygit
# =============================================================================
step "lazygit — git, but for people with a life 😌"

LAZYGIT_VERSION=$(latest_github_release "jesseduffield/lazygit")
LAZYGIT_VERSION_CLEAN="${LAZYGIT_VERSION#v}"

_install_lazygit=true
if command -v lazygit &>/dev/null; then
  INSTALLED_LG=$(lazygit --version | grep -oP 'version=\K[^,]+')
  if [ "$INSTALLED_LG" = "$LAZYGIT_VERSION_CLEAN" ]; then
    skip "lazygit $INSTALLED_LG"
    _install_lazygit=false
  else
    warn "lazygit $INSTALLED_LG → upgrading to $LAZYGIT_VERSION_CLEAN"
  fi
fi

if [ "$_install_lazygit" = "true" ]; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  ARCH_LABEL="x86_64" ;;
    aarch64) ARCH_LABEL="arm64"  ;;
    *)       fail "unsupported architecture: $ARCH" ;;
  esac
  LG_TAR="lazygit_${LAZYGIT_VERSION_CLEAN}_Linux_${ARCH_LABEL}.tar.gz"
  LG_URL="https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/${LG_TAR}"
  curl -fsSL "$LG_URL" -o "$TMPDIR_BUILD/$LG_TAR" >> "$LOG_FILE" 2>&1
  tar -xzf "$TMPDIR_BUILD/$LG_TAR" -C "$TMPDIR_BUILD" >> "$LOG_FILE" 2>&1
  sudo install -m 0755 "$TMPDIR_BUILD/lazygit" /usr/local/bin/lazygit
  ok "lazygit $(lazygit --version | grep -oP 'version=\K[^,]+') installed"
fi

# =============================================================================
# 14. Dotfiles
# =============================================================================
step "dotfiles — cloning your digital DNA 🧬"

if [ -d "$DOTFILES_DIR/.git" ]; then
  skip "dotfiles already cloned — pulling latest"
  git -C "$DOTFILES_DIR" pull --ff-only >> "$LOG_FILE" 2>&1
else
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR" >> "$LOG_FILE" 2>&1
  ok "dotfiles cloned to $DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
for dir in git tmux zshrc; do
  if [ -d "$DOTFILES_DIR/$dir" ]; then
    stow --adopt --restow --target="$HOME" "$dir" >> "$LOG_FILE" 2>&1 || \
      warn "stow conflict for '$dir' — check manually"
  fi
done
git -C "$DOTFILES_DIR" checkout -- . >> "$LOG_FILE" 2>&1

ok "configs symlinked via stow"

# =============================================================================
# 15. Oh My Zsh + plugins
# =============================================================================
step "Oh My Zsh — making your terminal look gorgeous 💅"

OMZ_DIR="$HOME/.oh-my-zsh"

if [ -d "$OMZ_DIR" ]; then
  skip "Oh My Zsh — updating"
  git -C "$OMZ_DIR" pull --ff-only >> "$LOG_FILE" 2>&1
else
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    >> "$LOG_FILE" 2>&1
  ok "Oh My Zsh installed"
fi

ZSH_SYNTAX_DIR="${ZSH_CUSTOM:-$OMZ_DIR/custom}/plugins/zsh-syntax-highlighting"
if [ -d "$ZSH_SYNTAX_DIR" ]; then
  git -C "$ZSH_SYNTAX_DIR" pull --ff-only >> "$LOG_FILE" 2>&1
else
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_DIR" \
    >> "$LOG_FILE" 2>&1
fi

ZSH_AUTOSUG_DIR="${ZSH_CUSTOM:-$OMZ_DIR/custom}/plugins/zsh-autosuggestions"
if [ -d "$ZSH_AUTOSUG_DIR" ]; then
  git -C "$ZSH_AUTOSUG_DIR" pull --ff-only >> "$LOG_FILE" 2>&1
else
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_AUTOSUG_DIR" \
    >> "$LOG_FILE" 2>&1
fi

P10K_DIR="${ZSH_CUSTOM:-$OMZ_DIR/custom}/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
  git -C "$P10K_DIR" pull --ff-only >> "$LOG_FILE" 2>&1
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" \
    >> "$LOG_FILE" 2>&1
fi

ok "oh-my-zsh + zsh-syntax-highlighting + zsh-autosuggestions + powerlevel10k"

# =============================================================================
# 16. .zshrc
# =============================================================================
step ".zshrc — patching the shell config matrix 🔧"

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

ensure_pattern "$ZSHRC" '^export ZSH=' 'export ZSH="$HOME/.oh-my-zsh"'

if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
else
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
fi

if grep -q '^plugins=(' "$ZSHRC"; then
  for plugin in git zsh-syntax-highlighting zsh-autosuggestions; do
    grep -q "$plugin" "$ZSHRC" || \
      sed -i "s/^plugins=(\(.*\))/plugins=(\1 $plugin)/" "$ZSHRC"
  done
else
  echo 'plugins=(git zsh-syntax-highlighting zsh-autosuggestions)' >> "$ZSHRC"
fi

ensure_pattern "$ZSHRC" 'oh-my-zsh.sh' 'source "$ZSH/oh-my-zsh.sh"'
ensure_line "$ZSHRC" 'export PATH="$HOME/.local/bin:$PATH"'
ensure_line "$ZSHRC" 'export BUN_INSTALL="$HOME/.bun"; export PATH="$BUN_INSTALL/bin:$PATH"'

P10K_INSTANT='if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi'
if ! grep -q 'p10k-instant-prompt' "$ZSHRC"; then
  echo -e "$P10K_INSTANT\n$(cat "$ZSHRC")" > "$ZSHRC"
fi

ensure_pattern "$ZSHRC" '\.p10k\.zsh' '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'

ok ".zshrc configured"

# =============================================================================
# 17. Fonts
# =============================================================================
step "MesloLGS NF — you are now legally a nerd 🤓"

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

FONTS_NEEDED=false
for font in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
            "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
  [ ! -f "$FONT_DIR/$font" ] && FONTS_NEEDED=true && break
done

if [ "$FONTS_NEEDED" = "true" ]; then
  FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
  for font in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
              "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
    curl -fsSL "${FONT_BASE}/${font// /%20}" -o "$FONT_DIR/$font" >> "$LOG_FILE" 2>&1
  done
  fc-cache -fv "$FONT_DIR" >> "$LOG_FILE" 2>&1
  ok "MesloLGS NF installed — set your terminal font to 'MesloLGS NF'"
else
  skip "MesloLGS NF fonts already present"
fi

# =============================================================================
# 18. win32yank (WSL2 clipboard)
# =============================================================================
step "win32yank — bridging WSL2 to Windows clipboard 📋"

WIN32YANK_PATH="/usr/local/bin/win32yank.exe"

if [ -f "$WIN32YANK_PATH" ]; then
  skip "win32yank already installed"
else
  WIN32YANK_VERSION=$(latest_github_release "equalsraf/win32yank")
  WIN32YANK_VERSION_CLEAN="${WIN32YANK_VERSION#v}"
  WIN32YANK_URL="https://github.com/equalsraf/win32yank/releases/download/${WIN32YANK_VERSION}/win32yank-x64.zip"
  curl -fsSL "$WIN32YANK_URL" -o "$TMPDIR_BUILD/win32yank.zip" >> "$LOG_FILE" 2>&1
  unzip -q "$TMPDIR_BUILD/win32yank.zip" -d "$TMPDIR_BUILD/win32yank" >> "$LOG_FILE" 2>&1
  sudo install -m 0755 "$TMPDIR_BUILD/win32yank/win32yank.exe" "$WIN32YANK_PATH"
  ok "win32yank $WIN32YANK_VERSION_CLEAN installed"
fi

NVIM_OPTS="$HOME/.config/nvim/lua/config/options.lua"
if [ -f "$NVIM_OPTS" ]; then
  grep -q 'clipboard' "$NVIM_OPTS" || \
    echo 'vim.opt.clipboard = "unnamedplus"' >> "$NVIM_OPTS"
fi

# =============================================================================
# 19. Neovim providers
# =============================================================================
step "Neovim providers — feeding the plugin beast 🍖"

if npm list -g --depth=0 2>/dev/null | grep -q ' neovim@'; then
  skip "neovim npm package"
else
  npm install -g neovim >> "$LOG_FILE" 2>&1
  ok "node provider ready"
fi

if command -v tree-sitter &>/dev/null; then
  skip "tree-sitter-cli"
else
  npm install -g tree-sitter-cli >> "$LOG_FILE" 2>&1
  ok "tree-sitter-cli ready"
fi

# python3-pynvim installed via apt above
ok "python provider ready (pynvim via apt)"

if perl -MNeovim::Ext -e 1 2>/dev/null; then
  skip "Neovim::Ext (perl provider)"
else
  cpanm -n Neovim::Ext >> "$LOG_FILE" 2>&1 || warn "perl provider had warnings — run 'cpanm Neovim::Ext' manually"
  ok "perl provider ready"
fi

if gem list neovim -i &>/dev/null; then
  skip "neovim gem (ruby provider)"
else
  sudo gem install neovim --quiet >> "$LOG_FILE" 2>&1
  ok "ruby provider ready"
fi

if command -v nvr &>/dev/null; then
  skip "neovim-remote (nvr)"
else
  pipx install neovim-remote >> "$LOG_FILE" 2>&1
  ok "neovim-remote (nvr) ready"
fi

# =============================================================================
# 20. Neovim config (kickstart.nvim)
# =============================================================================
step "Neovim config — cloning your kickstart setup 🥾"

NVIM_CONFIG_REPO="https://github.com/QuentinGibson/kickstart.nvim"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

if [ -d "$NVIM_CONFIG_DIR/.git" ]; then
  skip "kickstart.nvim already cloned — pulling latest"
  git -C "$NVIM_CONFIG_DIR" pull --ff-only >> "$LOG_FILE" 2>&1
else
  mkdir -p "$HOME/.config"
  git clone "$NVIM_CONFIG_REPO" "$NVIM_CONFIG_DIR" >> "$LOG_FILE" 2>&1
  ok "kickstart.nvim cloned to $NVIM_CONFIG_DIR"
fi

# =============================================================================
# 21. Neovim plugins
# =============================================================================
step "Neovim plugins — lazy loading the apocalypse 🔌"

if [ -f "$HOME/.config/nvim/init.lua" ]; then
  nvim --headless "+Lazy! sync" +qa >> "$LOG_FILE" 2>&1 || \
    warn "headless sync had warnings — run ':Lazy sync' manually on first open"
  ok "plugins synced"
else
  warn "no ~/.config/nvim/init.lua found — skipping plugin sync"
fi

# =============================================================================
# 22. tmux plugins
# =============================================================================
step "tmux plugins — moar plugins, always 🪄"

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  skip "tpm already installed — pulling latest"
  git -C "$TPM_DIR" pull --ff-only >> "$LOG_FILE" 2>&1
else
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" >> "$LOG_FILE" 2>&1
  ok "tpm installed"
fi

if [ -f "$HOME/.tmux.conf" ] || [ -f "$HOME/.config/tmux/tmux.conf" ]; then
  "$TPM_DIR/bin/install_plugins" >> "$LOG_FILE" 2>&1 || \
    warn "press prefix + I inside tmux to install plugins manually"
  ok "tmux plugins installed"
fi

# =============================================================================
# 23. Default shell
# =============================================================================
step "zsh — making it your default, forever ⚡"

if [ "$SHELL" != "$(which zsh)" ]; then
  chsh -s "$(which zsh)"
  ok "default shell set to zsh — restart terminal to take effect"
else
  skip "zsh is already the default shell"
fi

# =============================================================================
# Done
# =============================================================================

echo ""
_bar
echo ""
echo -e "${BOLD}${GREEN}  ╭──────────────────────────────────────────────────╮${NC}"
echo -e "${BOLD}${GREEN}  │${NC}              🎉  all done! ship it.              ${BOLD}${GREEN}│${NC}"
echo -e "${BOLD}${GREEN}  ╰──────────────────────────────────────────────────╯${NC}"
echo ""
echo -e "  here's everything that was set up on this machine:"
echo ""

echo -e "  ${BOLD}${BLUE}── runtimes & languages ──────────────────────────────${NC}"
echo -e "  ${GREEN}✓${NC}  Python      $(python3 --version 2>&1)  +  black, ruff, mypy, ipython"
echo -e "  ${GREEN}✓${NC}  Node.js     $(node --version 2>/dev/null || echo 'restart shell to verify')  via nvm  (npm $(npm --version 2>/dev/null || echo '?'))"
echo -e "  ${GREEN}✓${NC}  Bun         $(bun --version 2>/dev/null || echo 'restart shell to verify')"
echo -e "  ${GREEN}✓${NC}  Rust        $(rustc --version 2>/dev/null || echo 'restart shell to verify')"
echo -e "  ${GREEN}✓${NC}  PHP         $(php --version 2>&1 | head -1)  (via ondrej/php PPA)"
echo -e "  ${GREEN}✓${NC}  Java        $(java -version 2>&1 | head -1)"
echo -e "  ${GREEN}✓${NC}  Lua         $(lua5.4 -v 2>&1)  +  luarocks"
echo ""

echo -e "  ${BOLD}${BLUE}── package managers ──────────────────────────────────${NC}"
echo -e "  ${GREEN}✓${NC}  pnpm        $(pnpm --version 2>/dev/null || echo 'restart shell to verify')"
echo -e "  ${GREEN}✓${NC}  Composer    $(composer --version 2>/dev/null | head -1 || echo 'restart shell to verify')"
echo ""

echo -e "  ${BOLD}${BLUE}── cli tools ─────────────────────────────────────────${NC}"
echo -e "  ${GREEN}✓${NC}  Claude Code $(claude --version 2>/dev/null || echo 'restart shell to verify')"
echo -e "  ${GREEN}✓${NC}  GitHub CLI  $(gh --version 2>&1 | head -1)"
echo -e "  ${GREEN}✓${NC}  lazygit     $(lazygit --version 2>&1 | grep -oP 'version=\K[^,]+' || echo 'installed')  (git TUI)"
echo -e "  ${GREEN}✓${NC}  tmux        $(tmux -V 2>&1)  (built from source)"
echo -e "  ${GREEN}✓${NC}  ripgrep     $(rg --version | head -1)"
echo -e "  ${GREEN}✓${NC}  fzf         $(fzf --version)"
echo -e "  ${GREEN}✓${NC}  fd          $(fd --version 2>/dev/null || fdfind --version 2>/dev/null || echo 'installed')"
echo ""

echo -e "  ${BOLD}${BLUE}── neovim ────────────────────────────────────────────${NC}"
echo -e "  ${GREEN}✓${NC}  Neovim      $(nvim --version 2>&1 | head -1)  (via neovim-ppa/unstable)"
echo -e "  ${GREEN}✓${NC}  config      QuentinGibson/kickstart.nvim  →  ~/.config/nvim"
echo -e "  ${GREEN}✓${NC}  plugins     bootstrapped via lazy.nvim"
echo -e "  ${GREEN}✓${NC}  providers   node · python (pynvim) · perl · ruby"
echo -e "  ${GREEN}✓${NC}  extras      tree-sitter-cli · neovim-remote (nvr)"
echo -e "  ${GREEN}✓${NC}  clipboard   win32yank  (WSL2 → Windows clipboard bridge)"
echo ""

echo -e "  ${BOLD}${BLUE}── shell & terminal ──────────────────────────────────${NC}"
echo -e "  ${GREEN}✓${NC}  zsh         $(zsh --version)  (default shell)"
echo -e "  ${GREEN}✓${NC}  Oh My Zsh   plugins: git · zsh-syntax-highlighting · zsh-autosuggestions"
echo -e "  ${GREEN}✓${NC}  theme       powerlevel10k"
echo -e "  ${GREEN}✓${NC}  font        MesloLGS NF  (set this in Windows Terminal)"
echo -e "  ${GREEN}✓${NC}  tmux tpm    plugins installed"
echo ""

echo -e "  ${BOLD}${BLUE}── dotfiles ──────────────────────────────────────────${NC}"
echo -e "  ${GREEN}✓${NC}  cloned      QuentinGibson/dotfiles  →  ~/dotfiles"
echo -e "  ${GREEN}✓${NC}  symlinked   git · tmux · zshrc  (via GNU stow)"
echo ""

echo -e "  ${BOLD}next steps:${NC}"
echo -e "  ${CYAN}1.${NC}  set terminal font  →  'MesloLGS NF' in Windows Terminal settings"
echo -e "  ${CYAN}2.${NC}  restart terminal   →  exec zsh  (p10k wizard runs automatically)"
echo -e "  ${CYAN}3.${NC}  auth GitHub        →  gh auth login"
echo -e "  ${CYAN}4.${NC}  start Claude       →  claude"
echo -e "  ${CYAN}5.${NC}  open nvim          →  plugins finish installing on first launch"
echo -e "  ${CYAN}6.${NC}  open tmux          →  prefix + I  to confirm tpm plugins"
echo ""
echo -e "  ${BLUE}tip:${NC} re-run the p10k wizard anytime  →  p10k configure"
echo -e "  ${BLUE}tip:${NC} full install logs saved at  →  $LOG_FILE"
echo ""
