#!/usr/bin/env bash
# Custom shell functions - Managed by dev-bootstrap

# Git helpers
git_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

git_clean_merged() {
  git branch --merged | grep -v "\*" | grep -v "main" | grep -v "master" | xargs -r git branch -d
}

git_uncommit() {
  git reset --soft HEAD~1
}

# Directory navigation
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

up() {
  local levels="${1:-1}"
  local path=""
  for ((i=0; i<levels; i++)); do
    path="../$path"
  done
  cd "$path" || return
}

# File operations
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar x "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Process helpers
psg() {
  ps aux | grep -v grep | grep -i -e VSZ -e "$@"
}

killport() {
  local port="$1"
  if [ -z "$port" ]; then
    echo "Usage: killport <port>"
    return 1
  fi
  local pid
  pid=$(lsof -ti:"$port")
  if [ -n "$pid" ]; then
    echo "Killing process $pid on port $port"
    kill -9 "$pid"
  else
    echo "No process found on port $port"
  fi
}

# Development helpers
serve() {
  local port="${1:-8000}"
  python3 -m http.server "$port"
}

json_pretty() {
  if [ -t 0 ]; then
    # Input is from argument
    echo "$1" | jq '.'
  else
    # Input is from pipe
    jq '.'
  fi
}

yaml_to_json() {
  if command -v yq >/dev/null 2>&1; then
    yq eval -o=json "$@"
  else
    echo "yq is not installed"
    return 1
  fi
}

# Docker helpers
docker_cleanup() {
  echo "Removing stopped containers..."
  docker container prune -f
  echo "Removing dangling images..."
  docker image prune -f
  echo "Removing unused volumes..."
  docker volume prune -f
  echo "Removing unused networks..."
  docker network prune -f
}

docker_stop_all() {
  docker stop $(docker ps -q)
}

# Network helpers
myip() {
  curl -s https://api.ipify.org
}

localip() {
  if command -v ip >/dev/null 2>&1; then
    ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1
  else
    ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
  fi
}

# History search
h() {
  if [ -z "$1" ]; then
    history
  else
    history | grep "$@"
  fi
}

# Quick edit config files
edit_bashrc() {
  ${EDITOR:-nvim} ~/.bashrc
}

edit_zshrc() {
  ${EDITOR:-nvim} ~/.zshrc
}

edit_nvim() {
  ${EDITOR:-nvim} ~/.config/nvim/init.vim
}

# Reload shell config
reload() {
  if [ -n "$BASH_VERSION" ]; then
    source ~/.bashrc
    echo "Reloaded ~/.bashrc"
  elif [ -n "$ZSH_VERSION" ]; then
    source ~/.zshrc
    echo "Reloaded ~/.zshrc"
  fi
}

# System info
sysinfo() {
  echo "=== System Information ==="
  echo "OS: $(uname -s)"
  echo "Kernel: $(uname -r)"
  echo "Architecture: $(uname -m)"
  if [ -f /etc/os-release ]; then
    echo "Distribution: $(grep '^NAME=' /etc/os-release | cut -d'"' -f2)"
    echo "Version: $(grep '^VERSION=' /etc/os-release | cut -d'"' -f2)"
  fi
  echo "Hostname: $(hostname)"
  echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
}

# Path manipulation
path() {
  echo "$PATH" | tr ':' '\n'
}

# Project initialization helper
init_project() {
  local project_type="${1:-generic}"
  local project_name="${2:-$(basename $(pwd))}"

  case "$project_type" in
    node|nodejs)
      echo "Initializing Node.js project..."
      npm init -y
      echo "node_modules/" >> .gitignore
      git init
      ;;
    python|py)
      echo "Initializing Python project..."
      python3 -m venv venv
      echo "venv/" >> .gitignore
      echo "__pycache__/" >> .gitignore
      echo "*.pyc" >> .gitignore
      git init
      ;;
    go|golang)
      echo "Initializing Go project..."
      go mod init "$project_name"
      git init
      ;;
    rust)
      echo "Initializing Rust project..."
      cargo init
      ;;
    *)
      echo "Initializing generic project..."
      git init
      touch README.md
      echo "# $project_name" > README.md
      ;;
  esac

  echo "Project initialized: $project_name"
}
