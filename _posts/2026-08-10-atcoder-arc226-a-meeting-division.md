---
layout: post
title: "[AtCoder] ARC226 A — Meeting Division: when the constraint is the solution"
date: 2026-08-10 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, atcoder, interval_graphs, graph_theory, prefix_sums]
author: "Seroze"
published: true
---

Problem: [ARC226 A — Meeting Division](https://atcoder.jp/contests/arc226/tasks/arc226_a)

---

`N` meetings, meeting `i` occupying the half-open interval `[S_i, T_i)`. Assign each one to Takahashi or Aoki so that neither person is ever double-booked — two meetings can share a person only if one ends at or before the other starts. Count the assignments, modulo 998244353.

Constraints: `N ≤ 3×10^5`, and — this turns out to matter more than anything in the statement — `1 ≤ S_i < T_i ≤ 2N`, with all `2N` endpoints distinct.

## The DP that doesn't work

At first glance this looked like a DP problem. My initial thought was:

- Sort intervals by end time.
- Let `dp(i, 0)` be the number of ways where the `i`-th meeting goes to Takahashi.
- If meeting `i` overlaps `i-1`, force opposite colours; otherwise inherit both possibilities.

This falls apart completely, and the reason is worth stating precisely: **a meeting can overlap much earlier meetings, not just its predecessor in sorted order.**

```text
A : [1,10]
B : [2,3]
C : [4,5]
```

Sorted by end time: `B`, `C`, `A`. When processing `A`, it overlaps both `B` and `C`, but the state only remembers the colour of `C`. The information that's still relevant has already been thrown away.

You could patch this by carrying more state, but the amount you'd need to carry is exactly "the colour of every interval still alive" — which is the whole problem again.

## Reframing

Treat each meeting as a vertex, and connect two vertices when their intervals overlap. The problem becomes:

> Count the number of valid 2-colourings of this **interval graph**.

Which, stated in that generality, is:

- 0 if the graph isn't bipartite;
- $$2^C$$ otherwise, where `C` is the number of connected components — each component's colouring is fully determined once you fix one vertex, and the two choices there are the only freedom.

That's the standard answer for counting proper 2-colourings of any graph. The work is normally in the bipartite check and the component count, and doing that naively means building the edge set — which is $$O(N^2)$$ edges in the worst case (imagine `N/2` intervals all containing a common point). So the graph framing alone doesn't buy anything. What buys everything is that this isn't an arbitrary graph.

## Insight 1: non-bipartite ⟺ some point has three intervals

For interval graphs:

> The graph is bipartite **if and only if** no point is covered by three or more intervals.

Two directions, and both are short.

**Three intervals over a point ⟹ not bipartite.** They're pairwise overlapping, so they form a triangle, and a triangle is an odd cycle.

**Not bipartite ⟹ three intervals over a point.** This is the direction that does the real work, and it goes through two classical facts:

1. *Interval graphs are chordal* — they contain no induced cycle of length ≥ 4. So a non-bipartite interval graph, which has some odd cycle, has a triangle: take a shortest odd cycle; if its length were ≥ 5 it would have a chord, and that chord splits it into two shorter cycles, one of which is odd — contradiction. So the shortest odd cycle has length 3.
2. *Intervals have the Helly property* — if intervals pairwise intersect, they share a common point. For three intervals this is a one-liner: `max(S_i) < min(T_i)` follows directly from each pair overlapping, and any point in between is covered by all three.

Fact 2 is the step that's easy to skip past, and it's the one that converts a graph-theoretic statement (triangle) into something you can actually test with a sweep (a point covered three times). A triangle in a general graph tells you nothing about a shared location; in an interval graph it does.

So the bipartite check is: **does the coverage count ever reach 3?**

## Insight 2: components are the runs of positive coverage

The second observation from the editorial is just as clean:

> The number of connected components equals the number of times the active interval count goes from `0` to positive during a left-to-right sweep.

The intuition: whenever the active count hits zero, you've completely left one component — nothing to the right can reach back across a gap with no coverage. Whenever it becomes positive again, you've entered a new one.

The other half — that everything inside one maximal run of positive coverage really is a *single* component, not several — follows because within such a run, at every moment of "handover" from one interval to the next there's an instant where both are active, so consecutive intervals in the run are adjacent, and adjacency chains the whole run together.

## Insight 3: the constraint hands you the sweep

The constraint

```text
1 ≤ S_i < T_i ≤ 2N
```

is the real gift. The coordinate range is only `2N`, so no sorting or compression is needed — a plain difference array (the imos trick) does it:

```python
diff[s] += 1
diff[t] -= 1
```

Note the half-open convention `[S, T)`: a meeting ending exactly when another begins is *not* a conflict, and decrementing at `T` rather than `T+1` is what encodes that. Getting this off by one turns "back-to-back meetings" into an overlap and quietly changes the component count.

Then one prefix-sum pass over `1..2N`:

- if the running count ever reaches `3`, the answer is `0`;
- every transition from `0` to positive starts a new component.

Since all endpoints are integers, intervals are unions of unit segments `[x, x+1)`, so sampling the coverage at each integer `x` misses nothing.

```python
import sys

MOD = 998244353

def main():
    data = sys.stdin.buffer.read().split()
    n = int(data[0])
    diff = [0] * (2 * n + 2)
    for i in range(n):
        s = int(data[1 + 2 * i])
        t = int(data[2 + 2 * i])
        diff[s] += 1
        diff[t] -= 1

    active = 0
    components = 0
    for x in range(1, 2 * n + 1):
        prev = active
        active += diff[x]
        if active >= 3:
            print(0)
            return
        if prev == 0 and active > 0:
            components += 1

    print(pow(2, components, MOD))

main()
```

$$O(N)$$ time and memory, no graph ever built.

Checking it against the samples: `(1,3), (2,4), (5,6)` — the first two overlap into one component, the third is its own, coverage peaks at 2, so $$2^2 = 4$$. And `(1,4), (2,5), (3,6)` are all active at `x = 3`, so `0`. I also ran it against a brute-force enumeration of all $$2^N$$ assignments over 3000 random cases with `N ≤ 6`; they agree.

## Answering my own TODO

The thing I wanted to know after solving it was: what if the coordinates were arbitrary, say up to `10^9`? The difference array is dead at that size.

The answer is that almost nothing changes — the imos array was a convenience, not a load-bearing part of the argument. Both insights are about the *order* of the endpoints, not their values. Sort the `2N` endpoints as events and sweep:

```python
def solve(meetings):
    events = []
    for s, t in meetings:
        events.append((s, 1))   # start
        events.append((t, 0))   # end — sorts first at equal coordinate
    events.sort()

    active = components = 0
    for _, kind in events:
        if kind == 1:
            if active == 0:
                components += 1
            active += 1
            if active >= 3:
                return 0
        else:
            active -= 1
    return pow(2, components, MOD)
```

$$O(N \log N)$$, dominated by the sort. The one detail that needs care is ties: at a shared coordinate, ends must be processed before starts, which is what the `0`-before-`1` tiebreak in the sort key does. That's the half-open `[S, T)` convention again, now expressed as a sort order instead of an array index. Get it backwards and back-to-back meetings register as overlapping. I checked this variant against brute force too, over 5000 random cases with duplicate coordinates deliberately allowed.

So there's no deeper technique hiding behind the small-coordinate constraint. `T_i ≤ 2N` just lets you skip the sort — a constant-factor and a log, not an idea.

## Takeaway

I overcomplicated this by reaching for DP first, and then by assuming the graph reframing meant I'd have to actually construct a graph. What made it tractable was neither: it was noticing that in an *interval* graph, "is it bipartite" and "how many components" both collapse into properties of a single coverage function, and that a coverage function over a small integer range is just an array.

The constraints hid the intended solution more than the statement did.
