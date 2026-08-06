---
layout: post
title: "[Leetcode] Biweekly 188 — Fence Width Optimization: From O(n³) to O(n²)"
date: 2026-08-01 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, leetcode, counting, hash_maps, complexity_analysis]
author: "Seroze"
published: true
---

*A TLE that wasn't fixed by micro-optimizing the inner loop — it was fixed by running the loops in the other order.*

---

## Problem

You have a collection of planks with given heights. Two planks can be joined end to end into a single plank whose height is the sum of the two, and each plank can be used at most once. Pick a target height `H` and count how many planks of exactly height `H` you can end up with — either planks that already have that height, or pairs joined to reach it. Maximize that count over all choices of `H`.

## The O(n³) approach

My first version was the direct reading of the statement:

- Generate every possible target height.
- For each target, scan all distinct plank heights and count how many disjoint pairs can form that height.
- Add the planks that already have the target height.

The idea is correct, but it's **O(n³)** in the worst case:

- O(n²) possible target heights.
- O(n) work to recompute the pair count for each target.

It passed most of the test cases and then hit TLE.

## The key observation

For a fixed target height `H`, the number of pairs is

- `freq[x] / 2` if `2 * x == H`
- `min(freq[x], freq[y])` for every `x < y` such that `x + y == H`

The realization that fixes everything: **every unordered pair of values contributes to exactly one target sum.**

Instead of

> for every target, iterate over every value

reverse the loops:

> for every unordered pair of values, add its contribution to the corresponding target

```text
pairCount[x + y] += min(freq[x], freq[y])
pairCount[2 * x] += freq[x] / 2
```

Once all contributions are accumulated, the answer for a target is just

```text
pairCount[target] + freq[target]
```

where `freq[target]` accounts for planks that already have the required height.

### Why the accumulation is safe

Worth spelling out, since "just add contributions into a bucket" often does overcount. For a **fixed** target `H`, a value `x` has exactly one partner: `H - x`. It cannot appear in two different pairs that both sum to `H`. So the contributions landing in `pairCount[H]` come from disjoint groups of planks, and summing them is legitimate.

Planks of height `H` itself never collide with that either — `x + y = H` with positive heights forces both `x` and `y` to be strictly less than `H`, so `freq[H]` counts planks that no pair term could have touched.

## Code

```python
from collections import Counter, defaultdict
from typing import List

class Solution:
    def maxPlanks(self, heights: List[int]) -> int:
        freq = Counter(heights)
        vals = sorted(freq)

        pair_count = defaultdict(int)
        for i, x in enumerate(vals):
            pair_count[2 * x] += freq[x] // 2          # x with itself
            for y in vals[i + 1:]:
                pair_count[x + y] += min(freq[x], freq[y])

        candidates = set(pair_count) | set(freq)
        return max(pair_count[h] + freq.get(h, 0) for h in candidates)
```

The `vals[i + 1:]` slice is what enforces *unordered* pairs — each `{x, y}` is visited once, so each contribution is added once.

## Complexity

- Building frequencies: **O(n)**
- Enumerating unordered pairs of distinct values: **O(m²)**, where `m` is the number of distinct heights (`m ≤ n`)
- Computing the final answer: **O(m²)**, since `pairCount` holds at most that many keys

Overall: **O(n²)**, fast enough for the given constraints.

## Takeaway

The trick was not to optimize the pair-counting process, but to notice that it never needs to be recomputed. Every pair naturally belongs to exactly one target height, so its contribution can be banked immediately instead of being rediscovered once per target.

The general shape: when an inner loop recomputes the same quantity for many outer values, check whether each inner item actually affects only *one* outer value. If it does, invert the nesting and the recomputation disappears entirely.
