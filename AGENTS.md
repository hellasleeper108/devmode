# Repository Guidelines

## Project Structure & Module Organization
- `bootstrap.sh` is the cross-platform entrypoint; it picks `install_linux.sh` or `install_mac.sh`, forwards shared flags, and announces execution steps.
- `bootstrap.ps1` and `install_windows.ps1` mirror the Bash flow for Windows; keep Windows-specific logic isolated there.
- OS installers manage package installation, profile snippets, and template syncing. Place reusable snippets in `config_snippets/` and load them through helpers like `sync_config_file`/`Sync-ConfigFile`.
- Add new bootstrap assets under `config_snippets/` with descriptive filenames; installers should copy or template them rather than duplicating content.

## Build, Test, and Development Commands
- `./bootstrap.sh --dry-run` previews the full Linux/macOS flow without mutations; run before every PR.
- `bash -n bootstrap.sh install_linux.sh install_mac.sh` validates bash syntax for staged changes.
- `shellcheck bootstrap.sh install_linux.sh install_mac.sh` enforces lint and flags unsafe shell patterns.
- `pwsh -File .\bootstrap.ps1 -DryRun` performs the Windows dry run; pair with `pwsh -NoProfile -Command { Invoke-ScriptAnalyzer install_windows.ps1 }` for lint.

## Coding Style & Naming Conventions
- Stick to `set -euo pipefail` and guard optional variables; prefer 2-space indentation and `snake_case` function names in Bash.
- For PowerShell, keep `Set-StrictMode -Version Latest`, favor verb-noun functions (e.g., `Ensure-Winget`), and return early on dry-run paths.
- Log helpers rely on emoji markers; extend them consistently so progress output stays uniform.

## Testing Guidelines
- Exercise both `--dry-run` and live installs inside disposable VMs or containers; capture console output for review.
- Add unit-style coverage via script blocks when practical, but focus on integration verification of idempotent reruns.
- Name any helper scripts `test_<target>.sh` or `Test-<Target>.ps1` and place them at repo root for discoverability.

## Commit & Pull Request Guidelines
- Git history is not tracked here; format new commit messages in imperative mood (`Add Linux distro guard`) and reference affected platform.
- PRs should describe scenarios tested (OS, dry-run vs live), link to related issues, and include any console snippets that capture regressions.

## Security & Configuration Tips
- Review any new download URLs or package IDs with checksums or vendor docs; avoid piping unverified scripts to shell.
- Keep secrets out of installer defaults; surface environment variables instead and document them in the PR.
