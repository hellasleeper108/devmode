#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

init_colors() {
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
}

log_step() { printf "%b⚙️  %s%b\n" "$COL_BLUE" "$1" "$COL_RESET"; }
log_success() { printf "%b✅ %s%b\n" "$COL_GREEN" "$1" "$COL_RESET"; }
log_warn() { printf "%b⚠️  %s%b\n" "$COL_YELLOW" "$1" "$COL_RESET"; }
log_error() { printf "%b✖ %s%b\n" "$COL_RED" "$1" "$COL_RESET"; }

print_usage() {
  cat <<'USAGE'
Usage: update.sh [options]

Updates all dev-bootstrap installed tools to their latest versions.

Options:
  -h, --help         Show this help message
  --system-only      Only update system package manager packages
  --tools-only       Only update binary tools (starship, lazygit, etc.)
  --asdf-only        Only update asdf plugins
  --all              Update everything (default)

Examples:
  update.sh                  # Update everything
  update.sh --system-only    # Only update apt/brew packages
  update.sh --tools-only     # Only update binary tools
USAGE
}

update_system_packages() {
  local os
  os="$(uname -s 2>/dev/null || echo "unknown")"

  case "$os" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        log_step "Updating Homebrew packages..."
        brew update
        brew upgrade
        brew cleanup
        log_success "Homebrew packages updated"
      else
        log_warn "Homebrew not found"
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        log_step "Updating apt packages..."
        sudo apt-get update
        sudo apt-get upgrade -y
        sudo apt-get autoremove -y
        log_success "Apt packages updated"
      elif command -v pacman >/dev/null 2>&1; then
        log_step "Updating pacman packages..."
        sudo pacman -Syu --noconfirm
        log_success "Pacman packages updated"
      else
        log_warn "No supported package manager found"
      fi
      ;;
    *)
      log_warn "Unsupported OS: ${os}"
      ;;
  esac
}

update_asdf() {
  if [[ ! -d "$HOME/.asdf" ]]; then
    log_warn "asdf not installed; skipping"
    return
  fi

  log_step "Updating asdf..."
  if command -v asdf >/dev/null 2>&1; then
    # Source asdf if not already available
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
      # shellcheck disable=SC1091
      source "$HOME/.asdf/asdf.sh"
    fi

    # Update asdf itself
    cd "$HOME/.asdf"
    git fetch --tags
    latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
    git checkout "$latest_tag"
    cd - > /dev/null
    log_success "asdf updated to ${latest_tag}"

    # Update all plugins
    log_step "Updating asdf plugins..."
    asdf plugin update --all
    log_success "asdf plugins updated"
  else
    log_warn "asdf command not available"
  fi
}

update_binary_tools() {
  log_step "Checking for tool updates..."

  # Starship
  if command -v starship >/dev/null 2>&1; then
    log_step "Updating starship..."
    if curl -sS https://starship.rs/install.sh | sh -s -- --yes > /dev/null 2>&1; then
      log_success "Starship updated"
    else
      log_warn "Failed to update starship"
    fi
  fi

  # Lazygit (if installed via binary)
  if command -v lazygit >/dev/null 2>&1 && [[ -f "$HOME/.local/bin/lazygit" ]]; then
    log_step "To update lazygit, run the installer script again"
  fi
}

update_dev_bootstrap() {
  log_step "Updating dev-bootstrap repository..."

  if [[ -d "${SCRIPT_DIR}/.git" ]]; then
    cd "$SCRIPT_DIR"
    git fetch origin
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    git pull origin "$current_branch"
    log_success "dev-bootstrap repository updated"
    cd - > /dev/null
  else
    log_warn "Not a git repository; skipping dev-bootstrap update"
  fi
}

init_colors

UPDATE_MODE="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --system-only)
      UPDATE_MODE="system"
      shift
      ;;
    --tools-only)
      UPDATE_MODE="tools"
      shift
      ;;
    --asdf-only)
      UPDATE_MODE="asdf"
      shift
      ;;
    --all)
      UPDATE_MODE="all"
      shift
      ;;
    *)
      log_warn "Unknown option: $1"
      shift
      ;;
  esac
done

log_step "Starting update process (mode: ${UPDATE_MODE})"

case "$UPDATE_MODE" in
  system)
    update_system_packages
    ;;
  tools)
    update_binary_tools
    ;;
  asdf)
    update_asdf
    ;;
  all)
    update_dev_bootstrap
    update_system_packages
    update_binary_tools
    update_asdf
    ;;
esac

log_success "Update process completed!"
log_warn "Please restart your shell to ensure all updates take effect"

exit 0
