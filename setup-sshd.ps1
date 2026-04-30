#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets up Cygwin OpenSSH server (sshd) as a Windows service.
.DESCRIPTION
    Assumes Cygwin is already installed. Installs openssh and cygrunsrv
    packages if missing, then configures and starts sshd.
    Run this script once from an elevated PowerShell prompt.
.PARAMETER CygwinRoot
    Path to your Cygwin installation. Defaults to C:\cygwin64.
.PARAMETER SshPort
    Port for sshd to listen on. Defaults to 22.
.PARAMETER CygwinMirror
    Cygwin package mirror URL. Defaults to https://mirrors.kernel.org/sourceware/cygwin/
#>
param(
    [string]$CygwinRoot = "C:\cygwin64",
    [int]$SshPort = 22,
    [string]$CygwinMirror = "https://mirrors.kernel.org/sourceware/cygwin/"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$bash = Join-Path $CygwinRoot "bin\bash.exe"

function Invoke-Cygwin {
    param([string]$Command)
    & $bash --login -c $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Cygwin command failed (exit $LASTEXITCODE): $Command"
    }
}

# --- Preflight: Cygwin itself must exist ---

if (-not (Test-Path $bash)) {
    throw "Cygwin bash not found at $bash. Install Cygwin first, then re-run this script."
}

# --- Install missing Cygwin packages ---
# Locate setup-x86_64.exe: check common spots, then download if absent.

function Get-CygwinSetup {
    $candidates = @(
        (Join-Path $CygwinRoot "setup-x86_64.exe"),
        (Join-Path $env:USERPROFILE "Downloads\setup-x86_64.exe"),
        (Join-Path $env:TEMP "setup-x86_64.exe")
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }

    $dest = Join-Path $env:TEMP "setup-x86_64.exe"
    Write-Host "Downloading Cygwin setup to $dest..."
    Invoke-WebRequest -Uri "https://cygwin.com/setup-x86_64.exe" -OutFile $dest -UseBasicParsing
    return $dest
}

$missingPackages = @()
if (-not (Test-Path (Join-Path $CygwinRoot "bin\cygrunsrv.exe"))) {
    $missingPackages += "cygrunsrv"
}
& $bash --login -c "which sshd > /dev/null 2>&1"
if ($LASTEXITCODE -ne 0) {
    $missingPackages += "openssh"
}

if ($missingPackages.Count -gt 0) {
    $pkgList = $missingPackages -join ","
    Write-Host "Installing Cygwin packages: $pkgList"
    $setup = Get-CygwinSetup
    # setup-x86_64.exe often returns non-zero even on success; verify by checking files.
    & $setup --quiet-mode --no-shortcuts --no-startmenu --no-desktop `
        --root $CygwinRoot `
        --site $CygwinMirror `
        --packages $pkgList

    $stillMissing = @()
    if ($missingPackages -contains "cygrunsrv" -and
        -not (Test-Path (Join-Path $CygwinRoot "bin\cygrunsrv.exe"))) {
        $stillMissing += "cygrunsrv"
    }
    if ($missingPackages -contains "openssh") {
        & $bash --login -c "which sshd > /dev/null 2>&1"
        if ($LASTEXITCODE -ne 0) { $stillMissing += "openssh" }
    }
    if ($stillMissing.Count -gt 0) {
        throw "Package installation failed - still missing: $($stillMissing -join ', '). Check your internet connection or try a different -CygwinMirror."
    }
    Write-Host "Packages installed." -ForegroundColor Green
} else {
    Write-Host "openssh and cygrunsrv already present." -ForegroundColor Green
}

# --- Run ssh-host-config ---
# --yes answers all prompts non-interactively.
# --privileged creates the cyg_server local account for privilege separation:
# pre-auth phase runs as cyg_server (limited), post-auth runs as the logged-in user.

Write-Host "Running ssh-host-config..."
Invoke-Cygwin "ssh-host-config --yes --privileged --name sshd"

# --- Configure sshd_config port if non-default ---

if ($SshPort -ne 22) {
    Write-Host "Setting sshd port to $SshPort..."
    $sshdConfig = Join-Path $CygwinRoot "etc\sshd_config"
    (Get-Content $sshdConfig) -replace '^#?Port \d+', "Port $SshPort" |
        Set-Content $sshdConfig
}

# --- Windows Firewall rule ---

$ruleName = "Cygwin sshd (port $SshPort)"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Firewall rule '$ruleName' already exists, skipping."
} else {
    Write-Host "Adding firewall rule '$ruleName'..."
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $SshPort `
        -Action Allow `
        -Profile Any | Out-Null
    Write-Host "Firewall rule added." -ForegroundColor Green
}

# --- Start the service ---

Write-Host "Starting sshd service..."
Start-Service sshd
Set-Service sshd -StartupType Automatic

$svc = Get-Service sshd
Write-Host "sshd service status: $($svc.Status)" -ForegroundColor Green

Write-Host ""
Write-Host "Setup complete. Connect with: ssh <username>@<this-machine> -p $SshPort" -ForegroundColor Cyan
