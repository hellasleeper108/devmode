# Developer Terminal Bootstrap

Modern developers bounce between macOS, Linux, WSL, and Windows. This framework provides a single automated bootstrap that detects the host platform, installs a curated CLI toolchain, and applies cohesive shell ergonomics and visuals.

## Features

- ✅ One-command bootstrap (`bootstrap.sh` or `bootstrap.ps1`) with `--dry-run` preview support.
- ⚙️ Platform-aware installers for Homebrew, apt/pacman, and winget with WSL detection.
- 🔧 Shell hardening for bash, zsh, and PowerShell: history tuning, aliases, fzf/zoxide/direnv/starship wiring, and asdf sourcing.
- 🔧 Shared configuration assets (`starship.toml`, `.inputrc`, `.tmux.conf`) synced idempotently.
- 🚀 asdf + direnv integration, per-project templates, and post-install version verification.

## Usage

1. Clone or download this repository.
2. Run the appropriate bootstrap script:
   - macOS, Linux, or WSL:
     ```bash
     ./bootstrap.sh
     ```
   - Windows (PowerShell 7+ recommended):
     ```powershell
     pwsh -File .\bootstrap.ps1
     ```
3. Add `--dry-run` to preview actions without executing them.

## Notes

- The installers are idempotent; rerun them anytime to apply updates.
- Optional packages (`lazygit`, `delta`, `tmux` via winget, etc.) are attempted but will not block completion if unavailable.
- After installation, open a new shell session to pick up the refreshed RC files and starship prompt.

Enjoy your polished terminal!
