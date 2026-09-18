---
layout: post
title: "[Rust] Locking in Rust"
date: 2026-09-18 00:00:00 +0530
categories: rust
tags: [rust, concurrency, locking, mutex, once_lock, threads]
author: "Seroze"
published: true
---

*Started as a question about `Once`, turned into a tour of the whole locking shelf in
`std::sync`. Companion to [A primer on Rust](/primer-on-rust/).*

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The short version

If you only want the takeaway from the conversation that kicked this post off:

- `Once` is "run this closure exactly once, no matter how many threads call it." It holds
  no data — it's just synchronisation state.
- `OnceLock<T>` is "initialise this value once, then hand everyone a `&T`." It stores the
  value.
- `LazyLock<T>` is `OnceLock<T>` with the initialiser baked in at the declaration, so
  callers just deref the static and never think about initialisation at all.
- For mutable shared state you want `Mutex<T>` or `RwLock<T>`, usually behind an `Arc`.
- For a single counter or flag, skip locks entirely and use an atomic.

The rest of this post is why each of those exists.

## Rust puts the data inside the lock

The first thing to unlearn from C or Java: in Rust a lock is not a thing you remember to
take before touching a variable. The lock *owns* the variable.

```rust
use std::sync::Mutex;

let counter = Mutex::new(0);
```

There is no way to read that `0` without going through `counter.lock()`. The discipline
that in C lives in a comment above the declaration ("callers must hold `foo_mutex`") is,
here, a type. You cannot forget it, because there's no unlocked path to the data.

```
Mutex<i32>
   │
   ├── lock state (who holds it, who's waiting)
   └── the i32 itself  ← only reachable through a guard
```

## `Mutex`: one writer at a time

`lock()` blocks until the mutex is free, then gives you a `MutexGuard<T>`, which derefs to
`&mut T` and releases the lock when it drops.

```rust
use std::sync::{Arc, Mutex};
use std::thread;

fn main() {
    let counter = Arc::new(Mutex::new(0));
    let mut handles = vec![];

    for _ in 0..10 {
        let counter = Arc::clone(&counter);
        handles.push(thread::spawn(move || {
            let mut n = counter.lock().unwrap();
            *n += 1;
        }));
    }

    for h in handles {
        h.join().unwrap();
    }

    println!("{}", *counter.lock().unwrap()); // 10
}
```

Two things in there are worth naming.

The `Arc` is doing a different job from the `Mutex`. `Arc` answers "how do ten threads all
get to refer to the same value?" — shared ownership. `Mutex` answers "how do they take
turns mutating it?" — mutual exclusion. You need both, which is why `Arc<Mutex<T>>` is such
a common sight.

The `unwrap()` is about *poisoning*. If a thread panics while holding the lock, the data
behind it might be half-updated, so every later `lock()` returns `Err(PoisonError)` to warn
you. `unwrap()` says "if that happened, I'd rather crash too." If you know your data is
still consistent after a panic, `lock().unwrap_or_else(|e| e.into_inner())` takes the guard
out of the error and carries on.

The guard's drop is what unlocks, so scope matters:

```rust
{
    let mut n = counter.lock().unwrap();
    *n += 1;
} // released here

expensive_unrelated_work(); // runs without holding the lock
```

Holding a guard across something slow — a network call, a long computation — is the
single most common way to turn a correct program into a slow one.

## `RwLock`: many readers or one writer

When reads vastly outnumber writes, `Mutex` serialises work that didn't need serialising.
`RwLock<T>` splits the API in two:

```rust
use std::sync::RwLock;

let table = RwLock::new(vec![1, 2, 3]);

{
    let r = table.read().unwrap();   // many of these can coexist
    println!("{}", r.len());
}

{
    let mut w = table.write().unwrap(); // exclusive
    w.push(4);
}
```

It is not free. A read lock does more bookkeeping than a mutex acquire, and writers can be
starved by a steady stream of readers depending on the platform's implementation. The rule
of thumb: reach for `RwLock` when reads dominate *and* the critical section is long enough
that the extra bookkeeping is noise. For a short read of a small value, `Mutex` often wins.

## `Once`: run something exactly once

This is the primitive that started the conversation. `Once` guarantees that a closure runs
exactly once, even if several threads race into it.

```rust
use std::sync::Once;

static INIT: Once = Once::new();

fn initialize() {
    INIT.call_once(|| {
        println!("Initializing...");
    });
}

fn main() {
    initialize();
    initialize();
    initialize();
}
```

Output:

```
Initializing...
```

Three calls, one print. Across threads it behaves the same way:

```rust
use std::sync::Once;
use std::thread;

static INIT: Once = Once::new();

fn setup() {
    INIT.call_once(|| {
        println!("Initialization happened");
    });
}

fn main() {
    let mut handles = vec![];

    for _ in 0..10 {
        handles.push(thread::spawn(|| setup()));
    }

    for h in handles {
        h.join().unwrap();
    }
}
```

Still one line of output. The property that makes it useful isn't just "runs once" — it's
that the losers of the race *block* until the winner finishes, and then observe the
completed initialisation.

```
Thread 1 ──┐
Thread 2 ──┤
Thread 3 ──┼──> INIT.call_once(...) ──> initialization happens once
Thread 4 ──┤
Thread 5 ──┘
```

Without that second half you'd have the classic double-checked-locking bug: a thread sees
the "initialised" flag set, proceeds, and reads a value the initialising thread hasn't
finished writing.

The thing to notice is what `Once` *doesn't* hold:

```rust
static INIT: Once = Once::new();
```

No `T` anywhere. It's synchronisation state and nothing else. If your initialisation
produces a value, you're on your own for storing it — which is exactly the gap the next
type fills.

## `OnceLock`: initialise a value once

`OnceLock<T>` is "run this once *and keep the result*."

```rust
use std::sync::OnceLock;

static CONFIG: OnceLock<String> = OnceLock::new();

fn config() -> &'static String {
    CONFIG.get_or_init(|| {
        println!("Loading config...");
        "production".to_string()
    })
}

fn main() {
    println!("{}", config());
    println!("{}", config());
}
```

Output:

```
Loading config...
production
production
```

The first call builds the `String`; every call after that just returns a reference to it.

```
Once
  └── call_once(|| initialize())

OnceLock<T>
  ├── get_or_init(|| create_T())
  └── stores the resulting T
```

`get_or_init` is the usual entry point, but the other methods matter in practice:

- `get()` returns `Option<&T>` — "is it ready yet?" without initialising.
- `set(value)` returns `Result<(), T>` — hands your value back if someone beat you to it.
- `get_or_init(f)` is the one you want 95% of the time.

This is what people used to pull in `lazy_static` or `once_cell` for. Since Rust 1.70 it's
in `std`, and unlike the old `lazy_static!` macro there's no hidden `Deref` type involved —
`CONFIG` is just a static of a normal type.

## `LazyLock`: the version you'll actually write

`OnceLock` still makes every call site say *how* to initialise. If there's only one sensible
answer, put it at the declaration instead:

```rust
use std::sync::LazyLock;
use std::collections::HashMap;

static TABLE: LazyLock<HashMap<&str, u32>> = LazyLock::new(|| {
    println!("building table");
    HashMap::from([("a", 1), ("b", 2)])
});

fn main() {
    println!("{}", TABLE["a"]); // builds it here
    println!("{}", TABLE["b"]); // already built
}
```

`LazyLock<T>` derefs to `T`, so `TABLE["a"]` reads like a plain global. Initialisation
happens on first deref, still exactly once, still thread-safe. Stable since 1.80, and it's
the closest thing Rust has to "a global with an initialiser".

Picking between the three is mostly mechanical:

| You want | Use |
|---|---|
| a side effect to happen once | `Once` |
| a value built once, initialiser varies or needs runtime input | `OnceLock<T>` |
| a value built once from a fixed expression | `LazyLock<T>` |

The middle row is the one people miss. If your config path comes from `main` and only then
gets stored, `LazyLock` can't see it — `OnceLock` plus a `set()` early in `main` is the
shape you want.

## When not to lock at all

A lock is the general answer, and general answers cost something. Two cheaper ones come up
constantly.

**Atomics**, when the shared state is a single integer or flag:

```rust
use std::sync::atomic::{AtomicUsize, Ordering};

static COUNTER: AtomicUsize = AtomicUsize::new(0);

COUNTER.fetch_add(1, Ordering::Relaxed);
```

No guard, no poisoning, no blocking. `Relaxed` is fine when the counter is only ever read
for its own sake; the moment the counter's value is meant to signal that *other* memory is
ready, you need `Acquire`/`Release` and should think carefully rather than guess.

**Channels**, when threads are handing work along rather than sharing it:

```rust
use std::sync::mpsc;
use std::thread;

let (tx, rx) = mpsc::channel();

thread::spawn(move || {
    tx.send("done").unwrap();
});

println!("{}", rx.recv().unwrap());
```

If you find yourself locking a `Vec` just so one thread can push and another can drain, a
channel is the thing you were building by hand.

## The ways this goes wrong

**Deadlock by lock ordering.** Thread A takes lock 1 then lock 2; thread B takes 2 then 1.
Both stop forever. Rust's type system does not save you here — the borrow checker knows
about data races, not deadlocks. The fix is the old one: pick a global order for your locks
and always take them in that order.

**Deadlock by re-entry.** `std::sync::Mutex` is not reentrant. Locking it twice on the same
thread deadlocks, and that's easy to do accidentally when one locked method calls another.

**Holding a guard across `.await`.** In async code, a `MutexGuard` held across an await
point is both a correctness hazard and usually a compile error (the future stops being
`Send`). Either end the guard's scope before the await:

```rust
let value = {
    let g = state.lock().unwrap();
    g.clone()
}; // guard dropped here
do_async_thing(value).await;
```

or use `tokio::sync::Mutex`, whose guard is await-safe. Don't reach for the async mutex by
default though — it's slower, and most async code only needs the lock for a few
non-awaiting lines.

**Temporaries that live longer than you think.** `if let Some(x) = map.lock().unwrap().get(k)`
keeps the guard alive for the whole `if let` body in older editions. Bind the guard to a
name when the lifetime matters.

## What I'd tell myself a week ago

- `Once` has no data. `OnceLock<T>` has data. `LazyLock<T>` has data *and* the recipe. That
  one sentence is most of `std::sync`'s lazy-init story.
- `Arc` is for sharing, `Mutex` is for mutating. `Arc<Mutex<T>>` isn't redundant.
- The guard is the lock. Where it drops is where you unlock, so pay attention to scopes.
- Poisoning is a feature, not noise — `unwrap()` on a lock is a deliberate "panic if
  someone else panicked", not laziness.
- Before adding a `Mutex`, check whether an atomic or a channel already says what you mean.
