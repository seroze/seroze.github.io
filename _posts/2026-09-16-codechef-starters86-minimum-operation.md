---
layout: post
title: "[CodeChef] Starters 86 — Minimum Operation: the case my gut missed"
date: 2026-09-16 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, number_theory, gcd, sieve, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Minimum Operation](https://www.codechef.com/problems/MINIMUMOP) (Starters 86,
difficulty 2170). Official editorial:
[MINIMUMOP editorial](https://discuss.codechef.com/t/minimumop-editorial/105897).

I got the hard half of this problem right and the easy half wrong. I proved — properly, with
algebra — that two operations always suffice, and then I asserted without proof that two operations
are sometimes *necessary*. The assertion was false, it cost me a wrong answer, and the false step
was the one I never bothered to write down. That asymmetry is the whole story of this writeup.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

You get $$N$$ and $$M$$ with $$M \ge 2$$, and an array $$A$$ of size $$N$$ with
$$2 \le A_i \le M$$. One operation is: pick an integer $$X$$ with $$2 \le X \le M$$, and replace
every element simultaneously,

$$A_i \gets \gcd(A_i, X).$$

Make all elements equal in as few operations as possible, and print the $$X$$ you used for each
one.

Constraints: $$N \le 10^5$$ with the sum of $$N$$ over tests at most $$3 \cdot 10^5$$, and
$$M \le 10^6$$ — but note the sum of $$M$$ is **not** bounded. That last clause is not decoration;
it decides what the implementation is allowed to do per test case, and I'll come back to it.

The sample is friendly: $$[4, 8, 12, 16, 20]$$ with $$M = 100$$ takes one operation, $$X = 4$$,
because 4 is the gcd of everything.

## Two operations always suffice

Here's the first thing I worked out, and it's still the part I like.

Apply $$X = M - 1$$, then $$X = M$$. After the first operation element $$i$$ becomes

$$g_i = \gcd(A_i, M - 1),$$

and the claim is that the second operation sends every $$g_i$$ to 1, i.e. that
$$\gcd(g_i, M) = 1$$ for every $$i$$ regardless of what $$A_i$$ was.

Why: $$g_i$$ divides $$M - 1$$, so write $$M - 1 = k g_i$$, which gives

$$M = k g_i + 1.$$

Suppose some prime $$p$$ divided both $$M$$ and $$g_i$$. Write $$M = p x_1$$ and $$g_i = p x_2$$
and substitute:

$$p x_1 = k p x_2 + 1 \implies p (x_1 - k x_2) = 1.$$

The left side is a multiple of $$p$$ and the right side is 1, so $$p = 1$$ — not a prime.
Contradiction, hence $$\gcd(g_i, M) = 1$$.

That argument is fine, and it's also more work than the situation needs. Once you have
$$M = k g_i + 1$$ you can just run one step of Euclid:

$$\gcd(M, g_i) = \gcd(k g_i + 1, \; g_i) = \gcd(1, g_i) = 1.$$

Same content, one line. Worth internalising the shortcut: *anything of the form
$$(\text{multiple of } d) + 1$$ is automatically coprime to $$d$$*, which is exactly why
consecutive integers are coprime.

The editorial's version of this fallback is blunter and better: use $$X = 2$$, then $$X = 3$$. The
first collapses every element to 1 or 2, and $$\gcd(1, 3) = \gcd(2, 3) = 1$$, so the second
flattens everything to 1. Both constructions need their $$X$$ values to be at most $$M$$, which is
free here — I'll show later that this branch is only ever reached when $$M$$ is large.

## The wrong answer

So I had: 0 if the array is already flat, 1 if $$\gcd(A) > 1$$ (take $$X = \gcd(A)$$ and every
element becomes $$\gcd(A)$$), and otherwise 2 via the construction above. That's this:

```python
from math import gcd

def solve():
    n, m = map(int, input().split())
    a = list(map(int, input().split()))

    if min(a) == max(a):
        print(0)
        return

    gc = 0
    for x in a:
        gc = gcd(x, gc)

    if gc > 1:
        print(1)
        print(gc)
    else:
        print(2)
        print(m - 1, m)
```

Wrong answer. And the reasoning I'd used to justify the `else` branch, said out loud, was: *one
operation can only work if the array has a common divisor $$d > 1$$.*

Half of that is a real theorem. If one operation with $$X$$ leaves every element equal to $$Y$$,
then $$Y = \gcd(A_i, X)$$ divides each $$A_i$$, so

$$Y \mid \gcd(A_1, \ldots, A_N).$$

When $$\gcd(A) = 1$$ that forces $$Y = 1$$. Which is where I stopped reading my own proof — I
concluded "so there's no valid $$Y$$" when what it actually says is "so the only available $$Y$$ is
1". Those are very different sentences. $$Y = 1$$ is a perfectly good target: all ones is all
equal.

The counterexample is three lines long. Take $$M = 10$$ and

$$A = [2, 3, 5],$$

whose gcd is 1. Pick $$X = 7$$. Every element is coprime to 7, so the array becomes $$[1, 1, 1]$$
in a single operation. My code prints 2. Valid, but not minimal, and the problem asks for minimal.

## Characterising one operation properly

Now state the thing carefully instead of by feel. Assume the array isn't already flat, so the
answer is at least 1. Then:

> One operation suffices **iff** $$\gcd(A) > 1$$, or there is a prime $$p \le M$$ that divides none
> of the $$A_i$$.

Both directions are short.

If $$\gcd(A) = g > 1$$, take $$X = g$$; every element becomes $$g$$. If instead some prime
$$p \le M$$ divides no $$A_i$$, take $$X = p$$; then $$\gcd(A_i, p)$$ is $$p$$ or 1, and it can't
be $$p$$, so every element becomes 1.

Conversely, suppose one operation with some $$X$$ works and $$\gcd(A) = 1$$. By the divisibility
argument above every element ends at 1, so $$\gcd(A_i, X) = 1$$ for all $$i$$. Since $$X \ge 2$$ it
has at least one prime factor $$p$$, and $$p \le X \le M$$. If $$p$$ divided some $$A_i$$ it would
divide $$\gcd(A_i, X) = 1$$, which is absurd. So $$p$$ is a prime at most $$M$$ dividing no
element.

That last direction is the one worth noticing: it says you lose nothing by only ever considering
*prime* $$X$$. A composite $$X$$ that works can always be replaced by any one of its prime factors.
Searching over $$M$$ candidates becomes searching over $$\pi(M) \approx 78{,}498$$ candidates for
$$M = 10^6$$, and more importantly it turns a vague search into a concrete question: **is every
prime up to $$M$$ a factor of some element?**

So the complete answer is 0, 1, or 2, and the only interesting work is that question.

## Finding the missing prime

Collect the distinct prime factors of every $$A_i$$ into a set, then walk the primes in increasing
order and stop at the first one that isn't in the set.

Factorising each $$A_i$$ by trial division would be $$O(\sqrt{A_i})$$, which is survivable but
silly when all values share a bound. The standard trick is a smallest-prime-factor sieve: build
`spf[x]` once for all $$x \le 10^6$$, then peel factors off a number one at a time.

```python
MAXM = 10**6
spf = list(range(MAXM + 1))
for i in range(2, 1001):            # 1000 * 1000 > MAXM, so this is far enough
    if spf[i] == i:                 # i is prime
        for j in range(i * i, MAXM + 1, i):
            if spf[j] == j:
                spf[j] = i
primes = [p for p in range(2, MAXM + 1) if spf[p] == p]
```

Each peel divides the number by at least 2, so factorising one $$A_i$$ costs
$$O(\log M)$$ and the whole array costs $$O(N \log M)$$.

### The constraint that bites

"The sum of $$M$$ over all test cases isn't bounded" is the trap. With $$T$$ up to $$10^5$$ and
$$M$$ up to $$10^6$$, anything that does $$O(M)$$ work *per test case* — allocating a
`bytearray(m + 1)`, or scanning all primes up to $$m$$ — is $$10^{11}$$ operations in the worst
case. The sieve is fine because it's built once; the per-test part must not touch $$M$$.

The scan is safe anyway, as long as you break out the instant you find a missing prime. The set of
used primes has at most $$N \log M$$ elements, so:

- if a missing prime exists, you hit it within $$N \log M + 1$$ steps, because that's how many
  primes can possibly be in the way;
- if no missing prime exists, then *every* prime up to $$M$$ divides something, so
  $$N \log M \ge \pi(M) \approx M / \log M$$. That's a lower bound on $$N$$, and the sum of $$N$$
  is bounded, so this can only happen a few times.

That second bullet also settles the $$X = 2, 3$$ question from earlier: reaching the fallback needs
every prime up to $$M$$ to divide some element, which needs a big $$N$$ and certainly needs
$$M \ge 3$$. (For $$M = 2$$ the constraint $$2 \le A_i \le M$$ makes the array all 2s, so the
answer is 0 and we never get there.)

Use a `set` rather than an array indexed up to `m`, and the per-test memory is $$O(N \log M)$$ too.

## The finished solution

```python
import sys
from math import gcd

MAXM = 10**6
spf = list(range(MAXM + 1))
for i in range(2, 1001):
    if spf[i] == i:
        for j in range(i * i, MAXM + 1, i):
            if spf[j] == j:
                spf[j] = i
primes = [p for p in range(2, MAXM + 1) if spf[p] == p]

def main():
    data = sys.stdin.buffer.read().split()
    pos = 0
    t = int(data[pos]); pos += 1
    out = []

    for _ in range(t):
        n, m = int(data[pos]), int(data[pos + 1]); pos += 2
        a = list(map(int, data[pos:pos + n])); pos += n

        if min(a) == max(a):
            out.append("0")
            continue

        g = 0
        for x in a:
            g = gcd(g, x)
        if g > 1:
            out.append("1"); out.append(str(g))
            continue

        used = set()
        for x in a:
            while x > 1:
                p = spf[x]
                used.add(p)
                while x % p == 0:
                    x //= p

        chosen = 0
        for p in primes:
            if p > m:
                break
            if p not in used:
                chosen = p
                break

        if chosen:
            out.append("1"); out.append(str(chosen))
        else:
            out.append("2"); out.append("2 3")

    sys.stdout.write("\n".join(out) + "\n")

main()
```

The sieve is about 0.2 s in CPython (only ~2 million inner-loop steps, since the outer loop stops
at 1000), and everything after it is linear-ish in the sum of $$N$$.

I checked this against a brute force — BFS over reachable arrays, trying every $$X \in [2, M]$$ —
for all arrays of length up to 3 over every $$M \le 24$$, and the operation counts agree
everywhere. That's cheap to write and it would have caught my original submission on the very first
$$M = 10$$, $$A = [2, 3]$$ style case.

## What I'd take away

The bug wasn't in the number theory. I proved the genuinely fiddly claim correctly and then tripped
on a claim so obvious-feeling that I never wrote it down — "one op needs a common divisor" — which
turned out to be false because I'd silently assumed the final common value had to exceed 1.

The pattern is worth naming, because it isn't "prove more things", it's narrower than that: **the
steps most likely to be wrong are the ones that felt too obvious to state.** The fiddly claims get
proved precisely because they look fiddly. The one-liners get waved through. In this problem, the
waved-through step was an "only if" masquerading as an "iff", and the fix was simply writing both
directions out — at which point the counterexample fell straight out of the failed direction.

A cheap habit that catches this class of bug: whenever a solution branches on a condition, ask what
happens at the *degenerate* value on each side. Here the degenerate value is $$Y = 1$$, and it's
exactly the case I dropped.
