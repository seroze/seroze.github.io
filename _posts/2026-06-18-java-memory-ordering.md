---
layout: post
title: "Memory Ordering in Java"
date: 2026-06-18 00:00:00 +0530
categories: java
tags: [java, concurrency, memory-model]
author: "Seroze"
published: true
---

*How the JVM, the compiler, and the CPU conspire to reorder your code — and how to stop them.*

---

## Why memory ordering matters

Modern CPUs and compilers don't execute your code in the order you wrote it. They reorder instructions for performance — and that's fine in a single-threaded program, because the end result is the same. In a multi-threaded program, another thread can observe the intermediate reordered state, which leads to bugs that are nearly impossible to reproduce.

```java
// Thread 1
data = 42;
ready = true;   // compiler or CPU may reorder this BEFORE the line above

// Thread 2
if (ready) {
    System.out.println(data); // may print 0, not 42
}
```

The Java Memory Model (JMM) defines exactly when one thread is guaranteed to see the writes made by another.

---

## The Java Memory Model — happens-before

The JMM uses one core concept: **happens-before**. If action A happens-before action B, then every write A made is visible to B.

Key happens-before rules:

- Every action in a thread happens-before every action that comes later in that same thread (program order).
- A `synchronized` unlock happens-before every subsequent lock on the same monitor.
- A write to a `volatile` field happens-before every subsequent read of that field.
- `Thread.start()` happens-before any action in the started thread.
- All actions in a thread happen-before `Thread.join()` returns.

If there is no happens-before chain between a write and a read, the read is allowed to see a stale value.

---

## `volatile` — visibility without locking

Marking a field `volatile` gives two guarantees:

1. **Visibility** — a write to a volatile field is immediately flushed to main memory; a read always fetches from main memory, never a CPU cache.
2. **No reordering** — writes and reads of volatile fields cannot be reordered with surrounding code.

```java
class StopFlag {
    private volatile boolean stop = false;

    public void shutdown() {
        stop = true;          // visible to all threads immediately
    }

    public void run() {
        while (!stop) {       // always reads fresh value
            doWork();
        }
    }
}
```

Without `volatile`, the JIT compiler might hoist `stop` into a register and loop forever even after `shutdown()` is called.

**What `volatile` does NOT give you:** atomicity for compound operations. Read-modify-write sequences like `counter++` are still a race condition — `volatile` only makes individual reads and writes atomic.

```java
private volatile int counter = 0;
counter++;   // still a race — this is read + increment + write, not one atomic op
```

For that, use `AtomicInteger`.

---

## `synchronized` — mutual exclusion + full memory barrier

`synchronized` gives a stronger guarantee than `volatile`. On entry to a synchronized block, the thread refreshes all shared variables from main memory. On exit, all writes are flushed. No reads or writes inside the block can be reordered across the boundaries.

```java
class Counter {
    private int count = 0;

    public synchronized void increment() {
        count++;   // safe: only one thread at a time, full visibility on entry and exit
    }

    public synchronized int get() {
        return count;
    }
}
```

Both the writer and reader must synchronize on the **same monitor** for the guarantee to hold. Synchronizing only the write but not the read is a common bug.

---

## `final` fields — safe publication

A field declared `final` is guaranteed to be fully initialized before any thread can observe the object, as long as the reference to the object doesn't escape the constructor.

```java
class ImmutablePoint {
    final int x;
    final int y;

    ImmutablePoint(int x, int y) {
        this.x = x;
        this.y = y;
        // no 'this' escape — safe to share across threads
    }
}
```

Without `final`, another thread could theoretically see the default value (0) for `x` or `y` even after the constructor has run, due to reordering.

---

## `AtomicInteger` and the `java.util.concurrent.atomic` package

For lock-free thread-safe counters and flags, use the atomic classes. They use CPU-level compare-and-swap (CAS) instructions under the hood.

```java
AtomicInteger counter = new AtomicInteger(0);

counter.incrementAndGet();          // atomic ++
counter.getAndAdd(5);               // atomic += 5, returns old value
counter.compareAndSet(10, 20);      // if value == 10, set to 20; returns true/false
```

Other useful atomics: `AtomicBoolean`, `AtomicLong`, `AtomicReference<T>`.

`AtomicReference` is useful for atomically swapping an object reference:

```java
AtomicReference<String> ref = new AtomicReference<>("old");
ref.compareAndSet("old", "new");   // atomic swap, only if current value is "old"
```

---

## Double-checked locking — the classic broken pattern

A common attempt to lazily initialize a singleton:

```java
// BROKEN without volatile
class Singleton {
    private static Singleton instance;

    public static Singleton getInstance() {
        if (instance == null) {                    // first check
            synchronized (Singleton.class) {
                if (instance == null) {            // second check
                    instance = new Singleton();    // can be partially visible to other threads
                }
            }
        }
        return instance;
    }
}
```

The problem: `instance = new Singleton()` is not atomic. It compiles to roughly:
1. allocate memory
2. write reference to `instance`
3. call constructor

A CPU may reorder steps 2 and 3. Another thread doing the first check sees a non-null `instance` that hasn't been constructed yet.

**Fix:** declare `instance` as `volatile`. The volatile write in step 2 cannot be reordered before the constructor completes.

```java
private static volatile Singleton instance;  // fix
```

---

## Quick reference

| Tool | Guarantees | Does not guarantee |
|---|---|---|
| `volatile` | Visibility, no reordering | Atomicity of compound ops |
| `synchronized` | Mutual exclusion, full memory barrier | Non-blocking progress |
| `final` | Safe publication of initialized fields | Mutability of the object |
| `AtomicInteger` etc. | Atomic read-modify-write | Locking multiple variables together |

**Rules of thumb:**
- Use `volatile` for a single flag or reference that one thread writes and others read.
- Use `synchronized` (or `ReentrantLock`) when you need atomicity over multiple fields or compound operations.
- Use `AtomicInteger`/`AtomicReference` for lock-free single-variable counters and swaps.
- Always declare singleton `instance` fields as `volatile` if using double-checked locking.
