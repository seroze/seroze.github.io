---
layout: post
title: "[Leetcode] Weekly 509 — Subsequence After One Replacement: Did You Consume the Matched Character?"
date: 2026-07-05 00:00:00 +0530
categories: competitive-programming
tags: [cp, two_pointers, leetcode]
author: "Seroze"
published: true
---

*[LeetCode — Subsequence After One Replacement](https://leetcode.com/problems/subsequence-after-one-replacement/). Can `s` become a subsequence of `t` if you're allowed to replace at most one character of `s`? The algorithm is a standard prefix/suffix greedy match, but I hit two classic implementation bugs — this post is mostly about those.*

---

## The approach

If zero replacements are needed, `s` is already a subsequence of `t` — one greedy two-pointer scan answers that.

For exactly one replacement, think about *which* position `i` of `s` gets replaced. Then:

- `s[0..i-1]` must match greedily as a subsequence into some **prefix** of `t`,
- `s[i+1..]` must match greedily into some **suffix** of `t`,
- and there must be **at least one unused position of `t` strictly between them** where the replaced `s[i]` can land (it can be changed to whatever character sits there).

So precompute two arrays:

- `pref[i]` — the position in `t` where `s[i]` gets matched when matching `s[0..i]` greedily **as early as possible** (left to right).
- `suff[i]` — the position in `t` where `s[i]` gets matched when matching `s[i..]` greedily **as late as possible** (right to left).

Greedy-earliest for the prefix and greedy-latest for the suffix is the standard trick: it leaves the maximum possible gap in the middle, so if *any* split works, this one does.

Then for each candidate replacement index `i`:

```python
left  = -1 if i == 0    else pref[i-1]   # last t-index used by the left part
right = nt if i == ns-1 else suff[i+1]   # first t-index used by the right part

if left + 1 < right:   # at least one free slot in between
    return True
```

The sentinels `-1` and `nt` handle replacing the first or last character — an empty side consumes nothing. Everything is a linear scan: **O(ns + nt)**.

## Bug #1: forgetting to consume the matched character

My first prefix scan looked like this:

```python
# BUGGY
for i in range(ns):
    while j < nt and s[i] != t[j]:
        j += 1
    pref[i] = j        # matched s[i] at t[j]... and then left j there
```

The `while` loop stops **on** the match, so `t[j]` is now used up by `s[i]`. If you don't advance `j` past it, the next iteration can match `s[i+1]` against the *same* `t[j]` — two characters of `s` silently mapped to one character of `t`. Correct version:

```python
while j < nt and s[i] != t[j]:
    j += 1

pref[i] = j
j += 1          # consume the matched character
```

And symmetrically for the suffix scan:

```python
while j >= 0 and s[i] != t[j]:
    j -= 1

suff[i] = j
j -= 1          # consume the matched character
```

This is easy to miss precisely because the code *looks* done after `pref[i] = j` — the match succeeded, the value is recorded, what's left? The consumption step lives after the "interesting" line, so it's the one that gets forgotten.

## Bug #2: overcomplicating the gap check

For the "replace `s[i]`" case, I initially wrote something like:

```python
# BUGGY (and convoluted)
if left < right and left + 1 <= right:
    return True
```

Those two conditions collapse to just `left < right` — which is wrong, because it accepts `right == left + 1`, i.e. the left part and right part are packed back-to-back with **no free slot** for the replaced character.

The clean way to think about it: the replaced `s[i]` needs one position in `t` from the open interval `(left, right)`, i.e. some index in `left+1 .. right-1`. That range is non-empty iff:

```python
if left + 1 < right:
    return True
```

One comparison. When a boundary check feels like it needs multiple clauses, it's usually a sign I haven't found the right framing yet — "is the open interval non-empty" was the framing here.

## Full solution

```python
class Solution:
    def canMakeSubsequence(self, s: str, t: str) -> bool:

        ns = len(s)
        nt = len(t)
        pref = [nt] * ns
        suff = [-1] * ns

        j = 0
        for i in range(ns):
            # try to match t[j] from s[i]
            while j < nt and s[i] != t[j]:
                j += 1

            pref[i] = j
            j += 1

        # now construct the suffixes
        j = nt - 1
        for i in range(ns - 1, -1, -1):
            while j >= 0 and s[i] != t[j]:
                j -= 1

            suff[i] = j
            j -= 1

        # no edits case
        if pref[-1] <= nt - 1:
            return True

        # single edit case
        for i in range(ns):
            left = -1 if i == 0 else pref[i - 1]
            right = nt if i == ns - 1 else suff[i + 1]

            if left + 1 < right:
                return True

        return False
```

(Note: if the prefix scan runs out of `t`, `j` saturates past `nt`, so `pref[i]` for unmatched positions is `>= nt` — the `left + 1 < right` check then fails naturally, no special-casing needed.)

## The takeaway

One small implementation tip for future contests: whenever you're writing a two-pointer subsequence scan, mentally ask yourself:

> **"Did I consume the matched character?"**

It's probably the most common bug in these problems. The match-finding `while` loop draws all the attention; the `j += 1` after it is where the correctness actually lives.

And second: prefix/suffix decomposition with sentinels (`left = -1`, `right = nt`) plus an "is the open interval non-empty" check (`left + 1 < right`) is a reusable pattern for any "delete/replace/insert one element" subsequence problem.
