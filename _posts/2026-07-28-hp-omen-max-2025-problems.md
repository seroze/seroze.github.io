---
layout: post
title: "Problems with the HP Omen Max 2025 (275HX + RTX 5080)"
date: 2026-07-28 00:00:00 +0530
categories: hardware
tags: [hardware, laptop, windows, usb_c, troubleshooting]
author: "Seroze"
published: true
---

*A running list of annoyances with my HP Omen Max 2025 — Intel Core Ultra 9 275HX, RTX 5080. The machine is fast. The peripherals and power management are where it gets irritating. I'll add to this as things come up.*

## The Wi-Fi icon disappears

Every so often the Wi-Fi icon vanishes from the system tray entirely. Not "connected with no internet," not a red X — the icon is simply gone, as though the machine has no wireless adapter at all. The only thing that reliably brings it back is a restart.

That symptom is the tell: a missing icon (rather than a failed connection) means Windows has stopped seeing the adapter as a device, not that the connection dropped. So the interesting question is why the adapter falls off the bus in the first place.

The most common explanation is Windows suspending the adapter to save power and then failing to wake it. Worth ruling out first:

**Device Manager**

1. `Win + X` → Device Manager
2. Expand **Network adapters**, right-click the wireless adapter → **Properties**
3. **Power Management** tab → uncheck **"Allow the computer to turn off this device to save power"**

**Power plan**

Control Panel → Power Options → Change plan settings → Change advanced power settings → **Wireless Adapter Settings** → **Power Saving Mode** → set to **Maximum Performance** on both battery and plugged in.

**Caveat:** this is the fix that comes up most often when researching the symptom, and it's a sound explanation for the behaviour, but I haven't had the machine up long enough since changing it to say it's actually fixed. The failure is intermittent, which makes it hard to confirm — going a few days without a recurrence is weak evidence at best. I'll update this once I have a real verdict.

If it *does* come back with power management disabled, the next suspects are the adapter driver (HP's OEM build vs. the chipset vendor's reference driver) and the WLAN AutoConfig service.

> TODO: note the exact adapter model from Device Manager, and whether HP's
> driver or the vendor's generic one is installed.

## USB devices don't re-enumerate when the monitor power cycles

The more reproducible problem. I run the laptop into an ASUS ProArt 27CJV, which acts as a USB-C hub — one cable carries display, power, and everything plugged into the monitor's downstream ports.

If I turn the monitor off and back on, the display comes back fine. The USB devices hanging off it do not. They're just gone, and nothing short of physically unplugging and replugging the USB-C cable brings them back.

So the display side of the link renegotiates on power-up but the USB side doesn't. The host never gets told to re-enumerate the hub, so as far as Windows is concerned those devices were removed and never came back.

Things worth trying, roughly in order of how easy they are:

- **The monitor's own power setting.** Many ASUS displays have an OSD option that governs whether the built-in USB hub stays powered in standby — usually under a "Power Setting" or "System Setup" menu, with something like *Standard* vs. *Power Saving*. In the power-saving mode the hub is cut when the panel sleeps, which would produce exactly this behaviour. If that setting exists here, switching it to standard is the fix most likely to actually address the cause rather than the symptom.
- **USB selective suspend.** Power Options → advanced settings → **USB settings** → **USB selective suspend setting** → Disabled.
- **Power management on the USB hubs.** Device Manager → **Universal Serial Bus controllers** → for each USB Root Hub and Generic USB Hub → Properties → Power Management → uncheck "Allow the computer to turn off this device to save power." Tedious, since there are several.
- **Scan for hardware changes.** In Device Manager, Action → **Scan for hardware changes** forces a re-enumeration. If this brings the devices back it's not a fix, but it beats crawling behind the desk for the cable.

**Caveat:** same as above — these are candidate fixes, not confirmed ones. The last item is the only one I know works, and it's a workaround rather than a fix.

The uncomfortable possibility is that this isn't fixable from the Windows side at all, and it's the monitor cutting hub power on standby with no way to turn that off. In that case the workarounds are a powered USB hub that doesn't depend on the monitor, or simply not powering the monitor off.

## The Case of the Missing RTX 5080

The ProArt stopped waking over HDMI, and Task Manager showed only the Intel iGPU — the RTX 5080 had seemingly vanished. About 1.5 hours in, `Get-PnpDevice -Class Display` showed the GPU was still on the bus, just in an `Error` state with `Problem: CM_PROB_DISABLED` — Code 22, simply disabled in Device Manager (likely a misclick during earlier Wi-Fi troubleshooting). `Enable-PnpDevice` on it brought the monitor straight back.

**Lesson:** check `Get-PnpDevice` error codes before reaching for reboots or resets — a disabled device survives all of them.

## Still to investigate

- [ ] Whether the Wi-Fi fix actually holds over a couple of weeks.
- [ ] The exact wireless adapter model and driver version.
- [ ] Whether the ProArt has an OSD setting for USB-in-standby, and what it's called.
- [ ] Whether either problem behaves differently on battery vs. plugged in.
- [ ] Whether a BIOS or HP firmware update addresses either.
