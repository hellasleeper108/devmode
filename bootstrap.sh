#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DRY_RUN=0
FORWARD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

if command -v tput >/dev/null 2>&1; then
  COL_BLUE="$(tput setaf 4)"
  COL_GREEN="$(tput setaf 2)"
  COL_YELLOW="$(tput setaf 3)"
  COL_RED="$(tput setaf 1)"
  COL_RESET="$(tput sgr0)"
else
  COL_BLUE="\033[34m"
  COL_GREEN="\033[32m"
  COL_YELLOW="\033[33m"
  COL_RED="\033[31m"
  COL_RESET="\033[0m"
fi

log_step() { printf "%b⚙️  %s%b\n" "$COL_BLUE" "$1" "$COL_RESET"; }
log_success() { printf "%b✅ %s%b\n" "$COL_GREEN" "$1" "$COL_RESET"; }
log_warn() { printf "%b⚠️  %s%b\n" "$COL_YELLOW" "$1" "$COL_RESET"; }
log_error() { printf "%b✖ %s%b\n" "$COL_RED" "$1" "$COL_RESET"; }

log_step "Developer terminal bootstrap starting"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log_warn "Dry-run mode enabled; no changes will be applied"
  FORWARD_ARGS+=("--dry-run")
fi

OS="$(uname -s 2>/dev/null || echo "unknown")"
IS_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=1
fi

case "$OS" in
  Darwin)
    TARGET="${SCRIPT_DIR}/install_mac.sh"
    PLATFORM_LABEL="macOS"
    ;;
  Linux)
    TARGET="${SCRIPT_DIR}/install_linux.sh"
    PLATFORM_LABEL="Linux"
    ;;
  *)
    log_error "Unsupported platform detected (${OS}). Use bootstrap.ps1 for native Windows."
    exit 1
    ;;
esac

if [[ "$IS_WSL" -eq 1 ]]; then
  log_step "WSL environment detected; using Linux installer with WSL-specific tweaks"
  FORWARD_ARGS+=("--wsl")
fi

if [[ ! -x "$TARGET" ]]; then
  log_error "Installer not executable: $TARGET"
  exit 1
fi

log_step "Dispatching to ${PLATFORM_LABEL} installer 🚀"
"$TARGET" "${FORWARD_ARGS[@]}"

STATUS=$?
if [[ $STATUS -eq 0 ]]; then
  log_success "Installer completed successfully"
else
  log_error "Installer failed with exit code $STATUS"
fi

exit $STATUS
