#!/usr/bin/env bash

set -euo pipefail

APT_PACKAGES=(jq ripgrep)
SNAP_PACKAGES=(glow)
REQUIRED_COMMANDS=(jq rg glow)

is_installed() {
  local command_name

  for command_name in "${REQUIRED_COMMANDS[@]}"; do
    command_exists "$command_name" || return 1
  done

  return 0
}

list_targets() {
  local command_name

  for command_name in "${REQUIRED_COMMANDS[@]}"; do
    printf '%s\n' "$command_name"
  done
}

has_existing_config() {
  return 1
}

install_tool() {
  if [ "${#APT_PACKAGES[@]}" -gt 0 ]; then
    install_packages "${APT_PACKAGES[@]}"
  fi

  if [ "${#SNAP_PACKAGES[@]}" -gt 0 ]; then
    install_snap_packages "${SNAP_PACKAGES[@]}"
  fi
}

apply_tool() {
  :
}
