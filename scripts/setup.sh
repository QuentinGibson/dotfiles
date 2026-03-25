#!/usr/bin/env bash
# =============================================================================
# WSL2 Ubuntu 24.04 LTS - Dev Environment Setup
# Installs: Python, Bun, Node.js (nvm), Claude Code, Neovim, tmux (latest),
#           lazygit (latest), gh CLI, zsh, Oh My Zsh, Powerlevel10k,
#           zsh-syntax-highlighting, zsh-autosuggestions
# Dotfiles: https://github.com/QuentinGibson/dotfiles
# =============================================================================

set -euo pipefail

DOTFILES_REPO="https://github.com/QuentinGibson/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
TMPDIR_BUILD="$(mktemp -d)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[x]${NC} $1"; exit 1; }
section(){ echo -e "\n${BLUE}==> $1${NC}"; }

cleanup() { rm -rf "$TMPDIR_BUILD"; }
trap cleanup EXIT

# Helper: fetch latest GitHub release tag for a repo (owner/repo)
latest_github_release() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
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

# =============================================================================
# 1. System update + base dependencies
# =============================================================================
section "Updating system packages"
sudo apt-get update -qq
sudo apt-get install -y \
  git curl wget unzip tar \
  build-essential autoconf automake pkg-config \
  libevent-dev libncurses-dev bison byacc \
  zsh stow fontconfig \
  python3 python3-venv python3-dev python3-full pipx \
  ripgrep fd-find fzf \
  xclip xsel \
  ca-certificates gnupg lsb-release

log "System packages installed"

# =============================================================================
# 2. Python setup
# =============================================================================
section "Setting up Python"

if ! command -v python &>/dev/null; then
  sudo apt-get install -y python-is-python3
fi

# pipx is installed via apt above — ensure its bin dir is on PATH now
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath --force

# Install global Python CLI tools via pipx (each gets its own isolated venv)
for tool in black ruff mypy ipython; do
  if pipx list 2>/dev/null | grep -q "$tool"; then
    warn "$tool already installed via pipx — upgrading"
    pipx upgrade "$tool" || true
  else
    pipx install "$tool"
    log "$tool installed via pipx"
  fi
done

log "Python $(python3 --version) ready"

# =============================================================================
# 3. Bun (JavaScript runtime + package manager)
# =============================================================================
section "Installing Bun"

if command -v bun &>/dev/null; then
  warn "Bun already installed: $(bun --version) — upgrading"
  bun upgrade
else
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

log "Bun $(bun --version 2>/dev/null || echo 'installed') ready"

# =============================================================================
# 4. Node.js via nvm (required for Claude Code + pnpm)
# =============================================================================
section "Installing Node.js via nvm"

export NVM_DIR="$HOME/.nvm"

if [ -d "$NVM_DIR" ]; then
  warn "nvm already installed — updating"
  (
    cd "$NVM_DIR"
    git fetch --tags --quiet
    LATEST_NVM=$(git describe --abbrev=0 --tags)
    git checkout "$LATEST_NVM" --quiet
  )
else
  NVM_VERSION=$(latest_github_release "nvm-sh/nvm")
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
  log "nvm $NVM_VERSION installed"
fi

# Load nvm as a shell function (nvm is NOT a binary — type/source required)
export NVM_DIR="$HOME/.nvm"
\. "$NVM_DIR/nvm.sh"

# Install latest LTS and set as default
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'

# Put the active node on PATH for the rest of this script
export PATH="$(nvm which current | xargs dirname):$PATH"

log "Node.js $(node --version) / npm $(npm --version) ready"

# Persist nvm in .zshrc
NVM_LINES='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
grep -qF 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null \
  || echo "$NVM_LINES" >> "$HOME/.zshrc"

# =============================================================================
# 5. pnpm
# =============================================================================
section "Installing pnpm"

if command -v pnpm &>/dev/null; then
  warn "pnpm already installed: $(pnpm --version) — updating"
  npm update -g pnpm
else
  npm install -g pnpm
  log "pnpm $(pnpm --version) installed"
fi

# Configure pnpm global store and add to PATH
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
pnpm setup --force 2>/dev/null || true

# Persist pnpm PATH in .zshrc
PNPM_LINES='export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"'
grep -qF 'PNPM_HOME' "$HOME/.zshrc" 2>/dev/null \
  || echo "$PNPM_LINES" >> "$HOME/.zshrc"

# =============================================================================
# 6. Claude Code
# =============================================================================
section "Installing Claude Code"

if command -v claude &>/dev/null; then
  warn "Claude Code already installed — updating"
  npm update -g @anthropic-ai/claude-code
else
  npm install -g @anthropic-ai/claude-code
  log "Claude Code installed"
fi

# Verify claude is reachable on PATH
if ! command -v claude &>/dev/null; then
  # npm global bin may not be on PATH yet — find and add it
  NPM_GLOBAL_BIN="$(npm root -g)/../bin"
  export PATH="$NPM_GLOBAL_BIN:$PATH"
fi

log "Claude Code $(claude --version 2>/dev/null || echo 'installed — restart shell to verify') ready"

# =============================================================================
# 6. GitHub CLI (gh)
# =============================================================================
section "Installing GitHub CLI"

if command -v gh &>/dev/null; then
  warn "gh already installed: $(gh --version | head -1) — skipping"
else
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y gh
  log "gh $(gh --version | head -1) installed"
fi

# =============================================================================
# 5. Neovim (latest stable via PPA)
# =============================================================================
section "Installing Neovim"

if command -v nvim &>/dev/null; then
  warn "Neovim already installed: $(nvim --version | head -1)"
else
  sudo add-apt-repository -y ppa:neovim-ppa/unstable
  sudo apt-get update -qq
  sudo apt-get install -y neovim
fi

log "Neovim $(nvim --version | head -1) ready"

# =============================================================================
# 6. tmux — latest release built from source
# =============================================================================
section "Installing tmux (latest from source)"

TMUX_VERSION=$(latest_github_release "tmux/tmux")
TMUX_VERSION_CLEAN="${TMUX_VERSION#v}"

_build_tmux=false
if command -v tmux &>/dev/null; then
  INSTALLED_TMUX=$(tmux -V | awk '{print $2}')
  if [ "$INSTALLED_TMUX" = "$TMUX_VERSION_CLEAN" ]; then
    warn "tmux $INSTALLED_TMUX already up-to-date — skipping build"
  else
    warn "tmux $INSTALLED_TMUX installed; building latest ($TMUX_VERSION_CLEAN)..."
    _build_tmux=true
  fi
else
  _build_tmux=true
fi

if [ "$_build_tmux" = "true" ]; then
  TMUX_TAR="tmux-${TMUX_VERSION_CLEAN}.tar.gz"
  TMUX_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/${TMUX_TAR}"
  log "Downloading tmux $TMUX_VERSION_CLEAN..."
  curl -fsSL "$TMUX_URL" -o "$TMPDIR_BUILD/$TMUX_TAR"
  tar -xzf "$TMPDIR_BUILD/$TMUX_TAR" -C "$TMPDIR_BUILD"
  pushd "$TMPDIR_BUILD/tmux-${TMUX_VERSION_CLEAN}" > /dev/null
    ./configure --prefix=/usr/local
    make -j"$(nproc)"
    sudo make install
  popd > /dev/null
  log "tmux $(tmux -V) installed from source"
fi

# =============================================================================
# 7. lazygit — latest release binary
# =============================================================================
section "Installing lazygit (latest)"

LAZYGIT_VERSION=$(latest_github_release "jesseduffield/lazygit")
LAZYGIT_VERSION_CLEAN="${LAZYGIT_VERSION#v}"

_install_lazygit=true
if command -v lazygit &>/dev/null; then
  INSTALLED_LG=$(lazygit --version | grep -oP 'version=\K[^,]+')
  if [ "$INSTALLED_LG" = "$LAZYGIT_VERSION_CLEAN" ]; then
    warn "lazygit $INSTALLED_LG already up-to-date — skipping"
    _install_lazygit=false
  else
    warn "lazygit $INSTALLED_LG installed; upgrading to $LAZYGIT_VERSION_CLEAN..."
  fi
fi

if [ "$_install_lazygit" = "true" ]; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  ARCH_LABEL="x86_64" ;;
    aarch64) ARCH_LABEL="arm64"  ;;
    *)       error "Unsupported architecture: $ARCH" ;;
  esac
  LG_TAR="lazygit_${LAZYGIT_VERSION_CLEAN}_Linux_${ARCH_LABEL}.tar.gz"
  LG_URL="https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/${LG_TAR}"
  log "Downloading lazygit $LAZYGIT_VERSION_CLEAN..."
  curl -fsSL "$LG_URL" -o "$TMPDIR_BUILD/$LG_TAR"
  tar -xzf "$TMPDIR_BUILD/$LG_TAR" -C "$TMPDIR_BUILD"
  sudo install -m 0755 "$TMPDIR_BUILD/lazygit" /usr/local/bin/lazygit
  log "lazygit $(lazygit --version | grep -oP 'version=\K[^,]+') installed"
fi

# =============================================================================
# 8. Clone dotfiles + stow
# NOTE: This happens BEFORE Oh My Zsh so that OMZ config is written on top
#       of the stowed .zshrc, not the other way around.
# =============================================================================
section "Cloning dotfiles"

if [ -d "$DOTFILES_DIR/.git" ]; then
  warn "Dotfiles already cloned — pulling latest"
  git -C "$DOTFILES_DIR" pull --ff-only
else
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  log "Cloned dotfiles to $DOTFILES_DIR"
fi

section "Symlinking configs with GNU Stow"
cd "$DOTFILES_DIR"

for dir in git nvim tmux zshrc; do
  if [ -d "$DOTFILES_DIR/$dir" ]; then
    log "Stowing: $dir"
    # --adopt pulls any pre-existing home files into the repo, then we restore
    stow --adopt --restow --target="$HOME" "$dir" 2>&1 || \
      warn "Stow conflict for '$dir' — check for conflicts manually"
  else
    warn "Directory '$dir' not found in dotfiles — skipping"
  fi
done

# Restore repo to its committed state (undoes any --adopt overwrites in the repo)
# ~/ symlinks are now established and will reflect the repo's original content.
git -C "$DOTFILES_DIR" checkout -- .

log "Dotfiles symlinked"

# =============================================================================
# 9. Oh My Zsh
# NOTE: KEEP_ZSHRC=yes preserves the stowed .zshrc from your dotfiles repo.
#       We then patch it below to add OMZ bootstrap lines if they're missing.
# =============================================================================
section "Installing Oh My Zsh"

OMZ_DIR="$HOME/.oh-my-zsh"

if [ -d "$OMZ_DIR" ]; then
  warn "Oh My Zsh already installed — updating"
  git -C "$OMZ_DIR" pull --ff-only
else
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  log "Oh My Zsh installed"
fi

# ── zsh-syntax-highlighting ──────────────────────────────────────────────────
ZSH_SYNTAX_DIR="${ZSH_CUSTOM:-$OMZ_DIR/custom}/plugins/zsh-syntax-highlighting"
if [ -d "$ZSH_SYNTAX_DIR" ]; then
  warn "zsh-syntax-highlighting already installed — updating"
  git -C "$ZSH_SYNTAX_DIR" pull --ff-only
else
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_DIR"
  log "zsh-syntax-highlighting installed"
fi

# ── zsh-autosuggestions ───────────────────────────────────────────────────────
ZSH_AUTOSUG_DIR="${ZSH_CUSTOM:-$OMZ_DIR/custom}/plugins/zsh-autosuggestions"
if [ -d "$ZSH_AUTOSUG_DIR" ]; then
  warn "zsh-autosuggestions already installed — updating"
  git -C "$ZSH_AUTOSUG_DIR" pull --ff-only
else
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_AUTOSUG_DIR"
  log "zsh-autosuggestions installed"
fi

# ── Powerlevel10k ────────────────────────────────────────────────────────────
P10K_DIR="${ZSH_CUSTOM:-$OMZ_DIR/custom}/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
  warn "Powerlevel10k already installed — updating"
  git -C "$P10K_DIR" pull --ff-only
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  log "Powerlevel10k installed"
fi

# =============================================================================
# 10. Patch .zshrc with OMZ bootstrap lines
# The stowed .zshrc may not have OMZ setup if the dotfiles predate this script.
# We add any missing lines without touching lines that already exist.
# =============================================================================
section "Configuring .zshrc"

ZSHRC="$HOME/.zshrc"

# Ensure .zshrc exists (stow may have left it missing if the dotfiles dir was empty)
touch "$ZSHRC"

# 1. ZSH variable (must come before sourcing OMZ)
ensure_pattern "$ZSHRC" '^export ZSH=' 'export ZSH="$HOME/.oh-my-zsh"'

# 2. Theme — replace existing ZSH_THEME line or add it
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
  log "ZSH_THEME updated to powerlevel10k"
else
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
  log "ZSH_THEME added to .zshrc"
fi

# 3. Plugins — replace existing plugins line or add one
if grep -q '^plugins=(' "$ZSHRC"; then
  # Inject missing plugins into the existing array
  for plugin in git zsh-syntax-highlighting zsh-autosuggestions; do
    if ! grep -q "$plugin" "$ZSHRC"; then
      sed -i "s/^plugins=(\(.*\))/plugins=(\1 $plugin)/" "$ZSHRC"
      log "Added $plugin to plugins array"
    fi
  done
else
  echo 'plugins=(git zsh-syntax-highlighting zsh-autosuggestions)' >> "$ZSHRC"
  log "Added plugins line to .zshrc"
fi

# 4. Source OMZ (must come after ZSH= and plugins= lines)
ensure_pattern "$ZSHRC" 'oh-my-zsh.sh' 'source "$ZSH/oh-my-zsh.sh"'

# 5. PATH additions
ensure_line "$ZSHRC" 'export PATH="$HOME/.local/bin:$PATH"'
ensure_line "$ZSHRC" 'export BUN_INSTALL="$HOME/.bun"; export PATH="$BUN_INSTALL/bin:$PATH"'

# 6. p10k instant prompt (performance boost — add near the top if missing)
P10K_INSTANT='if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi'
if ! grep -q 'p10k-instant-prompt' "$ZSHRC"; then
  # Prepend to file
  echo -e "$P10K_INSTANT\n$(cat "$ZSHRC")" > "$ZSHRC"
  log "Added p10k instant prompt to .zshrc"
fi

# 7. Source p10k config if ~/.p10k.zsh exists
ensure_pattern "$ZSHRC" '\.p10k\.zsh' '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'

log ".zshrc configured"

# =============================================================================
# 11. MesloLGS NF font (required for p10k icons)
# =============================================================================
section "Installing MesloLGS NF (Powerlevel10k font)"

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
    log "Downloading: $font"
    curl -fsSL "${FONT_BASE}/${font// /%20}" -o "$FONT_DIR/$font"
  done
  fc-cache -fv "$FONT_DIR" > /dev/null 2>&1
  log "MesloLGS NF installed — set your terminal font to 'MesloLGS NF'"
else
  warn "MesloLGS NF fonts already present — skipping"
fi

# =============================================================================
# 12. Neovim plugin bootstrap (lazy.nvim)
# =============================================================================
section "Bootstrapping Neovim plugins"

if [ -f "$HOME/.config/nvim/init.lua" ]; then
  log "Running Neovim headless plugin sync..."
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || \
    warn "Headless sync had warnings — run ':Lazy sync' manually on first open"
else
  warn "No ~/.config/nvim/init.lua found — skipping Neovim plugin sync"
fi

# =============================================================================
# 13. tmux plugin manager (tpm) + plugins
# =============================================================================
section "Setting up tmux plugin manager (tpm)"

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  warn "tpm already installed — pulling latest"
  git -C "$TPM_DIR" pull --ff-only
else
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  log "tpm installed"
fi

if [ -f "$HOME/.tmux.conf" ] || [ -f "$HOME/.config/tmux/tmux.conf" ]; then
  log "Installing tmux plugins headlessly..."
  "$TPM_DIR/bin/install_plugins" 2>/dev/null || \
    warn "Press  prefix + I  inside tmux to install plugins manually"
fi

# =============================================================================
# 14. Set zsh as default shell
# =============================================================================
section "Setting zsh as default shell"

if [ "$SHELL" != "$(which zsh)" ]; then
  chsh -s "$(which zsh)"
  log "Default shell changed to zsh — restart terminal to take effect"
else
  log "zsh is already the default shell"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Setup complete!                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Installed:"
echo "    python3     $(python3 --version 2>&1)"
echo "    bun         $(bun --version 2>/dev/null || echo 'restart shell to verify')"
echo "    node        $(node --version 2>/dev/null || echo 'restart shell to verify')"
echo "    pnpm        $(pnpm --version 2>/dev/null || echo 'restart shell to verify')"
echo "    claude      $(claude --version 2>/dev/null || echo 'restart shell to verify')"
echo "    gh          $(gh --version 2>&1 | head -1)"
echo "    nvim        $(nvim --version 2>&1 | head -1)"
echo "    tmux        $(tmux -V 2>&1)"
echo "    lazygit     $(lazygit --version 2>&1 | grep -oP 'version=\K[^,]+' || echo 'installed')"
echo "    oh-my-zsh   $OMZ_DIR"
echo "    theme       powerlevel10k/powerlevel10k"
echo "    plugins     git, zsh-syntax-highlighting, zsh-autosuggestions"
echo "    font        MesloLGS NF"
echo ""
echo "  Next steps:"
echo "  1. Set terminal font     →  'MesloLGS NF' in Windows Terminal settings"
echo "  2. Restart terminal      →  exec zsh   (p10k wizard runs automatically)"
echo "  3. Auth GitHub CLI       →  gh auth login"
echo "  3b. Start Claude Code    →  claude"
echo "  4. Open nvim             →  plugins finish on first launch"
echo "  5. Open tmux, press      →  prefix + I   to confirm plugins"
echo "  6. Run lazygit           →  lazygit   (inside any git repo)"
echo ""
echo "  Tip: re-run the p10k wizard anytime →  p10k configure"
echo ""
