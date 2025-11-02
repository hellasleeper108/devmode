# Developer Terminal Bootstrap

Modern developers bounce between macOS, Linux, WSL, and Windows. This framework provides a single automated bootstrap that detects the host platform, installs a curated CLI toolchain, and applies cohesive shell ergonomics and visuals.

## Features

### Core Features
- ✅ One-command bootstrap (`bootstrap.sh` or `bootstrap.ps1`) with `--dry-run` preview support
- ⚙️ Platform-aware installers for Homebrew, apt/pacman, and winget with WSL detection
- 🔧 Shell hardening for bash, zsh, and PowerShell: history tuning, aliases, fzf/zoxide/direnv/starship wiring, and asdf sourcing
- 🔧 Shared configuration assets (`starship.toml`, `.inputrc`, `.tmux.conf`) synced idempotently
- 🚀 asdf + direnv integration, per-project templates, and post-install version verification

### Extended Toolset
- 📦 **Modern CLI Tools**: neovim, jq, yq, httpie, kubectl, k9s, docker utilities
- 🐍 **Language Support**: Node.js, Python, Go, Rust via asdf plugin system
- 🎨 **Editor Configuration**: Pre-configured Neovim with sensible defaults
- 🔀 **Git Enhancement**: Custom aliases, delta integration, commit templates, global gitignore

### Developer Experience
- 🛠️ **Custom Shell Functions**: 30+ productivity functions (mkcd, extract, killport, docker_cleanup, etc.)
- 📋 **Project Templates**: Ready-to-use templates for Node.js, Python, Go, Rust projects
- 💾 **Backup/Restore**: Save and restore all your configurations with timestamped backups
- 🔄 **Update Management**: Keep all tools up-to-date with a single command
- 🖥️ **Platform Optimizations**: WSL-specific tweaks and macOS optimizations
- 🔌 **MCP Server Support**: Install and configure Model Context Protocol servers

## Quick Start

### Installation

1. Clone or download this repository:
   ```bash
   git clone <repository-url>
   cd devmode
   ```

2. Run the appropriate bootstrap script:

   **macOS, Linux, or WSL:**
   ```bash
   ./bootstrap.sh
   ```

   **Windows (PowerShell 7+ recommended):**
   ```powershell
   pwsh -File .\bootstrap.ps1
   ```

3. Preview changes without installing:
   ```bash
   ./bootstrap.sh --dry-run
   ```

### Post-Installation

After installation, open a new shell session or source your shell config:
```bash
source ~/.bashrc  # or ~/.zshrc
```

## Installed Tools

### Core CLI Tools
- **Shell**: bash, zsh with enhanced history and completion
- **Modern Alternatives**: eza (ls), bat (cat), ripgrep (grep), fd (find), zoxide (cd)
- **Multiplexer**: tmux with custom configuration
- **Fuzzy Finder**: fzf with shell integration
- **Prompt**: starship with custom theme
- **Git**: git-delta, lazygit

### Development Tools
- **Editor**: neovim with sensible defaults
- **Data Tools**: jq, yq for JSON/YAML processing
- **HTTP Client**: httpie for API testing
- **Containers**: docker, docker-compose
- **Kubernetes**: kubectl, k9s

### Language Management
- **asdf**: Universal version manager
- **Languages**: Node.js, Python, Go, Rust (via asdf plugins)
- **Environment**: direnv for per-directory environment variables

## Additional Scripts

### Backup Configuration
Create a timestamped backup of all your configurations:
```bash
./backup.sh
```

Backups are stored in `~/.config/dev-bootstrap/backups/`

### Restore Configuration
List available backups:
```bash
./restore.sh
```

Restore from a specific backup:
```bash
./restore.sh ~/.config/dev-bootstrap/backups/20231201_120000
```

### Update Tools
Update all installed tools:
```bash
./update.sh              # Update everything
./update.sh --system-only  # Only system packages
./update.sh --tools-only   # Only binary tools
./update.sh --asdf-only    # Only asdf plugins
```

### MCP Server Installation
Install Model Context Protocol servers:
```bash
./install_mcp.sh          # Install all MCP servers
./install_mcp.sh --filesystem  # Install only filesystem server
./install_mcp.sh --github      # Install only GitHub server
```

## Custom Shell Functions

The following functions are available after installation:

### Navigation
- `mkcd <dir>` - Create and enter directory
- `up [n]` - Go up n directories (default: 1)

### File Operations
- `extract <file>` - Extract any archive format
- `json_pretty [json]` - Pretty-print JSON
- `yaml_to_json <file>` - Convert YAML to JSON

### Git Helpers
- `git_current_branch` - Get current branch name
- `git_clean_merged` - Delete all merged branches
- `git_uncommit` - Undo last commit (keep changes)

### Development
- `serve [port]` - Start HTTP server (default: 8000)
- `killport <port>` - Kill process on specific port
- `psg <pattern>` - Search processes
- `init_project <type>` - Initialize project (node/python/go/rust/generic)

### Docker
- `docker_cleanup` - Remove unused containers, images, volumes
- `docker_stop_all` - Stop all running containers

### System
- `myip` - Show public IP address
- `localip` - Show local IP addresses
- `sysinfo` - Display system information
- `reload` - Reload shell configuration

### Editor
- `edit_bashrc` - Edit ~/.bashrc
- `edit_zshrc` - Edit ~/.zshrc
- `edit_nvim` - Edit neovim config

## Project Templates

Initialize new projects with pre-configured templates:

```bash
# Available in templates/ directory
templates/
├── nodejs/    # Node.js with package.json, eslint, prettier
├── python/    # Python with venv, pytest, black
├── golang/    # Go with go.mod
├── rust/      # Rust with Cargo.toml
├── react/     # React project template
└── nextjs/    # Next.js project template
```

Copy a template to start a new project:
```bash
cp -r templates/nodejs my-new-project
cd my-new-project
```

## Platform-Specific Features

### WSL (Windows Subsystem for Linux)
- Automatic WSL detection
- Windows interop helpers (explorer, code commands)
- X11 display configuration
- Optimized file permissions

### macOS
- Homebrew integration
- macOS-specific aliases (show_hidden, cleanup_ds)
- Optimized file descriptor limits
- Fixed locale settings

## Configuration Files

All configuration files are stored in:
- `~/.config/dev-bootstrap/` - Main configuration directory
- `~/.config/dev-bootstrap/templates/` - Project templates
- `~/.config/dev-bootstrap/shell_functions.sh` - Custom functions
- `~/.config/dev-bootstrap/backups/` - Configuration backups

## Git Configuration

The installer sets up:
- **Aliases**: st, co, br, ci, lg, graph, amend, undo, sync
- **Diff Tool**: delta with syntax highlighting
- **Commit Template**: Conventional commit format
- **Global Gitignore**: Common files and patterns

View all git aliases:
```bash
git aliases
```

## Customization

### Modifying Shell Functions
Edit the custom functions file:
```bash
nvim ~/.config/dev-bootstrap/shell_functions.sh
```

Then reload your shell:
```bash
reload
```

### Adding Your Own Templates
Add new project templates to the `templates/` directory:
```bash
mkdir -p templates/mytemplate
# Add your template files
```

## Troubleshooting

### Tools not found after installation
Ensure your PATH includes `~/.local/bin`:
```bash
echo $PATH | grep -q ~/.local/bin || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### asdf plugins not working
Source asdf in your shell:
```bash
source ~/.asdf/asdf.sh
```

### Shell configuration not loading
Restart your terminal or source the config:
```bash
source ~/.bashrc  # or ~/.zshrc
```

## Notes

- The installers are idempotent; rerun them anytime to apply updates
- Optional packages (`lazygit`, `delta`, `tmux` via winget, etc.) are attempted but will not block completion if unavailable
- Configuration files are merged, not replaced - your existing settings are preserved
- Backups are created automatically before making changes

## License

MIT

Enjoy your polished terminal! 🚀
