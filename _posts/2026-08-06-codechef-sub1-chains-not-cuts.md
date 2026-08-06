---
layout: post
title: "[CodeChef] Starters 250 — Subsequence 1: Chains, not cuts"
date: 2026-08-06 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, dynamic_programming, greedy, codechef]
author: "Seroze"
published: true
---

[SUB1 (Subsequence 1)](https://www.codechef.com/problems/SUB1) gives you an array $$A$$ and lets
$$f(A)$$ be the largest $$L$$ such that $$1, 2, \dots, L$$ appears in $$A$$ as a subsequence. You may cut
$$A$$ into any number of contiguous pieces $$A_1 + A_2 + \dots + A_K$$ and you want to maximise
$$\sum_i f(A_i)$$. You choose $$K$$ too.

Rating ~1749. The interesting part is not the final code — it's twelve lines — but how the problem
stops looking like a partitioning problem.

## The trap: thinking about cut points

My first framing was the obvious one. Let $$dp[i]$$ be the answer for the prefix ending at $$i$$, and
transition by choosing where the last piece begins:

$$dp[i] = \max_{j < i}\ \big(dp[j] + f(A[j{+}1 \ldots i])\big)$$

That's $$O(N^2)$$ transitions, and each $$f$$ of a segment needs its own structure to evaluate — a BIT
where I add each value and look for the largest prefix that's fully covered, so $$O(N^2 \log N)$$
overall. Correct, and hopeless against $$N \le 2\cdot10^5$$.

The instinct at this point is to speed up "evaluate $$f$$ on a segment." That's the trap. The right
move is to notice that the cut points don't matter at all.

## The reframing: you're selecting elements, not choosing cuts

Look at what the answer is actually made of. In the sample `[2, 1, 1, 2, 1, 3, 4]` the answer is 5,
realised by the split `[2,1] + [1,2,1,3,4]`. But what *contributes* is only the elements
`1` and `1,2,3,4` — a subsequence of $$A$$ made of consecutive runs $$1,2,\dots,L_1$$ then
$$1,2,\dots,L_2$$, and so on.

Claim: the answer equals the maximum of $$\sum_j L_j$$ over all ways to pick disjoint, index-ordered
chains $$1,2,\dots,L_j$$ as a subsequence of $$A$$.

Both directions are one line each:

- **Any selection is achievable.** Given chains $$C_1, \dots, C_k$$ in index order, cut $$A$$
  immediately after the last element of each chain. Piece $$j$$ then contains $$C_j$$ entirely, so
  $$f(A_j) \ge |C_j|$$.
- **Any split gives a selection.** Whatever $$f(A_j)$$ is, it's witnessed by an actual chain inside
  $$A_j$$, and those chains are disjoint and ordered.

So the cut points were never a real degree of freedom. They're free to place after the fact. What's
left is a pure left-to-right selection problem, which is a much friendlier shape.

## Two observations that kill the search space

**$$f$$ grows by at most 1 per element.** Appending one element to an array either extends the chain
by exactly one or leaves it alone. This is what makes the last piece cheap to reason about: if the
last element $$a_i$$ is used at all, it closes a chain whose top value is exactly $$a_i$$. Not more,
not less.

**Among all chains closing at $$i$$ with value $$v = a_i$$, take the shortest one.** All of them pay
you the same $$v$$. A shorter chain starts later, which leaves a longer prefix to the left, and $$dp$$
is non-decreasing — so the latest-starting chain dominates every other. No tie-breaking, no
comparison needed. This is a clean exchange argument, and it's the entire reason a greedy array
replaces the BIT.

Together: at index $$i$$ there is exactly **one** candidate transition worth trying.

## The DP

Let `largest_chain_start[v]` be the largest index at which a chain $$1,2,\dots,v$$ can begin, among
chains fully contained in the prefix seen so far. Then:

$$dp[i] = \max\big(dp[i-1],\; a_i + dp[\texttt{largest\_chain\_start}[a_i] - 1]\big)$$

and when $$v = a_i$$ occurs, the latest chain reaching $$v-1$$ gets extended:
`largest_chain_start[v] = largest_chain_start[v-1]`.

Two invariants make this safe:

- `largest_chain_start[v]` is only touched when $$v$$ actually occurs, because any chain topping out
  at $$v$$ must physically end on an occurrence of $$v$$.
- `largest_chain_start[v] <= largest_chain_start[v-1]` always holds, and `largest_chain_start[v-1]`
  is non-decreasing over time, so the assignment never moves an index backwards. A plain array
  suffices; nothing ever needs undoing.

The case $$v = 1$$ *is* genuinely special: a fresh chain extends nothing, so it can begin at any
position. Whenever $$a_i = 1$$, taking it as a one-element chain is always an option
($$dp[i] \ge 1 + dp[i-1]$$), and the latest place a chain $$1$$ can begin is $$i$$ itself, so
`largest_chain_start[1]` moves up to $$i$$.

```python
def solve():
    n = int(input())
    a = list(map(int, input().split()))

    dp = [0]*(n+1)
    largest_chain_start = [0]*(n+1)

    for i in range(1, n+1):
        dp[i] = dp[i-1]

        cur = a[i-1]
        # find the chain which has largest starting point and ends with cur-1
        if largest_chain_start[cur-1] > 0:
            prev_idx = largest_chain_start[cur-1] - 1
            dp[i] = max(dp[i], cur + dp[prev_idx])

            # now update chain for cur
            largest_chain_start[cur] = largest_chain_start[cur-1]

        else:
            # now we cannot extend any previous chain unless cur == 1
            if cur == 1:
                dp[i] = max(dp[i], 1+dp[i-1])

        # what if it's 1 ? then we are at start of a fresh chain
        if cur == 1:
            largest_chain_start[cur] = i


    # print(dp, ' dp')
    print(dp[n])


tc = int(input())
for _ in range(tc):
    solve()
```

$$O(N)$$ time, $$O(N)$$ memory. From $$O(N^2 \log N)$$, and the BIT disappeared entirely.

## What I'd take away

The speedup didn't come from a better data structure. It came from noticing that the quantity I was
struggling to compute — $$f$$ of an arbitrary segment — was never something I needed. Once the
"maximum over splits" was re-read as "maximum over selections of chains," the segment queries
evaporated, and the two greedy facts ($$f$$ increases by at most 1; shortest closing chain dominates)
reduced $$N$$ candidate transitions per index to one.

Worth keeping as a general prompt: when a DP transition needs an expensive query, check whether the
thing being queried is actually forced. Sometimes the structure you're paying a log factor to
maintain is a structure the optimal solution never uses.
