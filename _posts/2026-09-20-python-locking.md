---
layout: post
title: "[Python] Locking in Python"
date: 2026-09-20 00:00:00 +0530
categories: python
tags: [python, concurrency, locking, threads, system_design, pending]
author: "Seroze"
published: true
---

*Companion to [A primer in Python](/python-primer/) — its [GIL section](/python-primer/#the-gil) argues that
`counter += 1` needs a `Lock` and then never shows you one. This post is that missing half,
worked through a single design problem instead of a tour of the `threading` module. The
[Rust version](/rust-locking/) of the same material is a useful contrast: there the compiler
does half of this for you.*

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

Design a thread-safe parking lot. It's one-dimensional — a row of `n` slots.

- A car occupies 1 slot.
- A truck occupies 2 *consecutive* slots.
- Parking and removal happen concurrently, from many threads.

That's the whole spec, and it's a good one, because the truck is where all the difficulty
lives. A car is a single-slot compare-and-set. A truck is a transaction across two slots,
and every interesting concurrency question in this problem falls out of that.

## Start with the API, not the locks

Two shapes are reasonable and they're not the same problem.

**Caller picks the position:**

```python
lot.park(pos, length)      # length ∈ {1, 2}
lot.remove(pos, length)
lot.is_free(pos, length)
```

**Lot picks the position:**

```python
lot.park(length) -> position | None
lot.remove(position, length)
```

The second is what a real parking lot does, and it's the harder one — now you have to
*search* for a free run of slots while other threads are filling them in underneath you.
The first is fine if the requirement really is "put this vehicle at slot 7."

I'll build the second, because the search is where the subtle bug is. Internally it still
needs the first as a primitive: `park(length)` is a loop over candidate positions calling
"try to take exactly this range, atomically."

## One lock is correct and too slow

The obvious implementation:

```python
class ParkingLot:
    def __init__(self, n):
        self.lock = threading.Lock()
        self.occupied = [""] * n
```

Every operation takes `self.lock`. This is *correct* — that's worth saying, because a lot
of concurrency work consists of starting here and only leaving when you've measured a
reason to. But a 500-slot lot serialises 500 independent slots behind one mutex. Two cars
parking at opposite ends of the row have nothing to do with each other and still queue.

So: one lock per slot.

```
slot 0 -> lock 0
slot 1 -> lock 1
slot 2 -> lock 2
...
```

A car takes one lock. A truck takes two adjacent ones. Disjoint operations never touch.

## The check and the write must happen under the same lock

This is the part that's easy to get wrong, and it's not specific to parking lots.

For a car:

```
acquire(lock[i])
    check  slot[i] is free
    occupy slot[i]
release(lock[i])
```

For a truck:

```
acquire(lock[i])
acquire(lock[i+1])
    check  slot[i] and slot[i+1] are both free
    occupy both
release(lock[i+1])
release(lock[i])
```

If you check outside the lock and write inside it, you get:

```
T1: sees slot i free
T2: sees slot i free
T1: occupies i
T2: occupies i        <- two vehicles, one slot
```

The lock isn't protecting the *write*. It's protecting the window between reading the state
and acting on what you read. That window is the transaction, and a check-then-act split
across a lock boundary is a bug however careful the write half looks.

For the truck this matters twice over: you must hold *both* locks before checking *either*
slot. Check `i`, take `i`, then check `i+1` and find it taken, and now you have to give `i`
back — which is doable but it's a rollback, and rollbacks are the thing lock-set acquisition
exists to avoid.

## Does this deadlock?

Two trucks arrive. One wants `[i, i+1]`, the other wants `[i+1, i+2]`. They overlap. Is
there an interleaving where both stop forever?

A deadlock needs a cycle in the wait-for graph:

```
T1 holds i     -> waiting for i+1
T2 holds i+1   -> waiting for i
```

For that second line to happen, T2 must acquire `i+1` *and then* try to acquire `i`. But T2
wants `[i+1, i+2]`, and it acquires in increasing position order, so after `i+1` it reaches
for `i+2` — never backwards. The cycle can't be formed.

An actual execution looks like:

```
T1: acquire i
T2: acquire i+1
T1: try i+1     -> blocks
T2: acquire i+2 -> ok
T2: finishes, releases i+2, i+1
T1: gets i+1, finishes
```

T1 waits. Nobody deadlocks. Waiting is fine; waiting in a cycle is not.

The property doing the work here is not "trucks are only 2 long" — it's **a global
acquisition order that every thread obeys**. Generalise to a vehicle of length `k` and
nothing changes:

```
acquire: i, i+1, i+2, ..., i+k-1
release: i+k-1, ..., i+1, i
```

Increasing position is a total order on the locks, so the wait-for graph is a DAG by
construction. This is the standard deadlock-prevention technique and it's worth naming as
such: you're not reasoning about your specific access patterns, you're removing the
possibility of a cycle.

One asymmetry worth being precise about: **the acquisition order is what prevents
deadlock. Releasing in reverse order does not.** Release order is a discipline — it keeps
nested lock scopes properly nested, which matters once locks are held across function
boundaries, and it's what `with` blocks give you for free. But you could release in any
order and still be deadlock-free.

## Why not read-write locks

My first instinct was `RwLock` per slot. It isn't worth it here.

Look at what a parking operation actually does:

```
lock
    read state
    validate
    modify state
unlock
```

That's a writer, start to finish. The read is *part of* the write — it's a
read-modify-write, and a read lock can't hold across the upgrade. `is_free()` could take
read locks, but `is_free()` isn't on the hot path of anything (and, as below, it's barely
useful). You'd be paying a reader-writer lock's extra bookkeeping on every parking
operation to speed up a query nobody runs.

Plain mutexes:

```python
self.locks = [threading.Lock() for _ in range(n)]
self.occupied = [""] * n
```

`RwLock` earns its keep when reads genuinely dominate and genuinely don't mutate — a
config map, a routing table, a cache read path. Not here.

## `occupied[i] = True` isn't enough state

Say the lot looks like this, with a truck in slots 0–1 and a car in slot 2:

```
slot:   0    1    2    3
        T    T    C    .
```

Someone calls `remove(1, 1)`. Should that work?

No — slot 1 isn't a vehicle, it's *half* of one. With a boolean array you can't tell the
difference, and you'd cheerfully free slot 1 and leave a one-slot truck behind in slot 0.
The state has to record what's there, not just that something is:

```python
self.occupied[i] = vehicle_id     # "" means free
```

```
slot 0 -> truck_123
slot 1 -> truck_123
slot 2 -> car_456
```

Now removal can validate ownership: every slot in the range must name the vehicle being
removed, or the operation is rejected. The invariant the data structure is enforcing is
"a vehicle is removed whole or not at all," and you can't enforce an invariant you can't
represent.

Keying by `vehicle_id` also lets the caller say `remove("truck_123")` without remembering
where it parked, which is the API you actually want.

## The implementation

```python
import threading
from contextlib import ExitStack


class ParkingLot:
    def __init__(self, n: int):
        self.n = n

        # Domain 1: the slots. Protected by one lock per slot.
        self.slot_locks = [threading.Lock() for _ in range(n)]
        self.occupied = ["" for _ in range(n)]

        # Domain 2: the index. Protected by its own lock.
        self.meta_lock = threading.Lock()
        self.pos = {}  # vehicle_id -> (position, length)

    @staticmethod
    def _length_of(vehicle_id: str) -> int:
        if vehicle_id.startswith("truck_"):
            return 2
        if vehicle_id.startswith("car_"):
            return 1
        raise ValueError(f"unknown vehicle type: {vehicle_id}")

    def _hold(self, stack: ExitStack, pos: int, length: int) -> None:
        """Acquire every lock in [pos, pos+length), in increasing order."""
        for lock in self.slot_locks[pos:pos + length]:
            stack.enter_context(lock)

    def occupy(self, pos: int, length: int, vehicle_id: str) -> bool:
        """Atomically take [pos, pos+length). False if any slot is taken."""
        if pos < 0 or length <= 0 or pos + length > self.n:
            return False

        with ExitStack() as stack:
            self._hold(stack, pos, length)

            # Check only after every lock is held.
            if any(self.occupied[i] for i in range(pos, pos + length)):
                return False

            for i in range(pos, pos + length):
                self.occupied[i] = vehicle_id
            return True

    def park(self, vehicle_id: str) -> int:
        """Park at the first position that fits. Returns the start position."""
        length = self._length_of(vehicle_id)

        for pos in range(self.n - length + 1):
            if self.occupy(pos, length, vehicle_id):
                with self.meta_lock:
                    self.pos[vehicle_id] = (pos, length)
                return pos

        raise RuntimeError("no space available")

    def remove(self, vehicle_id: str) -> bool:
        with self.meta_lock:
            info = self.pos.get(vehicle_id)
        if info is None:
            return False
        pos, length = info

        with ExitStack() as stack:
            self._hold(stack, pos, length)

            # Ownership check, under the locks.
            if any(self.occupied[i] != vehicle_id for i in range(pos, pos + length)):
                return False

            for i in range(pos, pos + length):
                self.occupied[i] = ""

        with self.meta_lock:
            self.pos.pop(vehicle_id, None)
        return True

    def is_free(self, pos: int, length: int) -> bool:
        """Was [pos, pos+length) free a moment ago. See the caveat below."""
        if pos < 0 or length <= 0 or pos + length > self.n:
            return False

        with ExitStack() as stack:
            self._hold(stack, pos, length)
            return not any(self.occupied[i] for i in range(pos, pos + length))
```

`ExitStack` is the right tool for a lock *set* whose size isn't known until runtime. You
can't write `with lock[i], lock[i+1]:` when the count is a variable, and hand-rolling it as

```python
for lock in locks:
    lock.acquire()
try:
    ...
finally:
    for lock in reversed(locks):
        lock.release()
```

works but has a real hole: if `acquire()` raises partway through the first loop — a
`KeyboardInterrupt` lands between two acquisitions, say — the `try` hasn't started and
the locks already taken are never released. `ExitStack` registers each lock's release the
instant it's acquired, and unwinds in reverse order on the way out. Same discipline, no
gap.

## Why `park()` doesn't call `is_free()`

The tempting version of the search loop:

```python
for pos in range(self.n - length + 1):
    if self.is_free(pos, length):          # wrong
        self.occupy(pos, length, vehicle_id)
        return pos
```

```
T1: is_free(5, 2) -> True
T2: is_free(5, 2) -> True
T1: occupy(5, 2)  -> True
T2: occupy(5, 2)  -> False   ... and T2 returns 5 anyway
```

Nothing is *corrupted* — `occupy()` is still atomic, so T2 doesn't get the slots. But T2
believed it had parked. The lock was released between the check and the act, so the answer
`is_free()` gave was already stale by the time it was used.

This is the same check-then-act bug as before, one level up. The fix is the same: make the
check part of the operation, not a separate call before it. `occupy()` *is* the
reservation primitive — it answers "is this free?" and "take it" in one locked step — so
`park()` just tries:

```python
if self.occupy(pos, length, vehicle_id):
```

and lets the return value be the answer.

Which makes `is_free()` a bit of a trap. It's a fine public API for a dashboard, and it's
honestly named above, but it must never appear in the implementation. Any value it returns
describes a past that may already be gone.

## Two lock domains

The slot locks protect `occupied`. They do not protect `self.pos`, which is a different
data structure with a different access pattern — keyed by vehicle, touched once per park
and once per remove. It gets its own lock:

```
slot locks    ->  occupied[0..n-1]
meta_lock     ->  pos: vehicle_id -> (position, length)
```

In CPython a single `dict` assignment happens to be atomic under the GIL, so you could
argue `self.pos[vehicle_id] = ...` is "safe" without a lock. Don't build on that. It's an
implementation detail of one interpreter, it's exactly what the [free-threaded
build](/python-primer/#the-gil) is changing, and "protected by the GIL" is not a sentence
you can point at in a design review. Naming the lock that protects each structure is.

Two questions follow from having two domains, and they're the last hard part of this
design.

## Does the metadata lock remove the serialization assumption?

For the dictionary, yes. For the vehicle, no — and that gap is the distinction most worth
carrying out of this problem.

`meta_lock` makes every access to `self.pos` mutually exclusive:

```python
with self.meta_lock:
    self.pos[vehicle_id] = (pos, length)
```

Three threads running `park("car_1")`, `remove("car_1")` and `park("car_1")` at once can't
corrupt that dict, can't read a half-written entry, can't lose an insert. That guarantee
needs no assumption about who calls what when.

It does not make `park` and `remove` atomic *with respect to each other*. Each takes
several locks over its lifetime, releasing in between, and another thread can land in any
of those gaps:

```
T1 park(car_1):
    occupies slot 10

T2 remove(car_1):
    reads pos -> car_1 isn't there yet
    returns False

T1:
    pos["car_1"] = (10, 1)
```

The dictionary was never in a bad state. Every individual access to it was locked. The
outcome is still wrong: the car is parked, the removal reported failure, and slot 10 is now
held by a vehicle nobody will ever ask about again.

**A thread-safe data structure does not give you thread-safe operations.** The two lock
domains protect two structures. Neither protects the *transition* — "this vehicle goes from
unparked to parked" — which spans both of them.

Two ways out, and which one is right depends on the requirement:

- **Keep the assumption.** If operations for a given `vehicle_id` are serialized by the
  caller — one request in flight per vehicle, which is how a gate terminal actually behaves
  — the gap can never be observed and the code above is finished. That's a legitimate
  answer as long as it's stated rather than smuggled in.
- **Drop the assumption.** Give each vehicle its own lock and hold it across the whole
  operation, so park and remove for the same vehicle serialize against each other. It's
  cheap: different vehicles still don't contend, which is the property you were buying with
  per-slot locks in the first place.

They fail differently, which is the reason to know which one you picked. Under the
assumption, a caller who breaks it gets a silently leaked slot. Under the per-vehicle lock,
they get to wait.

## Can two classes of lock deadlock?

The earlier argument covered the slot locks — increasing position, no cycle. `meta_lock` is
a second *class* of lock, so that argument has to be redone. The question is no longer "in
what order do I take slot locks" but "where does `meta_lock` sit relative to them."

Name them:

```
M                   = meta_lock
L0, L1, ..., Ln-1   = slot locks
```

Now suppose `park()` held its slot locks while reaching for the metadata, and `remove()`
did the reverse:

```
park:    L5 -> L6 -> M
remove:  M  -> L5 -> L6
```

```
T1 (park)            T2 (remove)

holds L5             holds M
   |                     |
waits for M          waits for L5
```

Deadlock. Neither thread is doing anything unreasonable in isolation, and both are
internally consistent about slot ordering — my original "always take `i` before `i+1`"
rule is satisfied on both sides. The cycle comes from the two *classes* being visited in
opposite orders: `L5 -> M` on one path, `M -> L5` on the other. Adding a lock class
invalidates the old proof even when no existing code changed.

Two fixes, both fine.

**Put M in the total order.** Declare

```
M < L0 < L1 < ... < Ln-1
```

and require every path to acquire left to right. `M -> L5 -> L6` is legal; `L5 -> M` is
not. No cycle can form, for exactly the reason from before — a thread holding a higher lock
never reaches back for a lower one.

**Or never hold both at once,** which is what the implementation above does. `park()` takes
the slot locks, releases them, and only then takes `meta_lock`. `remove()` takes `meta_lock`
to read `pos`, releases it, takes the slot locks, releases those, then takes `meta_lock`
again to delete. No thread ever holds a lock of one class while waiting on the other, so
the wait-for graph has no edge between classes at all.

The weaker-looking option is often the better one. A total order is a rule you have to keep
enforcing as the code grows; "these two domains are never held together" is a property a
reviewer can check by eye. The cost is the gap in the middle — which is precisely the
operation-level race from the previous section. You're trading a deadlock risk for an
atomicity gap, and it's worth saying that out loud rather than discovering it later.

## Proving it, in four steps

The habit generalises past this problem, and it's the part I'd actually want to remember:

1. **List every lock.** Including the ones that don't look like locks — a queue's internal
   mutex, a connection pool's semaphore, the lock inside a library you call while holding
   your own.
2. **Define a total ordering over them.** It has to come from something intrinsic to the
   resources — slot index, account id, inode number — never from the order a particular
   request happened to mention them.
3. **Walk every code path** that takes more than one lock, and write down the sequence it
   acquires.
4. **Check that every sequence is increasing** in that order.

If all four hold, deadlock is impossible and you can say so as a proof instead of as a
feeling about your access patterns. For this class the audit is short:

| path | acquires | verdict |
|---|---|---|
| `occupy` | slot locks, left to right | increasing |
| `is_free` | slot locks, left to right | increasing |
| `park` | slot locks (via `occupy`), then M on its own | never held together |
| `remove` | M on its own, then slot locks, then M on its own | never held together |

Step 3 is the one people skip, and it's where the bugs live: the ordering is usually right
in the function you're reading and wrong in the one that calls it while already holding
something.

## Checking it actually holds

The bug this design exists to prevent is silent, so it's worth a harness that would catch
it. Park and remove from many threads at once, then assert the invariant: every occupied
run is exactly one whole vehicle.

```python
import random
from concurrent.futures import ThreadPoolExecutor

lot = ParkingLot(64)

def churn(worker: int):
    for i in range(2000):
        kind = random.choice(("car", "truck"))
        vid = f"{kind}_{worker}_{i}"
        try:
            lot.park(vid)
        except RuntimeError:
            continue
        lot.remove(vid)

with ThreadPoolExecutor(max_workers=16) as pool:
    list(pool.map(churn, range(16)))

assert all(slot == "" for slot in lot.occupied), "leaked slots"
assert not lot.pos, "leaked index entries"
```

Move the check in `occupy()` to before the `_hold()` call and this fails every run on my
machine. Drop it to 2 threads doing 20 iterations each and the same broken code passed 20
times out of 20 — which is the real lesson. Concurrency bugs are a probability, not an
event, and the probability is a function of how hard you push. A test that passes once has
told you very little.

## The pattern underneath

Strip out the parking lot and what's left generalises:

```python
locks = relevant_locks()          # chosen by a global, total order

with ExitStack() as stack:
    for lock in locks:
        stack.enter_context(lock)

    # validate
    # mutate
# released in reverse
```

Establish a consistent lock order, acquire the *whole* set, perform the state transition,
release. Row-level locks in a database, a bank transfer touching two accounts, a memory
allocator's size-class locks, a filesystem renaming across two directories — same four
steps, and the global order is always something intrinsic to the resources (slot index,
account id, inode number) rather than the order the request happened to mention them in.

## A second problem: an asynchronous task processor

**TODO** — not written yet.

Design an asynchronous task processing system and extend it to support:

- scheduling tasks for a particular time,
- scheduling tasks at recurring intervals,
- task processing and execution management.

The shape most implementations converge on:

```
                    submit()
                       |
                       v
              +----------------+
              |  Scheduler     |
              |                |
              | min-heap       |
              | (run_at, task) |
              +-------+--------+
                      |
                task becomes due
                      |
                      v
              +----------------+
              | Ready Queue    |
              | FIFO / channel |
              +-------+--------+
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
       Worker 1    Worker 2    Worker N
          |           |           |
          +-----------+-----------+
                      |
                      v
                 execute(task)
```

### Why the heap and the queue are separate structures

### Scheduling for a particular time

### Recurring intervals

### Execution management: cancellation, failure, shutdown

## What I'd tell myself before starting

- Design the API first. `park(length) -> position` and `park(pos, length)` are different
  problems and only one of them has a search in it.
- One global lock is correct. Leave it for a reason, not by reflex.
- The lock protects the window between reading state and acting on it, not the write.
  Check-then-act across a lock boundary is a bug even when both halves look careful.
- Acquire the whole lock set before inspecting any of it. Partial acquisition means
  rollback.
- A global acquisition order is what kills deadlock. Reverse release order is discipline,
  not the mechanism.
- Reach for `RwLock` only when reads dominate *and* don't mutate. A read-modify-write is a
  write.
- Your state has to be able to express your invariant — a boolean array can't say "this
  truck is one object."
- Say which lock protects which structure. "The GIL makes it fine" isn't an answer, and
  the free-threaded build is busy making it less of one.
- A thread-safe data structure is not a thread-safe operation. Locking every access to a
  dict says nothing about whether the multi-step operation around it is atomic.
- Adding a second *class* of lock invalidates your old deadlock proof even if no existing
  code changed. Either place it in the total order, or never hold the two classes at once.
- The proof is four steps: list every lock, define a total order, walk every multi-lock
  path, check each sequence is increasing. Step 3 is where the bugs are.
