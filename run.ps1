$DryRun = $true

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $ScriptDir "config_snippets"

function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    $currentColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Message
    $Host.UI.RawUI.ForegroundColor = $currentColor
}

function Write-Step { param([string]$Message) Write-Log "⚙️  $Message" ([ConsoleColor]::Cyan) }
function Write-Info { param([string]$Message) Write-Log "I $Message" ([ConsoleColor]::Cyan) }
function Write-Success { param([string]$Message) Write-Log "✅ $Message" ([ConsoleColor]::Green) }
function Write-Warn { param([string]$Message) Write-Log "⚠️  $Message" ([ConsoleColor]::Yellow) }
function Write-ErrorLog { param([string]$Message) Write-Log "✖ $Message" ([ConsoleColor]::Red) }

function Invoke-Step {
    param(
        [ScriptBlock]$Action,
        [string]$Description,
        [switch]$AllowFailure
    )
    if ($DryRun) {
        Write-Info "[dry-run] $Description"
        return
    }
    Write-Info $Description
    try {
        & $Action
    } catch {
        if ($AllowFailure) {
            Write-Warn "$Description failed ($($_.Exception.Message)); continuing"
        } else {
            throw
        }
    }
}

function Ensure-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Success "winget is available"
        return
    }
    Write-ErrorLog "winget is required but not found. Install App Installer from Microsoft Store."
    throw "winget missing"
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$DisplayName,
        [switch]$Optional
    )
    Invoke-Step -Description "Installing $DisplayName ($Id)" -AllowFailure:$Optional -Action {
        winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Null
    }
}

function Sync-ConfigFile {
    param(
        [string]$Source,
        [string]$Destination
    )
    if (-not (Test-Path $Source)) {
        Write-ErrorLog "Missing config source: $Source"
        return
    }
    $destDir = Split-Path $Destination -Parent
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    if ((Test-Path $Destination) -and ((Get-Content -Raw $Source) -eq (Get-Content -Raw $Destination))) {
        Write-Success "$Destination already matches template"
        return
    }
    if ($DryRun) {
        Write-Info "[dry-run] Would copy $Source -> $Destination"
        return
    }
    Copy-Item $Source $Destination -Force
    Write-Success "Wrote $Destination"
}

Write-Step "Developer terminal bootstrap starting"
if ($DryRun) {
    Write-Warn "Dry-run mode enabled; no changes will be applied"
}

Write-Step "Windows developer terminal provisioning"
if ($DryRun) {
    Write-Warn "Dry-run active - no changes will be persisted"
}

Ensure-Winget

$packages = @(
    @{ Id = "Git.Git"; Name = "Git"; Optional = $false },
    @{ Id = "BurntSushi.ripgrep.MSVC"; Name = "ripgrep"; Optional = $false },
    @{ Id = "sharkdp.fd"; Name = "fd"; Optional = $false },
    @{ Id = "sharkdp.bat"; Name = "bat"; Optional = $false },
    @{ Id = "eza-community.eza"; Name = "eza"; Optional = $false },
    @{ Id = "junegunn.fzf"; Name = "fzf"; Optional = $false },
    @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide"; Optional = $false },
    @{ Id = "direnv.direnv"; Name = "direnv"; Optional = $true },
    @{ Id = "Starship.Starship"; Name = "starship"; Optional = $false },
    @{ Id = "JesseDuffield.lazygit"; Name = "lazygit"; Optional = $true },
    @{ Id = "dandavison.delta"; Name = "delta"; Optional = $true }
)

Write-Step "Installing toolchain via winget"
foreach ($pkg in $packages) {
    Install-WingetPackage -Id $pkg.Id -DisplayName $pkg.Name -Optional:$pkg.Optional
}

Sync-ConfigFile -Source (Join-Path $ConfigDir "inputrc") -Destination (Join-Path $env:USERPROFILE ".inputrc")
Sync-ConfigFile -Source (Join-Path $ConfigDir "tmux.conf") -Destination (Join-Path $env:USERPROFILE ".tmux.conf")
Sync-ConfigFile -Source (Join-Path $ConfigDir "starship.toml") -Destination (Join-Path $env:USERPROFILE ".config\starship.toml")

exit 0