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
handoff point between the threads producing events and the machinery that persists them.
The question worth asking of any such component is what happens when events arrive faster
than they can be drained, and who pays — the producing thread blocking, or the trace
losing events. dial9 answers "the trace": a bounded ring that drops the oldest batch and
counts the loss, so the producer never waits. More on that in the threading section.

**The flush thread.** A dedicated background thread so that persistence never happens on
a worker thread. It wakes on a timer, takes what the collector has, and pushes it
onward.

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

## The threading model

The one-line version: **many writers, one consumer.** Your application's threads encode
events into buffers they own outright, a single dedicated flush thread is the only thing
that ever touches the trace file, and an optional worker thread handles whatever is slow
after that — gzip, symbolization, S3. dial9 never adds threads to your Tokio runtime,
and never blocks one of your threads in order to record something.

```
 Your threads (Tokio workers, blocking pool, plain std threads)
 ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
 │ thread-local  │ │ thread-local  │ │ thread-local  │   encode events locally
 │ buffer (~1MB) │ │ buffer (~1MB) │ │ buffer (~1MB) │   (almost never contended)
 └──────┬────────┘ └──────┬────────┘ └──────┬────────┘
        │ full batch, or epoch bump         │
        ▼                                   ▼
 ┌──────────────────────────────────────────────────┐   lock-free bounded queue,
 │ CentralCollector (1024 batches, drops oldest)    │   never blocks the sender
 └──────────────────────┬───────────────────────────┘
                        ▼
 ┌──────────────────────────────────────────────────┐   "dial9-flush" (nice +10)
 │ flush thread: every 5ms                          │   ONLY thread that writes
 │  - Source::flush() (perf rings, alloc queues…)   │   the segment files
 │  - drain collector → SegmentWriter               │
 │  - rotation / drain of idle thread buffers       │
 └──────────────────────┬───────────────────────────┘
                        ▼ sealed *.bin files
 ┌──────────────────────────────────────────────────┐   "dial9-worker" thread with
 │ worker: gzip → symbolize → S3 upload             │   its own single-threaded
 └──────────────────────────────────────────────────┘   Tokio runtime ("pipeline")
```

### Your threads: the producers

In `dial9-core/src/encoder.rs`, each thread lazily creates a `thread_local!` buffer.
Events are encoded straight into a local `Vec<u8>` with its own string and stack pools —
there is no shared channel on the per-event path at all, which is the whole reason
recording is cheap.

The buffer does live in an `Arc<Mutex<…>>`, which looks alarming until you see who takes
the lock. The owning thread is the only regular user. The flush thread takes it only to
drain a buffer that has gone idle, which is the handshake described below. In practice
the mutex is uncontended essentially always.

A thread hands its buffer off when it reaches about 1 MB, or when it notices that the
global `drain_epoch` has moved past its own. The handoff is
`CentralCollector::accept_flush`, a lock-free `force_push` onto a bounded ring of 1024
batches. And that is the answer to "what happens under pressure": if the collector is
full, the *oldest* batch is dropped and counted, and the flush thread logs a rate-limited
warning. Nothing on the producer path ever blocks. If a buffer's mutex somehow gets
poisoned, that thread simply stops recording and the rest of the process carries on.
When a thread exits, `Drop` on its buffer flushes whatever was left.

Finding the recorder is similarly cheap. `Dial9Handle::current()` in `handle.rs` checks
three places in order: a thread-local handle installed by Tokio's `on_thread_start` hook
and cleared on `on_thread_stop`; then a process-global handle in a lock-free
`ArcSwapOption`, if you called `install_global_handle()`; then a disabled handle that
makes recording a no-op. Whether recording is on, off or permanently stopped is a single
`AtomicU8`, so the "should I record this?" check is one atomic load.

### The flush thread: the single consumer

`Recorder::start` in `recording.rs` spawns a thread named `dial9-flush` and puts it at
`nice(10)`, so it yields to your application whenever the machine is busy. Its loop, in
`flush_loop.rs`, waits up to 5 ms on a control channel — the only command it understands
is `FinalizeAndStop`, sent at shutdown — and then does three things.

First it calls `flush()` on every registered `Source`. This is how background data
enters the trace, and it's where the design pays off. The CPU profiler reads perf's
kernel-shared ring buffers, or `ctimer`/`SIGPROF` samples, without taking a lock. The
memory profiler's allocator hook runs on *your* thread, where it is not allowed to
allocate or lock, so all it does is push fixed-size records into two lock-free
`ArrayQueue`s; the flush thread drains those, interns the stacks and encodes the events
later. Process resource usage, socket accept queues and the other sampled sources work
the same way. Everything that would be dangerous on a hot path — encoding a stack from
inside a signal handler or an allocator, doing file I/O — has been moved here.

Then it drains the collector and writes the batches through the `SegmentWriter`. This is
the only code path that touches the writer, which is precisely why the writer needs no
locking of its own.

Finally, it flushes its own thread-local buffer, but only about once a second, so it
doesn't fill the trace with many tiny batches of its own bookkeeping.

### Draining quiet threads

There's a subtle problem with per-thread buffers: a thread that records rarely might sit
on the same buffer for minutes, and its events would then land in whichever file happens
to be open when it finally flushes — the wrong one. `docs/design/tl-buffer-drain.md`
describes the fix, which is a two-step handshake.

On one tick, the flush thread increments `drain_epoch`. Busy threads notice on their very
next event and flush themselves. On the next tick, roughly 5 ms later, the flush thread
walks the registered `Weak<Mutex<Buffer>>` handles and skips every buffer whose epoch
already matches — those are the threads that flushed themselves. It locks and drains only
the ones that stayed silent.

The result is that busy threads never contend with the flush thread. The only buffers
that get locked from outside belong to threads that, by definition, aren't doing anything
at that moment.

### The background worker

With the `pipeline` feature on, `worker/mod.rs` spawns a thread named `dial9-worker`,
which builds its *own* single-threaded Tokio runtime called `dial9-worker-rt` to run
async processors like the S3 upload. It watches for sealed segment files and pushes each
one through the processor chain.

The separate runtime is the point. A slow S3 upload cannot steal your worker threads, and
dial9 behaves identically whether or not your application uses Tokio at all. Panics in
the worker are caught and logged rather than taking the process down, and
`graceful_shutdown(timeout)` gives it a bounded amount of time to finish before it's
abandoned.

### How your Tokio runtime fits in

dial9 does not own any of your runtime's threads. `attach_tokio_runtime` just registers
callbacks on your `tokio::runtime::Builder` — see `tokio_hooks.rs`. `on_thread_start` and
`on_thread_stop` install and clear the thread-local handle and call
`Source::on_thread_start`/`on_thread_stop`, which is how, for instance, the sched profiler
opens a perf fd per worker thread. `on_before_task_poll`/`on_after_task_poll`,
`on_thread_park`/`unpark` and `on_task_spawn`/`terminate` record events into that thread's
local buffer. A worker thread's index is resolved lazily on its first unpark or poll,
because Tokio's `RuntimeMetrics` isn't available yet during `on_thread_start`.

You can attach several runtimes — including one runtime per thread in a thread-per-core
setup. They all share one `SharedState`, one collector and one flush thread, so everything
still lands in a single trace.

### Shutdown order

`stop_flush_thread` in `recording.rs` runs a fixed sequence: clear the global handle;
drain the calling thread's own buffer, since that thread never gets a stop hook; send
`FinalizeAndStop` and wait for the acknowledgement; join the flush thread; mark the state
`Stopped`, which is permanent; release the sources. `graceful_shutdown` then hands the
worker its drain timeout.

The documented advice is to drop your runtime *before* calling `graceful_shutdown`, so
that the worker threads have already flushed their buffers via `on_thread_stop` by the
time the flush thread is asked to finalize.

### Summary

| Concern | Mechanism |
|---|---|
| Recording on hot path | Thread-local encoder, uncontended mutex, lock-free handoff |
| Backpressure | None: bounded ring buffer drops oldest batches, never blocks |
| File I/O | Single flush thread (`nice +10`), only owner of the writer |
| Signal handler / allocator data | Lock-free queues or perf mmap rings, encoded later by the flush thread |
| Idle-thread events | Two-step `drain_epoch` handshake |
| Compression / upload | Separate thread with a private current-thread Tokio runtime |
| Handle lookup | Thread-local handle, then global `ArcSwap`, then disabled no-op |

These concurrency paths are covered by [shuttle](https://github.com/awslabs/shuttle)
tests — `pipeline_shuttle_tests.rs`, `worker/shuttle_tests.rs` and the shuttle scenarios
in `shared_state.rs` — and a `primitives` module swaps the std and Tokio primitives for
shuttle's deterministic versions when those run. Which is the right way to test this: the
whole design is a pile of "this is safe because of when it happens", and that's exactly
the class of claim a model checker can actually check.

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
   order, with the threading model above open alongside. This is the real content.
4. One producer that matches what you care about — `tokio-telemetry` for async,
   `perf-self-profile` for CPU and memory.
5. `dial9-viewer` — only when you want to know what the trace is supposed to tell you.

The thread that ties it all together is the answer to *what happens under pressure*. An
always-on tracer is defined by its behaviour when the buffers are full and the service is
already struggling, because that is exactly the moment you most want the trace and least
want the tracer making things worse. dial9's answer is consistent everywhere you look:
the producer never waits, the trace loses data instead, and the loss is counted so you
know it happened.
