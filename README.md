# Cygwin OpenSSH Server Setup

Sets up `sshd` as a Windows service using an existing Cygwin installation.

## Prerequisites

- Cygwin must already be installed (base install is enough).
- `openssh` and `cygrunsrv` packages are installed automatically by the script if missing.

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

1. Checks for `openssh` and `cygrunsrv`; downloads and installs them via `setup-x86_64.exe` if missing.
2. Runs `ssh-host-config --yes --privileged` to generate host keys and register the Windows service.
3. Runs `mkpasswd -l` and `mkgroup -l` to populate `/etc/passwd` and `/etc/group` with local Windows accounts — required for sshd to resolve Windows usernames at login.
4. Optionally patches `/etc/sshd_config` for a non-default port.
5. Adds a Windows Firewall inbound rule for the chosen port.
6. Starts the `sshd` service and sets it to auto-start on boot.

## Teardown

```powershell
.\teardown-sshd.ps1
```

## Connecting

### Public key authentication (recommended)

Password authentication against Windows local accounts has proven unreliable. Use public key auth instead:

```sh
# On the Windows machine, in a Cygwin terminal:
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
# Paste your public key into ~/.ssh/authorized_keys
```

Then connect from your machine:

```sh
ssh -i ~/.ssh/your_private_key shopp@<windows-machine-ip>
```

### Password authentication

Works only with local Windows accounts (not Microsoft/email accounts). If it fails, check:
- `PasswordAuthentication yes` is set in `/etc/sshd_config`
- The account is a local account: `net user <username>`
- `/etc/passwd` has an entry for the user: `grep <username> /etc/passwd`

## Verifying the service

```powershell
Get-Service sshd | Select-Object Name, Status, StartType
```

The service may not appear in the Services GUI by default — use the above command or search for "sshd" in Services.

## Running commands on user login

To run a Cygwin command automatically when the Windows user logs in, add a registry run key from a Cygwin terminal:

```sh
regtool set '/HKCU/Software/Microsoft/Windows/CurrentVersion/Run/myapp' 'C:\cygwin64\bin\bash.exe --login -c "your-command-here"'
```

This runs under the logged-in user's account (no elevation). Triggers on interactive Windows login, not at boot.

To remove it:

```sh
regtool unset '/HKCU/Software/Microsoft/Windows/CurrentVersion/Run/myapp'
```

To run at boot regardless of login, use Task Scheduler instead (run from an elevated prompt):

```sh
schtasks /create /tn "MyStartupTask" /tr "C:\\cygwin64\\bin\\bash.exe --login -c \"your-command\"" /sc onstart /ru shopp /rp password /f
```

Replace `shopp` and `password` with the actual Windows username and password. To remove it:

```sh
schtasks /delete /tn "MyStartupTask" /f
```

## Notes

- `ssh-host-config` creates a `cyg_server` local Windows account for privilege separation. Pre-auth runs as the limited `cyg_server`; post-auth hands off to your Windows user. This is more secure than running sshd as SYSTEM.
- `cyg_server` requires `SeAssignPrimaryTokenPrivilege`, `SeCreateTokenPrivilege`, `SeTcbPrivilege`, and `SeServiceLogonRight`. These are set by `ssh-host-config` but can be verified with `editrights -l -u cyg_server` (run as Administrator in Cygwin).
- `setup-x86_64.exe` spawns a child process and returns immediately. The script uses `Start-Process -Wait` to block until installation finishes.
- Host keys are stored in `/etc/ssh/` (Cygwin path) = `C:\cygwin64\etc\ssh\`.
- If new Windows user accounts are created after setup, re-run `mkpasswd -l > /etc/passwd` in a Cygwin terminal to make them accessible via SSH.
- The sshd log is at `/var/log/sshd.log`. To enable verbose logging, add `LogLevel DEBUG3` to `/etc/sshd_config` and restart sshd.
