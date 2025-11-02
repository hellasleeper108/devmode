#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BACKUP_DIR="${HOME}/.config/dev-bootstrap/backups/$(date +%Y%m%d_%H%M%S)"

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
Usage: backup.sh

Backs up all dev-bootstrap managed configuration files to a timestamped directory.

The backup includes:
- Shell configuration files (.bashrc, .zshrc)
- Git configuration (.gitconfig, .gitignore_global)
- Editor configuration (.config/nvim)
- Tool configurations (.tmux.conf, .config/starship.toml)
- asdf configuration (.tool-versions, .envrc)

Backups are stored in: ~/.config/dev-bootstrap/backups/
USAGE
}

backup_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$src" ]] && [[ ! -d "$src" ]]; then
    log_warn "Skipping ${src} (not found)"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  if cp -r "$src" "$dest" 2>/dev/null; then
    log_success "Backed up ${src}"
  else
    log_warn "Failed to backup ${src}"
  fi
}

init_colors

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

log_step "Creating backup directory: ${BACKUP_DIR}"
mkdir -p "$BACKUP_DIR"

log_step "Backing up configuration files..."

# Shell configs
backup_file "$HOME/.bashrc" "${BACKUP_DIR}/.bashrc"
backup_file "$HOME/.zshrc" "${BACKUP_DIR}/.zshrc"
backup_file "$HOME/.bash_profile" "${BACKUP_DIR}/.bash_profile"
backup_file "$HOME/.profile" "${BACKUP_DIR}/.profile"

# Git configs
backup_file "$HOME/.gitconfig" "${BACKUP_DIR}/.gitconfig"
backup_file "$HOME/.gitconfig.devmode" "${BACKUP_DIR}/.gitconfig.devmode"
backup_file "$HOME/.gitignore_global" "${BACKUP_DIR}/.gitignore_global"
backup_file "$HOME/.gitmessage" "${BACKUP_DIR}/.gitmessage"

# Editor configs
backup_file "$HOME/.config/nvim" "${BACKUP_DIR}/.config/nvim"
backup_file "$HOME/.vimrc" "${BACKUP_DIR}/.vimrc"

# Tool configs
backup_file "$HOME/.tmux.conf" "${BACKUP_DIR}/.tmux.conf"
backup_file "$HOME/.config/starship.toml" "${BACKUP_DIR}/.config/starship.toml"
backup_file "$HOME/.inputrc" "${BACKUP_DIR}/.inputrc"

# asdf/direnv
backup_file "$HOME/.tool-versions" "${BACKUP_DIR}/.tool-versions"
backup_file "$HOME/.envrc" "${BACKUP_DIR}/.envrc"

# Dev-bootstrap configs
backup_file "$HOME/.config/dev-bootstrap/shell_functions.sh" "${BACKUP_DIR}/.config/dev-bootstrap/shell_functions.sh"
backup_file "$HOME/.config/dev-bootstrap/templates" "${BACKUP_DIR}/.config/dev-bootstrap/templates"

# Create manifest
cat > "${BACKUP_DIR}/manifest.txt" <<EOF
Backup created: $(date)
Hostname: $(hostname)
User: $(whoami)
OS: $(uname -s)
Backup directory: ${BACKUP_DIR}
EOF

log_success "Backup completed successfully!"
log_step "Backup location: ${BACKUP_DIR}"

# List backup size
if command -v du >/dev/null 2>&1; then
  BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
  log_step "Backup size: ${BACKUP_SIZE}"
fi

exit 0
