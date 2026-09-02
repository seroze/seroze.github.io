---
layout: post
title: "[CodeChef] Starters 95 — Break This Array: the cut probability I kept forgetting"
date: 2026-09-02 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, dynamic_programming, probability, expected_value, modular_arithmetic, todo]
author: "Seroze"
published: true
---

Problem: [CodeChef — Break This Array](https://www.codechef.com/problems/ARRAY_BREAK) (Starters 95, difficulty 2722)

This is a very good first problem if you want to learn how 2D DP and probability fit together.
The state is an interval, the transition is a random cut, and the answer is an expected value
printed modulo $$10^9 + 7$$. Nothing exotic — but every step is a place where I got something
slightly wrong, which is exactly what makes it worth writing up.

Fair warning up front: **this post does not contain a solution fast enough for the full
constraints.** I got as far as an $$O(K \cdot N^3)$$ formulation that is correct and clears
subtask 1, and the reduction to $$O(K \cdot N^2)$$ is still open. There's a TODO at the bottom.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

You get an array $$A$$ of size $$N$$ and a string $$S$$ of length $$K$$ over the alphabet
$$\{L, R\}$$. You perform $$K$$ operations. In operation $$i$$:

- if the array has size $$1$$, nothing happens;
- otherwise pick $$X$$ uniformly at random from $$1 \le X < \lvert A \rvert$$, split $$A$$ into
  $$A[1, X]$$ and $$A[X+1, \lvert A \rvert]$$, and keep the left half if $$S_i = L$$, the right
  half if $$S_i = R$$.

Report the expected sum of the surviving array, as $$P \cdot Q^{-1} \bmod (10^9 + 7)$$.

Constraints are small and deliberately suggestive: $$N, K \le 500$$, and both sums bounded by
$$500$$ across all test cases. That shape — a few hundred, with a generous 5.5 s limit — says
"quadratic-ish DP with a layer per operation".

## Why the naive picture fails

My first instinct was to think in terms of final subarrays: enumerate every $$[l, r]$$, work out
the probability it survives, multiply by its sum. That's the right *shape* of the answer,

$$\mathbb{E}[\text{sum}] = \sum_{l \le r} \Pr\big([l, r] \text{ survives}\big) \cdot \sum_{j=l}^{r} A_j$$

but the probability in the middle is not something you can write down in closed form by staring at
it. Different intervals are reachable by wildly different numbers of cut sequences, the cut
distribution changes as the array shrinks (a cut in an array of length $$m$$ has $$m-1$$ options,
not $$N-1$$), and singletons freeze forever. Those probabilities have to be *built up*, one
operation at a time. Which is to say: DP.

## The state is an interval

The array is only ever a contiguous slice of the original, so the state is a pair of endpoints.
Define

$$dp_i[l][r] = \Pr\big(\text{after } i \text{ operations the array is exactly } A[l..r]\big)$$

with $$dp_0[1][N] = 1$$ and everything else zero. This is the whole modelling step, and it's worth
naming why it's legal: the interval carries all the information the future needs. Nothing about
*how* we arrived at $$[l, r]$$ — which cuts, in which order — affects what happens next. The
process is Markov in the interval, so an interval is a sufficient state.

Note also that $$i$$ genuinely has to be part of the state. I glossed over this at first and
thought of the intervals as if they lived on their own, but the operation you're about to apply
depends on $$S_i$$, so layer $$i$$ and layer $$i+1$$ behave differently. Three indices:
step, left, right.

## Getting to $$[l, r]$$

Now the transition. Suppose operation $$i$$ has $$S_i = L$$, so we keep the left half. Which
states can land on $$[l, r]$$?

Keeping a left half never moves the left endpoint. So the parent must have been $$[l, r']$$ for
some $$r' > r$$, and the cut was made exactly after position $$r$$:

```
[l ........ r | r+1 .... r']
```

Symmetrically, when $$S_i = R$$ we keep the right half, the right endpoint is untouched, and the
parent must have been $$[l', r]$$ with $$l' < l$$:

```
[l' .... l-1 | l ........ r]
```

That much I had. What I *didn't* have was the weight. My first version of the recurrence was
essentially

$$dp_i[l][r] \;=\; \sum_{\text{parents}} dp_{i-1}[\text{parent}]$$

which is wrong, and wrong in a way that's easy to miss because it looks like a perfectly ordinary
"sum over predecessors" DP. A parent doesn't hand over all of its probability — it hands over the
share corresponding to *one specific cut*. The correct statement is the law of total probability
with the conditional kept in:

$$\Pr([l, r]) \;=\; \sum_{\text{parents}} \Pr(\text{parent}) \cdot \Pr(\text{that exact cut} \mid \text{parent})$$

A parent $$[l, r']$$ has length $$r' - l + 1$$ and therefore $$r' - l$$ equally likely cut
positions, so the conditional factor is $$\frac{1}{r' - l}$$. The two recurrences are:

$$dp_i[l][r] = \sum_{r' = r+1}^{N} \frac{dp_{i-1}[l][r']}{r' - l} \qquad (S_i = L)$$

$$dp_i[l][r] = \sum_{l' = 1}^{l-1} \frac{dp_{i-1}[l'][r]}{r - l'} \qquad (S_i = R)$$

The lesson generalises past this problem: in a probability DP, every edge carries a factor, and
the denominator of that factor usually depends on the *parent's* size, not the child's. If your
transition looks like a plain sum of predecessors, you've probably dropped it.

## One case that isn't in the recurrence

Length-1 arrays. The statement says the operation is skipped when $$\lvert A \rvert = 1$$, so a
singleton isn't a dead end that loses its probability — it's absorbing. Probability mass that
reaches $$[l, l]$$ stays at $$[l, l]$$ for every remaining operation.

That's not an edge case you can ignore and patch later: forget it and your probabilities stop
summing to $$1$$, silently, and the final answer comes out too small. It also isn't covered by the
formulas above (there's no cut with $$r' - l = 0$$), so it has to be written as its own line in
the code.

## Push, don't pull

The recurrences above are written as *pulls*: for each state, look back at its parents. When I
actually wrote the code I flipped it around and *pushed* instead — for each state at layer
$$i-1$$, hand its probability forward to all the children it can produce:

- $$S_i = L$$: the interval $$[l, r]$$ sends $$\frac{dp[l][r]}{r-l}$$ to each of
  $$[l, l], [l, l+1], \ldots, [l, r-1]$$.
- $$S_i = R$$: it sends the same share to each of
  $$[l+1, r], [l+2, r], \ldots, [r, r]$$.

Mathematically identical, but much harder to get wrong. Pushing, the $$\frac{1}{r-l}$$ is right
there next to the interval it belongs to — you're standing at the parent, so you can't confuse
whose length the denominator comes from. Pulling, you have to reason about "all possible parents
of this state" and remember that the denominator varies *within* the sum. That's where I dropped
the factor in the first place.

## Doing the second sample by hand

Worth grinding through once, because it's the fastest way to be sure you believe the model.
$$N = 5$$, $$A = [1,2,3,4,5]$$, $$S = \texttt{LR}$$.

Operation 1 is $$L$$ on $$[1,5]$$, four cuts, each with probability $$\frac{1}{4}$$, giving
$$[1,1], [1,2], [1,3], [1,4]$$.

Operation 2 is $$R$$, applied to each of those:

- $$[1,1]$$ is a singleton — skipped, sum $$1$$.
- $$[1,2]$$ has one cut, giving $$[2,2]$$, sum $$2$$.
- $$[1,3]$$ has two cuts, giving $$[2,3]$$ (sum $$5$$) or $$[3,3]$$ (sum $$3$$); expected $$4$$.
- $$[1,4]$$ has three cuts, giving sums $$9, 7, 4$$; expected $$\frac{20}{3}$$.

So the answer is

$$\frac{1}{4}\left(1 + 2 + 4 + \frac{20}{3}\right) = \frac{1}{4} \cdot \frac{41}{3} = \frac{41}{12}$$

and since $$12^{-1} \equiv 83333334$$, we get $$41 \cdot 83333334 \bmod (10^9+7) = 416666673$$,
which is the expected output. Notice how the three operative details all show up in this one tiny
case: the singleton that skips, the denominators that shrink, and the fact that everything is done
in the field $$\mathbb{Z}_p$$ rather than with fractions.

## Code

```python
MOD = 10**9 + 7

def solve():
    n, k = map(int, input().split())
    a = list(map(int, input().split()))
    s = input().strip()

    # Precompute modular inverses
    inv = [1] * (n + 1)
    for i in range(2, n + 1):
        inv[i] = pow(i, MOD - 2, MOD)

    # dp[l][r] = probability after current step
    dp = [[0] * n for _ in range(n)]
    dp[0][n - 1] = 1

    for ch in s:
        ndp = [[0] * n for _ in range(n)]

        for l in range(n):
            for r in range(l, n):
                if dp[l][r] == 0:
                    continue

                length = r - l + 1

                # singleton stays forever
                if length == 1:
                    ndp[l][r] = (ndp[l][r] + dp[l][r]) % MOD
                    continue

                if ch == 'L':
                    # keep left part
                    for cut in range(l, r):
                        # resulting interval = [l, cut]
                        ndp[l][cut] += dp[l][r] * inv[length - 1]
                        ndp[l][cut] %= MOD
                else:
                    # keep right part
                    for cut in range(l, r):
                        # resulting interval = [cut+1, r]
                        ndp[cut + 1][r] += dp[l][r] * inv[length - 1]
                        ndp[cut + 1][r] %= MOD

        dp = ndp

    # prefix sums of original array
    pref = [0]
    for x in a:
        pref.append(pref[-1] + x)

    ans = 0
    for l in range(n):
        for r in range(l, n):
            segsum = pref[r + 1] - pref[l]
            ans = (ans + segsum * dp[l][r]) % MOD

    print(ans)


t = int(input())
for _ in range(t):
    solve()
```

Two small things worth noting. The inverses are precomputed once per test case with Fermat's
little theorem — $$i^{-1} \equiv i^{p-2} \pmod p$$ — so the inner loops never call `pow` again;
if you want it faster, the linear recurrence
$$\text{inv}[i] = -\lfloor p/i \rfloor \cdot \text{inv}[p \bmod i]$$ gets all $$n$$ of them in
one pass. And the final sum goes through a prefix-sum array, because $$A_i$$ can be $$10^9$$ and a
segment sum can overflow past the modulus if you're careless in a language without big integers.

## Checking it

The sample passes. Beyond that I ran the DP against an exact-fraction brute force — one that keeps
the whole probability tree in Python `Fraction`s and only reduces mod $$p$$ at the very end — over
every string $$S$$ with $$1 \le K \le 4$$, every $$1 \le N \le 6$$, and three random arrays each:
540 cases, zero mismatches.

That comparison is worth setting up even when the DP looks obviously right, because the specific
bug I was at risk of — a missing or wrong $$\frac{1}{r-l}$$ — produces answers that are the right
*order of magnitude* nonsense in modular arithmetic, i.e. a uniformly random-looking number that
you cannot eyeball. Exact fractions on tiny inputs are the only cheap oracle.

## Where this falls over

Count the work per layer. There are $$O(N^2)$$ intervals, and each one pushes to
$$O(\text{its length})$$ children, so a layer costs

$$\sum_{L=1}^{N} (N - L + 1) \cdot L = O(N^3)$$

and with $$K$$ layers the total is $$O(K \cdot N^3)$$. At $$N = K = 500$$ that's on the order of
$$10^{10}$$ operations. Hopeless in Python, and not obviously comfortable in C++ either.

Measured, in Python, on my laptop:

| $$N = K$$ | time |
|---|---|
| 50 | 0.01 s |
| 100 | 0.16 s |
| 150 | 0.68 s |

which is clean fourth-power growth in $$N$$ (both loops scale together) and extrapolates to
roughly a minute and a half at $$N = K = 500$$. So this is a subtask-1 solution and a reference
implementation, not a submission.

## TODO: get to $$O(K \cdot N^2)$$

This is the actual content of the problem and I haven't done it yet.

The wasteful step is that each state spends $$O(N)$$ time updating its children one at a time,
when what it's really doing is adding the same constant to a contiguous run of cells —
$$ndp[l][l \ldots r-1]$$ for an $$L$$ step, $$ndp[l+1 \ldots r][r]$$ for an $$R$$ step. That's a
range update, and range updates over a fixed row want a difference array or a running suffix sum,
which would make each state $$O(1)$$ and each layer $$O(N^2)$$.

The direction I want to try, stated in pull form for $$S_i = L$$:

$$dp_i[l][r] = \sum_{r' > r} \frac{dp_{i-1}[l][r']}{r' - l}$$

Here $$l$$ is fixed along the whole sum, so for each fixed $$l$$ the quantity
$$\frac{dp_{i-1}[l][r']}{r' - l}$$ can be accumulated as a suffix sum while sweeping $$r$$
downward, and every entry of the row comes out in one pass. The $$R$$ case is the mirror image
with $$r$$ fixed and a prefix sum over $$l'$$. That would be $$O(N^2)$$ per layer,
$$O(K \cdot N^2) \approx 1.25 \times 10^8$$ overall, which is what the 5.5 s limit is sized for.

I haven't implemented or verified any of that — the two things I'd expect to bite are the
singleton absorption (it has to survive the rewrite, and it's no longer a natural special case
when you're sweeping rows) and whether the sweep direction is right for each of $$L$$ and $$R$$.
Next session. I'll edit this section when it's actually working.

## What I want to keep from this

**Every edge in a probability DP carries a factor.** The transition is
$$\Pr(\text{parent}) \times \Pr(\text{transition} \mid \text{parent})$$, and when I write a
"sum over predecessors" without a weight I have almost certainly forgotten the second half.

**The denominator belongs to the parent.** The number of cuts is $$\lvert \text{parent} \rvert - 1$$,
not anything about the child. Pushing forward instead of pulling backward makes that impossible to
mix up, which is a good reason to prefer push formulations while you're still unsure of a
recurrence.

**Absorbing states need an explicit line.** "If the size is 1, do nothing" reads like a throwaway
sentence in the statement and is actually a self-loop with probability $$1$$. Probability that
isn't forwarded is probability that's lost.

**Correct first, then attack the constant.** The $$O(K \cdot N^3)$$ version is too slow, but it
gave me an oracle to test the fast version against — and it made the redundancy visible, because
you can *see* the inner loop writing the same value into consecutive cells. Optimising a DP you
haven't yet written correctly is how you end up with something that's both wrong and fast.
