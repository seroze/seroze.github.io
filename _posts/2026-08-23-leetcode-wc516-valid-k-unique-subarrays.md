---
layout: post
title: "[LeetCode] Weekly Contest 516 — Valid K-Unique Subarrays I: Mo's algorithm, and where the √N actually comes from"
date: 2026-08-23 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, leetcode, mos_algorithm, sqrt_decomposition, offline_queries]
author: "Seroze"
published: true
---

Problem: [Valid K-Unique Subarrays I](https://leetcode.com/problems/valid-k-unique-subarrays-i/) (Weekly Contest 516, hard)

You're given an array `nums`, an integer `k`, and a list of queries `[l, r]`. A subarray `nums[l..r]` is *valid* if it contains exactly `k` distinct numbers **and** every number in it appears an even number of times. Return a boolean per query. Both `n` and the number of queries go up to $$10^5$$.

This is about as clean a Mo's algorithm problem as you will find, and I want to use it to write down the thing that took me longest to actually believe: where the $$\sqrt{N}$$ comes from, and why the analysis still works even though the right pointer visibly runs backwards.

## The shape of the problem

The naive answer is to scan each query's range and build a frequency table. That's $$O(r - l)$$ per query, so $$O(NQ)$$ overall, which at $$10^5 \times 10^5$$ is $$10^{10}$$ and hopeless.

But look at two queries sitting next to each other:

```
[2, 6]
[2, 7]
```

They differ by a single element. If I already know the answer state for `[2,6]`, recomputing everything for `[2,7]` from scratch is absurd — I should just fold in `nums[7]` and be done.

That observation is the whole of Mo's algorithm. It isn't a data structure. It's a way of *ordering the queries* so that consecutive ones are cheap to get between.

## The window and the four moves

Mo maintains exactly one window, `[curL, curR]`, starting empty at `curL = 0`, `curR = -1`. To serve a query it walks the two pointers to the requested `[L, R]`, and every single step of that walk is one of two operations:

```
add(i)      # index i enters the window
remove(i)   # index i leaves the window
```

Left and right don't need separate handlers, because an element entering from the left is the same event as an element entering from the right — the window is a set, it doesn't care which end you fed it from.

So the design question for any Mo problem is: **what do I need to maintain so that `add` and `remove` are $$O(1)$$?**

## What this problem needs maintained

Two conditions, two counters.

**Exactly `k` distinct** is easy. Keep `freq[x]` and a running `distinct`. A value joins the distinct set when its frequency goes $$0 \to 1$$, and leaves when it goes $$1 \to 0$$.

**Every frequency is even** is the interesting half. The trap is to think you need to check every value in the window. You don't — you only need to know whether *any* value is currently odd, so keep a count of how many are:

```
oddFreq = number of values x with freq[x] odd
```

The query is satisfiable iff `oddFreq == 0`. And this counter is trivially incremental, because adding or removing one occurrence flips the parity of exactly one value. Frequency $$4 \to 5$$ means one more odd value, so `oddFreq += 1`. Frequency $$5 \to 6$$ means one fewer, so `oddFreq -= 1`.

That gives:

```python
def add(i):
    x = nums[i]
    if freq[x] == 0:
        distinct += 1
    freq[x] += 1
    if freq[x] & 1:
        oddFreq += 1     # was even, now odd
    else:
        oddFreq -= 1     # was odd, now even

def remove(i):
    x = nums[i]
    if freq[x] & 1:
        oddFreq -= 1     # was odd, now even
    else:
        oddFreq += 1     # was even, now odd
    freq[x] -= 1
    if freq[x] == 0:
        distinct -= 1
```

Note the symmetry: `remove` reads the parity *before* decrementing, `add` reads it *after* incrementing. Both are asking the same question — "what is the parity of the frequency that is currently in the window?" — and the answer for a removal is the pre-decrement value. Getting this backwards is the standard off-by-one in this problem, and it doesn't crash, it just silently returns wrong answers.

With both counters in hand, every query is answered by a single comparison:

```python
ans[idx] = (distinct == k and oddFreq == 0)
```

No scanning, ever.

## Where the √N comes from

This is the part that the `add`/`remove` discussion completely sidesteps, and it's the actual algorithm.

We're free to answer the queries in any order we like, since we record answers by original index. So: what order minimises the total pointer movement?

Sorting purely by `L` is bad, because `R` then jumps wildly. Sorting purely by `R` is bad for the mirror reason. Mo's compromise is to chop the array into blocks of some size $$B$$ and sort by

$$(\lfloor L/B \rfloor,\; R)$$

which reads as: *hold the left endpoint roughly still for a while, and while it's still, sweep the right endpoint forward in order.*

Now count the two costs separately.

**Left pointer.** All queries in the same block have their `L` inside a window of width $$B$$, so consecutive queries move `L` by at most $$O(B)$$. Across all $$Q$$ queries that's $$O(QB)$$. (Block transitions add another $$O(B)$$ each, and there are only $$N/B$$ of them, so they vanish into the same term.)

**Right pointer.** Within one block, `R` is sorted increasing, so it only ever moves forward — at most $$N$$ steps for the whole block. There are $$N/B$$ blocks, so the total is

$$\frac{N}{B} \times N = \frac{N^2}{B}$$

**Total.**

$$T(B) \;=\; QB + \frac{N^2}{B}$$

Notice the two terms pull in opposite directions, which is exactly why an interior optimum exists. Setting $$B = 1$$ pins the left pointer but gives you $$N$$ blocks, each of which lets the right pointer sweep the whole array — $$O(N^2)$$. Setting $$B = N$$ gives one block so the right pointer is perfect, but now `L` can teleport across the entire array between consecutive queries — $$O(QN)$$. Both ends are terrible.

Differentiating, $$T'(B) = Q - N^2/B^2 = 0$$ gives

$$B = \frac{N}{\sqrt{Q}}, \qquad T = 2N\sqrt{Q}$$

so the honest bound is $$O(N\sqrt{Q})$$. When $$Q \approx N$$ — which is the usual competitive-programming setup, and is exactly this problem — that collapses to $$B = \sqrt{N}$$ and the familiar $$O((N+Q)\sqrt{N})$$. Worth knowing the general form: if a problem hands you far fewer queries than array elements, `int(sqrt(n))` is leaving time on the table and `n / sqrt(q)` is the right block size.

## "But the right pointer *does* go backwards"

This is the objection that stalled me, and it's a good one.

Take $$N = 16$$, $$B = 4$$, and these sorted queries:

```
block 0:  (0,5)  (1,9)  (2,15)
block 1:  (4,6)  (5,14)  (6,7)
```

Inside block 0 the right pointer goes $$5 \to 9 \to 15$$, monotone, fine. Then the very first query of block 1 is `(4,6)` and `R` slams from $$15$$ back down to $$6$$. That's an enormous backward jump. So the claim "R only moves forward" is plainly false.

The resolution is that the claim was never needed. "R only moves forward" is true *within* a block and false *across* blocks, and the bound only ever used the within-block version. The accounting is:

> Each left-endpoint block gets charged at most one full traversal of the array, $$O(N)$$. There are $$N/B$$ blocks. Hence $$N^2/B$$.

The one big backward jump at a block boundary is at most $$N$$ steps, and it is already sitting inside that block's $$O(N)$$ budget. The proof never assumes monotonicity globally — it just refuses to charge any block more than a single sweep.

So the intuition to carry around isn't "the pointers move forward". It's "the pointers never do more than one sweep of the array per block, and there are only $$\sqrt{N}$$ blocks".

## The odd-even trick

That backward jump is asymptotically free but practically annoying — it's a real $$N$$ steps of pointer movement that does nothing useful. The standard fix is to alternate the sweep direction:

```python
queries.sort(key=lambda q: (
    q[0] // block,
    q[1] if (q[0] // block) % 2 == 0 else -q[1]
))
```

Even blocks sweep `R` left to right, odd blocks sweep it right to left. Now the end of one block and the start of the next are *both* at the far end of the array, so the transition costs almost nothing:

```
without:  ... 9  15  →  6  7 ...       (jump of 9)
with:     ... 9  15  →  14  7 ...      (jump of 1)
```

Same $$O((N+Q)\sqrt{N})$$, roughly half the constant in practice. It's two extra characters in a lambda and it's the difference between TLE and AC often enough that I now just write it by default.

## The pointer-move order is a trap

One implementation detail that bites people. This ordering is safe:

```python
while curL > L: curL -= 1; add(curL)      # expand left
while curR < R: curR += 1; add(curR)      # expand right
while curL < L: remove(curL); curL += 1   # shrink left
while curR > R: remove(curR); curR -= 1   # shrink right
```

**Expand both ends first, then shrink.** If you shrink first, you can transiently invert the window — `curR` dropping below `curL` — which means calling `remove` on indices that were never added, driving frequencies negative.

For *this* problem you happen to get away with it, because `distinct` and `oddFreq` are both exact functions of the frequency array (`oddFreq` counts odd values, and parity is well-defined for negatives; `distinct` counts values with `freq >= 1`, and the ±1 crossings of the 0/1 boundary telescope). The spurious removes get undone by matching adds before the answer is read. But the moment you maintain something that *isn't* recoverable that way — a running maximum frequency, a sum over buckets, a "count of values with frequency exactly $$c$$" table — the transient garbage sticks. Expand-then-shrink costs nothing and removes the whole class of bug.

## The full solution

```python
import math
from collections import defaultdict

class Solution:
    def validSubarrays(self, nums: list[int], k: int, queries: list[list[int]]) -> list[bool]:
        n = len(nums)
        block = max(1, int(math.sqrt(n)))

        qs = [(l, r, i) for i, (l, r) in enumerate(queries)]
        qs.sort(key=lambda q: (
            q[0] // block,
            q[1] if (q[0] // block) % 2 == 0 else -q[1]
        ))

        freq = defaultdict(int)
        distinct = 0
        oddFreq = 0
        ans = [False] * len(queries)
        curL, curR = 0, -1

        def add(i):
            nonlocal distinct, oddFreq
            x = nums[i]
            if freq[x] == 0:
                distinct += 1
            freq[x] += 1
            if freq[x] & 1:
                oddFreq += 1
            else:
                oddFreq -= 1

        def remove(i):
            nonlocal distinct, oddFreq
            x = nums[i]
            if freq[x] & 1:
                oddFreq -= 1
            else:
                oddFreq += 1
            freq[x] -= 1
            if freq[x] == 0:
                distinct -= 1

        for L, R, idx in qs:
            while curL > L:
                curL -= 1
                add(curL)
            while curR < R:
                curR += 1
                add(curR)
            while curL < L:
                remove(curL)
                curL += 1
            while curR > R:
                remove(curR)
                curR -= 1
            ans[idx] = (distinct == k and oddFreq == 0)

        return ans
```

$$O((N+Q)\sqrt{N})$$ time, $$O(N)$$ extra space for the frequency table.

A practical caveat: that's around $$6 \times 10^7$$ pointer moves at the stated limits. In C++ that's comfortable. In Python each of those moves is a function call plus a dict lookup, and the version above will very likely time out — you'd want `freq` as a flat list of size $$10^5 + 1$$ (values are bounded) and the bodies of `add`/`remove` inlined into the four while loops. The structure of the algorithm doesn't change; it's purely interpreter overhead. The 1.6% acceptance rate on this problem is, I suspect, mostly people fighting that fight rather than people failing to see Mo's.

Two cheap short-circuits also help: a valid subarray has every frequency even, so its **length must be even** — odd-length queries are instantly `false`. And `k` distinct values each appearing at least twice means the length is at least $$2k$$. Both are one-line filters before the main loop.

## An aside: you don't strictly need Mo here

Worth knowing, because it shows how the two conditions decouple.

The "every frequency is even" condition has a slick standalone trick. Assign each distinct value a random 64-bit key, and take prefix XORs of the keys. Every value in `nums[l..r]` appears an even number of times exactly when the prefix XORs at `l` and `r+1` are equal, since even occurrences cancel. That's $$O(1)$$ per query with a $$2^{-64}$$ chance of a false positive per query.

The "exactly `k` distinct" condition is the classic offline distinct-count-in-range problem, solvable with a BIT sweeping `r` and moving a marker at each value's previous occurrence — $$O((N+Q)\log N)$$.

So there's a strictly faster route. But it's two separate non-obvious techniques and maybe sixty lines, versus Mo's twenty lines where the *only* problem-specific thinking was "keep a count of odd frequencies". That's the actual pitch for Mo's algorithm: it converts "answer this range query" into "maintain this under single-element insert and delete", and the second question is nearly always the easier one.

## The takeaway

The reusable part of all this is a template with a hole in it:

1. Sort queries by $$(\lfloor L/B \rfloor, R)$$ with the odd-even flip, $$B = N/\sqrt{Q}$$.
2. Walk two pointers, expand before shrink.
3. Write `add` and `remove`.

Steps 1 and 2 are copy-paste and never change. Step 3 is the entire problem, and it's usually a couple of counters. Here it was `distinct` and `oddFreq`; elsewhere it's a running sum, a count of values with frequency exactly one, a bucket array for "smallest missing frequency". The skill Mo's algorithm actually asks you to develop is spotting *what quantity is cheap to maintain incrementally* — the $$\sqrt{N}$$ machinery around it is fixed furniture.
