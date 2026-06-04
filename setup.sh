#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

LIST_ONLY=0
NON_INTERACTIVE=0
OVERWRITE_MODE="prompt"
SELECTED_TOOLS_RAW=""
LAST_RUN_STATUS=""

usage() {
  cat <<'EOF'
Usage:
  ./setup.sh
  ./setup.sh --list
  ./setup.sh --tools tmux
  ./setup.sh --tools tmux,example --yes-overwrite --non-interactive

Options:
  --list               Print supported tools and exit.
  --tools <ids>        Comma-separated tool ids or "all".
  --yes-overwrite      Overwrite existing tool configuration without prompting.
  --non-interactive    Skip prompts. Existing configuration is skipped unless
                       --yes-overwrite is also provided.
  --help               Show this help message.
EOF
}

discover_tool_dirs() {
  local -a dirs=()
  local tool_env

  while IFS= read -r -d '' tool_env; do
    dirs+=("$(dirname "$tool_env")")
  done < <(find "$SCRIPT_DIR" -mindepth 2 -maxdepth 2 -name tool.env -print0 | sort -z)

  printf '%s\n' "${dirs[@]}"
}

load_tool_metadata() {
  local tool_dir="$1"
  unset TOOL_ID TOOL_NAME TOOL_DESCRIPTION
  # shellcheck disable=SC1090
  source "$tool_dir/tool.env"
}

print_supported_tools() {
  local tool_dir

  echo "Supported tools:"
  while IFS= read -r tool_dir; do
    [ -n "$tool_dir" ] || continue
    load_tool_metadata "$tool_dir"
    printf '  - %s: %s\n' "$TOOL_ID" "$TOOL_DESCRIPTION"
  done < <(discover_tool_dirs)
}

prompt_tool_selection() {
  local -a tool_dirs=()
  local tool_dir
  local index=1

  while IFS= read -r tool_dir; do
    [ -n "$tool_dir" ] || continue
    tool_dirs+=("$tool_dir")
  done < <(discover_tool_dirs)

  if [ "${#tool_dirs[@]}" -eq 0 ]; then
    die "No supported tools were found."
  fi

  echo "Supported tools:"
  for tool_dir in "${tool_dirs[@]}"; do
    load_tool_metadata "$tool_dir"
    printf '  %d. %s (%s)\n' "$index" "$TOOL_ID" "$TOOL_DESCRIPTION"
    index=$((index + 1))
  done

  read -r -p "Select tools by number or id (comma separated, or 'all'): " SELECTED_TOOLS_RAW
}

normalize_csv() {
  local value="$1"
  value="${value// /}"
  value="${value#,}"
  value="${value%,}"
  printf '%s\n' "$value"
}

resolve_selected_tool_dirs() {
  local selection
  local -A by_id=()
  local -A by_index=()
  local -a requested=()
  local -a resolved=()
  local -a tool_dirs=()
  local tool_dir
  local index=1
  local item

  while IFS= read -r tool_dir; do
    [ -n "$tool_dir" ] || continue
    tool_dirs+=("$tool_dir")
    load_tool_metadata "$tool_dir"
    by_id["$TOOL_ID"]="$tool_dir"
    by_index["$index"]="$tool_dir"
    index=$((index + 1))
  done < <(discover_tool_dirs)

  if [ "${#tool_dirs[@]}" -eq 0 ]; then
    die "No supported tools were found."
  fi

  selection="$(normalize_csv "$SELECTED_TOOLS_RAW")"
  if [ -z "$selection" ] || [ "$selection" = "all" ]; then
    printf '%s\n' "${tool_dirs[@]}"
    return 0
  fi

  IFS=',' read -r -a requested <<< "$selection"
  for item in "${requested[@]}"; do
    if [ -n "${by_id[$item]:-}" ]; then
      resolved+=("${by_id[$item]}")
      continue
    fi

    if [ -n "${by_index[$item]:-}" ]; then
      resolved+=("${by_index[$item]}")
      continue
    fi

    die "Unsupported tool selection: $item"
  done

  printf '%s\n' "${resolved[@]}" | awk '!seen[$0]++'
}

should_apply_existing_config() {
  local tool_name="$1"
  local targets="$2"

  case "$OVERWRITE_MODE" in
    always)
      return 0
      ;;
    skip)
      log_warn "Skipping $tool_name because configuration already exists: $targets"
      return 1
      ;;
  esac

  if prompt_yes_no "Existing configuration found for $tool_name at $targets. Overwrite?" "n"; then
    return 0
  fi

  log_warn "Skipped $tool_name."
  return 1
}

run_tool() {
  local tool_dir="$1"
  local targets

  load_tool_metadata "$tool_dir"
  # shellcheck disable=SC1090
  source "$tool_dir/tool.sh"

  log_info "Processing $TOOL_NAME..."

  if ! is_installed; then
    log_info "$TOOL_NAME is not installed. Installing dependencies first."
    install_tool
  else
    log_info "$TOOL_NAME is already installed."
  fi

  targets="$(list_targets | join_lines ', ')"
  if has_existing_config; then
    if ! should_apply_existing_config "$TOOL_NAME" "$targets"; then
      LAST_RUN_STATUS="skipped"
      return 0
    fi
  fi

  apply_tool
  LAST_RUN_STATUS="applied"
  log_success "$TOOL_NAME setup completed."
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --list)
        LIST_ONLY=1
        ;;
      --tools)
        shift
        [ "$#" -gt 0 ] || die "--tools requires a value."
        SELECTED_TOOLS_RAW="$1"
        ;;
      --yes-overwrite)
        OVERWRITE_MODE="always"
        ;;
      --non-interactive)
        NON_INTERACTIVE=1
        if [ "$OVERWRITE_MODE" = "prompt" ]; then
          OVERWRITE_MODE="skip"
        fi
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
    shift
  done
}

main() {
  local -a selected_tool_dirs=()
  local tool_dir
  local applied=0
  local skipped=0

  parse_args "$@"

  if [ "$LIST_ONLY" -eq 1 ]; then
    print_supported_tools
    exit 0
  fi

  if [ -z "$SELECTED_TOOLS_RAW" ]; then
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
      SELECTED_TOOLS_RAW="all"
    else
      prompt_tool_selection
    fi
  fi

  while IFS= read -r tool_dir; do
    [ -n "$tool_dir" ] || continue
    selected_tool_dirs+=("$tool_dir")
  done < <(resolve_selected_tool_dirs)

  for tool_dir in "${selected_tool_dirs[@]}"; do
    run_tool "$tool_dir"
    case "$LAST_RUN_STATUS" in
      applied)
        applied=$((applied + 1))
        ;;
      skipped)
        skipped=$((skipped + 1))
        ;;
    esac
  done

  log_success "Setup finished. Applied: $applied, skipped: $skipped."
}

main "$@"
