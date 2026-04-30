# Cygwin OpenSSH Server Setup

Sets up `sshd` as a Windows service using an existing Cygwin installation.

## Prerequisites

In **Cygwin Setup** (`setup-x86_64.exe`), install these packages:
- `openssh`
- `cygrunsrv`

## Usage

Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup-sshd.ps1
```

To use a custom Cygwin path or port:

```powershell
.\setup-sshd.ps1 -CygwinRoot "C:\cygwin" -SshPort 2222
```

## What it does

1. Verifies Cygwin, `sshd`, and `cygrunsrv` are present.
2. Runs `ssh-host-config --yes --privileged` to generate host keys and register the Windows service.
3. Optionally patches `/etc/sshd_config` for a non-default port.
4. Adds a Windows Firewall inbound rule for the chosen port.
5. Starts the `sshd` service and sets it to auto-start.

## Teardown

```powershell
.\teardown-sshd.ps1
```

## Connecting

```sh
ssh yourusername@<windows-machine-hostname-or-ip>
```

Use your Windows account credentials. The username is your Windows login name (not the Cygwin one, unless they match).

## Notes

- `ssh-host-config` creates a `cyg_server` local Windows account for privilege separation. Pre-auth runs as the limited `cyg_server`; post-auth hands off to your Windows user.
- Host keys are stored in `/etc/ssh/` (Cygwin path) = `C:\cygwin64\etc\ssh\`.
