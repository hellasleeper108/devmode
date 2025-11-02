#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MCP_CONFIG_DIR="${HOME}/.config/mcp"

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
Usage: install_mcp.sh [options]

Installs and configures Model Context Protocol (MCP) servers.

Options:
  -h, --help         Show this help message
  --filesystem       Install filesystem MCP server
  --github           Install GitHub MCP server
  --postgres         Install PostgreSQL MCP server
  --all              Install all available MCP servers (default)

Examples:
  install_mcp.sh                # Install all MCP servers
  install_mcp.sh --filesystem   # Install only filesystem server
USAGE
}

check_dependencies() {
  if ! command -v node >/dev/null 2>&1 && ! command -v asdf >/dev/null 2>&1; then
    log_error "Node.js is required but not installed"
    log_step "Install Node.js via asdf: asdf plugin add nodejs && asdf install nodejs latest"
    return 1
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log_error "npm is required but not installed"
    return 1
  fi

  return 0
}

install_mcp_filesystem() {
  log_step "Installing MCP filesystem server..."

  local server_dir="${MCP_CONFIG_DIR}/servers/filesystem"
  mkdir -p "$server_dir"

  cat > "${server_dir}/package.json" <<'EOF'
{
  "name": "mcp-server-filesystem",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "latest"
  }
}
EOF

  (cd "$server_dir" && npm install) || {
    log_error "Failed to install MCP filesystem server"
    return 1
  }

  log_success "MCP filesystem server installed"
}

install_mcp_github() {
  log_step "Installing MCP GitHub server..."

  local server_dir="${MCP_CONFIG_DIR}/servers/github"
  mkdir -p "$server_dir"

  cat > "${server_dir}/package.json" <<'EOF'
{
  "name": "mcp-server-github",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "latest",
    "octokit": "latest"
  }
}
EOF

  (cd "$server_dir" && npm install) || {
    log_error "Failed to install MCP GitHub server"
    return 1
  }

  log_success "MCP GitHub server installed"
  log_warn "Remember to configure your GitHub token in the MCP config"
}

install_mcp_postgres() {
  log_step "Installing MCP PostgreSQL server..."

  local server_dir="${MCP_CONFIG_DIR}/servers/postgres"
  mkdir -p "$server_dir"

  cat > "${server_dir}/package.json" <<'EOF'
{
  "name": "mcp-server-postgres",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "latest",
    "pg": "latest"
  }
}
EOF

  (cd "$server_dir" && npm install) || {
    log_error "Failed to install MCP PostgreSQL server"
    return 1
  }

  log_success "MCP PostgreSQL server installed"
  log_warn "Remember to configure your database connection in the MCP config"
}

create_mcp_config() {
  log_step "Creating MCP configuration..."

  mkdir -p "$MCP_CONFIG_DIR"

  cat > "${MCP_CONFIG_DIR}/config.json" <<'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["~/.config/mcp/servers/filesystem/index.js"],
      "env": {}
    },
    "github": {
      "command": "node",
      "args": ["~/.config/mcp/servers/github/index.js"],
      "env": {
        "GITHUB_TOKEN": ""
      }
    },
    "postgres": {
      "command": "node",
      "args": ["~/.config/mcp/servers/postgres/index.js"],
      "env": {
        "DATABASE_URL": ""
      }
    }
  }
}
EOF

  log_success "MCP configuration created at ${MCP_CONFIG_DIR}/config.json"
  log_step "Edit this file to customize your MCP server settings"
}

init_colors

INSTALL_MODE="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --filesystem)
      INSTALL_MODE="filesystem"
      shift
      ;;
    --github)
      INSTALL_MODE="github"
      shift
      ;;
    --postgres)
      INSTALL_MODE="postgres"
      shift
      ;;
    --all)
      INSTALL_MODE="all"
      shift
      ;;
    *)
      log_warn "Unknown option: $1"
      shift
      ;;
  esac
done

log_step "MCP Server Installation (mode: ${INSTALL_MODE})"

if ! check_dependencies; then
  exit 1
fi

case "$INSTALL_MODE" in
  filesystem)
    install_mcp_filesystem
    ;;
  github)
    install_mcp_github
    ;;
  postgres)
    install_mcp_postgres
    ;;
  all)
    install_mcp_filesystem
    install_mcp_github
    install_mcp_postgres
    ;;
esac

create_mcp_config

log_success "MCP server installation completed!"
log_step "MCP servers installed in: ${MCP_CONFIG_DIR}/servers"
log_step "MCP configuration: ${MCP_CONFIG_DIR}/config.json"

exit 0
