#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$REPO_DIR/.deps"

# Clone snacks.nvim dependency if not present in any local Neovim directory
if [ ! -d "$DEPS_DIR/snacks.nvim" ] && \
   [ ! -d "$HOME/.local/share/nvim/site/pack/core/opt/snacks.nvim" ] && \
   [ ! -d "$HOME/.local/share/nvim/lazy/snacks.nvim" ]; then
  echo "Cloning snacks.nvim test dependency..."
  mkdir -p "$DEPS_DIR"
  git clone --depth=1 https://github.com/folke/snacks.nvim.git "$DEPS_DIR/snacks.nvim"
fi

echo "Running init-lua-picker.nvim unit tests..."
nvim --headless -u NONE -c "luafile $SCRIPT_DIR/test_picker.lua"

