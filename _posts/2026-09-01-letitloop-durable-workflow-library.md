---
layout: post
title: "[Python] LetItLoop — Notes From Building a Durable Workflow Library"
date: 2026-09-01 00:00:00 +0530
categories: python
tags: [python, durable_workflows, libraries]
author: "Seroze"
published: true
---

I spent a day building `pickup`, a small library that makes a Python function
crash-resumable. You wrap a function in `@run`, wrap each expensive call in
`step(...)`, and if the process dies halfway through, the next run skips
everything that already finished.

```python
@run("nightly-sync")
def sync():
    users = step("fetch", fetch_users)
    return step("summarize", summarize, users)
```

The code is at [github.com/seroze/pickup](https://github.com/seroze/pickup).
These are the notes from building it, phase by phase.

## Phase 0–1: records, codec, journal

The journal is an append-only JSONL file. One record per line: an open record
when a run starts, a step record for each completed step, a seal record when
the run finishes. `replay()` reads the file back into a dict of completed steps.

Two things mattered here. First, `append()` does an `fsync` — without it, a
`kill -9` loses the last few steps and the whole premise falls apart. Second,
a crash mid-write leaves a torn final line, so replay discards an unparsable
last line instead of blowing up.

## Phase 2–3: RunContext, ContextVar, step()

`step("fetch", fn)` takes no context argument, which is the whole point —
user code shouldn't thread a context object through five stack frames. So
`step()` looks the context up from ambient state:

```python
_current = ContextVar("pickup_run_context", default=None)

def bind(ctx):    return _current.set(ctx)   # returns a Token
def unbind(token): _current.reset(token)
```

A `ContextVar` is a global with one crucial difference: each thread and each
asyncio task sees its own value. Two concurrent runs in two tasks don't stomp
on each other. The `Token` matters for nesting — `unbind` restores the previous
context rather than setting `None`, so an inner run ending doesn't wipe out the
outer one.

Two edges worth knowing: a task created *inside* a run inherits that run, but a
plain `threading.Thread` starts from a fresh context and raises `NoActiveRun`.

`RunContext.execute()` is the actual logic, and its read path never touches
disk. The journal is read once at startup to populate `completed`; after that,
reads hit memory and only writes go to disk.

## Phase 4: the @run decorator

`@run("sync")` has parentheses, so it's a decorator *factory* — `run(...)`
returns the decorator, which returns the wrapper. The lifecycle it owns:

```python
state = journal.replay()
ctx   = RunContext(run_id, journal, completed=state.completed)
if not state.sealed:
    journal.open(run_id)
token = bind(ctx)
try:
    result = fn(*args, **kwargs)
finally:
    unbind(token)
if not state.sealed:
    journal.seal()
return result
```

The design question I had to settle: who creates the journal? I gave it to
`@run`, deriving the path from the run id (`.pickup/<run_id>.jsonl`), with a
`journal=` escape hatch. That keeps the user-facing API to one decorator.

**Why seal at all?** Because "every step is present" doesn't mean "the run
finished". A run does work outside of steps — computing a return value, a final
API call — and a run that got through all its steps and then died has a journal
byte-identical to one that succeeded. The seal record is the one bit that tells
them apart, which is what a supervisor ("which runs failed?") or a retention
policy ("which journals are safe to delete?") needs.

I verified this against real process death, not a caught exception: a subprocess
calling `os._exit(1)` mid-run, which skips every `finally`. Attempt 1 ran
`fetch` and died, attempt 2 ran only `summarize`, attempt 3 ran nothing.

## Phase 5: locking

Two processes starting the same `run_id` at the same time both replay an empty
journal, both see nothing completed, and both charge the customer:

```
CHARGED $100 by procA
CHARGED $100 by procB
```

The race isn't on the file, it's on the *decision*. The critical section is the
entire read-modify-write cycle — replay through seal — so the lock has to be
held for the whole run, not per append.

`fcntl.flock` on a sidecar file (`<journal>.lock`), because the kernel releases
it when the process dies, including `kill -9`. No stale-lock heuristics needed.
It's a sidecar rather than the journal itself for reasons I'll get to below.

Default is fail-fast — `RunLocked` immediately rather than queueing, since
"someone else is running this" is usually something the caller wants to know.
One surprise found while testing: a process blocks against *itself*, so a nested
run on the same journal would deadlock. A module-level registry of held paths
catches that and raises instead of hanging.

### Never delete the lock file

`release()` closes the file descriptor and stops there. It does not unlink the
lock file. That empty file sits on disk forever, and that is correct — deleting
it is a race condition waiting to happen.

To see why, you need the distinction Unix makes between three things that people
usually think of as one:

```
   open()                                    flock()

filename ------------> inode <---------------- file descriptor
(directory entry)   (the actual file)        (per-process handle)
```

A filename is just an entry in a directory that maps a name to an inode number.
The inode is the real object — permissions, size, pointers to the data blocks.
And `unlink()`, which is what `rm` actually calls, only removes the directory
entry. It doesn't erase anything. The inode survives as long as either another
hard link points at it or some process still has it open, which is why a
deleted log file keeps working for the process that had it open, and why a
running executable can be deleted out from under itself.

Now put a lock on top of that. `flock()` attaches to the open file description,
which refers to the inode — never to the name. So here's the failure:

```
A holds flock on lockfile -> inode 100
A calls unlink("lockfile")     # directory entry gone, inode 100 alive
C calls open("lockfile", O_CREAT)   # creates a NEW inode 200
C calls flock(fd) -> succeeds immediately
```

Two processes now believe they hold the same lock, because they are locking two
different inodes that happen to share a name. Mutual exclusion is simply gone,
and nothing anywhere reports an error.

The variant where nobody recreates the file is only marginally better: a fourth
process calling `open("lockfile")` gets `ENOENT` and can't participate in the
synchronization at all.

This is also why the lock lives on a sidecar rather than on the journal itself.
`Journal.clear()` calls `unlink()`. If the lock were on the journal, clearing a
journal while another process held the run would silently hand out a free lock
to the next arrival.

So the rule is: a lock file has a stable path and a stable inode for the life of
the system. Everyone locks the same inode, the kernel arbitrates, and the empty
file on disk costs nothing. The lock lives in the kernel, not in the file's
contents — so there is nothing to clean up.

## Tests and examples

70 tests. The ones that were actually hard to write are the cross-process ones —
`flock` conflicts are enforced between open file descriptions and can't be
observed from inside a single process, so those tests spawn real subprocesses.

The `examples/` directory has four self-checking scenarios that crash for real
via `os._exit` and assert what survived. The nested one kills the process twice,
once inside a nested run and once in the outer run after it returned, and
verifies each of the four steps ran exactly once across four attempts.

One gotcha the examples surfaced:

```python
result = inner()                  # outer re-enters inner's body every time
result = step("report", inner)    # outer caches the result, never calls inner
```

Steps are skipped either way, but the non-step code in the inner body — logging,
a final API call — runs again in the first form.

## What's still broken

`replay()` breaks at the first unparsable line. That's right for a torn tail,
where everything after is genuinely unknowable, but for damage in the middle it
silently discards every valid record behind the break. A corrupt line at
position 0 returned 0 of 160 steps in a probe. Locking removed the most likely
cause, but disk errors haven't gone anywhere.

Also: step values must be JSON round-trippable, and JSON has no tuples and only
string keys. A step returning `(1, 2)` gets `[1, 2]` back after a resume, and
`{1: "a"}` becomes `{"1": "a"}`. Silent type drift across a crash is a nasty
class of bug for a library whose job is durability.

And the honest limit on the whole design: between "the side effect happened" and
"the record is durable" there is always an instant where a crash is
indistinguishable from the work never having happened. No journal format closes
that. You can narrow it with an intent record written *before* the step runs, so
replay can say "this step was in flight when we died" rather than silently
re-charging — but turning at-least-once into exactly-once needs the step itself
to be idempotent. The library's job is to make the ambiguity visible, not to
pretend it isn't there.
