#!/bin/bash

if ! command -v yay &>/dev/null; then
  echo "yay not found — install yay first: https://github.com/Jguer/yay"
  exit 1
fi

yay -S --needed --noconfirm github-cli
