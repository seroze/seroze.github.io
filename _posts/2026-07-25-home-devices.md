---
layout: post
title: "Home Lab"
date: 2026-07-25 00:00:00 +0530
categories: hardware
tags: [hardware, homelab, gpu, local_llm]
author: "Seroze"
published: true
---

*Notes on the home lab I'm planning to build out.*

---

## The plan

After a lot of back and forth, I've landed on the **Minisforum MS-A2**.

I spent a while leaning towards the **AI X1 Pro 470**, mostly on performance-per-dollar grounds.
What changed my mind is the chip. The MS-A2 carries the stronger CPU, and more importantly it's
the one that **ages gracefully** — the X1 Pro is built around an NPU-heavy story that I don't
expect to hold its value as a general-purpose machine, while the MS-A2 is just a lot of fast
cores that will still be a lot of fast cores in four years. For a box that's going to compile
things, run containers, and sit under long experiments, that's the property I actually want.

The other thing the MS-A2 gets me is a real **PCIe x16 slot**. That turns the eGPU question into
a much simpler one: drop in a **PCIe-to-OCuLink adapter**, run the cable out to a dock, and
attach the card. No Thunderbolt tax, no bundled-PSU compromise.

The nice part about a mini PC + eGPU setup is that the two halves upgrade independently. The
compute box stays the same while the GPU on the other end of the OCuLink cable can be swapped
whenever something better (or cheaper) shows up.

One thing to go in with eyes open about: Minisforum typically ships around **two BIOS updates**
for a machine and then stops. After that there's no further firmware support, so if something
breaks at that level — a bad flash, a bug that never gets patched, a hardware quirk that needed a
microcode fix — I'm out of luck. That's the trade for buying from a smaller vendor instead of a
tier-one OEM with a long support tail. Worth knowing before, not after.

---

## OCuLink

The adapter route is well-trodden at this point. The walkthrough I'm following for the install is
this one:

- [OCuLink eGPU install walkthrough](https://www.youtube.com/watch?v=61NyYB4ru90&t=603s)

**OCuLink is fine for now.** It gives PCIe 4.0 x4 to the card, well short of what a desktop x16
slot delivers, but for inference and kernel work the link isn't where I'll be losing time — and
it costs a fraction of a Thunderbolt 5 enclosure. If bandwidth ever actually becomes the
binding constraint, that's a problem worth paying to solve later.

---

## Thermals

The one recurring complaint about the MS-A2 is that it runs hot — the 9955HX will happily sit at
uncomfortable temperatures out of the box. Reddit consensus is that this is fixable, and the fix
is documented here:

- [Minisforum MS-A2 9955HX temperature fix](https://etcwiki.org/wiki/Minisforum_MS-A2_9955HX_temperature_fix)

Planning to apply this early rather than after living with a loud, throttling machine for a
month.

---

## What I already have

This is where the cost math works out. I already have lying around:

- **2 × 16 GB SODIMM laptop RAM** — 32 GB total, and SODIMM is the form factor the MS-A2 takes.
- **1 TB SN-series Gen4 NVMe drive** — fast enough that I won't be waiting on disk when loading
  model weights.

So the barebones purchase covers the motherboard, CPU and chassis, and my existing parts fill in
the memory and storage. That knocks a meaningful chunk off the total, and none of it is a
compromise — this is the RAM and SSD I'd have bought anyway.

---

## The GPU

The last piece is the card itself. What I want it for:

- Running local LLMs — inference, quantized models, trying out serving stacks.
- CUDA experiments: writing kernels, profiling, understanding what the hardware actually does.
- Small-scale training and fine-tuning runs.

The plan is to pick up a **refurbished 5070 Ti or 5080** and ship it in from the US, and **nothing
above that**. Given where GPU prices are right now, the next rung up costs more than the entire
rest of the build and I'd still be VRAM-limited for anything genuinely large. Refurbished is
where the value is — for workloads that are mostly about learning rather than uptime, a refurb
card is a perfectly reasonable risk.

Between the two, the **5070 Ti** is the better buy on paper: both cards land at 16 GB of VRAM, so
the 5080 mostly buys raw throughput rather than headroom for bigger models. Since VRAM is the
binding constraint for the LLM side, the extra spend doesn't move the ceiling on what I can
actually run.

The other half of that decision is to stop pretending the local box needs to do everything.
**Anything that genuinely needs a big GPU, I'll rent.** Cloud GPU time is cheap compared to
buying a card I'd use at full tilt a few days a year, and it means the local machine gets sized
for the thing it's actually good at — fast iteration, always-on, no per-hour meter running while
I stare at a profiler. Local for the loop, cloud for the long runs.

That's the whole build. MS-A2 barebones, my existing RAM and SSD, a PCIe-to-OCuLink adapter out
to one refurb card, and a cloud bill for anything that doesn't fit.
