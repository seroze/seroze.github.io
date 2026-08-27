---
layout: post
title: "[CodeChef] Starters 253 — Dis-Card: my dominance count was off by one, and off by a lot"
date: 2026-08-27 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, permutations, greedy, binary_search, sparse_table, pending]
author: "Seroze"
published: true
---

Problem: [CodeChef — Dis-Card](https://www.codechef.com/problems/DISCARD2) (Starters 253)

**I did not solve this one.** I got to an idea that passed three of the four sample tests, convinced
myself it was basically right, and then spent the rest of the time trying to patch a hypothesis that
was structurally wrong rather than slightly wrong. This is the post-mortem. I'm tagging it `pending`
because I want to come back in a few weeks and re-derive the whole thing without notes.

## The problem

You get two permutations $$P$$ and $$Q$$ of $$1 \dots N$$. There's a discard game: repeatedly pick
either the leftmost surviving element of $$P$$ or the leftmost surviving element of $$Q$$, and delete
that *value* from both rows. After $$N-1$$ discards one value is left.

You play the game, so you choose which side to discard from each turn. Before the game starts you may
swap adjacent elements inside $$P$$ or inside $$Q$$, one swap at a time, each costing $$1$$.

For every $$K$$ from $$1$$ to $$N$$, output the minimum number of swaps needed so that $$K$$ can be
the last survivor.

## Who survives, with no swaps at all

This part I got quickly and it turned out to be correct.

Say $$M$$ sits after $$K$$ in $$P$$ **and** after $$K$$ in $$Q$$. To ever discard $$M$$ it has to
reach the front of one of the rows, which means everything ahead of it in that row is gone — and
$$K$$ is ahead of it in both rows. So $$K$$ dies before $$M$$ does. $$K$$ cannot win.

The converse works too. Suppose every $$M \ne K$$ is before $$K$$ in at least one row. Then just
greedily discard any head that isn't $$K$$. Can you get stuck with $$K$$ at the head of both rows?
If $$K$$ heads $$P$$, everything still alive apart from $$K$$ was after $$K$$ in $$P$$, so by
assumption all of it was before $$K$$ in $$Q$$ — so the head of $$Q$$ isn't $$K$$. You never stall.

So, writing $$x_v$$ and $$y_v$$ for the positions of value $$v$$ in $$P$$ and $$Q$$:

$$K \text{ survives} \iff \text{for every } M \ne K,\ x_M < x_K \ \text{ or } \ y_M < y_K$$

Equivalently: **nothing is after $$K$$ in both rows.**

## The idea that was wrong

The condition above hands you an obvious guess. Count the elements that violate it:

$$\text{answer}(K) \stackrel{?}{=} \lvert \{\, M : x_M > x_K \text{ and } y_M > y_K \,\} \rvert$$

That's a 2D dominance count, one BIT sweep, very comfortable. Every violating element needs *some*
fixing, so it feels like a swap each.

It scored 3 out of 4 on the samples. The one that didn't match:

```
P = 2 5 3 4 1
Q = 3 5 2 1 4
expected:  0 2 2 0 3
mine:      0 2 2 0 2
```

Only $$K = 5$$ differs. The elements after $$5$$ in $$P$$ are $$\{3,4,1\}$$, after $$5$$ in $$Q$$ are
$$\{2,1,4\}$$, and the intersection is $$\{1,4\}$$ — size two. The real answer is three.

I burned a long time here assuming there was some extra obstruction I hadn't spotted, some hidden
dependency involving $$2$$ and $$3$$. There isn't. The obstruction set is exactly right. What's wrong
is the pricing: **each violator does not cost one swap.**

## What a swap actually does

Here's the step I never took during the contest, and it's the one that unlocks everything.

Take any adjacent swap that doesn't involve $$K$$. It exchanges two elements that are next to each
other, so both of them are on the same side of $$K$$ before the swap and both are on that same side
after. The survival condition only ever asks "is $$M$$ before or after $$K$$", so that swap changes
nothing about who can survive. It's pure waste.

So an optimal solution only ever swaps $$K$$ with a neighbour. And moving $$K$$ *left* only converts
elements from "before $$K$$" to "after $$K$$", which strictly hurts. Therefore:

> $$K$$ only ever moves right, in $$P$$ and in $$Q$$, and the cost is exactly how far it moves.

That reframes the whole problem. Instead of thinking about a set of violators to repair, pick the
final position $$i \ge x_K$$ of $$K$$ in $$P$$ and the final position $$j \ge y_K$$ in $$Q$$. Cost is

$$(i - x_K) + (j - y_K)$$

and now I just need to know when a choice of $$(i, j)$$ is legal.

Sliding $$K$$ from $$x_K$$ to $$i$$ in $$P$$ shifts everything it passes one step left, so the
elements still after $$K$$ in $$P$$ are precisely those that started at $$P$$-positions greater than
$$i$$. Each of them must end up before $$K$$ in $$Q$$, and after $$K$$ slides to $$j$$ in $$Q$$,
element $$M$$ is before $$K$$ exactly when $$y_M \le j$$. So the whole legality test collapses to one
number. Define

$$\mathrm{suf}(i) = \max \{\, y_{P_t} \ : \ t > i \,\}$$

the worst $$Q$$-position among everything left behind in $$P$$, with $$\mathrm{suf}(N-1) = -1$$. The
pair $$(i,j)$$ is legal iff $$j \ge \mathrm{suf}(i)$$, and since $$j \ge y_K$$ anyway the cheapest
legal $$j$$ is $$\max(y_K, \mathrm{suf}(i))$$. The answer is

$$\mathrm{answer}(K) = \min_{i \ge x_K} \Big[ (i - x_K) + \max\big(0,\ \mathrm{suf}(i) - y_K\big) \Big]$$

## Why the count was wrong, concretely

Look at $$K = 5$$ in that sample with this formula in hand. Violators are $$1$$ (at $$Q$$-position
$$3$$) and $$4$$ (at $$Q$$-position $$4$$), and $$5$$ sits at $$Q$$-position $$1$$.

To fix $$4$$ through $$Q$$ you have to drag $$5$$ past everything between them — three swaps, not
one. To fix it through $$P$$ you drag $$5$$ rightward past $$3$$ and $$4$$, and that also happens to
fix $$1$$ for free, because $$1$$ is further right still and gets picked up on the way. Two things
are true at once and my count modelled neither:

- fixing one violator costs a **distance**, not a unit;
- fixing violators is **shared** — one long slide in $$P$$ clears everything it passes, and on the
  $$Q$$ side you pay the single worst violator, a $$\max$$, never a sum.

A cost that is "distance on one axis, max on the other, minimised over where you stop" happens to
agree with a plain count on a lot of small inputs. That's why it survived three samples. It agrees
whenever the violators happen to be tightly packed just after $$K$$; test 2 spreads them out and the
two models separate immediately.

## Computing it fast

$$\mathrm{suf}$$ is a suffix maximum, so it's non-increasing in $$i$$. That splits the minimisation
in two at the first index where the $$\max(0, \cdot)$$ term dies. Let $$i_0$$ be the smallest
$$i \ge x_K$$ with $$\mathrm{suf}(i) \le y_K$$ — binary searchable precisely because $$\mathrm{suf}$$
is monotone.

For $$i \ge i_0$$ the second term is zero and the cost $$i - x_K$$ is increasing, so the best in that
half is $$i_0 - x_K$$.

For $$x_K \le i < i_0$$ the max is active and the cost becomes

$$(i + \mathrm{suf}(i)) - x_K - y_K$$

where $$i + \mathrm{suf}(i)$$ doesn't depend on $$K$$ at all. Precompute $$C_i = i + \mathrm{suf}(i)$$
once, and every query is a range minimum over $$[x_K,\ i_0 - 1]$$. Sparse table, $$O(N \log N)$$ to
build and $$O(1)$$ per query, $$O(N \log N)$$ overall for the binary searches.

## Code

```python
import sys
input = sys.stdin.readline

def solve(n, P, Q):
    x = [0] * (n + 1)
    y = [0] * (n + 1)
    for i, v in enumerate(P):
        x[v] = i
    for i, v in enumerate(Q):
        y[v] = i

    # suf[i] = max Q-position among P-positions strictly after i
    suf = [-1] * (n + 1)
    for i in range(n - 2, -1, -1):
        suf[i] = max(suf[i + 1], y[P[i + 1]])

    C = [i + suf[i] for i in range(n)]

    LOG = [0] * (n + 1)
    for i in range(2, n + 1):
        LOG[i] = LOG[i >> 1] + 1
    sp = [C[:]]
    for k in range(1, LOG[n] + 1):
        prev = sp[-1]
        half = 1 << (k - 1)
        sp.append([min(prev[i], prev[i + half])
                   for i in range(n - (1 << k) + 1)])

    def rmq(l, r):                      # inclusive, l <= r
        k = LOG[r - l + 1]
        return min(sp[k][l], sp[k][r - (1 << k) + 1])

    ans = [0] * n
    for v in range(1, n + 1):
        xv, yv = x[v], y[v]

        # smallest i >= xv with suf[i] <= yv; suf is non-increasing
        lo, hi = xv, n - 1
        while lo < hi:
            mid = (lo + hi) // 2
            if suf[mid] <= yv:
                hi = mid
            else:
                lo = mid + 1
        i0 = lo

        best = i0 - xv
        if i0 > xv:
            best = min(best, rmq(xv, i0 - 1) - xv - yv)
        ans[v - 1] = best
    return ans

t = int(input())
out = []
for _ in range(t):
    n = int(input())
    P = list(map(int, input().split()))
    Q = list(map(int, input().split()))
    out.append(' '.join(map(str, solve(n, P, Q))))
print('\n'.join(out))
```

On the sample that broke my first attempt this prints `0 2 2 0 3`. I also checked it against a
brute force that BFSes over the actual graph of adjacent swaps — every state is a pair of
permutations, edges are single swaps, and you stop at the first state where the survival condition
holds for $$K$$. Three hundred random cases up to $$N = 5$$ and a handful at $$N = 6$$, all matching.
That brute force takes about six lines and I should have written it during the contest instead of
staring at test 2.

## What I'd do differently

The dominance count wasn't a bad guess and I don't regret trying it. What I regret is the shape of
the debugging afterwards. Once it failed on exactly one value of exactly one test I decided the
*characterisation* of the failure set was incomplete and went looking for a missing obstruction. The
characterisation was fine. The **cost model** was the broken half, and I never separated those two
questions.

There's a general lesson sitting there. When a min-cost problem is "achieve property X cheaply",
there are two independent things to get right — what X is, and what a move costs — and an idea that
gets X right can still be wrong by a mile. Checking them separately is cheap: verify the predicate on
random small inputs, then verify the cost with a BFS. I did neither and paid for it.

And the actual key that I missed: *swaps not involving $$K$$ are useless.* One sentence, provable in
two lines, and it turns a vague optimisation over both permutations into picking one index $$i$$.
Whenever a problem lets you rearrange things to satisfy a condition, it's worth asking early which
moves can possibly change the condition at all. Usually it's far fewer than the problem offers.
