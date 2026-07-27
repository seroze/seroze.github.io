---
layout: post
title: "HTCondor: Notes on an Open-Source Job Scheduler"
date: 2026-07-27 00:00:00 +0530
categories: distributed-systems
tags: [htcondor, job_scheduling, distributed_systems, hpc]
author: "Seroze"
published: true
---

*Working notes on HTCondor — a workload manager for high-throughput computing. This one showed up on TrexQuant's job requirements, which is what sent me looking. Filling this in as I learn it.*

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## What is HTCondor?

HTCondor is an open-source workload manager: you hand it a description of a job, it finds a machine in a pool that can run it, ships the job there, runs it, and gets the output back to you. It comes out of the Center for High Throughput Computing at UW–Madison, where it started life as "Condor" in the 1980s before being renamed in 2012. It's Apache 2.0 licensed.

The phrase to anchor on is **high-throughput computing (HTC)**, not high-performance computing (HPC). The distinction is the thing HTCondor is actually organised around:

| | HPC | HTC |
|---|---|---|
| Optimises for | FLOPS over seconds/hours | Jobs completed over weeks/months |
| Typical job | One tightly-coupled MPI job across many nodes | Many independent jobs |
| Failure of one node | Kills the job | Reschedules one job |
| Hardware | Uniform, dedicated cluster | Heterogeneous, possibly borrowed |

If your workload is "run this simulation across 512 tightly-synchronised cores," that's Slurm/MPI territory. If it's "run these 200,000 independent backtests and tell me when they're all done," that's HTCondor.

> TODO: expand — where the HTC framing actually changes design decisions.

## Why quant firms use it

> TODO: fill in. The shape of the argument I want to make:
>
> - Parameter sweeps and backtests are embarrassingly parallel — the canonical HTC workload.
> - Research compute is bursty; a scheduler that reclaims idle desktops/cycles is worth a lot.
> - Fair-share and priority policy matters when many researchers contend for one pool.
> - It's free and self-hosted, so no per-core licensing on a large internal grid.
>
> Verify how much of this is actually why, vs. my speculation.

## Architecture

A pool has three roles. One machine can play more than one.

```
                  ┌──────────────────────────┐
                  │     Central Manager      │
                  │  collector + negotiator  │
                  └───────────┬──────────────┘
                              │ matchmaking
              ┌───────────────┴────────────────┐
              │                                │
    ┌─────────▼─────────┐          ┌───────────▼─────────┐
    │   Submit Node     │          │   Execute Node      │
    │      schedd       │──jobs──► │  startd → starter   │
    └───────────────────┘          └─────────────────────┘
```

| Daemon | Runs on | Job |
|---|---|---|
| `condor_master` | Every node | Supervises the other daemons, restarts them |
| `condor_collector` | Central manager | The pool's directory — everything advertises itself here |
| `condor_negotiator` | Central manager | Matchmaking: pairs waiting jobs with available machines |
| `condor_schedd` | Submit node | Owns the job queue, manages submitted jobs |
| `condor_startd` | Execute node | Advertises the machine's resources, accepts jobs |
| `condor_starter` | Execute node | Spawned per job; actually runs it and reports back |

> TODO: trace one job end-to-end through these daemons.

## ClassAds and matchmaking

The idea underneath everything else. Both jobs and machines describe themselves with **ClassAds** (classified advertisements) — sets of attribute/value pairs. Crucially, both sides state *requirements* and *preferences*:

- A job says: I need 4 GB of RAM and Linux, and I'd prefer a faster machine.
- A machine says: I'll accept jobs from these users, and I prefer short ones.

The negotiator then finds pairs where each side's `Requirements` expression evaluates true against the other's ad, and ranks the candidates by each side's `Rank` expression. It's bilateral — the machine gets a say, which is what makes "borrow idle desktops but give them back when someone sits down" expressible as policy rather than special-cased code.

> TODO: worked example of a job ad and a machine ad side by side, with the
> Requirements/Rank expressions that match them.

## Submitting a job

A submit file describes the job; `condor_submit` hands it to the schedd.

```
executable   = run_backtest.sh
arguments    = --strategy $(strategy) --year $(year)

output       = logs/out.$(Cluster).$(Process)
error        = logs/err.$(Cluster).$(Process)
log          = logs/job.log

request_cpus   = 1
request_memory = 4GB
request_disk   = 1GB

queue
```

- **Cluster** — the id of one `condor_submit` invocation.
- **Process** — the index within that cluster. A job is identified as `Cluster.Process`, e.g. `1234.56`.
- `queue N` submits N copies; the richer `queue ... from ...` forms are how you fan out over a parameter list.

> TODO: the `queue from`/`queue matching` variants, and the file transfer
> mechanism (`should_transfer_files`, `transfer_input_files`) — that's the part
> that actually bites when the execute node has no shared filesystem.

## Everyday commands

| Command | Does |
|---|---|
| `condor_submit job.sub` | Submit a job |
| `condor_q` | Show your queued jobs |
| `condor_q -better-analyze <id>` | Explain why a job isn't running |
| `condor_status` | Show machines in the pool and their state |
| `condor_rm <id>` | Remove a job |
| `condor_hold` / `condor_release` | Pause / resume a job |
| `condor_history` | Look at completed jobs |
| `condor_submit_dag <file>` | Submit a DAGMan workflow |

`condor_q -better-analyze` is the one to remember — "my job is idle and I don't know why" is the default HTCondor experience, and this is the tool that tells you which requirement failed to match.

> TODO: annotate real output from each of these once I have a pool running.

## Universes

The **universe** picks the runtime environment for a job.

| Universe | Use |
|---|---|
| `vanilla` | The default — any ordinary executable |
| `container` / `docker` | Run inside a container image |
| `parallel` | Multi-machine jobs (MPI) |
| `scheduler` | Runs on the submit node, doesn't wait for a match (DAGMan uses this) |
| `local` | Runs on the submit node immediately |
| `grid` | Delegate to an external resource manager |

> TODO: check which universes are current vs. deprecated in recent releases —
> `standard` is gone, and I think the docker universe is now folded into
> `container`. Verify before publishing.

## DAGMan — workflows with dependencies

Most real pipelines aren't a flat pile of independent jobs; step B needs step A's output. DAGMan (Directed Acyclic Graph Manager) is HTCondor's answer: you declare jobs and edges, it handles submission order, retries, and recovery from a partially-completed run.

```
JOB  fetch   fetch.sub
JOB  train   train.sub
JOB  report  report.sub

PARENT fetch  CHILD train
PARENT train  CHILD report

RETRY train 3
```

> TODO: rescue DAGs — the recovery-after-failure story is the actual selling
> point and I don't understand it yet.

## Things I still need to work out

- [ ] Set up a single-machine pool locally and run a real job through it.
- [ ] File transfer without a shared filesystem — the mechanics and the failure modes.
- [ ] Priorities and fair-share: how `condor_userprio` actually allocates between users.
- [ ] Job checkpointing and preemption — what happens to a job when a machine is reclaimed.
- [ ] Flocking (spilling jobs into another pool) and glideins (pilot jobs onto external resources).
- [ ] Security: how authentication works in a pool that isn't all one trusted host.
- [ ] How it compares to Slurm, Nomad, and Kubernetes Jobs, and when you'd pick which.

## References

> TODO: add links as I go.

- HTCondor manual — <https://htcondor.readthedocs.io>
- Center for High Throughput Computing, UW–Madison — <https://chtc.cs.wisc.edu>
