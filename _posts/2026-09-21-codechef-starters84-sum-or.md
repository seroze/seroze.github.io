---
layout: post
title: "[CodeChef] Starters 84 — SUM OR: a correct digit DP that still TLEs"
date: 2026-09-21 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, digit_dp, dynamic_programming, bit_manipulation, combinatorics, python, TODO]
author: "Seroze"
published: true
---

Problem: [CodeChef — SUM OR](https://www.codechef.com/problems/AWESUM_OR) (Starters 84, difficulty
2152). Official editorial:
[AWESUM_OR editorial](https://discuss.codechef.com/t/awesum-or-editorial/105734).

I solved this one as a digit DP, which is not how it's meant to be solved. The DP I ended up with is
*correct* — I've since checked it against brute force — and it still doesn't pass, because 60 bits
of work per test case times $$10^5$$ test cases is more than Python is willing to do in a second
and a half. This is a writeup of the two bugs I hit on the way there, the "fix" in the middle that
fixed nothing, and the thing the transition table was trying to tell me the whole time.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

Given a positive integer $$N$$, count the triples $$(X, Y, Z)$$ with

$$0 < X, Y, Z < N, \qquad X + Y + Z = N, \qquad X \mid Y \mid Z = N,$$

where $$\mid$$ is bitwise OR. Report the count modulo $$10^9 + 7$$. The constraints are
$$1 \le T \le 10^5$$ and $$1 \le N < 2^{60}$$, with a 1.5 second limit.

The sample is two lines, and both of them turned out to be load-bearing:

```
2          -> 0
3
7          -> 6
```

For $$N = 7$$ the six triples are the orderings of $$(1, 2, 4)$$. For $$N = 3$$ there's nothing:
$$1 + 1 + 1 = 3$$ but $$1 \mid 1 \mid 1 = 1$$, and every other way of splitting 3 into three
positive parts fails too.

## Why I reached for a digit DP

Both constraints are per-bit statements, just of different kinds.

The OR is the easy one. Bit $$k$$ of $$X \mid Y \mid Z$$ is set exactly when at least one of the
three has it set, so if I let

$$s_k = \text{the number of } X, Y, Z \text{ with bit } k \text{ set} \;\in\; \{0, 1, 2, 3\},$$

then the OR condition says $$s_k = 0$$ wherever $$N$$ has a 0 bit and $$s_k \ge 1$$ wherever it has
a 1.

The sum is the one that couples bits together, and it couples them in exactly one direction: a
carry out of position $$k$$ into position $$k+1$$. Adding three numbers column by column, position
$$k$$ receives $$s_k$$ ones plus the incoming carry $$c_k$$, has to leave behind bit $$n_k$$ of
$$N$$, and passes the rest upward:

$$s_k + c_k = n_k + 2 c_{k+1}.$$

That's the whole problem in one line, and it's the standard shape for a digit DP: walk the
positions low to high, carry the one piece of state that crosses a position boundary. So the state
I wrote down was

$$dp(\textit{pos}, \textit{prev\_carry}) \;\longrightarrow\; dp(\textit{pos}+1, \textit{new\_carry}),$$

with $$c_0 = 0$$ going in, and $$c_{60} = 0$$ required coming out (three numbers below $$2^{60}$$
sum to less than $$2^{62}$$, but $$N < 2^{60}$$, so anything still in flight at the top is a sum
that overshot).

## First attempt

At each position I enumerate $$s_k \in \{0, 1, 2, 3\}$$, throw away the values the OR forbids, throw
away the ones with the wrong parity, and weight the rest by how many ways there are to pick *which*
of the three numbers get the bit — $$\binom{3}{s_k}$$, or $$1, 3, 3, 1$$:

```python
from functools import cache

MOD = 10**9 + 7

def solve(N):
    @cache
    def dp(pos, prev_carry):
        if pos == 60:
            return 1 if prev_carry == 0 else 0

        nbit = (N >> pos) & 1
        ans = 0

        for sk in range(4):
            # OR condition
            if nbit == 0 and sk != 0:
                continue
            if nbit == 1 and sk == 0:
                continue

            total = sk + prev_carry

            # total = nbit + 2 * new_carry
            if total % 2 != nbit:
                continue

            new_carry = (total - nbit) // 2

            ways = [1, 3, 3, 1][sk]        # which of X, Y, Z get this bit

            ans += ways * dp(pos + 1, new_carry)
            ans %= MOD

        return ans

    return dp(0, 0)
```

On the sample this prints 9 and 27, against an expected 0 and 6.

Those are suspiciously round numbers. $$3 = \texttt{11}_2$$ has two set bits and $$9 = 3^2$$;
$$7 = \texttt{111}_2$$ has three and $$27 = 3^3$$. So the DP is computing $$3^{\text{popcount}(N)}$$,
which is "hand each set bit of $$N$$ to one of the three variables, independently" — a perfectly
sensible count of *something*, just not of what I was asked.

## The carry formula that wasn't the bug

The first thing I went after was the carry line, because I'd originally written

```python
new_carry = total // 2
```

and rearranging $$s_k + c_k = n_k + 2c_{k+1}$$ gives

$$c_{k+1} = \frac{s_k + c_k - n_k}{2},$$

with the $$n_k$$ subtracted off. So I changed it to `(total - nbit) // 2`.

That change is right, and it fixed nothing, because the two expressions are the same number. The
parity guard on the line above already established `total % 2 == nbit`, so when `nbit` is 1 `total`
is odd and integer division discards exactly the 1 I was subtracting; when `nbit` is 0 there is
nothing to subtract. I checked all 32 reachable combinations of `(nbit, sk, prev_carry)` afterwards
and they never disagree.

I'm keeping this in the writeup because the reasoning that led me to it was still worth doing, and
because of the failure mode it represents: I had a wrong answer, I found a line that was *arguably*
wrong, and I stopped looking. Writing `(total - nbit) // 2` is better code — it's the equation
solved for $$c_{k+1}$$, and it stays correct if the guard above it ever changes — but a
simplification that the guard makes invisible cannot be responsible for a wrong answer. If fixing
something doesn't change the output, the bug is still out there.

## The real bug: the DP can't see a zero

The condition I never encoded is $$X, Y, Z > 0$$.

Take $$N = 3$$. The DP happily counts the assignment "give bit 0 to $$X$$ and bit 1 to $$X$$",
producing $$(3, 0, 0)$$, which satisfies both $$X + Y + Z = 3$$ and $$X \mid Y \mid Z = 3$$ and is
not a legal triple. It counts $$(0, 3, 0)$$ and $$(0, 0, 3)$$ too, and every other assignment that
starves a variable. For $$N = 3$$ *all nine* of the counted assignments leave at least one variable
empty, which is why the answer should be 0 and I got 9.

And the DP structurally cannot notice. `ways = [1, 3, 3, 1][sk]` multiplies by the *number* of ways
to place the bits and immediately forgets which variable each one went to, so by the time the
recursion reaches position 60 there's nothing left to ask "did $$Y$$ ever receive anything?".
Positivity isn't a property of a position, it's a property of a whole path, and a DP can only check
those if it carries them in the state.

## Adding the mask

Three variables, one bit each for "has received a set bit at some point": a 3-bit mask, 8 values.
Instead of multiplying by a count, enumerate the actual subsets and OR them into the mask.

```python
from functools import cache

MOD = 10**9 + 7

# which of X, Y, Z receive this bit, grouped by how many of them do
CHOICES = {
    0: [0b000],
    1: [0b001, 0b010, 0b100],
    2: [0b011, 0b101, 0b110],
    3: [0b111],
}

def solve(N):
    @cache
    def dp(pos, prev_carry, mask):
        if pos == 60:
            return 1 if prev_carry == 0 and mask == 0b111 else 0

        nbit = (N >> pos) & 1
        ans = 0

        for sk in range(4):
            # OR condition
            if nbit == 0 and sk != 0:
                continue
            if nbit == 1 and sk == 0:
                continue

            total = sk + prev_carry

            # total = nbit + 2 * new_carry
            if total % 2 != nbit:
                continue

            new_carry = (total - nbit) // 2

            for bits in CHOICES[sk]:
                ans += dp(pos + 1, new_carry, mask | bits)
                ans %= MOD

        return ans

    return dp(0, 0, 0)


T = int(input())
for _ in range(T):
    print(solve(int(input())))
```

The base case now demands `mask == 0b111`, meaning all three variables picked up a bit somewhere.
This prints 0 and 6 on the sample, and I've since checked it against a brute force over all triples
for every $$N < 200$$ — they agree everywhere. It's right.

It also TLEs.

## Why it TLEs

Not for the reason I assumed. The state space is tiny:

$$60 \text{ positions} \times 2 \text{ carries} \times 8 \text{ masks} = 960 \text{ states},$$

so per test case this is nothing. The problem is the $$10^5$$ in front of it. The memo lives inside
`solve`, so it's built and thrown away once per test case, and there's no sharing to be had anyway
because `dp` closes over `N` — every test case is a different DP. Roughly a thousand memoised calls
plus their transition loops, a hundred thousand times over.

Timed locally on the worst case ($$N$$ just under $$10^{18}$$, all 60 positions live), a thousand
test cases take about 0.23 seconds, which puts the full input somewhere north of 20 seconds against
a 1.5 second limit — on my machine, which is friendlier than the judge. That's not an optimisation
away. PyPy might buy an order of magnitude and would still be over.

The useful version of "it TLEs" here isn't "Python is slow", it's that **the per-test cost is the
thing under my control, and 960 states is already too much when $$T$$ is $$10^5$$.** Anything
surviving 1.5 seconds has to be $$O(\log N)$$ with a small constant, or $$O(1)$$ after a
precomputation. Which is a hint about the shape of the real answer, and I should have read it as
one.

## What the transition table was trying to tell me

Before optimising anything, I wrote out every transition by hand. There are only four cases, and
they're much more constrained than the four-way loop over $$s_k$$ suggests.

**Carry 0, bit of $$N$$ is 0.** The OR forces $$s_k = 0$$, so $$0 = 0 + 2c_{k+1}$$ and the carry
stays 0. One transition, weight 1.

**Carry 0, bit of $$N$$ is 1.** Now $$s_k = 1 + 2c_{k+1}$$, so $$s_k$$ must be odd. Either
$$s_k = 1$$ with carry 0 out (3 ways — which variable gets it), or $$s_k = 3$$ with carry 1 out (1
way).

**Carry 1, bit of $$N$$ is 0.** The OR forces $$s_k = 0$$ again, so $$0 + 1 = 0 + 2c_{k+1}$$, and
$$1$$ is not even. **No transition at all** — this branch is dead.

**Carry 1, bit of $$N$$ is 1.** $$s_k + 1 = 1 + 2c_{k+1}$$ gives $$s_k = 2c_{k+1}$$, and $$s_k \ge
1$$, so $$s_k = 2$$ and the carry stays 1. Three ways.

Read the last two together: once you're carrying, **you can never stop carrying**, and you die the
moment $$N$$ has a zero bit. Since $$N$$ is finite, every position above its top bit is a zero bit,
so no path that ever enters carry 1 survives to the base case. The carry is always zero. Which
means

$$s_k = n_k \quad \text{for every } k,$$

no carries, no overlaps — each set bit of $$N$$ goes to exactly one of $$X, Y, Z$$. Which is the
editorial's opening observation, arrived at the long way round: $$X \mid Y \mid Z \le X + Y + Z$$
always, with equality exactly when the three share no bits.

From there it's counting. With $$K = \text{popcount}(N)$$ there are $$3^K$$ assignments; subtract
the $$2^K$$ that starve each of the three variables, add back the 3 that were subtracted twice, and

$$\text{answer} = 3^K - 3 \cdot 2^K + 3.$$

Check: $$N = 3$$, $$K = 2$$, $$9 - 12 + 3 = 0$$. $$N = 7$$, $$K = 3$$, $$27 - 24 + 3 = 6$$. Both
samples, and it matches my masked DP on every $$N$$ I've tried.

```python
import sys

MOD = 10**9 + 7

def main():
    data = sys.stdin.buffer.read().split()
    out = []
    for tok in data[1:1 + int(data[0])]:
        k = int(tok).bit_count()
        out.append((pow(3, k, MOD) - 3 * pow(2, k, MOD) + 3) % MOD)
    sys.stdout.write('\n'.join(map(str, out)) + '\n')

main()
```

The two terms of the DP each turned into one term of that formula: the $$3^K$$ is the unmasked
version I wrote first, and the $$- 3 \cdot 2^K + 3$$ is the mask.

## TODO

- **Digest the iterative `dp` / `ndp` version.** I only know how to write digit DPs as a recursion
  with `@cache`, and the usual competitive form is two flat arrays — `dp` for the current position,
  `ndp` for the next, swapped each step — which is where the constant factor goes. I haven't
  actually sat down and rewritten this one that way, and I want to, because the recursion is the
  reason I reached for "the state space is small, so it must be fast enough" instead of counting the
  work.
- Redo this one cold in a week and see whether the carry table comes out before the code does.

## What I'm taking away

**A fix that doesn't change the output didn't fix anything.** The carry formula looked wrong and
wasn't, and I spent the attention I should have spent on the missing constraint. Before believing a
fix, check that it changes a number.

**A DP can only enforce what its state can see.** `[1, 3, 3, 1][sk]` collapsed the assignment into a
count, and "each variable gets at least one bit" is a fact about the whole path, not about a
position. Anything the base case needs to ask has to be carried there.

**Round wrong answers are readable.** 9 and 27 on inputs with popcount 2 and 3 said
$$3^{\text{popcount}}$$ out loud, which named the exact over-count and pointed straight at the
missing condition. Worth pausing on a wrong answer to see whether it's a formula in disguise.

**Write the transition table out by hand.** My loop over $$s_k \in \{0,1,2,3\}$$ made it look like
there were up to four branches everywhere; enumerating the cases showed two of the four states are
dead ends and the carry is always zero. The DP was correct, but it was spending 960 states to
rediscover the same fact on every test case — and the table said so before the timer did.
