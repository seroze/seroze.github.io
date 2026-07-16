---
layout: post
title: "[CodeChef] Starters 247 — Red Blue Swaps: From Swaps to Buckets (A DP Pattern)"
date: 2026-07-16 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, dynamic_programming, codechef]
author: "Seroze"
published: true
---

*[CodeChef Starters 247 — Red Blue Swaps](https://www.codechef.com/problems/REDBLUESW). A swap-based reachability problem that looks like simulation but is actually a clean counting DP. The key move: stop thinking about swaps and start thinking about where each blue element can land.*

---

## The problem

You're given:

- A permutation $$A$$ of $$1 \ldots N$$.
- A binary color array $$B$$, where $$0$$ = Red and $$1$$ = Blue.

You may repeatedly swap two **adjacent** elements if:

1. Their colors are different.
2. The red element has a larger value than the blue element.

Both the values and their colors are swapped together.

Count the number of distinct permutations $$A$$ that are reachable.

---

## Observation 1: relative order is preserved

Every swap is between a **red** and a **blue** element.

Therefore:

- The relative order of all red elements never changes.
- The relative order of all blue elements never changes.

Ignoring the value constraint for a moment, the problem becomes:

> How many ways can we interleave two fixed sequences (reds and blues)?

This immediately shifts the focus from **simulating swaps** to **constructing valid interleavings**.

## Observation 2: reachable buckets

Fix the red sequence.

```text
Bucket 0   R1   Bucket 1   R2   Bucket 2   ...   Bucket R
```

A bucket represents **how many red elements appear before a blue**.

For every blue element:

- Compute the leftmost bucket it can reach, $$l_i$$.
- Compute the rightmost bucket it can reach, $$r_i$$.

A blue can move left/right only while every crossed red has a larger value.

The reachable buckets always form one continuous interval $$[l_i, r_i]$$.

## Observation 3: bucket assignments determine the permutation

Since the order of blue elements never changes, assigning each blue to a bucket uniquely determines the final permutation.

Multiple blues may occupy the same bucket.

Example:

```text
R1 B1 B2 R2
```

Both `B1` and `B2` belong to bucket $$1$$.

---

## The DP

Let $$dp[i][j]$$ denote the number of ways to place the first $$i$$ blue elements such that the $$i$$-th blue is placed in bucket $$j$$.

If the current blue is placed in bucket $$j$$, then the previous blue cannot be in a later bucket (otherwise their order would change). Therefore

$$dp[i][j] = \sum_{k \le j} dp[i-1][k],$$

and this transition is valid only if $$l_i \le j \le r_i$$; otherwise $$dp[i][j] = 0$$.

Using prefix sums, each transition becomes $$O(1)$$.

### Complexity

- Computing reachable intervals: $$O(N^2)$$
- DP with prefix sums: $$O(N^2)$$

---

## Implementation

```python
MOD = 998244353

def solve():
    n = int(input())
    a = list(map(int, input().split()))
    b = list(map(int, input().split()))

    red = [0]
    for i in range(n):
        if b[i] == 0:
            red.append(a[i])
    red.append(0)

    lt, rt = [], []
    cur = 0

    for i in range(n):
        if b[i] == 1:
            l = r = cur

            while a[i] < red[l]:
                l -= 1
            while a[i] < red[r + 1]:
                r += 1

            lt.append(l)
            rt.append(r)
        else:
            cur += 1

    m = len(red)
    dp = [0] * m
    ndp = [0] * m
    dp[0] = 1

    for i in range(len(lt)):
        pref = 0
        for j in range(m):
            pref = (pref + dp[j]) % MOD

            if lt[i] <= j <= rt[i]:
                ndp[j] = pref
            else:
                ndp[j] = 0

        dp, ndp = ndp, dp

    print(sum(dp) % MOD)

T = int(input())
for _ in range(T):
    solve()
```

---

## My thought process

This was the path I took before reading the editorial:

- ✅ Identified that **red-red** and **blue-blue** relative order is invariant.
- ✅ Realized the problem reduces to **interleaving two fixed sequences**.
- ❌ Spent time searching for a greedy "nearest red" restriction for each blue. That wasn't the right abstraction.
- ✅ The editorial's **bucket representation** immediately simplified the state space.
- ✅ The DP is **not about simulating swaps** — it's about counting valid bucket assignments.

### Biggest takeaway

A useful pattern to remember:

> Whenever an operation preserves the order inside multiple groups, stop thinking about swaps. Think in terms of **interleavings**, **bucket placements**, or **merging fixed sequences**. That often leads to a much cleaner DP.
