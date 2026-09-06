# Install Herdr on Windows and point it at the config tracked by this repo.
# Run from PowerShell: powershell -ExecutionPolicy Bypass -File .\scripts\setup-herdr.ps1

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $RepoDir ".dotfiles\herdr\.config\herdr\config.toml"

if (-not (Test-Path $ConfigPath)) {
    throw "Managed Herdr config not found: $ConfigPath"
}

if (-not (Get-Command herdr -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Herdr from herdr.dev..."
    Invoke-RestMethod https://herdr.dev/install.ps1 | Invoke-Expression
} else {
    Write-Host "Herdr is already installed."
}

# Windows normally reads %APPDATA%\herdr\config.toml. Pointing directly at the
# repository keeps one source of truth and avoids requiring symlink privileges.
[Environment]::SetEnvironmentVariable("HERDR_CONFIG_PATH", $ConfigPath, "User")
$env:HERDR_CONFIG_PATH = $ConfigPath

Write-Host "Herdr config: $ConfigPath"
Write-Host "Prefix: Ctrl+Space"
Write-Host "For one-key Caps Lock setup, see docs/HERDR.md."
