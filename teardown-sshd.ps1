#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes the Cygwin sshd service and firewall rule.
.PARAMETER CygwinRoot
    Path to your Cygwin installation. Defaults to C:\cygwin64.
.PARAMETER SshPort
    Port used when setup was run. Defaults to 22.
#>
param(
    [string]$CygwinRoot = "C:\cygwin64",
    [int]$SshPort = 22
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$bash = Join-Path $CygwinRoot "bin\bash.exe"

function Invoke-Cygwin {
    param([string]$Command)
    & $bash --login -c $Command
}

Write-Host "Stopping sshd service..."
Stop-Service sshd -ErrorAction SilentlyContinue
Set-Service sshd -StartupType Disabled -ErrorAction SilentlyContinue

Write-Host "Removing sshd Windows service..."
Invoke-Cygwin "cygrunsrv --remove sshd"

$ruleName = "Cygwin sshd (port $SshPort)"
Write-Host "Removing firewall rule '$ruleName'..."
Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

Write-Host "Done. sshd service and firewall rule removed." -ForegroundColor Green
