---
layout: post
title: "[Codeforces] Round 267 (Div. 2) C — George and Job: DP on Fixed-Length Segments"
date: 2026-07-17 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, dynamic_programming, codeforces]
author: "Seroze"
published: true
---

*[Codeforces Round 267 (Div. 2) — Problem C: George and Job](https://codeforces.com/problemset/problem/467/C).*

**Problem:** Choose exactly `K` non-overlapping subarrays, each of length `m`, such that their total sum is maximized.

## Observation

Since every chosen segment has the **same fixed length**, once we decide that a segment ends at position `i`, its starting position is also fixed:

```text
[i-m+1, i]
```

This makes the DP much simpler because we don't have to consider every possible left endpoint.

To answer segment sums in `O(1)`, we first build prefix sums.

## DP State

Let

```text
dp[i][j]
```

be the maximum sum obtainable by selecting exactly `j` valid segments using only the first `i` elements.

## Transition

There are only two choices.

### 1. Ignore the current element

We simply inherit the previous answer.

```text
dp[i][j] = dp[i-1][j]
```

### 2. End a segment at `i`

The segment is fixed as

```text
[i-m+1, i]
```

whose sum is

```text
pref[i] - pref[i-m]
```

Since segments cannot overlap, the previous `j-1` segments must lie completely within the first `i-m` elements.

Therefore,

```text
dp[i][j] = dp[i-m][j-1] + segment_sum
```

Taking the better of the two gives

```text
dp[i][j] = max(
    dp[i-1][j],
    dp[i-m][j-1] + pref[i] - pref[i-m]
)
```

## Complexity

- Prefix sums: **O(n)**
- DP: **O(nK)**
- Memory: **O(nK)**

This easily fits the constraints (`n ≤ 5000`).

## Accepted Code

```python
n,m,K = map(int, input().split())
p = list(map(int, input().split()))

# prefix sums
pref = [0]*(n+1)
for i in range(n):
    pref[i+1] = pref[i] + p[i]

NEG = -10**18

# dp[i][j] = maximum sum using exactly j segments
# within the first i elements
dp = [[NEG for _ in range(K+1)] for _ in range(n+1)]

# base case
for i in range(n+1):
    dp[i][0] = 0

# transition
for j in range(1, K+1):
    for i in range(1, n+1):
        # don't end a segment at i
        dp[i][j] = dp[i-1][j]

        # end a segment at i
        if i >= m:
            seg_sum = pref[i] - pref[i-m]
            dp[i][j] = max(
                dp[i][j],
                dp[i-m][j-1] + seg_sum
            )

print(dp[n][K])
```

## Key Learning

Whenever every selected interval has a **fixed length**, don't think about arbitrary subarrays. Instead, iterate over the **ending position** of each interval. The start becomes uniquely determined, often reducing what looks like an `O(n²K)` DP into a clean `O(nK)` solution.

## TODO

Think about how to optimize the memory here — the DP currently uses `O(nK)` space.
