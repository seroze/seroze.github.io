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

I'm planning to get a **Minisforum AI X1 Pro 470** and pair it with an eGPU docking station, so I
can attach a discrete GPU over the external link instead of being stuck with whatever the box has
onboard.

I did look hard at the **MS-02 Ultra**. It has the slightly better CPU and it's the more
future-proof machine on paper — four SODIMM slots, more PCIe, more networking. But the X1 Pro
offers **better performance per dollar**, and being honest with myself, I probably don't actually
need what the MS-02 adds. Buying headroom I never grow into is just a more expensive way of
owning the same machine.

The nice part about a mini PC + eGPU dock combination is that the two halves upgrade
independently. The compute box stays the same while the GPU in the dock can be swapped
whenever something better (or cheaper) shows up.

One thing to go in with eyes open about: Minisforum typically ships around **two BIOS updates**
for a machine and then stops. After that there's no further firmware support, so if something
breaks at that level — a bad flash, a bug that never gets patched, a hardware quirk that needed a
microcode fix — I'm out of luck. That's the trade for buying from a smaller vendor instead of a
tier-one OEM with a long support tail. Worth knowing before, not after.

---

## Picking the dock

My first thought was the **AGO3**, but there's a catch: its built-in power supply reportedly has
noise in it, and the common recommendation is to bring your own high-quality PSU instead. Which
raises the obvious question — if I'm going to supply my own power anyway, why pay for a bundled
PSU I don't want?

An 850W power supply costs around $100 USD. So the better move is a plain **non-PSU enclosure**
paired with a good PSU of my choosing. Candidates in that space include the **Minisforum DEG2**
and the **Aoostar EOG2**, both of which bring **Thunderbolt 5** support.

But thinking about it more, I'm going with the **Minisforum DEG1**. **OCuLink is fine for now**
and the DEG1 is sufficient for my use case — it's not worth putting that much investment into
keeping a GPU around. The cheaper dock gets me the same experiments at a fraction of the spend,
and if bandwidth ever actually becomes the limiting factor, that's a problem worth paying to
solve later.

---

## What I already have

This is where the cost math works out. I already have lying around:

- **2 × 16 GB SODIMM laptop RAM** — 32 GB total, and SODIMM is the form factor the X1 Pro takes.
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

The plan is to pick up a **refurbished 5070 Ti or 5080** and ship it in from the US. Refurbished
is where the value is — buying new at local retail prices would cost more than the rest of the
build put together, and for workloads that are mostly about learning rather than uptime, a
refurb card is a perfectly reasonable risk.

Between the two, the **5070 Ti** is the better buy on paper: both cards land at 16 GB of VRAM, so
the 5080 mostly buys raw throughput rather than headroom for bigger models. Since VRAM is the
binding constraint for the LLM side, the extra spend doesn't move the ceiling on what I can
actually run.

That's the whole build. Barebones mini PC, my existing RAM and SSD, a cheap OCuLink dock, and one
refurb card doing the heavy lifting.
