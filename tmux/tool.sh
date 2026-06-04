#!/usr/bin/env bash

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_CONF_SOURCE="$TOOL_DIR/files/.tmux.conf"
TMUX_CONF_TARGET="$HOME/.tmux.conf"
TMUX_PLUGIN_DIR="$HOME/.tmux/plugins"
TPM_DIR="$TMUX_PLUGIN_DIR/tpm"
TPM_REPO_URL="https://github.com/tmux-plugins/tpm"

is_installed() {
  command_exists tmux
}

list_targets() {
  printf '%s\n' "$TMUX_CONF_TARGET" "$TPM_DIR"
}

has_existing_config() {
  [ -f "$TMUX_CONF_TARGET" ] || [ -d "$TPM_DIR" ]
}

install_tool() {
  local packages=(tmux git)
  install_packages "${packages[@]}"
}

install_tpm() {
  mkdir -p "$TMUX_PLUGIN_DIR"

  if [ -d "$TPM_DIR/.git" ]; then
    log_info "TPM already exists. Updating the repository."
    git -C "$TPM_DIR" pull --ff-only
    return 0
  fi

  if [ -e "$TPM_DIR" ]; then
    log_warn "Replacing an existing TPM directory at $TPM_DIR."
    rm -rf "$TPM_DIR"
  fi

  git clone "$TPM_REPO_URL" "$TPM_DIR"
}

sync_plugins() {
  if [ ! -x "$TPM_DIR/bin/install_plugins" ]; then
    log_warn "TPM install script was not found. Run Prefix + I inside tmux after setup."
    return 0
  fi

  tmux start-server >/dev/null 2>&1 || true
  if ! TMUX_PLUGIN_MANAGER_PATH="$TMUX_PLUGIN_DIR" "$TPM_DIR/bin/install_plugins"; then
    log_warn "Automatic plugin sync failed. Run Prefix + I inside tmux to install plugins."
  fi
}

apply_tool() {
  copy_file "$TMUX_CONF_SOURCE" "$TMUX_CONF_TARGET"
  install_tpm
  sync_plugins
}
