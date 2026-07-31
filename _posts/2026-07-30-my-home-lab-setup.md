---
layout: post
title: "My Home Lab Setup"
date: 2026-07-30 00:00:00 +0530
categories: hardware
tags: [hardware, homelab, networking, nic, bandwidth, latency]
author: "Seroze"
published: true
---

*Notes on the networking side of the home lab plan — specifically why NIC speed keeps showing up
as a hard constraint once you start designing around disaggregated storage.*

---

## Why this matters for the lab

The plan for the home lab isn't just "one box with a GPU in it." I want **disaggregated
storage** — compute nodes and storage nodes as separate machines talking over the network instead
of everything living on local disks. That's a very different design problem from a single
workstation, because now every read and write has to survive a trip across a wire before it gets
anywhere near a CPU.

Once storage isn't local, the network *is* the storage bus. That single sentence is why NIC
speed stops being a spec-sheet curiosity and starts being the thing that decides whether the
whole setup works. So before buying anything, it's worth actually understanding what a NIC's
rated speed means, and why bandwidth and latency are two completely different axes that both
matter here.

## A single 100 Gbps NIC provides roughly 12.5 GB/s of bandwidth

This is probably the single most important number to internalize if you're building
infrastructure. Once it clicks, a lot of data center design starts making sense — and the reason
it trips people up is a units mismatch that's easy to miss if you've never had to divide by 8.

**Network equipment is advertised in bits per second. Storage devices are advertised in bytes per
second.** A byte is 8 bits, so to go from a NIC's rated speed to something comparable to a disk's
throughput, you divide by 8:

```
100 Gbps = 100 Gigabits/second
8 bits    = 1 byte
100 / 8   = 12.5

100 Gbps = 12.5 GB/s
```

And it lines up cleanly across the whole product line:

| NIC speed | Maximum throughput |
|---|---|
| 1 Gbps | 125 MB/s |
| 10 Gbps | 1.25 GB/s |
| 25 Gbps | 3.125 GB/s |
| 40 Gbps | 5 GB/s |
| 100 Gbps | 12.5 GB/s |
| 200 Gbps | 25 GB/s |
| 400 Gbps | 50 GB/s |

The practical consequence: when someone quotes you "100 Gbps networking," don't picture 100
gigabytes flying around — picture **12.5 GB/s**, which is a very different, much more sobering
number when you're planning how many VMs or storage clients that link needs to serve.

---

## Bandwidth vs. latency

These two get conflated constantly, but they answer completely different questions:

- **Bandwidth** answers: *how much data can move every second?*
- **Latency** answers: *how long until the first byte arrives?*

They are independent of each other, and a good network needs both, not one traded for the other.

### The water pipe picture

A narrow pipe carries little water per second; a wide pipe carries a lot. That's bandwidth — it's
about *width*, not distance:

```
narrow pipe          wide pipe
   |                |||||||||||||
   |                |||||||||||||
   |                |||||||||||||
little water/sec     lots of water/sec
```

Same idea with roads: one lane moves one car at a time, a six-lane highway moves six abreast.
More lanes = more bandwidth.

### The road-length picture

Latency has nothing to do with width — it's about *distance*, i.e. time-to-first-arrival:

```
Road A:  House ---- Shop        (500 m)
Road B:  House ---------------- Shop   (20 km)
```

Even if both roads had 20 lanes each, Road B's first car still arrives later, purely because
there's more road to cross. That delay is latency, and no amount of extra lanes fixes it —
lanes fix throughput, not distance.

A storage read makes the same trip, just electronically:

```
VM → NIC → Switch → Storage server → SSD → Switch → NIC → VM
```

If that whole round trip takes 200 microseconds, that's the latency of the request — completely
separate from how many bytes the link could carry per second if it were kept busy.

### Two extremes that make the independence obvious

**High bandwidth, terrible latency:** the "sneakernet" case — physically shipping drives. Load
100 TB onto a truck, drive it to another city. It takes 10 hours before the first byte arrives
(awful latency), but once it does, 100 TB lands at once (enormous effective bandwidth). Hence the
old joke: *never underestimate the bandwidth of a station wagon full of hard drives.*

**Tiny bandwidth, excellent latency:** send the string `"OK"` — 2 bytes — over fiber. It arrives
in half a millisecond. Latency is superb. Bandwidth used is negligible. Neither example is "the
better network" — they're optimized for opposite things.

### Why databases care about latency, not bandwidth

Suppose Postgres wants a single 4 KB page: `Read block #145`. The request is small, so bandwidth
barely matters — what matters is the round-trip time:

- At **50 μs** latency, the answer comes back almost instantly.
- At **5 ms** latency, the CPU waits **100× longer** for the exact same request, over the exact
  same 100 Gbps link.

Now scale that to a workload: one million 4 KB reads, 4 GB total data, but every request waits on
the previous one finishing. Total data moved is tiny, yet:

- At 50 μs/request, the whole million-read run finishes quickly.
- At 5 ms/request, the database becomes painfully slow — even though only 4 GB crossed the wire.

This is why databases are latency-sensitive workloads, not bandwidth-sensitive ones: small,
serialized requests expose round-trip time, not link width.

### Why bulk transfers care about bandwidth, not latency

Flip it around: copying a 100 GB file. Latency barely moves the needle here — what dominates is
link width.

```
On a 1 Gbps NIC   (125 MB/s):    100 GB / 125 MB/s   ≈ 800 s  ≈ 13 min
On a 100 Gbps NIC (12.5 GB/s):   100 GB / 12.5 GB/s   ≈ 8 s
```

The round-trip time to start the transfer is roughly the same in both cases. The 100× difference
in total time comes entirely from bandwidth.

### The restaurant mental model

If none of the above sticks, this one usually does: **latency is how long you wait before the
first plate arrives after ordering. Bandwidth is how many plates per minute the kitchen can bring
once service has started.** A 30-minute wait for the first dish is bad latency regardless of how
fast plates come after that; a kitchen that can only bring one plate every ten minutes is low
bandwidth regardless of how quickly the first one showed up. A good infrastructure design wants
both: quick to start, fast to sustain.

---

## Why disaggregated storage needs a fat NIC

This is the part that connects straight back to the lab plan. The moment storage lives on a
separate box from compute, *every* read and write that used to be a local disk I/O becomes a
network request instead — and the network has to absorb all of it simultaneously, from every VM,
all the time.

Take a host running 100 VMs, each doing a modest 50 MB/s of reads — nothing exotic, just ordinary
usage:

```
100 VMs × 50 MB/s = 5,000 MB/s ≈ 5 GB/s
5 GB/s × 8 bits/byte ≈ 40 Gbps
```

That's **40 Gbps consumed by reads alone**, on a per-VM number that isn't even aggressive. Add
writes, replication traffic between storage nodes, backups, and live migration traffic, and a
10 Gbps NIC (1.25 GB/s) isn't just tight — it's overloaded by nearly an order of magnitude before
any of that extra traffic is even counted.

Scale it the way a cloud provider would — 80 VMs at 150 MB/s each:

```
80 × 150 MB/s = 12,000 MB/s = 12 GB/s
```

A 10 Gbps NIC caps out around 1.25 GB/s — roughly a 10× shortfall. A 100 Gbps NIC caps out at
12.5 GB/s — just barely enough. This is the actual reason modern data center hosts ship with
100 Gbps-and-up NICs: dozens of VMs, distributed storage traffic, live migrations, backups, and
cluster/orchestration chatter are all sharing one physical link, and the arithmetic above is
exactly what sizing that link comes down to.

### Common speeds and what they're for

| Speed | Typical use |
|---|---|
| 10 Gbps | Small clusters |
| 25 Gbps | Entry-level production |
| 40 Gbps | Older enterprise deployments |
| 100 Gbps | Common in modern clouds |
| 200 Gbps | AI/HPC and large-scale storage |
| 400 Gbps | Cutting-edge cloud infrastructure |

### So why 25 Gbps for a home build

I'm obviously not sizing for 80 VMs at home. But the same arithmetic applies at a smaller
scale, and it's why **10 Gbps is the one tier I'd actively avoid** for a disaggregated setup, even
a small one:

- A single storage node serving even a handful of VMs or containers, plus scrub/rebuild traffic,
  plus the occasional bulk copy, eats into a 10 Gbps link (1.25 GB/s) fast — one saturated
  backup job and everything else on that link queues behind it.
- **25 Gbps (3.125 GB/s)** is the first tier where there's real headroom above "one thing at a
  time": storage traffic, a backup, and normal VM I/O can overlap without immediately fighting
  each other for the wire. It's also the tier where enterprise gear (SFP28, entry switches) is
  cheap on the used market, which matters a lot more at home-lab budget than at cloud-provider
  budget.
- Going straight to 100 Gbps at home is usually solving a problem I don't have yet — the switches,
  cabling (QSFP28), and NICs are all a different price bracket, and a home lab's VM count is
  nowhere near the 80-VM math above.

25 Gbps is the point where the link stops being the obvious first bottleneck without requiring
data-center-grade everything else around it — which is exactly the trade-off a disaggregated home
lab needs to get right before anything else about the storage design matters.

---

## The rest of the mini-cloud stack

The NIC is only the piece that made me stop and do the arithmetic. Once you're actually planning a
disaggregated setup, a few other things fall out of that same design decision and are worth
capturing here.

### The switch is part of the equation, not just the NIC

A fast NIC on both ends means nothing if the link between them is slower:

```
100 Gbps NIC
      |
 10 Gbps switch
      |
100 Gbps NIC
```

That path still tops out at **10 Gbps** — the slowest component in the chain sets the ceiling for
the whole path, full stop. It's an obvious point once stated, but easy to forget when you're
pricing NICs and treating the switch as an afterthought. A realistic small setup instead looks
like a NIC-per-server speed matched to a Top-of-Rack switch at the same speed, with a faster
uplink between switches so that switch-to-switch traffic isn't the next bottleneck down the line
— e.g. 25 Gbps to each server, 100 Gbps between switches. The whole point of the exercise is
making sure storage traffic never becomes the thing everything else waits behind.

### How many VMs actually fit on one host?

There's no fixed number — it depends on the workload — but in practice **RAM runs out well before
CPU does**, so RAM is usually the first constraint to size against, with CPU a close second.

For a host with 32 cores, 256 GB RAM, and a 25 Gbps NIC, a realistic density for small VPS-sized
instances is roughly **50–100 VMs**. Large cloud providers push this much further — servers with
hundreds of cores and terabytes of RAM can host several hundred lightweight VMs — but the ratio
that matters (RAM per VM, then cores per VM) stays the same idea at any scale.

### Thin provisioning

One storage detail that makes the density numbers above work out: a customer can be sold a
100 GB virtual disk while only 4 GB of it is actually written to real storage. Space gets
allocated as data lands, not up front for the full advertised size. It's the same idea as
overselling seats on a flight, applied to disk — and it's a big part of why disaggregated storage
clusters can serve more virtual capacity than they physically hold.

---

## Power Supplies and Storage Basics

While learning about storage systems and building home servers, I realized there were a few
fundamental hardware concepts worth understanding.

- A **Power Supply Unit (PSU)** converts the **230V AC** from a wall socket into the stable
  low-voltage **DC** rails (12V, 5V, 3.3V, etc.) required by computer components. An **850W PSU**
  doesn't always consume 850W — it simply means it can safely supply up to 850W if the system
  demands it. Laptop chargers are essentially external PSUs that usually output a single DC
  voltage (e.g., ~20V), which the laptop further converts internally.

- **SATA III** provides **6 Gbps (Gigabits/sec)** of interface bandwidth, which translates to
  roughly **550 MB/s** of usable throughput after overhead — not **6 GB/s**. Modern **NVMe SSDs**
  communicate over PCIe instead of SATA and can reach **7 GB/s+** on PCIe Gen4 and even higher on
  PCIe Gen5.

- The operating system is **not loaded entirely into RAM during boot**. The firmware loads a
  bootloader, which loads the kernel, after which the OS continuously loads executables,
  libraries, drivers, and other resources **on demand**. Frequently accessed files are cached in
  memory, while less-used pages are fetched from storage when needed.

- Storage performance is characterized by three key metrics:
  - **Throughput (MB/s or GB/s):** How much data can be transferred per second.
  - **IOPS (Input/Output Operations Per Second):** How many individual read or write requests can
    be completed per second, especially important for small random accesses.
  - **Latency:** The time taken to complete a single I/O request.

- **Read IOPS** and **Write IOPS** are measurements rather than hardware constants. They represent
  the number of completed read and write operations per second, respectively. Operating systems,
  databases, and distributed storage systems such as Ceph monitor these metrics because workloads
  involving many small random reads and writes are typically limited by IOPS and latency rather
  than raw bandwidth.

- **Throughput and IOPS are related, not independent.** Roughly:

  $$\text{Throughput} \approx \text{IOPS} \times \text{Average IO Size}$$

  At 1,000,000 IOPS with 4 KB requests, that's 4 GB/s. But the same 1,000,000 IOPS with 1 MB
  requests would imply 1,000,000 MB/s — which is impossible; the SSD saturates its throughput
  ceiling long before it gets anywhere near that IOPS number. So which metric actually limits a
  workload depends on request size: **small IO → IOPS matters**, **large IO → throughput
  matters**.

---

## End-to-End Journey of a YouTube Video

One of the most useful mental models I learned was tracing the complete journey of a streamed
video frame — from Google's servers all the way to the monitor.

```text
Google CDN (compressed video)
        │
        ▼
Internet
        │
        ▼
ISP
        │
        ▼
Home Router
        │
        ▼
Ethernet / Wi-Fi
        │
        ▼
Network Interface Card (NIC)
        │
        ▼
Kernel Networking Stack
(TCP/IP processing)
        │
        ▼
Browser Socket Buffer (RAM)
        │
        ▼
YouTube Player Buffer (RAM)
        │
        ▼
Video Decoder
(Usually dedicated GPU hardware such as AV1/VP9 decode)
        │
        ▼
Decoded Frames in GPU Memory
        │
        ▼
GPU Compositor / Renderer
        │
        ▼
Display Engine
        │
        ▼
Monitor
```

A few important observations:

- The video travels over the internet **in a compressed format** (AV1, VP9, H.264, etc.) to
  minimize bandwidth.
- The **NIC performs DMA (Direct Memory Access)**, placing incoming packets directly into system
  RAM instead of copying them through the CPU — the NIC writes straight into RAM without the CPU
  being involved in the transfer itself.
- The browser maintains a **playback buffer** in RAM (shown as *Buffer Health* in YouTube's *Stats
  for nerds*), allowing playback to continue even if the network experiences brief slowdowns.
- Dedicated **GPU video decoding hardware** decompresses the video into raw frames. This is
  different from the GPU's 3D rendering cores and is optimized specifically for video codecs.
- Finally, the GPU composites the decoded frames and sends them through the display engine to the
  monitor.

One question I found particularly interesting was: **Why isn't the video streamed directly into
the CPU cache?**

The answer is that CPU caches are tiny, hardware-managed, and optimized for accelerating
computation — not for storing large streaming buffers. Network devices use **DMA** to transfer
data directly into **system RAM**, and only the portions of memory actively accessed by the CPU
are automatically brought into the cache hierarchy.

## Reinforcing the Fundamentals

To test my understanding, I tried reasoning through a series of hardware and storage questions
instead of relying on definitions. Some of the key takeaways were:

- A PSU's wattage represents its **maximum delivery capacity**, not its constant power output.
  Components draw only the power they need, regardless of whether the PSU is rated for 850W or
  1600W.
- The performance difference between **SATA SSDs and NVMe SSDs** is largely due to the storage
  interface and protocol (SATA/AHCI vs. PCIe/NVMe), not necessarily because the NAND flash itself
  is different.
- **IOPS** and **throughput** measure different aspects of storage performance. Small random I/O
  workloads are typically IOPS-bound, while large sequential transfers are throughput-bound. A
  useful mental model is: **Throughput ≈ IOPS × Average I/O Size**.
- Modern operating systems continue to access the SSD long after boot through mechanisms such as
  demand paging, loading executables and shared libraries, memory-mapped files, and application
  data.
- The **page cache** keeps recently accessed disk pages in RAM, which explains why reopening an
  application is often significantly faster than launching it for the first time.
- While debugging YouTube playback, I learned that the **actual connection speed to YouTube's
  CDN**, rather than my ISP's advertised bandwidth, determines whether an 8K stream buffers.
- **Buffer Health** proved to be a valuable diagnostic metric. If it steadily drops to zero, the
  network is not keeping up with playback. If it remains healthy while playback stutters, the
  bottleneck is more likely decoding, rendering, or the browser.
- Video compression is far more sophisticated than simply reducing quality. Modern codecs exploit
  temporal and spatial redundancy, motion vectors, and other techniques to reduce an uncompressed
  8K HDR stream from tens of gigabits per second to only a few dozen megabits per second.
- In distributed storage systems such as Ceph, using **NVMe as a cache for hot data** can
  dramatically improve performance while keeping the bulk of the data on high-capacity HDDs.
- Finally, I reinforced the end-to-end path of streamed data: it travels from the content server
  through the network and NIC into RAM, is decoded (typically by dedicated GPU hardware), and then
  rendered to the display. Data isn't streamed directly into CPU caches — they're small,
  hardware-managed, and designed to accelerate computation rather than serve as large streaming
  buffers.

---

## PCIe, DDR, Bus Width, and Cache Lines

One concept that finally made all the bandwidth numbers click for me was understanding **bus
width**.

PCIe and DDR both advertise their speed in **Transfers per Second**, but the amount of data moved
in each transfer is completely different.

- **PCIe 5.0** advertises **32 GT/s** (32 billion transfers per second) **per lane**. A PCIe lane
  is a **serial link**, so each transfer effectively carries one bit before encoding is
  considered. After accounting for 128b/130b encoding and converting bits to bytes, a single
  PCIe 5.0 lane delivers about **4 GB/s**. A x16 slot simply combines sixteen such lanes, giving
  roughly **64 GB/s**.

- **DDR5-5600** advertises **5600 MT/s** (5600 million transfers per second). Unlike PCIe, a DDR
  memory channel has a **64-bit (8-byte) data bus**. Every transfer moves **64 bits (8 bytes)**
  simultaneously. Therefore:

  $$5600 \text{ MT/s} \times 8 \text{ bytes} = 44.8 \text{ GB/s per memory channel}$$

The important takeaway is that **"Transfers per second" tells you how often data moves, while the
bus width tells you how much data moves each time.**

This also ties into another important concept: **RAM is byte-addressable but not
byte-transferable.** Although software can read or write a single byte, the memory controller
communicates with DRAM in much larger chunks over its 64-bit-wide interface. In practice, the CPU
almost always fetches an entire **cache line (typically 64 bytes on modern x86 processors)**. Even
if a program requests a single byte, the hardware transfers the entire cache line into the CPU
cache because nearby data is likely to be accessed next (spatial locality).

This connection between **bus width → memory bandwidth → cache lines** helped me understand why
modern CPUs can sustain such enormous data rates despite individual loads and stores in software
appearing to operate on only a few bytes at a time.

---

## Key takeaway

Building this isn't really about "running some VMs." It's compute (KVM), networking (NICs,
switches), distributed storage (Ceph), Kubernetes, scheduling, and monitoring, all leaning on each
other — and the network sits right in the middle of that, not off to the side.

> Once storage becomes disaggregated, the network effectively becomes part of your storage
> subsystem. Choosing the right NICs and switches isn't just a networking decision anymore — it's
> directly tied to storage performance and how far the whole thing scales.
