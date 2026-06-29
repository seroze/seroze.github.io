---
layout: post
title: "Setting Up Passwordless SSH from macOS to Windows over Tailscale: Lessons Learned"
date: 2026-06-27 00:00:00 +0530
categories: devtools
tags: [ssh, tailscale, windows, wsl, macos, remote-development]
author: "Seroze"
published: true
---

*I recently configured a macOS machine to remotely develop on a Windows laptop (primarily using WSL) over Tailscale. While the final experience is fantastic, there were quite a few platform-specific quirks along the way.*

*These are the lessons I learned.*

---

## 1. Tailscale is only the network

One misconception I had initially was that Tailscale would also handle SSH authentication.

It doesn't.

Tailscale provides:

- Secure encrypted connectivity
- Private IP addressing
- NAT traversal
- Device authentication

OpenSSH still handles:

- Password authentication
- Public key authentication
- Authorization

Think of it as:

```
Mac
   │
   │ SSH
   ▼
Tailscale Network
   ▼
Windows OpenSSH Server
```

The VPN and SSH authentication are separate layers.

## 2. Verify Tailscale before debugging SSH

Before touching SSH, verify that the network itself works.

Useful commands:

```bash
tailscale status
tailscale ping <hostname>
```

If `tailscale ping` succeeds in both directions, your network is healthy.

At that point, any remaining issue is almost certainly related to SSH configuration.

## 3. Windows does not install an SSH server by default

Windows ships with an SSH client, but not necessarily the server.

The server must be installed separately:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

This requires an elevated PowerShell session.

## 4. Installing isn't enough

After installation:

```powershell
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
```

Verify:

```powershell
Get-Service sshd
```

## 5. Make sure something is actually listening

A quick sanity check:

```powershell
netstat -ano | findstr :22
```

If nothing is listening on port 22, no amount of SSH client debugging will help.

## 6. Passwordless SSH uses public keys only

Never copy the private key anywhere.

The flow is:

```
Mac
------------------------
id_ed25519        (private)
id_ed25519.pub    (public)

↓

Copy ONLY

id_ed25519.pub

↓

Windows

authorized_keys
```

The private key never leaves the client.

## 7. SSH debug output is incredibly useful

Instead of guessing, run:

```bash
ssh -vvv user@host
```

Look for:

```
Offering public key
```

This immediately tells you:

- which key is being used
- whether the server accepts it
- whether SSH falls back to password authentication

## 8. Multiple SSH keys can be confusing

Many developers have several keys:

```
id_ed25519
id_github
id_work
id_server
...
```

Without configuration, SSH may offer several keys.

A better approach is:

```
Host my-server
    HostName 100.x.x.x
    User username
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

This makes the behavior deterministic.

## 9. Windows has a special case for Administrator accounts

This was the most surprising discovery.

Windows OpenSSH ships with:

```
Match Group administrators
    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

If your account belongs to the Administrators group, OpenSSH ignores:

```
~/.ssh/authorized_keys
```

and instead expects:

```
C:\ProgramData\ssh\administrators_authorized_keys
```

For personal machines, many people simply remove this block and use the standard per-user `authorized_keys`.

This was the biggest "gotcha" in the entire setup.

## 10. WSL inherits the Windows working directory

When connecting over SSH:

```bash
ssh windows-machine
```

then launching:

```bash
wsl
```

does not start in the Linux home directory.

Instead, it preserves the Windows working directory.

Example:

```
C:\Users\User
```

becomes

```
/mnt/c/Users/User
```

This is actually a nice feature once you know about it.

## 11. Start WSL in the Linux home directory

Instead of:

```bash
wsl
```

use:

```bash
wsl --cd ~
```

This immediately starts in:

```
/home/<user>
```

## 12. The nicest developer experience

Once everything is configured:

```
Mac
      │
      │ ssh
      ▼
Windows
      │
      ▼
WSL Ubuntu
      │
      ├── Java
      ├── Python
      ├── Rust
      ├── Docker
      └── GPU development
```

It feels almost identical to developing on a remote Linux server while still having access to the Windows ecosystem.

## 13. What I'd do differently next time

If I were setting this up again:

1. Install OpenSSH Server first.
2. Verify `sshd` is running.
3. Test password login.
4. Configure SSH keys.
5. Use `ssh -vvv` immediately if key authentication fails.
6. Check whether the Windows account belongs to the Administrators group.
7. Configure an SSH alias with `IdentitiesOnly yes`.
8. Configure WSL to start in the Linux home directory (or even make WSL the default shell for SSH sessions).

## Final Thoughts

Most of the complexity wasn't in Tailscale—it was in understanding how Windows' OpenSSH implementation differs from the Linux/macOS defaults. Once configured, the experience is seamless: instant, passwordless SSH into a WSL environment over a secure private network, making remote development feel almost indistinguishable from working locally.
