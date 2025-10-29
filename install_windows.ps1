[CmdletBinding()]
param(
    [switch]$DryRun
)

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
function Write-Info { param([string]$Message) Write-Log "🔧 $Message" ([ConsoleColor]::Cyan) }
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

function Write-FileIfDiff {
    param(
        [string]$Destination,
        [string]$Content
    )
    $destDir = Split-Path $Destination -Parent
    if ($DryRun) {
        if ((Test-Path $Destination) -and ((Get-Content -Raw $Destination) -eq $Content)) {
            Write-Success "$Destination already up to date"
        } else {
            Write-Info "[dry-run] Would ensure $destDir exists and update $Destination"
        }
        return
    }
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    if ((Test-Path $Destination) -and ((Get-Content -Raw $Destination) -eq $Content)) {
        Write-Success "$Destination already up to date"
        return
    }
    [System.IO.File]::WriteAllText($Destination, $Content, [System.Text.Encoding]::UTF8)
    Write-Success "Updated $Destination"
}

function Add-ProfileSnippet {
    param(
        [string]$Marker,
        [string]$Snippet
    )
    $profileDir = Split-Path $PROFILE -Parent
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    }
    $startMarker = "# BEGIN $Marker"
    if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -SimpleMatch $startMarker -ErrorAction SilentlyContinue)) {
        Write-Success "$PROFILE already contains $Marker"
        return
    }
    if ($DryRun) {
        Write-Info "[dry-run] Would append $Marker block to $PROFILE"
        return
    }
    $endMarker = "# END $Marker"
    $block = @(
        $startMarker
        $Snippet
        $endMarker
    ) -join "`n"
    Add-Content -Path $PROFILE -Value "`n$block"
    Write-Success "Added $Marker to $PROFILE"
}

function Ensure-Asdf {
    $asdfVersion = "v0.14.0"
    $asdfDir = Join-Path $env:USERPROFILE ".asdf"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warn "git is required to manage asdf; skipping asdf install"
        return
    }
    if (Test-Path $asdfDir) {
        Invoke-Step -Description "Updating asdf checkout to $asdfVersion" -Action {
            git -C $asdfDir fetch --tags --quiet
            git -C $asdfDir checkout --quiet $asdfVersion
        }
        return
    }
    Invoke-Step -Description "Cloning asdf ($asdfVersion)" -Action {
        git clone https://github.com/asdf-vm/asdf.git $asdfDir --branch $asdfVersion
    }
}

function Ensure-Templates {
    $templateDir = Join-Path $env:USERPROFILE ".config\dev-bootstrap\templates"
    $toolVersions = @'
# Managed by dev-bootstrap
# Populate language versions with `asdf install`
'@
    $envrc = @'
use asdf
export NODE_OPTIONS=--max-old-space-size=8192
'@
    Write-FileIfDiff -Destination (Join-Path $templateDir ".tool-versions") -Content $toolVersions
    Write-FileIfDiff -Destination (Join-Path $templateDir ".envrc") -Content $envrc

    if (-not (Test-Path (Join-Path $env:USERPROFILE ".tool-versions"))) {
        Write-FileIfDiff -Destination (Join-Path $env:USERPROFILE ".tool-versions") -Content $toolVersions
    }
    if (-not (Test-Path (Join-Path $env:USERPROFILE ".envrc"))) {
        Write-FileIfDiff -Destination (Join-Path $env:USERPROFILE ".envrc") -Content $envrc
    }
}

function Run-DirenvAllow {
    if (-not (Get-Command direnv -ErrorAction SilentlyContinue)) {
        Write-Warn "direnv command not found; skipping automatic allow"
        return
    }
    $homeEnvrc = Join-Path $env:USERPROFILE ".envrc"
    if (-not (Test-Path $homeEnvrc)) {
        Write-Warn "$homeEnvrc not present; skipping direnv allow"
        return
    }
    Invoke-Step -Description "direnv allow in $env:USERPROFILE" -Action {
        Push-Location $env:USERPROFILE
        direnv allow | Out-Null
        Pop-Location
    }
}

function Configure-Profile {
    $snippet = @'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSStyle.OutputRendering = "Ansi"

Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -MaximumHistoryCount 200000
Set-PSReadLineKeyHandler -Key "Ctrl+Spacebar" -Function MenuComplete

function Set-DevBootstrapAliases {
    Set-Alias ls eza -ErrorAction SilentlyContinue
    function ll { param([Parameter(ValueFromRemainingArguments=$true)]$Args) eza -l --git @Args }
    function la { param([Parameter(ValueFromRemainingArguments=$true)]$Args) eza -al --group-directories-first --git @Args }
    Set-Alias cat bat -ErrorAction SilentlyContinue
    Set-Alias grep rg -ErrorAction SilentlyContinue
    Set-Alias find fd -ErrorAction SilentlyContinue
}
Set-DevBootstrapAliases

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $fzfInit = & fzf --powershell 2>$null
    if ($LASTEXITCODE -eq 0 -and $fzfInit) {
        Invoke-Expression $fzfInit
    } else {
        Write-Verbose "fzf PowerShell bindings not available; skipping"
    }
}
if (Get-Command direnv -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (direnv hook powershell | Out-String) })
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
if (Test-Path "$env:USERPROFILE\.asdf\asdf.ps1") {
    . "$env:USERPROFILE\.asdf\asdf.ps1"
}
'@
    Add-ProfileSnippet -Marker "dev-bootstrap core" -Snippet $snippet
}

function Print-Versions {
    $tools = @(
        @{ Name = "git"; Optional = $false; Test = { & git --version } },
        @{ Name = "ripgrep"; Optional = $false; Test = { & rg --version } },
        @{ Name = "fd"; Optional = $false; Test = { & fd --version } },
        @{ Name = "bat"; Optional = $false; Test = { & bat --version } },
        @{ Name = "eza"; Optional = $false; Test = { & eza --version } },
        @{ Name = "fzf"; Optional = $false; Test = { & fzf --version } },
        @{ Name = "zoxide"; Optional = $false; Test = { & zoxide --version } },
        @{ Name = "direnv"; Optional = $true; Test = { & direnv --version } },
        @{ Name = "starship"; Optional = $false; Test = { & starship --version } },
        @{ Name = "lazygit"; Optional = $true; Test = { & lazygit --version } },
        @{ Name = "delta"; Optional = $true; Test = { & delta --version } },
        @{
            Name = "asdf"
            Optional = $true
            Test = {
                $asdfScript = Join-Path $env:USERPROFILE ".asdf\asdf.ps1"
                if (Test-Path $asdfScript) {
                    "asdf init script present ($asdfScript)"
                } else {
                    throw "asdf init script not found"
                }
            }
        }
    )
    Write-Step "Verifying tool versions"
    foreach ($tool in $tools) {
        try {
            $output = & $tool.Test
            $lines = @()
            if ($null -ne $output) {
                if ($output -is [System.Array]) {
                    $lines = $output
                } else {
                    $lines = ,$output
                }
            }
            $message = ($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
            if ([string]::IsNullOrWhiteSpace($message)) {
                Write-Success "$($tool.Name) available"
            } else {
                Write-Success $message.Trim()
            }
        } catch {
            if ($tool.Optional) {
                Write-Info "$($tool.Name) optional: $($_.Exception.Message)"
            } else {
                Write-Warn "$($tool.Name) is not installed or not on PATH ($($_.Exception.Message))"
            }
        }
    }
}

function Print-Banner {
    Write-Log "🔥 Developer Terminal Ready 🔥" ([ConsoleColor]::Green)
}

Write-Step "Windows developer terminal provisioning"
if ($DryRun) {
    Write-Warn "Dry-run active – no changes will be persisted"
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

Ensure-Asdf
Ensure-Templates
Configure-Profile
Run-DirenvAllow
Print-Versions
Print-Banner
exit 0
