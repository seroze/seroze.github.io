---
layout: post
title: "[CodeChef] Starters 89 — Two Averages: fix the total, then split it"
date: 2026-09-12 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, binary_search, math, greedy, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Two Averages](https://www.codechef.com/problems/TWOAVG) (Starters 89,
difficulty 2353). Official editorial:
[TWOAVG editorial](https://discuss.codechef.com/t/twoavg-editorial/106092) — the link off the
problem page 404s, but the discuss thread is alive.

You get two arrays, $$A$$ of size $$N$$ and $$B$$ of size $$M$$, with every element in
$$[1, K]$$. One operation picks any $$X \in [1, K]$$ and appends it to either array. Find the
minimum number of operations to make $$\operatorname{mean}(A) > \operatorname{mean}(B)$$ strictly,
or report $$-1$$.

This one was a genuinely new pattern for me, and I want to write down exactly where I got stuck,
because the place I got stuck is the interesting part. I found the two useful operations in about a
minute, then sat there for a long time because I had two counters with no upper bound on either and
no idea how to search over them.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Only two of the four moves are ever worth making

There are four things you could conceivably do: append something big or small to $$A$$, or
something big or small to $$B$$. It collapses fast.

Appending the value $$v$$ to $$A$$ gives it mean $$(S_A + v)/(N+1)$$, which is increasing in $$v$$.
So if you have already decided to spend an operation on $$A$$, you spend it on $$v = K$$ — no other
choice can do better, and this one never hurts, since every element is at most $$K$$ so the mean is
at most $$K$$ and appending $$K$$ cannot pull it down. Symmetrically, an operation spent on $$B$$
should be $$v = 1$$, which never raises $$B$$'s mean because every element is at least 1.

That is a dominance argument, not a heuristic, so it is safe to throw away everything else. Two
counters survive:

- $$x$$ = how many copies of $$K$$ we append to $$A$$
- $$y$$ = how many copies of $$1$$ we append to $$B$$

and the goal is to minimise $$x + y$$ subject to

$$\frac{S_A + xK}{N + x} > \frac{S_B + y}{M + y},$$

where $$S_A = \sum A$$ and $$S_B = \sum B$$.

The $$K = 1$$ case is the only impossible one. Then every element of both arrays is 1 and both means
are permanently 1. For $$K \ge 2$$ a solution always exists, because pumping $$K$$ into $$A$$ drives
its mean towards $$K$$ while pumping 1 into $$B$$ drives its mean towards 1.

## Why "pick the better pure strategy" is wrong

My first instinct after the reduction was that since both operations push in the right direction and
neither interferes with the other, the answer should be the cheaper of the two pure strategies:
either only feed $$A$$, or only feed $$B$$. That is wrong, and the smallest counterexample is tiny:

$$A = [1], \qquad B = [2], \qquad K = 2.$$

Feeding only $$A$$, the mean is $$(1 + 2x)/(1 + x)$$, which climbs towards 2 but never reaches it,
while $$B$$ sits at exactly 2. Feeding only $$B$$, the mean is $$(2 + y)/(1 + y)$$, which falls
towards 1 but never reaches it, while $$A$$ sits at exactly 1. Both pure strategies fail *forever*.
Mixed, it takes three operations: one $$K$$ into $$A$$ puts it at 1.5, and two 1s into $$B$$ put it
at $$4/3$$.

So the two limits matter. Each pure strategy is asymptotically bounded by the other array's current
mean, and the only way past that wall is to move both walls at once. Mixing is not a marginal
improvement here — it is the difference between finite and infinite.

## The unlock: stop minimising $$x + y$$, start fixing it

This is the step I did not find on my own, and it is the whole trick.

Minimising $$x + y$$ over two unbounded variables is awkward. But asking

> can I succeed in exactly $$t$$ operations?

is a completely different question, because once $$t$$ is fixed, $$y = t - x$$ and there is only one
free variable left. Two unbounded dimensions become one bounded dimension: $$x$$ ranges over
$$[0, t]$$ and nothing else.

Substituting $$y = t - x$$ and cross-multiplying (both denominators are positive, so this is safe),
success at total $$t$$ means there exists an integer $$x \in [0, t]$$ with $$F(x) > 0$$, where

$$F(x) = (S_A + xK)(M + t - x) - (S_B + t - x)(N + x).$$

Now expand and look only at the $$x^2$$ term. The first product contributes $$-Kx^2$$ and the
second contributes $$+x^2$$, so

$$F(x) = (1-K)x^2 + bx + c, \qquad b = KM + Kt + N - S_A - S_B - t.$$

Since $$K \ge 2$$, the leading coefficient $$1-K$$ is negative: for a fixed budget $$t$$, the
achieved margin is a **strictly concave quadratic** in how you split that budget. That is the
structure that makes the problem finite.

## The vertex tells you where to look

Concavity means we do not have to scan $$x$$ at all. A downward parabola has one maximum, at

$$x^{*} = \frac{-b}{2(1-K)} = \frac{b}{2(K-1)},$$

and $$F$$ is increasing to the left of it and decreasing to the right. Over the integers the best
value is therefore at one of the two integers bracketing $$x^{*}$$ — $$\lfloor x^{*} \rfloor$$ or
$$\lceil x^{*} \rceil$$ — and if $$x^{*}$$ happens to be an integer, at $$x^{*}$$ itself.

The one wrinkle is the constraint $$0 \le x \le t$$. If the vertex falls outside that window, the
maximum over the window sits at whichever endpoint is nearer, because on a concave function
restricted to an interval the maximum is either at the interior peak or at a boundary. So the
candidate list is:

- $$\lfloor x^{*} \rfloor$$ and $$\lfloor x^{*} \rfloor + 1$$, the two integers around the vertex
- $$x = 0$$ and $$x = t$$, in case the vertex is out of range

Computing $$q = \lfloor b / (2(K-1)) \rfloor$$ with integer floor division gives $$\lfloor x^{*}
\rfloor$$ directly, and checking $$q$$ together with $$q+1$$ covers the rounding. Throwing in
$$q-1$$ costs nothing and makes you immune to sign-of-numerator worries if you are not sure your
language floors rather than truncates — Python's `//` floors, so I did not need it.

I checked this rather than trusting it. Over 40,000 random parameter sets, for every $$t$$ from 0 to
$$N+M+2$$, the four-candidate check agreed with a brute-force scan of all $$t+1$$ values of $$x$$
every single time. An integer ternary search over $$x$$ also agrees, if you would rather not do the
algebra — but with a closed form for the vertex available, the ternary search is just a slower way
to reach the same place.

The general shape of this is worth keeping: **when fixing a parameter turns your objective into a
concave or convex quadratic, the vertex replaces the scan.** You look at two integers instead of a
range.

## Feasibility is monotone, so binary search $$t$$

We can now answer "is $$t$$ enough?" in constant time. To get the minimum $$t$$ cheaply we need the
answer to be monotone, and it is: if $$t$$ operations suffice, so do $$t+1$$. Take the successful
configuration and append one more $$K$$ to $$A$$. Since $$\operatorname{mean}(A) \le K$$ always,
this cannot decrease $$A$$'s mean, so the strict inequality survives.

That gives the familiar `NO NO NO YES YES YES` shape, and binary search finds the boundary. (I
verified the monotonicity empirically too, over 5,000 random parameter sets with a full scan at
every $$t$$ — no inversions.)

## An upper bound you can actually prove

Binary search needs a right endpoint. Claim: $$t = N + M + 1$$ always works when $$K \ge 2$$, with
the explicit split $$x = M+1$$, $$y = N$$.

The reason is a nice near-miss. Try $$x = M$$, $$y = N$$ first, using the worst possible arrays —
$$A$$ all 1s so $$S_A = N$$, and $$B$$ all $$K$$s so $$S_B = KM$$. The cross-multiplied comparison
becomes

$$(N + MK)(M + N) \quad \text{versus} \quad (KM + N)(N + M),$$

which are *identical*. Exactly a tie, so that split never suffices, no matter what $$K$$ is. Bump
$$x$$ by one to $$M+1$$ and the difference is

$$(N + (M+1)K)(M+N) - (KM+N)(N+M+1) = K(M+N) - (KM+N) = N(K-1) > 0.$$

And since the left side only grows as $$S_A$$ grows and the right side only grows as $$S_B$$ grows,
proving it for the worst-case sums proves it for all of them. So $$\text{hi} = N + M + 1$$ is a
valid bound. The editorial uses $$x = M+1, y = N+1$$ and gets $$N+M+2$$, which is also fine — the
extra operation just costs one more binary-search step.

Worth knowing that this bound is not loose padding. With $$N = M = 10^5$$, $$A$$ all 1s, $$B$$ all
$$K$$s, the answer is exactly $$200001 = N + M + 1$$. In the large-$$K$$ limit the success
condition at budget $$t$$ degenerates to $$xy > NM$$, whose best split is $$x = y = t/2$$, so the
answer approaches $$2\sqrt{NM} + 1$$ — which is at most $$N + M + 1$$ by AM–GM, with equality
exactly when $$N = M$$. My table of worst-case shapes matched $$\lceil 2\sqrt{NM} \rceil + 1$$ on
the nose: 895 for $$N = 200, M = 1000$$, 2001 for $$N = M = 1000$$.

## The code

```python
import sys


def main():
    data = sys.stdin.buffer.read().split()
    p = 0
    T = int(data[p]); p += 1
    out = []

    for _ in range(T):
        N = int(data[p]); M = int(data[p + 1]); K = int(data[p + 2]); p += 3
        SA = sum(map(int, data[p:p + N])); p += N
        SB = sum(map(int, data[p:p + M])); p += M

        if SA * M > SB * N:          # already done, no operations needed
            out.append("0")
            continue
        if K == 1:                   # both means are pinned to 1 forever
            out.append("-1")
            continue

        den = 2 * (K - 1)

        def feasible(t):
            # F(x) = (SA + xK)(M + t - x) - (SB + t - x)(N + x)
            # concave in x, vertex at b / (2(K-1))
            b = K * M + K * t + N - SA - SB - t
            q = b // den
            for x in (0, t, q, q + 1):
                if 0 <= x <= t:
                    y = t - x
                    if (SA + x * K) * (M + y) > (SB + y) * (N + x):
                        return True
            return False

        lo, hi = 1, N + M + 1
        while lo < hi:
            mid = (lo + hi) // 2
            if feasible(mid):
                hi = mid
            else:
                lo = mid + 1
        out.append(str(lo))

    sys.stdout.write("\n".join(out) + "\n")


main()
```

Everything is integer arithmetic — the cross-multiplied comparison never touches a float, which
matters when $$K$$ is up to $$10^6$$ and the products reach around $$10^{17}$$. In C++ that is
`long long` territory; in Python you get it for free.

Cost is $$O(N + M)$$ to read and sum, plus $$O(\log(N+M))$$ constant-time feasibility checks. On the
heaviest inputs I could construct — $$T = 10^4$$ with $$\sum N = \sum M = 10^5$$, and separately one
test case with $$N = M = 10^5$$ — it runs in under 0.1 s against a 1.5 s limit, essentially all of
which is parsing.

## The editorial goes a simpler way

Having worked all that out, I read the editorial and found it does something noticeably less
clever, which was humbling in a useful way. It fixes $$x$$ instead of fixing $$t$$.

If you fix $$x$$, then $$A$$'s mean is a known constant and the condition on $$y$$ is a plain linear
inequality. Writing $$S_A' = S_A + xK$$ and $$N' = N + x$$, the requirement
$$S_A'(M+y) > N'(S_B + y)$$ rearranges to

$$y\,(S_A' - N') > N'S_B - S_A'M,$$

so with $$D = S_A' - N'$$ and $$R = N'S_B - S_A'M$$ the smallest valid $$y$$ is $$\lfloor R/D
\rfloor + 1$$ when $$R \ge 0$$, zero when $$R < 0$$, and nonexistent when $$D = 0$$ and $$R \ge 0$$.
Constant time per $$x$$. And the same bound argument says $$x$$ never needs to exceed $$N+M+2$$, so
you just scan every $$x$$ in that range and take the best $$x + y$$:

```python
best = N + M + 1
for x in range(0, N + M + 2):
    SA2, N2 = SA + x * K, N + x
    D = SA2 - N2
    R = N2 * SB - SA2 * M
    if R < 0:
        y = 0
    elif D == 0:
        continue
    else:
        y = R // D + 1
    best = min(best, x + y)
```

No concavity, no monotonicity, no binary search — one loop of length $$N+M+2$$, which is fine
because $$\sum N$$ and $$\sum M$$ are bounded. I cross-checked the two solutions on 4,607 inputs,
including an exhaustive sweep over every array with $$N, M \le 3$$ and $$K \le 4$$ compared against
a brute force that tries *every* multiset of appended values rather than assuming the
$$K$$-and-1 dominance. They agree everywhere, which is also the check that the dominance argument
was right in the first place.

The honest comparison: the editorial's version is simpler to derive and simpler to get right, and
the concavity version is asymptotically better per test case ($$O(\log)$$ versus $$O(N+M)$$ after
reading the input) in a way this problem's constraints do not reward. If I saw this again in a
contest I would write the editorial's one.

## What I actually take away

The lesson is not about averages. It is that I had the right reduction and then stalled on
"two unbounded counters, no bound on either", and both solutions escape by the same move: **bound
one of the two variables, then the other one falls out.**

The editorial bounds $$x$$ directly, by proving a crude split always works, and then solves for
$$y$$ in closed form. The route I was walked through bounds their *sum* instead, which is a
stronger constraint and buys more structure — with $$t$$ fixed, $$y = t-x$$ and the margin becomes a
concave quadratic in $$x$$, so the vertex answers the whole question in constant time and
monotonicity in $$t$$ lets you binary search.

So when a problem leaves me staring at an unbounded search space, the question to ask is not "how do
I search this?" but "what can I fix so that the rest is forced?" Fixing the answer, fixing a sum,
fixing one of two coupled counters — they are all the same move, and the payoff each time is that
the search collapses from a space into a line, and often from a line into a point.
