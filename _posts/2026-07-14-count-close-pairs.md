---
layout: post
title: "[AtCoder] ABC466 C — Count Close Pairs"
date: 2026-07-14 00:00:00 +0530
categories: competitive-programming
tags: [cp, two-pointers, interactive, atcoder]
author: "Seroze"
published: true
---

## Problem

N points on a number line, sorted left to right, coordinates hidden. You can ask up to 2N queries of the form "is distance(i, j) ≤ 1?" for i < j. Count all pairs (i, j) with distance ≤ 1.

## Approach: Two Pointers

Since points are sorted, for a fixed `i`, distance to `j` only increases as `j` increases. So the furthest point still within range of `i` — call it `f(i)` — is non-decreasing in `i`. That monotonicity means a right pointer `r` can sweep forward once across the whole outer loop and never needs to backtrack.

For each `i`, advance `r` with queries `? i r` as long as the answer is "Yes." Once "No" (or `r` hits `N`), stop — every pair `(i, k)` for `i < k < r` is a valid close pair, whether or not it was individually queried (monotonicity guarantees it).

**Query count:** `r` only ever moves forward, so total advances ≤ N−1. Each `i` triggers at most one "No." Total queries ≤ (N−1) + N = 2N−1, within the 2N budget.

## Code

```python
import sys

def main():
    data = sys.stdin
    out = sys.stdout
    N = int(data.readline())

    r = 1
    count = 0
    for i in range(1, N + 1):
        if r <= i:
            r = i + 1
        while r <= N:
            print(f"? {i} {r}")
            out.flush()
            resp = data.readline().strip()
            if resp == "Yes":
                r += 1
            else:
                break
        count += (r - 1) - i

    print(f"! {count}")
    out.flush()

main()
```
