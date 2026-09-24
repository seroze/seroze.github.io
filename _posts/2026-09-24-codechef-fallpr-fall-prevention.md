---
layout: post
title: "[CodeChef] FALLPR — Fall Prevention: I deleted the wrong element"
date: 2026-09-24 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, greedy, prefix_sums, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Fall Prevention](https://www.codechef.com/problems/FALLPR) (difficulty 1297).

Delete at most one element so that every prefix sum is $$\ge 0$$. Is it possible?

## The mistake

I rushed it: find the first index where the prefix sum goes negative, delete *that* element,
recheck. WA.

Counterexample: `[2, -2, -1, -1]`. Prefix sums are $$2, 0, -1$$, so I delete the `-1` at index 2
and get `[2, -2, -1]`, which still fails. Deleting the `-2` gives `[2, -1, -1]` with prefix sums
$$2, 1, 0$$, so the answer is YES.

## The fix

Let $$i$$ be the first failing index. The deletion must be at some $$j \le i$$, since anything later
leaves prefix $$i$$ negative. Deleting $$A_j$$ raises every prefix from $$j$$ onward by $$-A_j$$,
so the best choice is the **minimum** of `a[0..i]`. Delete it and check once more.

```python
j = min(range(fail + 1), key=lambda k: a[k])
curr, ok = 0, True
for k, x in enumerate(a):
    if k == j:
        continue
    curr += x
    if curr < 0:
        ok = False
        break
```

## A cute Python argmin

```python
j = min(range(fail + 1), key=lambda k: a[k])
```

`min` iterates over the indices, and `key` compares each one by `a[k]`, so it returns the
**index** of the minimum in a single pass. Ties go to the first index. That beats
`a.index(min(a[:fail + 1]))`, which slices and then scans twice. Swap in `max` for argmax.

**Lesson:** where the prefix sum breaks isn't the same as what to delete. A 10-line brute force
would have caught this before I submitted.
