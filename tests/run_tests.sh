#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running init-lua-picker.nvim unit tests..."
nvim --headless -u NONE -c "luafile $SCRIPT_DIR/test_picker.lua"
