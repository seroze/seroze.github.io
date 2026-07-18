---
layout: post
title: "[Codeforces] Round 1103 (Div. 3) E — Friendly Gifts: Good Segments and Unique Partners (WIP)"
date: 2026-07-18 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codeforces, brute_force, hashing]
author: "Seroze"
published: true
---

*[Codeforces Round 1103 (Div. 3) — Problem E: Friendly Gifts](https://codeforces.com/contest/2236/problem/E). My current approach captures the two key observations but still fails with Memory Limit Exceeded — writing it up anyway, with a TODO for the missing optimization.*

## Problem Summary

We are given an array `a` and need to choose two **non-overlapping subarrays of equal length** such that:

- Each subarray can be rearranged into consecutive integers.
- After concatenating both subarrays, the resulting array can also be rearranged into consecutive integers.

The goal is to maximize the common length.

---

## Observation 1: When is a subarray "good"?

A subarray is good if it can be rearranged into consecutive integers.

This happens **iff**:

- all elements are distinct, and
- `max - min + 1 == length`.

This allows us to identify good segments while expanding a window by maintaining:

- current minimum,
- current maximum,
- duplicate detection.

---

## Observation 2: The matching segment is uniquely determined

Suppose the left segment has value interval

```
[mn, mx]
```

Its length is

```
L = mx - mn + 1
```

Since both chosen segments must have **equal length**, the second segment must also have length `L`.

For the concatenation to be good, the value intervals must be adjacent.

Therefore the only possible partner is

```
[mx + 1, mx + L]
```

(or symmetrically `[mn - L, mn - 1]`).

This was the key insight that simplified the search considerably.

---

## Initial Approach

### Step 1

Enumerate every good segment in `O(n²)`.

For each segment store

```
(l, r, mn, mx)
```

---

### Step 2

Sweep from right to left.

Maintain all good segments completely inside the suffix.

For every good segment ending at the current split,

```
[mn, mx]
```

compute its unique partner interval

```
(mx + 1, mx + length)
```

and check whether such an interval already exists in the suffix.

---

## Improving the Memory

The first implementation stored every good segment twice:

- grouped by left endpoint,
- grouped by right endpoint.

This immediately exploded memory because an increasing array has

```
O(n²)
```

good segments.

Instead, I changed the sweep to generate segments **on the fly**.

For every split:

1. Enumerate all good segments starting at `split + 1` and insert their `(mn, mx)` interval into a hash map.
2. Enumerate all good segments ending at `split` and immediately query their matching interval.

This removes the need to store all good segments beforehand.

Pseudo-code:

```text
for split from right to left:
    enumerate good segments starting at split+1
    insert (mn, mx) into hash map

    enumerate good segments ending at split
    compute required partner interval
    check whether it exists
```

---

## Complexity

Each enumeration is linear.

Over all splits:

- Time: `O(n²)`

The implementation only keeps the active intervals inside a hash map instead of storing every segment.

---

## What Went Wrong?

Unfortunately, this approach still **does not pass**.

Both the Python and C++ implementations run into **Memory Limit Exceeded** on the larger tests.

The reason is that although good segments are generated on demand, the hash map still accumulates a huge number of distinct value intervals in the worst case (for example, on an increasing array).

So while the overall idea is elegant, the state representation is still too large for the constraints.

---

## Takeaways

- Characterizing a "good" segment using
  - distinct elements, and
  - `max - min + 1 == length`

  is the fundamental observation.

- The equal-length constraint uniquely determines the matching value interval.

- Generating good segments on demand is a significant improvement over storing every segment.

- Memory usage can still become the bottleneck even when the asymptotic time complexity looks acceptable.

---

## TODO

This solution **does not pass** due to memory usage and requires further optimization.

Possible directions to investigate:

- Compress the representation of active value intervals.
- Avoid storing every distinct `(mn, mx)` pair in the hash map.
- Look for a stronger observation that reduces the state space to `O(n)` or `O(n²)` bits instead of `O(n²)` hash entries.
