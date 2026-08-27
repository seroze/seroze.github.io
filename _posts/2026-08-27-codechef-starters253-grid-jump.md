---
layout: post
title: "[CodeChef] Starters 253 — Grid Jump: I assumed the answer sits at a corner"
date: 2026-08-27 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, math, greedy, parity, brute_force, silly_mistake]
author: "Seroze"
published: true
---

Problem: [CodeChef — Grid Jump](https://www.codechef.com/START253A/problems/GRDJUMP) (Starters 253)

You start at $$(0,0)$$ and want to reach $$(A,B)$$. Three moves are available:

- move $$1$$ **or** $$2$$ steps right, for $$P$$ coins
- move $$1$$ **or** $$2$$ steps up, for $$Q$$ coins
- move $$1$$ step right **and** $$1$$ step up, for $$R$$ coins

Minimise the coins spent. Constraints are tiny: $$T \le 1000$$ and $$A, B, P, Q, R \le 100$$.

This was the easy problem of the set, I treated it like one, and I got it wrong. The reduction I did
was correct; the one line of reasoning I bolted onto the end of it was a guess I never checked. This
is a writeup of the guess, why it's wrong, and what the function actually looks like.

## The reduction

Suppose you decide up front to use exactly $$k$$ diagonal moves. Diagonals are interchangeable and
order never matters, so all that's left is covering $$A-k$$ horizontally and $$B-k$$ vertically with
moves that each cover $$1$$ or $$2$$ units at a flat price. You'd obviously always take $$2$$ when
there's $$2$$ left, so the horizontal leg costs

$$\left\lceil \frac{A-k}{2} \right\rceil P$$

and the vertical leg is the same with $$B$$ and $$Q$$. So with $$K = \min(A,B)$$ the whole problem is
a one-variable minimisation:

$$f(k) = kR + \left\lceil \frac{A-k}{2} \right\rceil P + \left\lceil \frac{B-k}{2} \right\rceil Q,
\qquad 0 \le k \le K$$

Nothing controversial so far. Then I wrote down the sentence that cost me the problem:

> A diagonal either pays for itself or it doesn't, so the best $$k$$ must be $$0$$ or $$K$$.

and submitted $$\min\big(f(0), f(K)\big)$$.

## Why that felt safe, and why it isn't

The intuition behind it is that $$R$$ is being traded against $$P$$ and $$Q$$ at a fixed exchange
rate, so the trade is either good or bad and you should do all of it or none of it. That's a real
argument — for a *linear* cost function. Take the ceilings away and it's airtight.

The ceilings are exactly what breaks it. A move covers $$2$$ units for the same price as $$1$$, so
shaving one unit off the remaining distance is sometimes free and sometimes worth a whole move. The
value of a diagonal isn't fixed; it flips with parity.

Here's the smallest counterexample, small enough that I could have found it by hand in a minute:

$$A = B = 3, \qquad P = Q = 5, \qquad R = 8$$

| $$k$$ | cost |
|---|---|
| 0 | $$2P + 2Q = 20$$ |
| 1 | $$R + P + Q = 18$$ |
| 2 | $$2R + P + Q = 26$$ |
| 3 | $$3R = 24$$ |

The answer is $$18$$, at $$k=1$$. My submission would have printed $$\min(20, 24) = 20$$. The optimum
is at neither end, and the function isn't monotonic *or* convex — it zig-zags:

```
26 |                *
24 |                        *
22 |
20 |  *
18 |         *
   +-----------------------------
      0      1       2       3     <- k
```

The zig-zag survives at larger sizes. Same $$P, Q, R$$ with $$A = B = 5$$ gives

```
k : 0    1    2    3    4    5
f : 30   28   36   34   42   40
```

still minimal at $$k = 1$$, still bouncing.

## What one extra diagonal actually costs

The check I should have run takes about a minute. Write down the marginal cost:

$$f(k+1) - f(k) = R
+ P\left(\left\lceil \tfrac{A-k-1}{2} \right\rceil - \left\lceil \tfrac{A-k}{2} \right\rceil\right)
+ Q\left(\left\lceil \tfrac{B-k-1}{2} \right\rceil - \left\lceil \tfrac{B-k}{2} \right\rceil\right)$$

and then work out the one piece that matters, $$\lceil (x-1)/2 \rceil - \lceil x/2 \rceil$$:

| $$x$$ | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| $$\lceil x/2 \rceil$$ | 0 | 1 | 1 | 2 | 2 | 3 |
| difference | 0 | -1 | 0 | -1 | 0 | -1 |

It's $$-1$$ when $$x$$ is odd and $$0$$ when $$x$$ is even. So

$$f(k+1) - f(k) = R - \mathbf{1}[A-k \text{ odd}] \cdot P - \mathbf{1}[B-k \text{ odd}] \cdot Q$$

which says the thing the ceilings were hiding. A diagonal covers one unit in each direction; it
*saves* you a move only in the direction where the remaining distance is currently odd. When both
remainders are odd it's a bargain at $$R - P - Q$$. When both are even you pay $$R$$ and eliminate
nothing.

For $$A = B = 3$$ the slope alternates $$R-P-Q,\; R,\; R-P-Q$$, which with $$P=Q=5, R=8$$ is
$$-2, +8, -2$$ — exactly the $$20 \to 18 \to 26 \to 24$$ we saw.

## The structure I missed

The slope only depends on the parity of $$k$$, and that's the whole story. Take two steps instead of
one: of any two consecutive integers exactly one is odd, so the indicators over a double step always
contribute one $$P$$ and one $$Q$$, and

$$f(k+2) - f(k) = 2R - P - Q$$

for every $$k$$. A constant. So $$f$$ isn't one messy function — it's **two arithmetic progressions
interleaved**, one on the even $$k$$ and one on the odd $$k$$, both with the same common difference
$$2R - P - Q$$. If that difference is positive both sequences climb; if it's negative both fall; and
the graph zig-zags because the two sequences are offset from each other.

Which means my instinct wasn't even wrong, just misapplied. The minimum of an arithmetic progression
*is* at an endpoint — but there are two progressions here, so there are four endpoints, not two:

$$\text{answer} = \min_{k \in \{0,\ 1,\ K-1,\ K\} \cap [0, K]} f(k)$$

I checked this against the full loop on 300,000 random inputs and it never disagrees. For
$$A = B = 3, P = Q = 5, R = 8$$ the four candidates are $$f(0)=20$$, $$f(1)=18$$, $$f(2)=26$$,
$$f(3)=24$$ — which is everything, at that size — and the odd chain wins.

## The code

Given $$A, B \le 100$$ there is no reason to be clever. Loop:

```python
import sys

def solve(A, B, P, Q, R):
    return min(
        k * R + ((A - k + 1) // 2) * P + ((B - k + 1) // 2) * Q
        for k in range(min(A, B) + 1)
    )

data = sys.stdin.buffer.read().split()
t = int(data[0])
out = []
for i in range(t):
    A, B, P, Q, R = map(int, data[1 + 5*i : 6 + 5*i])
    out.append(solve(A, B, P, Q, R))
sys.stdout.write("\n".join(map(str, out)) + "\n")
```

That's $$10^3 \times 10^2 = 10^5$$ evaluations in the worst case. And the four-candidate version, if
$$A$$ and $$B$$ were up to $$10^{18}$$:

```python
def solve(A, B, P, Q, R):
    K = min(A, B)
    ks = {0, 1, K - 1, K}
    return min(k * R + ((A - k + 1) // 2) * P + ((B - k + 1) // 2) * Q
               for k in ks if 0 <= k <= K)
```

Both agree with all four sample tests and with each other everywhere I've tested.

## How bad was the guess

I got curious about whether I'd been unlucky. Sampling $$A, B, P, Q, R$$ uniformly from
$$1 \dots 100$$, the corners-only answer is **wrong on about 15.8% of inputs**. One in six. With
$$T$$ up to $$1000$$ per file, the probability that a single test file fails to catch it is
essentially zero — which is another way of saying this was never going to sneak through, and the
only surprise was mine.

The smallest counterexample by total size is

```
A=2 B=3 P=1 Q=3 R=2   ->  true answer 6 (k=1), corners give 7
```

which is one digit away from sample test 3 (`3 4 1 3 2`). The samples were sitting right next to a
case that kills the heuristic and it still passed them.

## So how do I stop doing this

The honest diagnosis isn't "I don't know enough maths." It's that **an easy problem produces
certainty without producing evidence.** On a hard problem I'm suspicious of my own claims by default
and I go looking for the proof. On an easy one the reduction lands, a plausible sentence follows it,
and the plausibility gets mistaken for a derivation because the whole thing took ninety seconds. The
speed *is* the failure mode. Nothing about the argument was ever checked.

Three things I'm taking from this.

**Spend thirty seconds trying to break it, not five minutes trying to prove it.** Proving is
expensive; falsifying is cheap. For any claim of the shape "the optimum is at an extreme", the
attack is always the same — grab the smallest interesting parameters, tabulate the objective for
every value of the decision variable, and look. Here that's four numbers for $$A=B=3$$. Had I written
that row out I'd have seen $$20, 18, 26, 24$$ and been done arguing.

**When you reduce to one variable, compute $$f(k+1) - f(k)$$ before you assume anything about the
shape.** This is the single highest-return habit in the whole category. The difference immediately
tells you whether you're looking at something monotonic, convex, or oscillating, and it costs one
line. Corners are only justified by monotonicity, convexity, an exchange argument, or a proof of a
unique turning point. If I can't name which one I'm relying on, I don't have an argument, I have a
hypothesis.

**Check whether being clever even buys anything.** This is the part that stings. $$A, B \le 100$$ —
the brute-force loop over every $$k$$ is *shorter* than the endpoint special-case, runs in $$10^5$$
operations, and requires no insight at all. I optimised away a loop that was already free, and paid
for it with a wrong answer. Before committing to a structural shortcut, look at the constraints and
ask what the shortcut is actually saving. If the answer is "nothing", the shortcut is pure downside:
it can only be wrong, it can't be fast.

The general failure here is treating a guess and a derivation as the same object because they arrive
in the same sentence. They don't feel different in the moment — that's exactly why the check has to
be mechanical rather than a matter of judgement. Tabulate the small case. Take the difference. Then
submit.
