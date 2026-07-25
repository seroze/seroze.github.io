---
layout: post
title: "Home Devices"
date: 2026-07-25 00:00:00 +0530
categories: hardware
tags: [hardware, homelab, gpu, local_llm]
author: "Seroze"
published: true
---

*Notes on the home setup I'm planning to build out.*

---

## The plan

I'm planning to get a **Minisforum AI X1 Pro 470** — a mini PC that should comfortably handle
day-to-day work, and pair it with an **AGO3 eGPU docking station** so I can attach a discrete GPU
over the external link instead of being stuck with whatever the box has onboard.

The nice part about a mini PC + eGPU dock combination is that the two halves upgrade
independently. The compute box stays the same while the GPU in the dock can be swapped
whenever something better (or cheaper) shows up.

---

## What I already have

This is where the cost math works out. I already have lying around:

- **2 × 16 GB SODIMM laptop RAM** — 32 GB total, which is exactly the form factor the X1 Pro takes.
- **1 TB SN-series Gen4 NVMe drive** — fast enough that I won't be waiting on disk when loading
  model weights.

So the barebones purchase covers the motherboard, CPU and chassis, and my existing parts fill in
the memory and storage. That knocks a meaningful chunk off the total, and none of it is a
compromise — this is the RAM and SSD I'd have bought anyway.

---

## The missing piece

The only thing left is a **low-cost GPU** for the dock. What I want it for:

- Running local LLMs — inference, quantized models, trying out serving stacks.
- CUDA experiments: writing kernels, profiling, understanding what the hardware actually does.
- Small-scale training and fine-tuning runs.

I don't need a top-end card for any of this. VRAM matters more than raw throughput for the LLM
side, and for CUDA learning almost any modern NVIDIA card is enough to be instructive. The goal is
the cheapest card that gives me enough VRAM to be useful, not the fastest one.

That's the one open decision. Everything else in the build is settled.
