---
layout: post
title: "[CodeChef] Starters 108 — Clan Expansion: the largest gap between sources"
date: 2026-08-12 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, greedy, arrays]
author: "Seroze"
published: true
redirect_from:
  - /spreading-and-coverage/
---

Problem: [CodeChef — Clan Expansion](https://www.codechef.com/problems/CLANEXPNSN)

> Territories on a line, each held by some clan. A clan expands from every territory it
> already holds, one step per second, simultaneously. For each clan, how long until it
> covers the whole line?

My first instinct was to simulate the expansion for every clan. For a fixed clan I could compute the distance of every territory to its nearest occurrence and take the maximum. That's correct, but it's $$O(N)$$ work per clan and $$O(N^2)$$ overall.

The trick is to completely change the viewpoint.

## The reframe

Imagine every occurrence of a clan as a **source** from which expansion starts simultaneously.

```
        source            source
----------●-----------------●----------
```

Instead of asking,

> *"How long does it take to reach every territory?"*

ask,

> *"Which territory is reached last?"*

The answer is always determined by the **largest uncovered gap**. And a gap is bounded by sources — so you only ever need to look at consecutive source positions, never at the territories in between.

## The three kinds of gap

There are only three:

- the **prefix** before the first occurrence,
- the **suffix** after the last occurrence,
- the **interior gaps** between consecutive occurrences.

The boundary gaps are reached from only one side. An interior gap is attacked from both ends at once, so it closes in half the time. With sources at 0-indexed positions $$p_1 < p_2 < \dots < p_k$$ in an array of length $$n$$:

| gap | reached from | contributes |
|---|---|---|
| prefix | the right only | $$p_1$$ |
| suffix | the left only | $$n - 1 - p_k$$ |
| interior | both ends | $$\left\lfloor (p_{j+1} - p_j) / 2 \right\rfloor$$ |

The answer for the clan is the maximum of these.

One detail worth pinning down, because "gap length" is ambiguous: $$d = p_{j+1} - p_j$$ is the **difference between the two source positions**, not the count of territories strictly between them (that would be $$d - 1$$). With that definition the interior contribution is exactly $$\lfloor d/2 \rfloor$$ — for sources at 0 and 4, position 2 is reached at time $$4/2 = 2$$; for sources at 0 and 5, both positions 2 and 3 are reached at time $$\lfloor 5/2 \rfloor = 2$$.

## The code

```python
from collections import defaultdict

def solve(n, a):
    pos = defaultdict(list)
    for i, clan in enumerate(a):
        pos[clan].append(i)          # positions come out sorted

    ans = {}
    for clan, p in pos.items():
        best = max(p[0], n - 1 - p[-1])          # prefix and suffix
        for x, y in zip(p, p[1:]):               # interior gaps
            best = max(best, (y - x) // 2)
        ans[clan] = best
    return ans
```

**Why this is linear overall.** Each clan's loop is proportional to its own number of occurrences, and every territory belongs to exactly one clan — so the occurrence counts sum to $$n$$. Handling *every* clan costs $$O(n)$$ in total, not $$O(n)$$ each. That's the whole win: the quadratic version re-scanned all $$n$$ territories per clan, and this one touches each position once.

I checked the gap formula against the brute-force "max distance to nearest source" definition on 30,000 random arrays — they agree everywhere.

## The bigger lesson

Whenever influence spreads uniformly from multiple starting points on a line, don't think about simulating the spread. Identify the **sources** and look for the **largest gap between them**.

The farthest point is almost always one of two things:

- a boundary, or
- the midpoint of the largest consecutive gap.

That turns a simulation problem into gap analysis — a single linear scan over the source positions.

## Mental checklist

When I see expansion on a line, I'll ask:

- Can I represent all starting positions as **sources**?
- Is the last affected position simply inside the **largest gap**?
- Can I compute the answer using only consecutive source positions instead of every index?

This pattern shows up all over the place: propagation, coverage, nearest-distance queries, Wi-Fi routers, heaters, influence spreading. Once you recognise it, many seemingly difficult simulations collapse into one pass over the sources.

## Quick reference

| Quantity | Value |
|---|---|
| Prefix gap | $$p_1$$ |
| Suffix gap | $$n - 1 - p_k$$ |
| Interior gap between $$p_j, p_{j+1}$$ | $$\lfloor (p_{j+1} - p_j)/2 \rfloor$$ |
| Answer for one source set | max of the above |
| Total cost over all groups | $$O(n)$$ — occurrence counts sum to $$n$$ |
