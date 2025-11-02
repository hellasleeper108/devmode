#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BACKUP_ROOT="${HOME}/.config/dev-bootstrap/backups"

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
Usage: restore.sh [backup_directory]

Restores configuration files from a backup directory.

If no backup directory is specified, lists available backups.

Options:
  -h, --help    Show this help message
  -l, --list    List available backups

Examples:
  restore.sh                              # List available backups
  restore.sh ~/.config/dev-bootstrap/backups/20231201_120000
USAGE
}

list_backups() {
  if [[ ! -d "$BACKUP_ROOT" ]]; then
    log_warn "No backups found at ${BACKUP_ROOT}"
    return
  fi

  log_step "Available backups:"
  local count=0
  while IFS= read -r -d '' backup_dir; do
    count=$((count + 1))
    local manifest="${backup_dir}/manifest.txt"
    if [[ -f "$manifest" ]]; then
      echo ""
      printf "%b[%d] %s%b\n" "$COL_GREEN" "$count" "$(basename "$backup_dir")" "$COL_RESET"
      grep "Backup created:" "$manifest" || true
      if command -v du >/dev/null 2>&1; then
        printf "    Size: %s\n" "$(du -sh "$backup_dir" | cut -f1)"
      fi
    else
      printf "%b[%d] %s%b\n" "$COL_YELLOW" "$count" "$(basename "$backup_dir")" "$COL_RESET"
    fi
  done < <(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -print0 | sort -rz)

  if [[ $count -eq 0 ]]; then
    log_warn "No backups found"
  fi
}

restore_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$src" ]] && [[ ! -d "$src" ]]; then
    return
  fi

  mkdir -p "$(dirname "$dest")"
  if cp -r "$src" "$dest" 2>/dev/null; then
    log_success "Restored ${dest}"
  else
    log_warn "Failed to restore ${dest}"
  fi
}

init_colors

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

if [[ "${1:-}" == "-l" ]] || [[ "${1:-}" == "--list" ]] || [[ -z "${1:-}" ]]; then
  list_backups
  exit 0
fi

BACKUP_DIR="$1"

if [[ ! -d "$BACKUP_DIR" ]]; then
  log_error "Backup directory not found: ${BACKUP_DIR}"
  echo ""
  list_backups
  exit 1
fi

log_step "Restoring from: ${BACKUP_DIR}"

# Show manifest
if [[ -f "${BACKUP_DIR}/manifest.txt" ]]; then
  echo ""
  cat "${BACKUP_DIR}/manifest.txt"
  echo ""
fi

# Confirm restoration
read -p "Continue with restoration? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  log_warn "Restoration cancelled"
  exit 0
fi

log_step "Restoring configuration files..."

# Shell configs
restore_file "${BACKUP_DIR}/.bashrc" "$HOME/.bashrc"
restore_file "${BACKUP_DIR}/.zshrc" "$HOME/.zshrc"
restore_file "${BACKUP_DIR}/.bash_profile" "$HOME/.bash_profile"
restore_file "${BACKUP_DIR}/.profile" "$HOME/.profile"

# Git configs
restore_file "${BACKUP_DIR}/.gitconfig" "$HOME/.gitconfig"
restore_file "${BACKUP_DIR}/.gitconfig.devmode" "$HOME/.gitconfig.devmode"
restore_file "${BACKUP_DIR}/.gitignore_global" "$HOME/.gitignore_global"
restore_file "${BACKUP_DIR}/.gitmessage" "$HOME/.gitmessage"

# Editor configs
restore_file "${BACKUP_DIR}/.config/nvim" "$HOME/.config/nvim"
restore_file "${BACKUP_DIR}/.vimrc" "$HOME/.vimrc"

# Tool configs
restore_file "${BACKUP_DIR}/.tmux.conf" "$HOME/.tmux.conf"
restore_file "${BACKUP_DIR}/.config/starship.toml" "$HOME/.config/starship.toml"
restore_file "${BACKUP_DIR}/.inputrc" "$HOME/.inputrc"

# asdf/direnv
restore_file "${BACKUP_DIR}/.tool-versions" "$HOME/.tool-versions"
restore_file "${BACKUP_DIR}/.envrc" "$HOME/.envrc"

# Dev-bootstrap configs
restore_file "${BACKUP_DIR}/.config/dev-bootstrap/shell_functions.sh" "$HOME/.config/dev-bootstrap/shell_functions.sh"
restore_file "${BACKUP_DIR}/.config/dev-bootstrap/templates" "$HOME/.config/dev-bootstrap/templates"

log_success "Restoration completed successfully!"
log_warn "Please restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to apply changes"

exit 0
