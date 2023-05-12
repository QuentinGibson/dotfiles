#!/bin/bash

if ! command -v zsh &> /dev/null; then
  echo "Zsh is not found. Installing..."

  # Install Zsh using the package manager
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS using Homebrew
    brew install zsh -y
  elif [[ "$OSTYPE" == "linux-gnu" ]]; then
    # Linux using apt-get
    sudo apt-get install zsh -y
  else
    echo "Unsupported operating system."
    exit 1
  fi

  echo "Zsh installation complete."
else
  echo "Zsh is already installed."
fi

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"


