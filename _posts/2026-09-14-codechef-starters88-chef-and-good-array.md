---
layout: post
title: "[CodeChef] Starters 88 — Chef and Good Array: pairs are intervals"
date: 2026-09-14 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, greedy, dynamic_programming, intervals, python, TODO]
author: "Seroze"
published: true
---

Problem: [CodeChef — Chef and Good Array](https://www.codechef.com/problems/UTLA) (Starters 88,
difficulty 2605). Official editorial:
[UTLA editorial](https://discuss.codechef.com/t/utla-editorial).

Another one from Starters 88 that I didn't get. On my own I only reached an $$O(N^3)$$ idea, which
is far too slow for $$N = 2000$$. After reading the editorial I could reconstruct an
$$O(N^2 \log N)$$ solution — the DP with a binary search, which I wrote myself and which does pass
— but the thing I did *not* see, even after the reduction was handed to me, is that the subproblem
has a much simpler greedy answer and the whole DP is unnecessary. That gap is what this post is
about, so both implementations are here.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

You're given an array $$A$$ of length $$N$$. Delete as few elements as possible so that what
remains is *good*: even length $$M$$, and

$$A_1 + A_2 = A_3 + A_4 = \cdots = A_{M-1} + A_M.$$

Constraints are small on paper — $$N \le 2000$$ and the sum of $$N$$ over all tests is also
$$2000$$ — which is a loud hint that an $$O(N^2)$$-ish solution is wanted, and that it's fine for
that solution to touch every pair of indices.

The sample is `[1, 2, 1, 1, 2, 1]` with answer 2: drop indices 3 and 6 to get `[1, 2, 1, 2]`, where
both adjacent sums are 3.

## Where I got on my own

The one thing that's obvious immediately is that the common sum should be fixed first. Call it
$$S$$. If you know $$S$$, the problem looks much more tractable — you're just trying to keep as many
elements as possible, in order, that split into consecutive pairs each summing to $$S$$. And since
deletions are $$N$$ minus what you keep, minimising deletions is maximising kept pairs.

So my plan was: enumerate the candidate sums, and for each one, do a linear scan. There are
$$O(N^2)$$ candidate sums (every $$A_i + A_j$$ is a candidate, and with values up to $$10^9$$ there's
no small universe to loop over), and a scan is $$O(N)$$, so that's $$O(N^3)$$ — around $$8 \cdot 10^9$$
operations at $$N = 2000$$. Hopeless.

I stared at that for a while trying to find a cheaper way to *evaluate* a fixed $$S$$, which was the
wrong place to look. The scan wasn't the problem. The enumeration was.

## The reframe: a kept pair is an interval

Here's the piece I never wrote down properly.

Suppose in the final array the pairs come from original indices $$(i_1, j_1), (i_2, j_2), \ldots$$
Deletion preserves order, so pair 1 occupies the first two surviving positions, pair 2 the next two,
and so on. That means no index of another pair can sit *between* $$i_1$$ and $$j_1$$ — if it did,
it would land between them in the surviving array too, and it would be paired with the wrong
partner.

So if you draw each kept pair $$(i, j)$$ as the interval $$[i, j]$$, the condition is simply that
the chosen intervals are **pairwise disjoint**. Nothing else. Every set of disjoint equal-sum
intervals is achievable, and every good array gives such a set.

The problem is now: for each sum $$S$$, take the list of intervals $$[i, j]$$ with
$$A_i + A_j = S$$, and find the maximum number of pairwise disjoint ones. That's textbook interval
scheduling.

## Why bucketing kills the extra factor of $$N$$

This is where my $$O(N^3)$$ dies, and it's almost embarrassing how small the fix is.

I was thinking "loop over sums, then do work proportional to $$N$$ for each". But every pair
$$(i, j)$$ belongs to exactly **one** sum. So instead of iterating sums on the outside, iterate
pairs on the outside and file each one into a bucket keyed by its sum:

```python
for j in range(n):
    for i in range(j):
        pairs[a[i] + a[j]].append((i, j))
```

There might be a million distinct sums, but the total number of intervals across *all* buckets is
exactly $$\binom{N}{2}$$. So "solve every sum" costs $$O(N^2)$$ in total, not $$O(N^2)$$ per sum.
The many-sums worry evaporates because most buckets are tiny — they have to be, they're sharing a
budget of $$N^2$$ intervals between them.

There's a free bonus hiding in that loop nest. The outer loop is over $$j$$, the right endpoint, and
it's increasing. So each bucket comes out **already sorted by right endpoint**, which is exactly the
order interval scheduling wants. No sorting step at all.

## Solving one bucket

Fix a sum and let its bucket be $$[l_1, r_1], \ldots, [l_K, r_K]$$ with $$r_1 \le \cdots \le r_K$$.
Two intervals are compatible when one ends strictly before the other starts — strictly, because
sharing an endpoint means reusing the same array element in two pairs.

### The DP with binary search, which is what I wrote

Let $$dp_i$$ be the best number of intervals you can pick from the first $$i+1$$ of them, given that
you do pick interval $$i$$. Then

$$dp_i = 1 + \max \{\, dp_x : r_x < l_i \,\}.$$

The reason this is cheap is that the $$r$$'s are sorted, so the compatible predecessors are a
*prefix* of the list. Binary-search for the first index whose right endpoint is $$\ge l_i$$, and
everything before it is fair game. Then keep a running prefix maximum of $$dp$$ so the "max over a
prefix" is an $$O(1)$$ lookup:

```python
from bisect import bisect_left

def fixed_sum_dp(intervals):
    # intervals already sorted by right endpoint
    k = len(intervals)
    rights = [r for l, r in intervals]

    dp = [0] * k
    pref = [0] * k

    for i, (l, r) in enumerate(intervals):
        # first right endpoint >= l, so [0 .. j-1] all end before l
        j = bisect_left(rights, l, 0, i)
        dp[i] = 1 if j == 0 else 1 + pref[j - 1]
        pref[i] = max(pref[i - 1] if i > 0 else 0, dp[i])

    return pref[-1] if k else 0
```

That's $$O(K \log K)$$ per bucket, $$O(N^2 \log N)$$ overall. It is correct and it passes.

Honestly, this is the part that annoys me most. "Sorted by right endpoint, so the compatible
predecessors form a prefix, so binary search plus a prefix maximum" is not an exotic idea — it's
the standard interval-DP shape and I've written it before. I should have reached it without the
editorial. What I needed from the editorial was only the reduction to intervals; once I had that,
the DP was sitting right there, and I want to be the person who gets that step unassisted next
time.

### The greedy, which is what I missed

Every interval is worth the same — one pair. That's the whole reason the DP is overkill. When all
weights are equal, the answer is: *always take the compatible interval that finishes earliest.*

```python
def fixed_sum_greedy(intervals):
    last_right, count = -1, 0
    for l, r in intervals:
        if l > last_right:
            count += 1
            last_right = r
    return count
```

Three lines, $$O(K)$$, no arrays, no binary search, no prefix maxima.

The exchange argument for why it's optimal: take any optimal selection and look at its
earliest-finishing interval $$X$$. Let $$Y$$ be the earliest-finishing interval in the whole bucket,
so $$r_Y \le r_X$$. Swap $$X$$ out for $$Y$$. Everything else in the optimal set started after
$$r_X \ge r_Y$$, so it still doesn't clash, and the count is unchanged. Repeat on the rest of the
list. So there's always an optimal solution that starts with the greedy choice, and by induction
the greedy is optimal throughout.

The thing I want to internalise is *how* the DP degenerates. My recurrence carefully computes the
best predecessor for every interval. But once the list is sorted by right endpoint and every
interval is worth 1, the best predecessor is always just "the last one I took" — there is never a
reason to skip a compatible interval, because taking it costs you nothing in room (it ends no later
than any alternative) and gains you one. So the entire `dp` and `pref` machinery is computing a
sequence that only ever increases by one at exactly the positions the greedy picks. Weighted
interval scheduling genuinely needs the DP. Unweighted never does.

## Putting it together

The greedy version, which is the one I'd submit:

```python
import sys

def main():
    data = sys.stdin.buffer.read().split()
    t = int(data[0])
    idx = 1
    out = []
    for _ in range(t):
        n = int(data[idx]); idx += 1
        a = list(map(int, data[idx:idx + n])); idx += n

        # j increases, so each bucket ends up sorted by right endpoint
        pairs = {}
        for j in range(n):
            aj = a[j]
            for i in range(j):
                pairs.setdefault(aj + a[i], []).append((i, j))

        best = 0
        for intervals in pairs.values():
            last_right, count = -1, 0
            for l, r in intervals:
                if l > last_right:
                    count += 1
                    last_right = r
            if count > best:
                best = count

        out.append(n - 2 * best)          # each kept pair saves two elements
    sys.stdout.write('\n'.join(map(str, out)) + '\n')

main()
```

Swapping `fixed_sum_greedy` for `fixed_sum_dp` in that loop gives my $$O(N^2 \log N)$$ version;
both produce the same answers. I checked both against a brute force that tries every subsequence,
on a few hundred random arrays with $$N \le 8$$ and small values, and all three agree everywhere.
On the sample they print 2 and 0.

Note that the empty array is good — length 0 is even — so `best = 0` is always a legal fallback and
the answer is never worse than $$N$$.

## A note on constant factors

The interesting part of the time limit here is that both solutions do the same $$O(N^2)$$ bucket
construction, and in CPython that dominates everything else. Timing one worst-case test with
$$N = 2000$$ and all-distinct values — two million singleton buckets, which is the adversarial
shape — I get roughly 3.9s for the greedy version and 6.5s for the DP version on my laptop, against
a 4.5s limit. Most of that is the two-million-iteration inner loop and the dict churn, not the
per-bucket work. Rewriting the pair as a packed integer `i * n + j` instead of a tuple barely moved
the needle for me.

So in Python this wants PyPy, and the editorial's remark that "too many map accesses or extra log
factors will result in TLE" is doing real work. The greedy isn't just prettier here — it's about
40% less time on the part that isn't the loop nest, and that's the difference between comfortable
and marginal.

## Takeaway

The reduction is the whole problem, and it comes in two steps that I half-saw.

Fixing the common sum was the right first move, but I applied it as an outer loop over sums, which
is what made it cubic. Turning it inside out — iterate over pairs, bucket by sum — costs nothing and
removes a whole factor of $$N$$, because each pair belongs to exactly one sum. Any time I'm about
to loop over "all possible values of some derived quantity", I should check whether I can instead
loop over the things that *produce* those values and group them.

And then: when every choice is worth the same, reach for a greedy before a DP. I wrote the
weighted-interval-scheduling DP for an unweighted problem and never noticed the weights were all 1.

## TODO

- Re-solve this cold in a week. The bar isn't "recall the greedy", it's "get from *fix the sum* to
  *these are disjoint intervals* on my own" — that's the 2605 part.
- Drill the sorted-by-right-endpoint DP until it's reflex. I already knew this pattern and still
  didn't produce it under my own steam; that's a retrieval problem, not a knowledge problem.
- Find two or three more problems where an outer loop over derived values should be turned inside
  out into bucketing. I suspect that trick is the reusable half of this problem.
