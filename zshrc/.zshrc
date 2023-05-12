# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
fi

export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git gem nvm rails fasd github npm asdf)
source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export EDITOR="vim"
clear

if ! command -v make &> /dev/null; then
  echo "Make is not found. Installing build-essentials..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install build-essential
  elif [[ "$OSTYPE" == "linux-gnu" ]]; then
    # Linux using apt-get
    sudo apt-get install build-essential -y
  else
    echo "Unsupported operating system."
    exit 1
  fi
  
  echo "make installation complete."
fi

if ! command -v git &> /dev/null; then
  echo "Git is not found. Installing git..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS using Homebrew
    brew install git -y
  elif [[ "$OSTYPE" == "linux-gnu" ]]; then
    # Linux using apt-get
    sudo apt-get install git -y
  else
    echo "Unsupported operating system."
    exit 1
  fi
  
  echo "git installation complete."
fi

if ! command -v flyctl &> /dev/null; then
  echo "fly command is not found. Installing flyctl..."

  # Install flyctl using curl
  curl -L https://fly.io/install.sh | sh
  
  echo "flyctl installation complete."
fi

export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# Install asdf
if ! command -v asdf &> /dev/null; then
  echo "asdf is not found. Installing..."

  # Clone the asdf repository and checkout the specified branch
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.3
  
  echo "asdf installation complete."
fi
# End install asdf

# Install Nodejs using asdf
if ! asdf plugin list | grep -q "nodejs"; then
  echo "Nodejs is not installed. Installing..."

  # Install the plugin using asdf plugin-add command
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git

  #Set up the latest version
  asdf install nodejs latest
  asdf global nodejs latest
  
  echo "Nodejs installation complete."
fi

# Install Python3 and pip
if ! command -v python3 &> /dev/null || ! command -v pip &> /dev/null; then
  echo "Python3 or pip is not found. Installing..."

  # Install python3 and pip using the package manager
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS using Homebrew
    brew install python
  elif [[ "$OSTYPE" == "linux-gnu" ]]; then
    # Linux using apt-get
    sudo apt-get install python4 python3-pip -y
  else
    echo "Unsupported operating system."
    exit 1
  fi
  
  echo "Python3 and pip installation complete."
fi

# Install rustup
if ! command -v rustup &> /dev/null; then
  echo "rustup is not found. Installing..."

  # Install rustup using the provided command
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  
  echo "rustup installation complete."
fi

# Install Lazygit
if ! command -v lazygit &> /dev/null; then
  echo "lazygit is not found. Installing..."

  # Get the latest version from GitHub API
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  
  # Download and extract the binary
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  
  # Install the binary
  sudo install lazygit /usr/local/bin
  
  # Clean up the downloaded files
  rm lazygit.tar.gz lazygit
  
  echo "lazygit installation complete."
fi

#Install Neovim
if ! command -v nvim &> /dev/null; then
  echo "Neovim is not found. Installing..."

  # Create a temporary directory
  tmpdir=$(mktemp -d)

  # Change to the temporary directory
  cd "$tmpdir"

  # Download Neovim archive
  curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim.appimage

  # Make the AppImage executable
  chmod u+x nvim.appimage
  
  # Move the AppImage to the bin directory
  mv nvim.appimage /usr/local/bin/nvim
  
  echo "Neovim installation complete."

  # Cleanup the temporary directory
  rm -rf "$tmpdir"
fi

# Setup Git
if ! git config --get user.name &> /dev/null || ! git config --get user.email &> /dev/null; then
  echo "Git configuration is incomplete. Setting up..."

  # Set Git username
  read -p "Enter your Git username: " username
  git config --global user.name "$username"

  # Set Git email
  read -p "Enter your Git email: " email
  git config --global user.email "$email"

  echo "Git configuration complete."
else
  echo "Git configuration is already set."
fi
