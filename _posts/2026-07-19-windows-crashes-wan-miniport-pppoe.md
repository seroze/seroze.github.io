---
layout: post
title: "Fixing Frequent Windows Crashes: A WAN Miniport (PPPOE) Story"
date: 2026-07-19 00:00:00 +0530
categories: debugging
tags: [windows, debugging, drivers, bsod]
author: "Seroze"
published: true
---

My Windows machine (HP OMEN Max) had been crashing frequently — sometimes the Wi-Fi icon would just disappear before the whole thing went down with a BSOD.

## Finding the culprit

Windows saves a crash dump every time it blue-screens, in `C:\Windows\Minidump\`. To read them I used **WinDbg** (free, on the Microsoft Store). Open the `.dmp` file, run `!analyze -v`, and it names the culprit:

```
FAILURE_BUCKET_ID:  0x9F_4_raspppoe!RasPppoeCleanup
IMAGE_NAME:         raspppoe.sys
```

A few things to decode here:

- `0x9F` is the `DRIVER_POWER_STATE_FAILURE` bugcheck — a driver failed to complete a power transition (sleep, resume, shutdown) in time.
- `raspppoe.sys` is the driver behind **WAN Miniport (PPPOE)**.

So the PPPoE driver was hanging during power transitions and taking the system down with it. That also explains the Wi-Fi icon vanishing right before the crash — the network stack was wedged.

## The fix

Device Manager → Network adapters → **WAN Miniport (PPPOE)** → Disable device.

PPPoE is not critical infra — it's only used for old-school DSL broadband dial-in, where you enter an ISP username and password to connect. I don't use that. Wi-Fi, Ethernet, and VPNs are unaffected by disabling it.

No crashes since. If something breaks in the future, I'll just re-enable it.

## Takeaway

If Windows is crashing and you don't know why, don't guess — the minidumps in `C:\Windows\Minidump\` plus WinDbg's `!analyze -v` will usually point straight at the offending driver.
