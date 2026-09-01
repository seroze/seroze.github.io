---
layout: post
title: "[CodeChef] Starters 97 — Triplets Min: the binary search that collapses into a prefix sum"
date: 2026-08-31 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, binary_search, prefix_sums, combinatorics, sorting]
author: "Seroze"
published: true
---

Problem: [CodeChef — Triplets Min](https://www.codechef.com/problems/TRIPLETMIN) (Starters 97, difficulty 1868)

You get an array $$A$$ of size $$N$$. Form the multiset

$$\{\, \min(A_i, A_j, A_k) \ : \ 1 \le i < j < k \le N \,\}$$

which has $$\binom{N}{3}$$ elements in it. Then answer $$Q$$ queries, each asking for the
$$K$$-th smallest element of that multiset. $$N$$ and $$Q$$ both go up to $$3 \cdot 10^5$$,
summed over all test cases.

## The reflex, and why it isn't enough on its own

"Find the $$K$$-th smallest" is one of those phrases that should immediately make you think
*binary search on the answer*. You don't search for the value directly, you search for a
threshold $$T$$ and ask a counting question:

$$f(T) = \#\{\text{triplets with } \min \le T\}$$

$$f$$ is non-decreasing in $$T$$, so the predicate $$f(T) \ge K$$ is a monotone
`0 0 0 ... 0 1 1 ... 1`, and the answer is the first $$T$$ where it flips to 1. Standard.

That's where I started, and it's the right instinct. But it isn't a solution yet, because of
the $$Q$$. If computing $$f(T)$$ costs a pass over the array, then each query costs
$$O(N \log C)$$ and the whole thing is $$O(Q N \log C)$$ — roughly $$10^{12}$$ operations for
the given limits. The counting function has to get cheap before the binary search is worth
anything.

## Counting triplets with min ≤ T

Sort the array first, into $$b_0 \le b_1 \le \dots \le b_{n-1}$$. This is the move that makes
the count tractable, because after sorting **the minimum of a triplet is always its leftmost
chosen element.** No comparisons needed — position tells you.

So instead of iterating over triplets, iterate over the position that supplies the minimum.
If the minimum sits at position $$i$$, the other two elements have to come from the suffix
strictly after $$i$$, and there are $$n - i - 1$$ of those. So position $$i$$ is the leftmost
element of exactly

$$\binom{n-i-1}{2}$$

triplets, and

$$f(T) = \sum_{i \,:\, b_i \le T} \binom{n-i-1}{2}$$

## The off-by-one I actually wrote

My first version of that count used $$n - i$$ elements in the suffix rather than
$$n - i - 1$$. It's an easy slip — you're thinking "how many elements are at or after $$i$$"
when the question is "how many are strictly after $$i$$", because $$b_i$$ itself is already
spoken for as the minimum.

What's nice about this particular bug is that there's a one-line check that catches it
instantly. Every triplet has exactly one minimum-position, so the frequencies must sum to the
total number of triplets:

$$\sum_{i=0}^{n-1} \binom{n-i-1}{2} = \binom{n}{3}$$

The buggy version gives

$$\sum_{i=0}^{n-1} \binom{n-i}{2} = \binom{n+1}{3}$$

which is off by a factor of about $$(n+1)/(n-2)$$ — invisible on tiny cases, fatal on real
ones. Any time you decompose a count by "which element plays role X", it's worth summing the
pieces and checking you get the total you expected. It costs one line and it would have saved
me a submission.

## The part that made it click

Once the frequencies are written down, something better than a value-domain binary search
falls out. Look at what the sorted triplet array actually *is*: since $$b$$ is sorted, the
minima come out in blocks, in order.

$$b_0 \text{ repeated } \binom{n-1}{2} \text{ times},\quad
  b_1 \text{ repeated } \binom{n-2}{2} \text{ times},\quad \dots$$

Take `1 2 4 7 9`. The frequencies are $$\binom{4}{2} = 6$$, $$\binom{3}{2} = 3$$,
$$\binom{2}{2} = 1$$, then $$0$$ and $$0$$, so the sorted triplet array is

```
1 1 1 1 1 1 2 2 2 4
```

Ten values, which is $$\binom{5}{3}$$. The last two elements have frequency zero, which makes
sense: there aren't two elements to the right of them to finish a triplet.

So the whole answer multiset is known in closed form. Build the prefix sums

$$P_i = \sum_{j=0}^{i} \binom{n-j-1}{2}$$

and $$P_i$$ is exactly "how many triplet minima come from position $$i$$ or earlier". The
answer to query $$K$$ is $$b_i$$ for the smallest $$i$$ with $$P_i \ge K$$, which is one
`bisect_left` on a monotone array.

The thing worth noticing is that this **is still the binary search I started with**, not a
different technique. The count function $$f$$ is a step function that can only change at
values present in the array, so searching the value domain and searching the index domain of
the sorted array find the same place. Restricting to indices buys two things: the search
space shrinks from $$10^9$$ values to $$N$$ positions, and the predicate becomes an
$$O(1)$$ array lookup instead of an $$O(N)$$ sweep. The binary search was never the expensive
part — recomputing the count at every midpoint was.

## Code

```python
import sys
from bisect import bisect_left

def main():
    data = sys.stdin.buffer.read().split()
    p = 0
    t = int(data[p]); p += 1
    out = []
    for _ in range(t):
        n, q = int(data[p]), int(data[p + 1]); p += 2
        a = sorted(map(int, data[p:p + n])); p += n

        # prefs[i] = number of triplets whose minimum sits at position <= i
        prefs = [0] * n
        cur = 0
        for i in range(n):
            r = n - i - 1
            cur += r * (r - 1) // 2
            prefs[i] = cur

        for _ in range(q):
            k = int(data[p]); p += 1
            out.append(a[bisect_left(prefs, k)])
    sys.stdout.write('\n'.join(map(str, out)) + '\n')

main()
```

`bisect_left(prefs, k)` gives the first index with $$P_i \ge K$$, which is what we want.
Duplicate values and trailing zero-frequency positions both take care of themselves: repeated
values just make consecutive $$b_i$$ equal, and zero-frequency positions produce repeated
$$P_i$$, where `bisect_left` picks the earliest — which is a position that genuinely has that
count.

I checked it against a brute force that enumerates all $$\binom{n}{3}$$ triplets and sorts
them, over 300 random arrays with $$n \le 8$$ and every valid $$K$$, plus the two samples. On
a locally generated worst case of $$N = Q = 3 \cdot 10^5$$ in a single test it runs in about
0.3 s against a 1.5 s limit, so plain Python has plenty of headroom here — the sort dominates.

## One note on `math.comb`

Somewhere along the way I picked up the belief that `math.comb(r, 2)` is much slower than
writing `r * (r - 1) // 2` by hand, and that you should always unroll it in a hot loop. I
measured it while writing this up, and on CPython 3.12 it's the other way round:

```
comb 0.037 s   closed form 0.063 s     (300k iterations, best of 3)
```

`comb` is a single C call. The "closed form" is a subtraction, a multiplication, a
floor-division and three intermediate `int` objects, all at Python level. The closed form is
the right answer in C++, where the call has no overhead to save; in Python the C builtin wins.
I kept the manual version in the code above only because it's what I'd write in a contest out
of habit — but the reason I believed it was faster was wrong, and either is comfortably fast
enough here.

## Complexity

Sorting is $$O(N \log N)$$, the prefix array is $$O(N)$$, and each query is
$$O(\log N)$$, so overall

$$O(N \log N + Q \log N)$$

The prefix values reach $$\binom{3 \cdot 10^5}{3} \approx 4.5 \cdot 10^{15}$$, which fits in a
signed 64-bit integer with room to spare — worth checking before you write this in C++, since
it's well past 32 bits.

## The takeaway

Two things I want to keep from this one.

The first is the pattern. "Return the $$K$$-th smallest element of some huge implicit
collection" almost always means binary search on the answer, with a counting function as the
predicate. The collection here has $$\binom{N}{3} \approx 4.5 \cdot 10^{15}$$ elements, so
nothing that materialises it can work, and yet the count is a two-line formula. Getting from
"I can't build this" to "I can count it" is the entire problem.

The second is that a binary search with a per-query predicate and a binary search over a
precomputed prefix array are the same search wearing different clothes. When there are many
queries, the useful question isn't "should I binary search?" but "what can I precompute so
that the predicate is $$O(1)$$?" Here the predicate turned out to be a prefix sum I could
build once and reuse for every query, and that's the whole difference between $$10^{12}$$
operations and $$10^6$$.
