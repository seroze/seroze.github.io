---
layout: post
title: "[Codeforces] Round 1103 (Div. 3) E — Friendly Gifts: Disjoint Value Intervals"
date: 2026-07-18 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codeforces, brute_force, hashing]
author: "Seroze"
published: true
---

*[Codeforces Round 1103 (Div. 3) — Problem E: Friendly Gifts](https://codeforces.com/contest/2236/problem/E). My initial sweep-line approach captured the two key observations but ran into Memory Limit Exceeded. The editorial's insight — disjoint value intervals automatically imply disjoint subarrays — makes the whole position-tracking machinery unnecessary.*

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

## Final Solution

The key observation from the editorial is that we never need to track the **positions** of the good segments.

Suppose two good segments have value intervals

```text
[x, x + L - 1]
[x + L, x + 2L - 1]
```

These value ranges are disjoint. Therefore, the corresponding subarrays **cannot overlap in the original array**, since a single array position cannot contain two different values. This completely eliminates the need for a sweep-line or interval matching approach.

Instead, we only need to record whether a particular value interval exists.

### Algorithm

1. Enumerate every subarray.
2. Maintain:
   - current minimum,
   - current maximum,
   - duplicate detection using a timestamp array.
3. Whenever

   ```text
   max - min == length - 1
   ```

   mark

   ```text
   good[min][max] = True
   ```

4. Try answers from `⌊n/2⌋` down to `1`.
5. For every possible starting value `x`, check whether both intervals

   ```text
   [x, x+L-1]
   [x+L, x+2L-1]
   ```

   exist. The first valid answer is the maximum one.

### Complexity

- **Time:** `O(n²)`
- **Memory:** `O(n²)`

### Implementation

```python
import sys

input = sys.stdin.readline


def solve():
    n = int(input())
    a = list(map(int, input().split()))

    good = [[False] * (n + 2) for _ in range(n + 2)]

    vis = [0] * (n + 1)
    timer = 0

    # Enumerate all good subarrays
    for l in range(n):
        timer += 1
        mn = n + 1
        mx = 0

        for r in range(l, n):
            x = a[r]

            if vis[x] == timer:
                break

            vis[x] = timer

            mn = min(mn, x)
            mx = max(mx, x)

            if mx - mn == r - l:
                good[mn][mx] = True

    # Try answers from largest to smallest
    for length in range(n // 2, 0, -1):
        for start in range(1, n - 2 * length + 2):
            if (
                good[start][start + length - 1]
                and good[start + length][start + 2 * length - 1]
            ):
                print(length)
                return

    print(0)


t = int(input())
for _ in range(t):
    solve()
```

### Key Takeaway

My initial solution focused on matching good subarrays by their indices using a sweep-line algorithm. While that approach was logically appealing, it introduced unnecessary state and eventually ran into memory issues.

The decisive observation is that **disjoint value intervals automatically imply disjoint subarrays**. Once that is recognized, the problem becomes much simpler: enumerate every good value interval once, record its existence, and directly check whether the two required consecutive intervals exist for each candidate answer.
