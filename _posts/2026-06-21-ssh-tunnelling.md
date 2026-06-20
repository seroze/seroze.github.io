---
layout: post
title: "SSH Tunnelling — Forwarding Ports Over SSH"
date: 2026-06-21 00:00:00 +0530
categories: networking
tags: [ssh, networking, tunnelling, port-forwarding]
author: "Seroze"
published: true
---

*I keep a dev server running on a remote Linux box but want to hit it from my laptop's browser. SSH tunnelling solves this in one line. These are my notes on what the flags actually mean.*

---

## The real situation that led me here

I was relearning HTML, and my files lived on my **Linux box** — that's where I was editing `test1.html` and friends. But I was actually working from my **macOS machine**. I wanted to preview the pages in my Mac's browser without copying files back and forth.

The fix was simple:

1. On the Linux box, in the directory holding the HTML files, I started a tiny web server:

   ```bash
   cd ~/html-practice          # the folder with test1.html
   python3 -m http.server 8000
   ```

2. On my Mac, I set up port forwarding so my Mac's `localhost:8000` points at the Linux box's `8000`:

   ```bash
   ssh -L 8000:localhost:8000 user@linux-host
   ```

3. Then in my Mac's browser I typed:

   ```
   http://localhost:8000/test1.html
   ```

   …and the actual HTML page rendered. The browser is on my Mac, but the file and the server are on the Linux box, with everything flowing through the SSH tunnel. Very cool.

> **Gotcha I hit:** `python3 -m http.server` only serves files in the **directory it was launched from**. If I started it in my home folder but `test1.html` lived in `~/html-practice/`, the server couldn't see it and I got a 404. Always `cd` into the folder with your files *before* starting `http.server` (or pass `--directory`).

---

## The one-liner

```bash
ssh -L 8000:localhost:8000 youruser@linux-machine
```

After running this, opening `http://localhost:8000` in my **laptop's** browser actually reaches a service listening on port `8000` of the **remote** `linux-machine`. The traffic rides inside the encrypted SSH connection.

## Reading the `-L` flag

`-L` means **local port forwarding**. The argument has three parts separated by colons:

```
-L  [local_port] : [target_host] : [target_port]
        8000      :   localhost   :    8000
```

- `8000` (first) — the port to open **on my laptop** (the SSH client side).
- `localhost` — the host to connect to, **as seen from the remote machine**. This is the key subtlety: `localhost` here is the remote box's own loopback, not my laptop's.
- `8000` (second) — the port on that target host.

So "take connections to `localhost:8000` on my laptop, send them through the SSH tunnel, and on the far end connect to `localhost:8000`."

## Why `localhost` refers to the remote machine

This trips people up. The `target_host:target_port` part is resolved **from the remote machine's perspective**, because that's where the tunnel exits. You can forward to other hosts the remote can reach, too:

```bash
# Reach a database that only the remote machine can see
ssh -L 5432:db.internal:5432 youruser@linux-machine
```

Here `db.internal` is resolved by `linux-machine`, not by my laptop. This is how you tunnel to internal services behind a bastion host.

## Local vs remote forwarding

There are two directions, and mixing them up is the classic mistake:

| Flag | Direction | "Expose ___ to ___" |
|---|---|---|
| `-L` | Local forwarding | a **remote** service → my **local** machine |
| `-R` | Remote forwarding | a **local** service → the **remote** machine |

```bash
# -L: I want to reach the remote's port 8000 from my laptop
ssh -L 8000:localhost:8000 youruser@linux-machine

# -R: I want the remote to reach my laptop's port 3000
ssh -R 3000:localhost:3000 youruser@linux-machine
```

## Handy extra flags

```bash
# -N : don't run a remote command, just hold the tunnel open
# -f : background the SSH process after connecting
ssh -N -f -L 8000:localhost:8000 youruser@linux-machine
```

`-N -f` is what I use when I just want the tunnel and don't need an interactive shell.

```bash
# Bind the local end to all interfaces, not just loopback
# (lets other machines on my LAN use the tunnel too)
ssh -L 0.0.0.0:8000:localhost:8000 youruser@linux-machine
```

## Tearing it down

If you backgrounded it with `-f`, find and kill it:

```bash
# Find the tunnel
ps aux | grep "ssh -N"

# or, if you forwarded a known port
lsof -i :8000
kill <pid>
```

For a foreground tunnel, just `Ctrl-C` (or type `~.` to drop an SSH session).

## Common gotchas

- **"Connection refused" on the remote side** usually means nothing is actually listening on the target port on the remote machine. SSH the box and check with `ss -tlnp`.
- **Port already in use locally** — pick a different local port: `-L 8001:localhost:8000`.
- **Service binds to `0.0.0.0` vs `127.0.0.1`** — if the remote service only listens on `127.0.0.1`, forwarding to `localhost` works fine. That's the common case.

---

A single `ssh -L` line is one of those tools that feels like magic the first time it clicks — encrypted, no extra software, and it works through anything that lets SSH out.
