---
layout: post
title: "[Rust] Decrusting the dial9 crate"
date: 2026-09-17 00:00:00 +0530
categories: rust
tags: [rust, dial9, tracing, profiling, observability, libraries]
author: "Seroze"
published: true
---

`dial9` is an always-on tracing and profiling system for Rust services. You add it to a
binary, it records what the process is actually doing — tasks, spans, CPU samples,
allocations, metrics — into a compact binary trace, seals that trace into segments and
ships them somewhere you can look at them later. The pitch is that you should not have
to reproduce a latency problem to explain it; the trace from the run that was slow is
already on disk.

The thing that makes it hard to read for the first time isn't any single piece of that.
It's that `dial9` is not one crate. It's a workspace of about a dozen, and the crate you
depend on — the one actually called `dial9` — contains almost none of the machinery.
It's a façade. So the usual approach of opening `lib.rs` and reading downwards gets you
a wall of `pub use` and then nothing.

This post is the map I wish I'd had: which crate owns which job, which three of them you
actually have to understand, and which ones you can safely skip until you need them.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Short version

| Crate | One-liner |
|---|---|
| **`dial9`** | What users depend on: re-exports, feature flags, env config, CLI |
| **`dial9-core`** | Thread-local buffers, collector, flush thread, segment writer, worker pipeline |
| **`dial9-trace-format`** (+ `-derive`) | Self-describing binary format, encoder and decoder |
| `dial9-tokio-telemetry` | Tokio runtime hooks, spawn, `TracedFuture`, task dumps |
| `dial9-perf-self-profile` | Linux perf CPU/sched sampling, memory allocator sampling, rusage, sockets, symbolization |
| `dial9-destinations-s3` | S3 upload step for sealed segments |
| `dial9-metrique` | Records metrique metric entries into the trace |
| `dial9-utils` | axum, tower, tracing-layer and span integrations |
| `dial9-macro` | `#[dial9::main]` |
| `dial9-viewer` | Web viewer, S3 browser, fleet aggregation, JS UI |
| `examples/*`, `tests-build` | Demos and macro compile tests |

The three in bold are the ones worth reading properly. Everything else is either a
source of events feeding into them, a sink taking data out, or ergonomics.

## The shape of the thing

Once you stop reading crate by crate and look at the direction data moves, the workspace
collapses into four groups:

```
  producers                    core                     sinks
  ─────────                    ────                     ─────

  tokio-telemetry  ─┐
  perf-self-profile ┤                                ┌─ destinations-s3
  metrique          ├──►  dial9-core  ──► segments ──┤
  utils (axum/tower)┤     (buffers,                  └─ local files
  your own spans   ─┘      collector,                        │
                           flush thread,                     ▼
                           writer)                     dial9-viewer

                    encoded by dial9-trace-format
```

Everything on the left produces events. `dial9-core` owns the only path those events
take to disk. `dial9-trace-format` decides what the bytes look like on the way. The
right-hand side is about getting the result somewhere a human can read it. And `dial9`
itself is the wrapper that makes the left-hand side reachable through one dependency and
a few feature flags.

That's the whole system. The rest of this post is detail on each group.

## The three crates that matter

### `dial9` — the façade

This is the crate you put in `Cargo.toml`, and it's deliberately thin. Its jobs are:

- re-export the public API so your code says `dial9::span!` and not
  `dial9_core::span!`,
- turn feature flags into which subsystems get compiled in at all,
- read environment configuration — where traces go, how much to sample, whether to run —
  so that behaviour is tunable in production without a redeploy,
- provide the CLI for working with trace files outside the process.

The feature flags are the part worth actually studying, because they're the real
architecture diagram. Which optional crates a feature pulls in tells you exactly which
subsystems are independent of each other. If `perf-self-profile` is behind a flag and
nothing in core mentions it, then core does not know sampling exists — sampling is a
producer like any other. That's a stronger statement about the design than any doc
comment.

Read this crate first, but read it as a table of contents rather than as code.

### `dial9-core` — where the work happens

This is the engine, and it's where all the interesting decisions live. The pipeline is:

**Thread-local buffers.** Recording an event has to be nearly free, because it happens
on the hot path of a service that is trying to do something else. So each thread writes
into its own buffer with no locking and no contention. This is the single most important
design choice in the system, and everything downstream exists to clean up after it —
per-thread buffers mean the trace arrives out of order and in fragments, which someone
has to reassemble.

**The collector.** Buffers fill up, and something has to take them. The collector is the
handoff point between threads that produce events and the machinery that persists them.
The questions to ask while reading it: what happens when a buffer fills faster than it
can be drained, and who pays — the producing thread blocking, or the trace losing
events? There's no free answer, and whichever one it picks is the crate's real
personality.

**The flush thread.** A dedicated background thread so that persistence never happens on
a worker thread. It wakes on a timer or on pressure, takes what the collector has, and
pushes it onward.

**The segment writer.** Traces aren't one endless file. They're cut into segments, each
sealed and self-contained. That's what makes uploading possible at all — you can't ship
a file that's still being written, but you can ship a sealed segment while the next one
fills. Segment boundaries are also the unit of retention and of recovery: if the process
dies, everything sealed before the crash is intact.

**The worker pipeline.** The steps a sealed segment goes through on its way out —
compression, upload, whatever else is configured. Note that this is a pipeline and not a
hardcoded destination, which is exactly why `dial9-destinations-s3` can be a separate
optional crate.

If you only read one crate in the workspace, read this one.

### `dial9-trace-format` (and `-derive`) — the bytes

The wire format, plus its encoder and decoder. The word doing the work here is
**self-describing**: the trace carries its own schema. A decoder that has never seen
your event types can still read a file containing them.

That property is not decoration. A trace is written by one binary, at one version, and
read months later by a viewer at a completely different version. If the format weren't
self-describing, every new field in an event type would be a coordinated deployment
between the thing writing traces and the thing reading them — which, across a fleet, is
not a thing you can actually do. Self-describing traces turn that into a non-problem.

The `-derive` companion is a proc-macro crate, and it exists for the usual reason: a
derive macro cannot live in the same crate as the code it's used with. It generates the
encode/decode implementations so that defining a new event type doesn't mean writing
serialisation by hand.

Read this second, right after core, because core's code is mostly moving buffers of
format-encoded bytes around and it makes much more sense once you know what's in them.

## The producers

These are the crates that generate events. None of them are load-bearing for
understanding the system — they all end at the same collector — so read whichever one
matches the problem you have.

`dial9-tokio-telemetry` hooks into the Tokio runtime. This is where async work becomes
visible: a traced `spawn`, a `TracedFuture` wrapper that records a task's lifecycle, and
task dumps for the case where everything is stuck and you want to know what every task
in the runtime is currently blocked on. For a service that's idle-but-not-progressing,
task dumps are usually the thing that ends the investigation.

`dial9-perf-self-profile` is the heaviest crate in the workspace and the most
Linux-specific. It does CPU and scheduler sampling through perf, samples the memory
allocator, reads `rusage`, watches sockets, and symbolizes the addresses it collects so
you get function names instead of hex. "Self-profile" is the key word — the process
profiles itself, continuously, rather than you attaching a profiler after the fact. This
is also where the platform assumptions live, which is a good reason for it to be its own
optional crate.

`dial9-metrique` bridges [metrique](https://github.com/awslabs/metrique) so that metric
entries land in the trace alongside everything else. The value isn't the metrics
themselves — you already had those — it's that a metric and the spans that produced it
now share a timeline.

`dial9-utils` is the integration layer for the crates a web service already uses: axum,
tower, and `tracing`. The `tracing` layer is the important one, because it means code
already instrumented with `tracing::info_span!` feeds dial9 without being rewritten.
That's usually the difference between adopting this in an afternoon and adopting it in a
quarter.

## The sinks

`dial9-destinations-s3` is one step in the worker pipeline: take a sealed segment, put
it in S3. That it's a whole crate, and an optional one, is the point — the pipeline is
pluggable and S3 is just the implementation that happens to exist.

`dial9-viewer` is the other end of the system entirely: a web UI, an S3 browser for
finding traces across a fleet, aggregation across many hosts, and the JavaScript that
draws it. It's a consumer of the trace format and shares nothing with the recording path
except `dial9-trace-format`. If you're debugging a recording problem, nothing in here is
relevant; if you're trying to understand what a trace *means*, this is the crate that
defines it, because the viewer's queries are the de facto specification of what the data
is for.

## The ergonomics

`dial9-macro` gives you `#[dial9::main]`. It wraps your `main` the way
`#[tokio::main]` does, so that initialisation, runtime hooks and shutdown-with-flush all
happen without you writing them. The shutdown half matters more than it looks: a trace
that isn't flushed on exit is a trace you don't have, and getting that right by hand at
every exit path is exactly the kind of thing people forget.

`examples/*` and `tests-build` are demos and compile tests. `tests-build` in particular
is there because proc-macro output can only really be tested by compiling it — a macro
that generates invalid code fails at build time or not at all, so the test is the build.

## Reading order

If you're opening this workspace for the first time:

1. `dial9` — skim `lib.rs` and `Cargo.toml` and note which features gate which crates.
2. `dial9-trace-format` — the event model and the encoding.
3. `dial9-core` — buffers, then collector, then flush thread, then writer, in that
   order. This is the real content.
4. One producer that matches what you care about — `tokio-telemetry` for async,
   `perf-self-profile` for CPU and memory.
5. `dial9-viewer` — only when you want to know what the trace is supposed to tell you.

And the one question to keep asking while reading core: *what happens under pressure?*
An always-on tracer is defined by its behaviour when the buffers are full and the
service is already struggling, because that is precisely the moment you most want the
trace and least want the tracer to make things worse.
