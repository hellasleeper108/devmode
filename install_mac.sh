#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="${SCRIPT_DIR}/config_snippets"
DRY_RUN=0

print_usage() {
  cat <<'USAGE'
Usage: install_mac.sh [--dry-run]

Installs and configures the developer terminal stack on macOS.
USAGE
}

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
log_info() { printf "%b🔧 %s%b\n" "$COL_BLUE" "$1" "$COL_RESET"; }
log_success() { printf "%b✅ %s%b\n" "$COL_GREEN" "$1" "$COL_RESET"; }
log_warn() { printf "%b⚠️  %s%b\n" "$COL_YELLOW" "$1" "$COL_RESET"; }
log_error() { printf "%b✖ %s%b\n" "$COL_RED" "$1" "$COL_RESET"; }

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] $*"
    return 0
  fi
  log_info "Running: $*"
  if "$@"; then
    return 0
  fi
  local status=$?
  log_error "Command failed (exit ${status}): $*"
  return $status
}

write_file_if_diff() {
  local dest="$1"
  local content="$2"
  local dest_dir
  dest_dir=$(dirname "$dest")

  if [[ -f "$dest" ]]; then
    if diff -q "$dest" <(printf '%s\n' "$content") >/dev/null 2>&1; then
      log_success "${dest} already up to date"
      return 0
    fi
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would update ${dest}"
    return 0
  fi

  mkdir -p "$dest_dir"
  printf '%s\n' "$content" > "$dest"
  log_success "Updated ${dest}"
}

sync_config_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$src" ]]; then
    log_error "Missing config source: ${src}"
    return 1
  fi

  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    log_success "${dest} already matches template"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would copy ${src} -> ${dest}"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  log_success "Wrote ${dest}"
}

ensure_shell_snippet() {
  local rc_file="$1"
  local marker="$2"
  local snippet="$3"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$(dirname "$rc_file")"
  fi

  if [[ -f "$rc_file" ]] && grep -Fq "# >>> ${marker} >>>" "$rc_file"; then
    log_success "${rc_file} already contains ${marker}"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would append ${marker} block to ${rc_file}"
    return 0
  fi

  {
    printf '\n# >>> %s >>>\n' "$marker"
    printf '%s\n' "$snippet"
    printf '# <<< %s <<<\n' "$marker"
  } >> "$rc_file"

  log_success "Added ${marker} to ${rc_file}"
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log_success "Homebrew is already installed"
    return 0
  fi

  log_step "Installing Homebrew via official script"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would run Homebrew installer"
    return 0
  fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  log_success "Homebrew installation complete"

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_brew_shellenv() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Would evaluate Homebrew shell environment"
    else
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  elif [[ -x "/usr/local/bin/brew" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Would evaluate Homebrew shell environment"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    log_warn "Homebrew binary not found in standard locations; PATH may need manual adjustment"
  fi
}

install_brew_packages() {
  local packages=(
    git
    tmux
    ripgrep
    fd
    bat
    eza
    fzf
    zoxide
    direnv
    starship
    asdf
  )

  local optional_packages=(
    lazygit
    git-delta
  )

  log_step "Updating Homebrew 🍺"
  run_cmd brew update

  log_step "Installing core toolchain"
  for pkg in "${packages[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      log_success "brew ${pkg} already installed"
      continue
    fi
    run_cmd brew install "$pkg"
  done

  log_step "Installing optional niceties"
  for pkg in "${optional_packages[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      log_success "brew ${pkg} already installed"
      continue
    fi
    if ! run_cmd brew install "$pkg"; then
      log_warn "Unable to install optional package ${pkg}; continuing"
    fi
  done
}

configure_fzf_keybindings() {
  local fzf_prefix
  if ! command -v fzf >/dev/null 2>&1; then
    log_warn "fzf not installed; skipping keybinding bootstrap"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    fzf_prefix="$(brew --prefix fzf 2>/dev/null || true)"
    if [[ -n "$fzf_prefix" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[dry-run] Would refresh fzf shell integrations"
        return
      fi
      "${fzf_prefix}/install" --key-bindings --completion --no-update-rc
      log_success "fzf keybindings refreshed"
      return
    fi
  fi

  log_warn "Unable to determine fzf install path for keybindings"
}

ensure_local_bin() {
  local dir="$HOME/.local/bin"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would ensure ${dir} exists"
    return
  fi
  mkdir -p "$dir"
  log_success "Ensured ${dir} exists"
}

ensure_asdf_templates() {
  local template_dir="$HOME/.config/dev-bootstrap/templates"
  local tool_versions_dest="${template_dir}/.tool-versions"
  local envrc_dest="${template_dir}/.envrc"
  local tool_versions_content="# Managed by dev-bootstrap
# Populate language versions with \`asdf install\`
"
  local envrc_content="use asdf
export NODE_OPTIONS=--max-old-space-size=8192
"

  write_file_if_diff "$tool_versions_dest" "$tool_versions_content"
  write_file_if_diff "$envrc_dest" "$envrc_content"

  if [[ ! -f "$HOME/.tool-versions" ]]; then
    write_file_if_diff "$HOME/.tool-versions" "$tool_versions_content"
  fi

  if [[ ! -f "$HOME/.envrc" ]]; then
    write_file_if_diff "$HOME/.envrc" "$envrc_content"
  fi
}

run_direnv_allow() {
  if ! command -v direnv >/dev/null 2>&1; then
    log_warn "direnv command not found; skipping automatic allow"
    return
  fi
  if [[ ! -f "$HOME/.envrc" ]]; then
    log_warn "~/.envrc not present; skipping direnv allow"
    return
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would run 'direnv allow' in ${HOME}"
    return
  fi
  (cd "$HOME" && direnv allow)
  log_success "direnv allow applied in ${HOME}"
}

configure_shells() {
  local bash_rc="$HOME/.bashrc"
  local zsh_rc="$HOME/.zshrc"

  local bash_snippet
  bash_snippet=$(cat <<'BASH'
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=200000
export HISTFILESIZE=400000
shopt -s histappend
shopt -s cmdhist
shopt -s checkwinsize
export PATH="$HOME/.local/bin:$PATH"
alias ls='eza -al --group-directories-first --git'
alias ll='eza -l --git'
alias cat='bat'
alias grep='rg'
alias find='fd'
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash || true)"
fi
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash || true)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash || true)"
fi
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash || true)"
fi
if [ -f "${HOME}/.asdf/asdf.sh" ]; then
  . "${HOME}/.asdf/asdf.sh"
elif command -v brew >/dev/null 2>&1; then
  ASDF_PREFIX="$(brew --prefix asdf 2>/dev/null || true)"
  if [ -n "$ASDF_PREFIX" ] && [ -f "${ASDF_PREFIX}/libexec/asdf.sh" ]; then
    . "${ASDF_PREFIX}/libexec/asdf.sh"
  fi
fi
if [ -f "${HOME}/.asdf/completions/asdf.bash" ]; then
  . "${HOME}/.asdf/completions/asdf.bash"
fi
BASH
)

  local zsh_snippet
  zsh_snippet=$(cat <<'ZSH'
HISTSIZE=200000
SAVEHIST=400000
HISTFILE="$HOME/.zsh_history"
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
export PATH="$HOME/.local/bin:$PATH"
alias ls='eza -al --group-directories-first --git'
alias ll='eza -l --git'
alias cat='bat'
alias grep='rg'
alias find='fd'
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh || true)"
fi
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh || true)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh || true)"
fi
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh || true)"
fi
if [[ -f "${HOME}/.asdf/asdf.sh" ]]; then
  source "${HOME}/.asdf/asdf.sh"
elif command -v brew >/dev/null 2>&1; then
  ASDF_PREFIX="$(brew --prefix asdf 2>/dev/null || true)"
  if [[ -n "$ASDF_PREFIX" && -f "${ASDF_PREFIX}/libexec/asdf.sh" ]]; then
    source "${ASDF_PREFIX}/libexec/asdf.sh"
  fi
fi
if [[ -f "${HOME}/.asdf/completions/asdf.zsh" ]]; then
  source "${HOME}/.asdf/completions/asdf.zsh"
fi
ZSH
)

  ensure_shell_snippet "$bash_rc" "dev-bootstrap core" "$bash_snippet"
  ensure_shell_snippet "$zsh_rc" "dev-bootstrap core" "$zsh_snippet"
}

print_versions() {
  local tools=(
    git
    tmux
    rg
    fd
    bat
    eza
    fzf
    zoxide
    direnv
    starship
    asdf
    lazygit
    delta
  )
  log_step "Verifying tool versions"
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      log_warn "$tool is not installed or not on PATH"
      continue
    fi
    case "$tool" in
      git|tmux|rg|fd|bat|eza|fzf|zoxide|direnv|starship|asdf|lazygit|delta)
        log_success "$("$tool" --version | head -n 1)"
        ;;
      *)
        log_success "$tool detected"
        ;;
    esac
  done
}

print_banner() {
  printf "%b🔥 Developer Terminal Ready 🔥%b\n" "$COL_GREEN" "$COL_RESET"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      log_warn "Unknown option ignored: $1"
      shift
      ;;
  esac
done

init_colors
log_step "macOS developer terminal provisioning"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log_warn "Dry-run active - no changes will be persisted"
fi

ensure_homebrew
ensure_brew_shellenv
install_brew_packages
configure_fzf_keybindings
ensure_local_bin
configure_shells
sync_config_file "${CONFIG_DIR}/inputrc" "$HOME/.inputrc"
sync_config_file "${CONFIG_DIR}/tmux.conf" "$HOME/.tmux.conf"
sync_config_file "${CONFIG_DIR}/starship.toml" "$HOME/.config/starship.toml"
ensure_asdf_templates
run_direnv_allow
print_versions
print_banner
exit 0
