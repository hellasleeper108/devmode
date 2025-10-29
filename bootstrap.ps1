[CmdletBinding()]
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Installer = Join-Path $ScriptDir "install_windows.ps1"

function Write-Log {
    param([string]$Message, [ConsoleColor]$Color)
    $current = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Message
    $Host.UI.RawUI.ForegroundColor = $current
}

function Write-Step { param([string]$Message) Write-Log "⚙️  $Message" ([ConsoleColor]::Cyan) }
function Write-Success { param([string]$Message) Write-Log "✅ $Message" ([ConsoleColor]::Green) }
function Write-Warn { param([string]$Message) Write-Log "⚠️  $Message" ([ConsoleColor]::Yellow) }
function Write-ErrorLog { param([string]$Message) Write-Log "✖ $Message" ([ConsoleColor]::Red) }

Write-Step "Developer terminal bootstrap starting"
if ($DryRun) {
    Write-Warn "Dry-run mode enabled; no changes will be applied"
}

if (-not (Test-Path $Installer)) {
    Write-ErrorLog "Unable to locate installer: $Installer"
    exit 1
}

Write-Step "Dispatching to Windows installer 🚀"
if ($DryRun) {
    . $Installer -DryRun
} else {
    . $Installer
}
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Success "Installer completed successfully"
} else {
    Write-ErrorLog "Installer failed with exit code $exitCode"
}
exit $exitCode
