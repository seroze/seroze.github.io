---
layout: post
title: "[CodeChef] Starters 252 — Tree Counting: a parity invariant, Scoins' formula, and a DP state I got wrong"
date: 2026-08-19 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, dynamic_programming, trees, counting, invariants]
author: "Seroze"
published: true
---

Problem: [CodeChef — Tree Counting](https://www.codechef.com/START252B/problems/TREECNT7) (Starters 252, Div 2)

Paraphrasing the setup: you're given $$N$$ vertex values $$A_1, \dots, A_N$$ with $$\sum A_i = N$$.
A labelled tree on those $$N$$ vertices is *good* if, using moves that shift one unit of value
between two vertices at distance exactly $$2$$, you can turn the array into all ones. Count the
good labelled trees, modulo $$998244353$$. $$N \le 400$$.

So the tree is the unknown. The values are fixed and we're counting which of the $$N^{N-2}$$
labelled trees happen to be solvable.

This one took me a while, and I got two things wrong on the way — a DP state that was missing a
dimension, and a factor of two at the very end. Both were more interesting than the problem itself,
so I'm writing down the whole path.

## Step 1: what does a move preserve?

Whenever a problem hands you an operation and asks "can I reach the target", the first question is
what the operation *can't* change.

Root the tree anywhere and give every vertex a depth. If $$u$$ and $$v$$ are at distance $$2$$,
there are only two possibilities: they share a parent, or one is the other's grandparent. In the
first case their depths are equal; in the second they differ by $$2$$. Either way,

$$\text{depth}(u) \equiv \text{depth}(v) \pmod 2.$$

A move takes one unit from $$u$$ and gives it to $$v$$, and those two vertices always sit on the
same side of the depth parity. So if $$E$$ is the set of even-depth vertices and $$O$$ the
odd-depth ones, then

$$\sum_{v \in E} A_v \quad\text{and}\quad \sum_{v \in O} A_v$$

never change. To reach all ones we need those two sums to be $$\lvert E \rvert$$ and
$$\lvert O \rvert$$ respectively. That's necessary, and since $$\sum A_i = N$$ and
$$\lvert E \rvert + \lvert O \rvert = N$$, the two conditions are really one condition — get
one side right and the other follows.

Note that $$E$$ and $$O$$ are exactly the two sides of the tree's bipartition, which doesn't depend
on which vertex you rooted at. So the condition is a statement about the tree itself.

### Why the condition is also sufficient

It would be easy to stop at "necessary" and hope. It isn't hard to close the gap.

Fix one parity class, say $$E$$, and build a new graph $$H$$ whose vertices are the vertices of
$$E$$, with an edge between two of them whenever they are at distance $$2$$ in the tree.

$$H$$ is connected. Take any two vertices of $$E$$ and look at the unique tree path between them.
Its length is even and the depths alternate in parity, so the path looks like

```
even — odd — even — odd — even
```

and every two consecutive even-depth vertices along it are at distance $$2$$ — i.e. adjacent in
$$H$$. That gives a walk in $$H$$ between any two of its vertices.

Now a move is precisely "push one unit along an edge of $$H$$". To move a unit from $$u$$ to $$w$$,
walk the path $$u = x_0, x_1, \dots, x_m = w$$ and push a unit one edge at a time, starting at
$$x_0$$. Nothing ever goes negative: $$x_0$$ had a unit to spare, and each later $$x_i$$ receives
one before it has to give one away. So on a connected graph, any distribution can be rearranged into
any other with the same total. Repeat: find a vertex above its target and one below, route a unit,
shrink the total error by one.

The same argument runs independently on $$O$$. So:

> A tree is good exactly when one side of its bipartition has value-sum equal to its size.

The problem is now pure counting, and the tree has disappeared into a single combinatorial
constraint on its bipartition.

## Step 2: counting valid subsets — the DP I got wrong

We need, for each $$k$$, the number of subsets $$S$$ of the vertices with

$$\lvert S \rvert = k \quad\text{and}\quad \sum_{v \in S} A_v = k.$$

My first attempt was a two-dimensional DP:

```
dp[i][j] = number of subsets of the first i elements
           of size j whose sum is also j
```

with transition `dp[i][j] = dp[i-1][j] + dp[i-1][j - A[i]]`.

This is wrong, and it's worth being precise about *why*, because "off by a dimension" undersells it.
The state tries to make one number $$j$$ mean two different things at once. Suppose I'm processing
a value $$3$$ and I'm sitting in state `dp[i][5]`. Taking that element raises the size by one and
the sum by three. Which one does the $$5$$ track? If it's the size, the new size is $$6$$ and the
new sum is unknown. If it's the sum, the new sum is $$8$$ and the size is unknown. The recurrence
`dp[i-1][j - A[i]]` is silently subtracting a *sum* from a *size*.

The tell is that I couldn't write the transition down without the question marks. The state had
thrown away information the next step needs.

The fix is the obvious one — track both:

$$dp[k][s] = \text{number of ways to pick } k \text{ elements with value-sum } s,$$

with $$dp[0][0] = 1$$ and the usual take-or-don't transition. Then $$cnt[k] = dp[k][k]$$.

The third dimension is cheap here, and it's cheap for a specific reason: because
$$\sum A_i = N$$, the only sums that ever matter are $$0 \dots N$$. So the sum axis is $$401$$
wide, not $$N^2$$ wide, and the whole DP is $$O(N^3)$$ — about $$6.4 \times 10^7$$ transitions at
$$N = 400$$, which is fine.

Iterating both axes downward lets you drop the "first $$i$$ elements" dimension entirely:

```python
dp = [[0] * (n + 1) for _ in range(n + 1)]
dp[0][0] = 1
for x in A:
    for k in range(n - 1, -1, -1):
        for s in range(n - x, -1, -1):
            dp[k + 1][s + x] = (dp[k + 1][s + x] + dp[k][s]) % MOD
```

## Step 3: how many trees have a given bipartition?

Now fix the two sides: one of size $$a$$, the other of size $$b = N - a$$. How many labelled trees
have *exactly* that bipartition?

$$a^{\,b-1} \, b^{\,a-1}$$

This is Scoins' formula, the bipartite analogue of Cayley's $$n^{n-2}$$. A quick sanity check at
$$N = 4$$: the splits of size $$2+2$$ give $$2^1 \cdot 2^1 = 4$$ trees each and there are $$3$$ such
splits, and the splits of size $$1+3$$ give $$1^2 \cdot 3^0 = 1$$ tree each with $$4$$ such splits.
That's $$12 + 4 = 16 = 4^2$$, every labelled tree on $$4$$ vertices, exactly once.

The Prüfer sequence explains where the exponents come from. A labelled tree on $$a+b$$ vertices maps
to a sequence of length $$a + b - 2$$ in which each vertex appears $$\deg(v) - 1$$ times. In a
bipartite tree every edge crosses the split, so the left degrees sum to the number of edges,
$$a + b - 1$$, and therefore

$$\sum_{u \in L} (\deg(u) - 1) = (a + b - 1) - a = b - 1.$$

So left-side labels take up exactly $$b-1$$ positions of the Prüfer sequence and right-side labels
the other $$a-1$$. Filling those positions freely gives the $$a^{b-1}$$ and $$b^{a-1}$$ factors.

I want to be honest about the gap here: that's where the exponents come from, but it isn't a proof.
Counting "choose the positions, fill them, divide by the binomial" needs an argument for why the
division is legitimate, and that division step is exactly the hard part. The clean proofs go through
a bipartite-specific Prüfer-style bijection or the Matrix–Tree theorem. Scoins proved it in 1962;
Moon's *Counting Labelled Trees* has the standard treatment. The formula is right — the two-line
derivation above is intuition, not justification.

## Step 4: the factor of two

Putting it together, my first submission looped over $$a$$ from $$1$$ to $$N-1$$, multiplied
$$dp[a][a]$$ by $$a^{\,N-a-1}(N-a)^{\,a-1}$$, and summed. On the sample with
$$A = [1,1,1,1]$$ it printed $$32$$ where the answer is $$16$$.

Where did the extra factor come from? Each subset of size $$2$$ contributed $$4$$ trees and there
are $$6$$ of them, which is $$24$$ — but the sum also picked up the four singletons ($$1$$ tree
each, the stars) and the four size-$$3$$ subsets ($$1$$ each, the same four stars again), so
$$4 + 24 + 4 = 32$$.

That last observation is the whole bug. A tree's bipartition is an *unordered* pair
$$\{S, V \setminus S\}$$, and since $$\sum A_i = N$$, if $$S$$ satisfies the size-equals-sum
condition then so does its complement. The DP counts both, so every good tree is counted exactly
twice.

I briefly convinced myself the $$a = b$$ case needed special handling — that a balanced split might
somehow be its own mirror image. It doesn't: no subset equals its own complement, so there's no
fixed point of the swap, and the double-counting is uniform across every $$a$$. One global
multiplication by $$\mathrm{inv}(2)$$ and it's done. The samples come out $$16, 1, 0$$.

## The solution

```python
import sys

MOD = 998244353

def solve(n, A):
    if n == 1:
        return 1 if A[0] == 1 else 0

    # dp[k][s] = ways to choose k vertices with value-sum s
    dp = [[0] * (n + 1) for _ in range(n + 1)]
    dp[0][0] = 1
    for x in A:
        for k in range(n - 1, -1, -1):
            row = dp[k]
            nxt = dp[k + 1]
            for s in range(n - x, -1, -1):
                if row[s]:
                    nxt[s + x] = (nxt[s + x] + row[s]) % MOD

    ans = 0
    for a in range(1, n):
        b = n - a
        cnt = dp[a][a]          # subsets of size a whose values sum to a
        if cnt:
            trees = pow(a, b - 1, MOD) * pow(b, a - 1, MOD) % MOD
            ans = (ans + cnt * trees) % MOD

    return ans * ((MOD + 1) // 2) % MOD   # each tree counted from both sides


def main():
    data = sys.stdin.buffer.read().split()
    p = 0
    t = int(data[p]); p += 1
    out = []
    for _ in range(t):
        n = int(data[p]); p += 1
        A = [int(v) for v in data[p:p + n]]; p += n
        out.append(solve(n, A))
    sys.stdout.write("\n".join(map(str, out)) + "\n")

main()
```

The `n == 1` guard is there because the loop over $$a$$ starts at $$1$$ and stops at $$n-1$$, which
is empty for a single vertex. A one-vertex tree has only one side to its bipartition, so it falls
outside the formula; it's good iff $$A_1 = 1$$. I couldn't tell from the constraints whether
$$N = 1$$ can occur, so I guarded it rather than find out the hard way.

## Checking it

The two ideas in this solution — "good iff the bipartition splits the sum correctly" and Scoins'
formula — are both the kind of claim that feels true and can quietly be false. So I brute-forced it.

For every $$n$$ from $$2$$ to $$6$$ and every value array summing to $$n$$ ($$636$$ arrays in
total), I generated all $$n^{n-2}$$ labelled trees from their Prüfer sequences, and for each tree
ran a BFS over the reachable value-distributions using the actual distance-$$2$$ moves, checking
whether all-ones is reachable. Counting the good trees that way agreed with the formula on every
single case. Both the characterisation and the counting survive.

On timing: I expected the $$O(N^3)$$ DP to be hopeless in Python, but the `if row[s]` guard saves
it, because the reachable $$(k, s)$$ states are sparse — sums are capped at $$N$$, so most of the
table is zero. A single $$N = 400$$ case runs in roughly $$0.6$$–$$2$$ seconds depending on the
shape of the input, worst for values like $$1, 2, 3, \ldots$$ that make the table dense. If that's
too close for comfort, the fix is to skip the zero-valued vertices during the DP entirely and fold
them back in at the end with binomials — choosing $$j$$ zeros adds $$j$$ to the size and nothing to
the sum, so

$$cnt[a] = \sum_k g[k][a] \binom{z}{a-k}$$

where $$z$$ is the number of zeros and $$g$$ is the same DP run over the nonzero values only. That
drops the same cases to $$0.006$$–$$0.2$$ seconds.

## What I'm actually taking away

The DP mistake bothered me more than the factor of two, because it felt stupid in a way I want to
stop repeating. But looking at it again, the mistake wasn't "I forgot a dimension" — it was that I
picked a state before writing a transition.

The test I'm going to use from now on is this: **if you hand me a state and nothing else, can I
compute every transition out of it?** If the answer needs information that isn't in the state, the
state is wrong. That's it. Write the recurrence *first*, and let it tell you what the state needs to
contain, rather than designing a state and then trying to make a recurrence fit.

Concretely, when a decision changes several quantities at once, ask whether any of them can be
derived from the others. In knapsack, value is the objective so only weight goes in the state. In
LIS, the length is the DP layer so it disappears. Here, size and sum move independently — one is
$$+1$$ per element and the other is $$+A_i$$ — and neither determines the other, so both have to be
stored. The condition size $$=$$ sum is a property of the *answer*, not something the state can
assume along the way, and collapsing them was assuming the answer while computing it.

I caught it within a minute of trying to write the transition down. That's the part that actually
generalises: you don't stop making these mistakes, you just start writing the recurrence early
enough that the mistake announces itself.
