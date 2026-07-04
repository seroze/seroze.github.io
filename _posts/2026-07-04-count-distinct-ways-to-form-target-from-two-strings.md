---
layout: post
title: "Count Distinct Ways to Form Target from Two Strings"
date: 2026-07-04 00:00:00 +0530
categories: competitive-programming
tags: [CP, DYNAMIC_PROGRAMMING]
author: "Seroze"
published: true
---

*[LeetCode 3981 — Count Distinct Ways to Form Target from Two Strings](https://leetcode.com/problems/count-distinct-ways-to-form-target-from-two-strings/description/) (Hard, Biweekly Contest 186). I got the state right and still overcounted — this post is about why.*

---

## The problem

Given three strings `word1`, `word2`, and `target`, count the number of ways to form `target` by picking characters from the two words such that:

- Each character of `target` comes from either `word1` or `word2` (and must match).
- The indices chosen from `word1` are strictly increasing; same for `word2`.
- **At least one** character is taken from **each** word.

Two ways differ if any position of `target` is sourced from a different string or a different index. Return the count modulo $$10^9 + 7$$.

**Example:** `word1 = "abc"`, `word2 = "bac"`, `target = "abc"` → **5** ways.

Constraints are small (all lengths ≤ 100), so a multi-dimensional memoized DP is fine.

---

## My first attempt — and its flaw

State: `(i, j, k)` = next unread positions in `word1`, `word2`, and `target`, plus two booleans tracking whether each word has contributed at least once. Transitions: take from `word1`, take from `word2`, **skip a char of `word1`**, or **skip a char of `word2`**.

```python
from functools import cache

class Solution:
    def interleaveCharacters(self, word1: str, word2: str, target: str) -> int:
        nw1, nw2, nt = len(word1), len(word2), len(target)
        MOD = 10**9 + 7

        @cache
        def solve(i, j, k, taken1, taken2):
            if k == nt:
                return 1 if (taken1 and taken2) else 0

            cnt = 0
            if i < nw1 and word1[i] == target[k]:
                cnt += solve(i+1, j, k+1, True, taken2)
            if j < nw2 and word2[j] == target[k]:
                cnt += solve(i, j+1, k+1, taken1, True)

            if i < nw1:
                cnt += solve(i+1, j, k, taken1, taken2)  # skip word1[i]
            if j < nw2:
                cnt += solve(i, j+1, k, taken1, taken2)  # skip word2[j]

            return cnt % MOD

        return solve(0, 0, 0, False, False)
```

This looks reasonable — every valid solution *is* reachable. But it wildly overcounts:

| Test | Expected | My code |
|---|---|---|
| `"abc"`, `"bac"`, `"abc"` | 5 | **51** |
| `"cd"`, `"cd"`, `"ccd"` | 4 | **10** |
| `"xy"`, `"xy"`, `"xyxy"` | 2 | 2 ✓ |
| `"ab"`, `"cde"`, `"ace"` | 1 | **4** |

Note the third case passes *by coincidence* — that input happens to consume both words fully, leaving no room for skips. One green test case proves nothing.

### The bug: skips in the two words are independent operations

Skipping `word1[i]` and skipping `word2[j]` commute — doing them in either order reaches the same state:

```
          (i, j, k)
         /         \
   skip w1        skip w2
       |              |
  (i+1, j, k)    (i, j+1, k)
        \            /
      skip w2    skip w1
          \        /
         (i+1, j+1, k)
```

Both paths end at `(i+1, j+1, k)` and eventually produce the **same set of chosen indices** — but the recursion counts them as two distinct ways. Memoization doesn't help: `@cache` avoids *recomputing* `(i+1, j+1, k)`, but its value still gets **added twice**, once through each parent.

The root cause: my DP was counting **sequences of skip operations**, while the problem asks for **choices of indices**. Multiple operation orderings collapse to the same combinatorial object.

---

## The fix — make every solution correspond to exactly one path

Kill the skip transitions. Instead, each transition consumes one target character and **jumps directly to the chosen index**: "the next `target[k]` comes from `word1[ii]`" for each candidate `ii ≥ i` (and symmetrically for `word2`). A final selection of indices now decomposes into exactly one sequence of transitions — no ordering ambiguity, no overcount.

```python
from functools import cache

class Solution:
    def interleaveCharacters(self, word1: str, word2: str, target: str) -> int:
        nw1, nw2, nt = len(word1), len(word2), len(target)
        MOD = 10**9 + 7

        @cache
        def solve(i, j, k, taken1, taken2):
            if k == nt:
                return 1 if (taken1 and taken2) else 0

            cnt = 0
            for ii in range(i, nw1):
                if word1[ii] == target[k]:
                    cnt += solve(ii+1, j, k+1, True, taken2)

            for jj in range(j, nw2):
                if word2[jj] == target[k]:
                    cnt += solve(i, jj+1, k+1, taken1, True)

            return cnt % MOD

        return solve(0, 0, 0, False, False)
```

The skipping still happens — it's implicit in jumping from `i` to `ii` — but there's only **one** way to skip a contiguous block, so nothing is double-counted.

Complexity: $$O(n_1 \cdot n_2 \cdot n_t)$$ states (×4 for the flags), each transition loop is $$O(n_1 + n_2)$$ — comfortably fast for $$n \le 100$$.

---

## The lesson: decision DP vs counting DP

I mixed up two kinds of DP, and the gap is a common one when moving from feasibility to counting:

> **Decision DP** asks: *can I reach every valid solution?*
>
> **Counting DP** asks: *can I reach each valid solution **exactly once**?*

A state design that's perfectly fine for "is it possible?" can be broken for "how many ways?" — reachability is not enough; **transitions must be unique**. Whenever two transition sequences (like `skip w1, skip w2` vs `skip w2, skip w1`) produce the same final object, the recurrence overcounts, and memoization won't save you.

So before trusting a counting DP, run the checklist:

1. Does every valid solution map to **at least one** path through the state graph? (completeness)
2. Does every valid solution map to **at most one** path? (uniqueness — the one people forget)

That second question catches a surprising number of overcounting bugs.
