#!/usr/bin/env bash

set -euo pipefail

PACKAGE_INDEX_UPDATED=0

log_info() {
  printf '[INFO] %s\n' "$1"
}

log_warn() {
  printf '[WARN] %s\n' "$1"
}

log_success() {
  printf '[DONE] %s\n' "$1"
}

die() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

prompt_yes_no() {
  local prompt="$1"
  local default_answer="${2:-n}"
  local suffix="[y/N]"
  local answer

  if [ "$default_answer" = "y" ]; then
    suffix="[Y/n]"
  fi

  read -r -p "$prompt $suffix " answer
  answer="${answer:-$default_answer}"

  case "$answer" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

detect_package_manager() {
  if command_exists apt-get; then
    printf 'apt-get\n'
    return 0
  fi

  if command_exists brew; then
    printf 'brew\n'
    return 0
  fi

  if command_exists dnf; then
    printf 'dnf\n'
    return 0
  fi

  if command_exists yum; then
    printf 'yum\n'
    return 0
  fi

  return 1
}

update_package_index_if_needed() {
  local manager="$1"

  if [ "$PACKAGE_INDEX_UPDATED" -eq 1 ]; then
    return 0
  fi

  case "$manager" in
    apt-get)
      sudo apt-get update
      ;;
  esac

  PACKAGE_INDEX_UPDATED=1
}

install_packages() {
  local manager
  manager="$(detect_package_manager)" || die "No supported package manager was found."

  case "$manager" in
    apt-get)
      update_package_index_if_needed "$manager"
      sudo apt-get install -y "$@"
      ;;
    brew)
      brew install "$@"
      ;;
    dnf)
      sudo dnf install -y "$@"
      ;;
    yum)
      sudo yum install -y "$@"
      ;;
    *)
      die "Unsupported package manager: $manager"
      ;;
  esac
}

install_snap_packages() {
  command_exists snap || die "snap is not installed on this system."
  sudo snap install "$@"
}

copy_file() {
  local source_path="$1"
  local target_path="$2"

  mkdir -p "$(dirname "$target_path")"
  cp "$source_path" "$target_path"
}

join_lines() {
  local separator="$1"

  awk -v separator="$separator" '
    NR > 1 { printf "%s", separator }
    { printf "%s", $0 }
    END { printf "\n" }
  '
}
