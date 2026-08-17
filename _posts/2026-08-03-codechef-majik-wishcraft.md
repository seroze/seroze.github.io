---
layout: post
title: "[CodeChef] Starters 105 — Wishcraft"
date: 2026-08-03 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, greedy, sorting]
author: "Seroze"
published: true
---

*[CodeChef — Wishcraft (MAJIK)](https://www.codechef.com/problems/MAJIK), rated 2105.*

While working on this problem, I noticed a surprisingly simple pattern that ended up being enough to solve it — a 2100-rated problem that collapses into three lines of Python once you look at it the right way.

## Problem

You're given an array $$A$$ of $$N$$ integers and two budgets $$P$$ and $$Q$$:

- **At most $$P$$ times:** pick two elements $$x, y$$, delete both, insert $$x + y$$.
- **At most $$Q$$ times:** pick two elements $$x, y$$, delete both, insert $$x - y$$.

Each operation shrinks the array by one. Operations can be interleaved in any order. Maximize

$$
\max(B) - \min(B)
$$

over all final arrays $$B$$.

Constraints: $$N \le 10^5$$, $$0 \le P, Q \le N-1$$, $$\lvert A_i \rvert \le 10^9$$, sum of $$N$$ up to $$3 \cdot 10^5$$.

## The shift in perspective

Instead of thinking about the operations directly, I focused on the quantity we're trying to maximize.

After sorting the array, the initial span is simply:

```
largest - smallest
```

The two extreme elements are already contributing to the span. Any additional gain can only come from the elements **between** them.

So temporarily ignore the smallest and largest elements and look only at the middle of the sorted array.

**The main observation: every element in the middle can increase the span by its absolute value $$\lvert x \rvert$$** — if we have an addition operation left, we merge it into the maximum; if we have a subtraction operation left, we subtract it from the smallest element. In detail, for a middle element $$v$$:

- **If $$v > 0$$:** merge it into the maximum with an *addition* ($$\max + v$$), or merge it into the minimum with a *subtraction* ($$\min - v$$). Either way the span grows by $$v$$.
- **If $$v < 0$$:** merge it into the minimum with an *addition* ($$\min + v$$), or merge it into the maximum with a *subtraction* ($$\max - v$$). Either way the span grows by $$\lvert v \rvert$$.

This is the crux: **every middle element can be cashed in with *either* operation type**, and it's always worth exactly its absolute value. A positive element prefers an addition but can settle for a subtraction; a negative element is the mirror image. So the two budgets aren't really separate — they pool into a single budget of $$P + Q$$ operations, each of which consumes one middle element and pays out its magnitude.

(Merging into the current max keeps the result as the new max, and likewise for the min, so the "extremes" survive every operation — nothing breaks by doing this repeatedly.)

## The greedy

1. Sort the array.
2. If $$n = 1$$ the answer is $$0$$ — there's only one element, so max and min coincide (and $$P = Q = 0$$ anyway, since $$P, Q \le N - 1$$).
3. Compute the initial gap $$a_{n-1} - a_0$$.
4. Ignore the first and last elements; only consider the middle ones.
5. Sort the middle elements by absolute value, descending.
6. Pick the top $$\min(P + Q,\ n - 2)$$ of them and add their magnitudes to the gap.

Full solution:

```python
import sys
input = sys.stdin.readline

def solve():
    n = int(input())
    p, q = map(int, input().split())
    a = list(map(int, input().split()))

    if n == 1:
        print(0)
        return

    a.sort()
    gap = a[-1] - a[0]

    # middle elements only, largest absolute values first
    middle = sorted((abs(x) for x in a[1:-1]), reverse=True)
    k = min(p + q, n - 2)
    print(gap + sum(middle[:k]))

t = int(input())
for _ in range(t):
    solve()
```

$$O(N \log N)$$ per test case, all of it in the sorts. With the sum of $$N$$ capped at $$3 \cdot 10^5$$, this passes comfortably within the 1-second limit.

## Sanity check against the samples

**Test 2:** $$A = [8, -1, -4, 2, 6, -3]$$, $$P = 1$$, $$Q = 2$$. Sorted: $$[-4, -3, -1, 2, 6, 8]$$, gap $$= 12$$. Middle by absolute value: $$6, 3, 2, 1$$. Take the top $$P + Q = 3$$: $$6 + 3 + 2 = 11$$. Answer $$12 + 11 = 23$$. ✓

**Test 3:** $$A = [-2, -4, 2, -2, -3, -1, -1]$$, $$P = Q = 6$$. Sorted gap $$= 2 - (-4) = 6$$. All five middle elements fit in the budget, magnitudes sum to $$9$$. Answer $$15$$. ✓

## Takeaway

What I enjoyed most about this problem wasn't the implementation — it was the shift in perspective.

Instead of asking:

> *"Which operations should I perform?"*

I asked:

> *"What actually contributes to increasing the span?"*

That small change in viewpoint turned what initially felt like a difficult constructive problem into a short greedy. It's a good reminder that in competitive programming, simplifying the objective is often more valuable than simulating the process.
