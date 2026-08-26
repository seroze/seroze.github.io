---
layout: post
title: "[CodeChef] Starters 117 — Equality Etiquette: the sign choice is the whole problem"
date: 2026-08-26 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, constructive, parity, math, ad_hoc]
author: "Seroze"
published: true
---

Problem: [CodeChef — Equality Etiquette](https://www.codechef.com/problems/EQUAL2) (Starters 117, rated 1898)

You're given $$A$$ and $$B$$. On move $$i$$ you must touch exactly one of them: if $$i$$ is odd you
add $$i$$ to it, if $$i$$ is even you subtract $$i$$ from it. Find the minimum number of moves that
makes them equal, or $$-1$$.

The statement spends most of its length on that odd/even rule, and it turns out not to matter at all.

## The reduction

Nothing in the problem depends on $$A$$ and $$B$$ separately — only on $$D = A - B$$. So look at what
one move does to $$D$$.

Say move $$i$$ is odd, so the move is "add $$i$$". Adding to $$A$$ sends $$D \to D + i$$; adding to
$$B$$ sends $$D \to D - i$$. Now say $$i$$ is even, so the move is "subtract $$i$$". Subtracting from
$$A$$ gives $$D - i$$, subtracting from $$B$$ gives $$D + i$$.

Both cases offer the same two outcomes. The odd/even split decides *which variable* gets the plus
sign, and since we're free to pick the variable, we're free to pick the sign either way. After $$n$$
moves the reachable differences are exactly

$$D \pm 1 \pm 2 \pm 3 \cdots \pm n$$

over all $$2^n$$ sign choices, and we want to know the smallest $$n$$ for which $$0$$ is in there.

## What that set looks like

Write $$T(n) = \tfrac{n(n+1)}{2}$$ and let $$S(n)$$ be the set of reachable differences after $$n$$
moves.

> **Claim.** $$S(n)$$ is every integer in $$[D - T(n),\, D + T(n)]$$ congruent to $$D + T(n)$$ mod 2.

The endpoints are obvious — take all signs positive or all negative. The content of the claim is that
nothing in between is missing.

Induction on $$n$$. The base case $$n = 0$$ is the single point $$\{D\}$$. For the step, the next move
shifts the whole set by $$\pm(n+1)$$:

$$S(n+1) = \bigl(S(n) + (n+1)\bigr) \cup \bigl(S(n) - (n+1)\bigr)$$

Both copies have the same parity, since they're shifted by the same amount, and that parity is the one
the claim predicts for $$n+1$$. The up-shifted copy spans $$[L + n + 1,\, R + n + 1]$$ and the
down-shifted one spans $$[L - n - 1,\, R - n - 1]$$, where $$L, R$$ are the old endpoints. Together
they cover the full interval as long as they don't leave a hole, i.e. as long as the up-shifted copy
starts no more than $$2$$ past where the down-shifted one ends:

$$L + (n+1) \le \bigl(R - (n+1)\bigr) + 2 \iff R - L \ge 2n$$

and $$R - L = 2T(n) \ge 2n$$ for every $$n \ge 0$$. So the two copies overlap (or touch at a gap of
exactly $$2$$, which is no gap at all within a fixed parity class), and the union is one contiguous
parity-interval again. $$\square$$

That inequality is the only place the triangular number does any work, and it's slack for all but the
first move — which is a decent sign that the problem is easier than it looks.

## The answer

Reaching $$0$$ therefore needs two things, and only these two:

$$T(n) \ge \lvert D \rvert \qquad\text{and}\qquad T(n) \equiv D \pmod 2$$

Since $$T(n)$$ grows without bound and its parity cycles, both are eventually satisfiable — the
$$-1$$ branch is dead code. Nice of them to include it.

## Two off-by-ones worth naming

**Finding the first $$n$$ with $$T(n) \ge D$$.** Solving $$n(n+1)/2 = D$$ gives
$$n = \frac{\sqrt{1 + 8D} - 1}{2}$$, and flooring that with `isqrt` lands on the *largest* $$n$$ with
$$T(n) \le D$$ — one short of what we want, whenever $$D$$ isn't itself triangular. My first attempt
then "fixed" it with

```python
while (n + 1) * (n + 2) // 2 <= D:
    n += 1
```

which is a loop for a different question: it climbs while the *next* triangular number still fits,
i.e. it also computes the largest $$n$$ with $$T(n) \le D$$. For $$D = 8$$ the estimate is $$n = 3$$,
$$T(4) = 10 \not\le 8$$, the loop never runs, and it returns $$3$$ with $$T(3) = 6 < 8$$. The
assertion caught it.

The loop for the question I actually had is the direct one:

```python
while n * (n + 1) // 2 < D:
    n += 1
```

Same shape, opposite inequality. And since the floor is off by at most one, that `while` could be an
`if`.

**Fixing the parity.** $$T(n) \bmod 2$$ runs $$1, 1, 0, 0, 1, 1, 0, 0, \dots$$ — odd exactly when
$$n \equiv 1, 2 \pmod 4$$, which is where the `(n - 1) % 4` trick comes from. But every window of
three consecutive $$n$$ contains both parities, so from the first candidate you need **at most two**
extra moves. No need for the closed form; just bump $$n$$ until the parity matches and let the loop
run its two iterations.

## Code

```python
import sys
from math import isqrt

def main():
    data = sys.stdin.buffer.read().split()
    t = int(data[0])
    out = []
    for i in range(t):
        a = int(data[1 + 2*i]); b = int(data[2 + 2*i])
        d = abs(a - b)
        if d == 0:
            out.append(0)
            continue
        n = (isqrt(1 + 8*d) - 1) // 2       # largest n with T(n) <= d
        if n*(n+1)//2 < d:
            n += 1                          # now: smallest n with T(n) >= d
        while (n*(n+1)//2 - d) % 2:
            n += 1                          # runs at most twice
        out.append(n)
    sys.stdout.write("\n".join(map(str, out)) + "\n")

main()
```

At $$A, B \le 10^9$$ the answer never exceeds $$44721$$, and $$10^5$$ test cases run in about
$$0.13$$s — the whole thing is one integer square root per case.

## Checking it

The claim about $$S(n)$$ is exactly the kind of thing to verify before trusting, so I brute-forced it:
start from $$\{D\}$$, apply $$x \mapsto x \pm i$$ to the whole set, and report the first step where
$$0$$ shows up. For every $$D$$ from $$0$$ to $$399$$ it agrees with the formula. Then a second sweep
up to $$D = 2 \times 10^5$$ confirmed the parity loop never runs more than twice.

Both checks take a couple of lines and would have caught a wrong parity table instantly, which is the
argument for writing them even when the proof feels finished.
