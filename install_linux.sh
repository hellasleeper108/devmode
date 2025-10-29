#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="${SCRIPT_DIR}/config_snippets"
DRY_RUN=0
IS_WSL=0
DISTRO_ID=""
DISTRO_LIKE=""
PKG_MANAGER=""
STARSHIP_VERSION="1.23.0"
LAZYGIT_VERSION="0.44.0"

print_usage() {
  cat <<'USAGE'
Usage: install_linux.sh [--dry-run] [--wsl]

Installs and configures the developer terminal stack on Linux distributions
based on apt (Debian/Ubuntu) or pacman (Arch/Manjaro).
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
  else
    local status=$?
    log_error "Command failed (exit ${status}): $*"
    return $status
  fi
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

detect_distro() {
  if [[ ! -f /etc/os-release ]]; then
    log_error "/etc/os-release not found; cannot detect distribution"
    exit 1
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  DISTRO_ID="${ID:-}"
  DISTRO_LIKE="${ID_LIKE:-}"

  case "$DISTRO_ID" in
    ubuntu|debian|pop|elementary)
      PKG_MANAGER="apt"
      ;;
    arch|manjaro|endeavouros|garuda)
      PKG_MANAGER="pacman"
      ;;
    *)
      if [[ "$DISTRO_LIKE" =~ (debian|ubuntu) ]]; then
        PKG_MANAGER="apt"
      elif [[ "$DISTRO_LIKE" =~ arch ]]; then
        PKG_MANAGER="pacman"
      else
        log_error "Unsupported Linux distribution: ${DISTRO_ID}"
        exit 1
      fi
      ;;
  esac
  log_step "Detected distribution: ${DISTRO_ID} (using ${PKG_MANAGER})"
}

install_packages_apt() {
  local packages=(
    git
    tmux
    ripgrep
    fd-find
    bat
    eza
    fzf
    zoxide
    direnv
    curl
  )
  local optional=(
    git-delta
  )

  log_step "Updating apt package metadata"
  run_cmd sudo apt-get update

  log_step "Installing core toolchain via apt"
  run_cmd sudo apt-get install -y "${packages[@]}"

  log_step "Installing optional niceties via apt"
  for pkg in "${optional[@]}"; do
    if ! run_cmd sudo apt-get install -y "$pkg"; then
      log_warn "Failed to install optional package ${pkg}; continuing"
    fi
  done
}

install_packages_pacman() {
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
    lazygit
    git-delta
    curl
  )

  log_step "Synchronizing pacman package database"
  run_cmd sudo pacman -Syu --noconfirm

  log_step "Installing toolchain via pacman"
  run_cmd sudo pacman -S --needed --noconfirm "${packages[@]}"
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

ensure_fd_symlink() {
  if command -v fd >/dev/null 2>&1; then
    return
  fi
  if ! command -v fdfind >/dev/null 2>&1; then
    return
  fi
  local target
  target="$(command -v fdfind)"
  local link="$HOME/.local/bin/fd"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would symlink fd -> fdfind"
    return
  fi
  ln -sf "$target" "$link"
  log_success "Created fd symlink at ${link}"
}

ensure_bat_symlink() {
  if command -v bat >/dev/null 2>&1; then
    return
  fi
  if ! command -v batcat >/dev/null 2>&1; then
    return
  fi
  local target
  target="$(command -v batcat)"
  local link="$HOME/.local/bin/bat"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would symlink bat -> batcat"
    return
  fi
  ln -sf "$target" "$link"
  log_success "Created bat symlink at ${link}"
}

ensure_starship_binary() {
  if command -v starship >/dev/null 2>&1; then
    return
  fi
  local arch=""
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) arch="aarch64-unknown-linux-gnu" ;;
    armv7l|armv7) arch="armv7-unknown-linux-gnueabihf" ;;
    *)
      log_warn "Unsupported architecture $(uname -m) for starship install; skipping"
      return
      ;;
  esac
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would install starship ${STARSHIP_VERSION} (${arch}) to ${HOME}/.local/bin/starship"
    return
  fi
  log_step "Installing starship (${STARSHIP_VERSION})"
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  local base="https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}"
  local tarball="starship-${arch}.tar.gz"
  local tar_path="${tmp}/${tarball}"
  local sha_path="${tar_path}.sha256"

  curl -fsSLo "$tar_path" "${base}/${tarball}"
  curl -fsSLo "$sha_path" "${base}/${tarball}.sha256"
  (cd "$tmp" && sha256sum --check "$(basename "$sha_path")")
  tar -xzf "$tar_path" -C "$tmp"
  install -Dm755 "${tmp}/starship" "$HOME/.local/bin/starship"
  trap - RETURN
  rm -rf "$tmp"
  log_success "Installed starship ${STARSHIP_VERSION}"
}

ensure_lazygit_binary() {
  if command -v lazygit >/dev/null 2>&1; then
    return
  fi
  local archive_suffix=""
  case "$(uname -m)" in
    x86_64|amd64) archive_suffix="Linux_x86_64" ;;
    aarch64|arm64) archive_suffix="Linux_arm64" ;;
    armv7l|armv7) archive_suffix="Linux_armv7" ;;
    *)
      log_warn "Unsupported architecture $(uname -m) for lazygit install; skipping"
      return
      ;;
  esac
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would install lazygit ${LAZYGIT_VERSION} (${archive_suffix}) to ${HOME}/.local/bin/lazygit"
    return
  fi
  log_step "Installing lazygit (${LAZYGIT_VERSION})"
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  local base="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}"
  local tarball="lazygit_${LAZYGIT_VERSION}_${archive_suffix}.tar.gz"
  local tar_path="${tmp}/${tarball}"
  local checksum_file="${tmp}/checksums.txt"

  curl -fsSLo "$tar_path" "${base}/${tarball}"
  curl -fsSLo "$checksum_file" "${base}/checksums.txt"
  local hash
  hash=$(awk -v name="$tarball" '$2 == name { print $1 }' "$checksum_file")
  if [[ -z "$hash" ]]; then
    log_error "Checksum for ${tarball} not found; aborting lazygit install"
    return 1
  fi
  printf '%s  %s\n' "$hash" "$tarball" > "${tmp}/checksum"
  (cd "$tmp" && sha256sum --check checksum)
  tar -xzf "$tar_path" -C "$tmp" lazygit
  install -Dm755 "${tmp}/lazygit" "$HOME/.local/bin/lazygit"
  trap - RETURN
  rm -rf "$tmp"
  log_success "Installed lazygit ${LAZYGIT_VERSION}"
}

ensure_asdf() {
  local asdf_dir="$HOME/.asdf"
  local asdf_version="v0.14.0"

  if [[ -d "$asdf_dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Would update existing asdf installation"
      return
    fi
    log_step "Refreshing existing asdf checkout"
    run_cmd git -C "$asdf_dir" fetch --tags --quiet
    run_cmd git -C "$asdf_dir" checkout "$asdf_version"
    return
  fi

  log_step "Installing asdf (${asdf_version})"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Would clone https://github.com/asdf-vm/asdf.git ${asdf_dir}"
    return
  fi
  run_cmd git clone https://github.com/asdf-vm/asdf.git "$asdf_dir" --branch "$asdf_version"
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
    log_success "$("$tool" --version | head -n 1)"
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
    --wsl)
      IS_WSL=1
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
log_step "Linux developer terminal provisioning"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log_warn "Dry-run active – no changes will be persisted"
fi
if [[ "$IS_WSL" -eq 1 ]]; then
  log_step "WSL adjustments enabled; ensuring Linux userland is optimized for Windows interop"
fi

detect_distro
case "$PKG_MANAGER" in
  apt) install_packages_apt ;;
  pacman) install_packages_pacman ;;
esac

ensure_local_bin
ensure_fd_symlink
ensure_bat_symlink
ensure_starship_binary
ensure_lazygit_binary
ensure_asdf
ensure_asdf_templates
configure_shells
sync_config_file "${CONFIG_DIR}/inputrc" "$HOME/.inputrc"
sync_config_file "${CONFIG_DIR}/tmux.conf" "$HOME/.tmux.conf"
sync_config_file "${CONFIG_DIR}/starship.toml" "$HOME/.config/starship.toml"
run_direnv_allow
print_versions
print_banner
exit 0
