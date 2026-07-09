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

At that point, any remaining issue is almost certainly related to SSH configuration — including, as I later re-learned, whether `sshd` is even running (see [section 14](#14-tailscale-ping-succeeding-doesnt-mean-sshd-is-running)).

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

## 14. tailscale ping succeeding doesn't mean sshd is running

Months after the initial setup, I hit this again: SSH over Tailscale simply failed to connect.

First instinct — re-check the network:

```bash
tailscale ping windows-machine
```

It succeeded, round trip and all. So the tailnet was healthy, the peer was reachable, and the connection wasn't even going through a DERP relay. And yet SSH still refused to connect.

The actual cause: the `sshd` service on the Windows box was simply stopped. Fixed it the same way as section 4:

```powershell
Get-Service sshd
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
```

Setting the startup type to `Automatic` matters — this is what prevents the service from silently staying down after the next reboot or Windows update.

**Why did `tailscale ping` succeed at all if the SSH server was down?**

Because `tailscale ping` doesn't test SSH, or any application, at all. It operates purely at the tailnet/network layer:

```
Mac  ──(WireGuard tunnel)──▶  Windows (tailscaled)
                 │
                 └── proves: this peer is up and reachable
                     over the tailnet (direct, or via DERP relay)
```

It's answered entirely by the `tailscaled` daemon on the peer — it has zero visibility into which services or ports are listening on top of that network. A machine can have a perfectly healthy Tailscale connection while every single service on it (SSH, RDP, whatever) is stopped. This is really just section 1's lesson again — *Tailscale is only the network* — showing up in a new, more confusing shape: it's easy to assume a successful ping clears SSH of suspicion, but it only clears the network layer.

**The takeaway / checklist for next time SSH-over-Tailscale fails:**

1. `tailscale ping <host>` succeeds → network layer is fine, stop debugging Tailscale.
2. SSH still fails → check whether `sshd` is actually running on the target, *not* just correctly configured:
   ```powershell
   Get-Service sshd
   ```
3. If it's `Stopped`, start it and set it to `Automatic` so it survives reboots:
   ```powershell
   Start-Service sshd
   Set-Service -Name sshd -StartupType Automatic
   ```
4. Always double check `StartType` is actually `Automatic` afterwards — don't just assume the command worked:
   ```powershell
   Get-Service sshd | Select-Object Name, Status, StartType
   ```
   ```
   Name  Status  StartType
   ----  ------  ---------
   sshd  Running Automatic
   ```
   If `StartType` ever drifts back to `Manual` or `Disabled` (e.g. after a Windows update), this is the step that catches it before it causes the next confusing outage.

## Final Thoughts

Most of the complexity wasn't in Tailscale—it was in understanding how Windows' OpenSSH implementation differs from the Linux/macOS defaults. Once configured, the experience is seamless: instant, passwordless SSH into a WSL environment over a secure private network, making remote development feel almost indistinguishable from working locally.
