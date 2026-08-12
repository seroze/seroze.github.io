---
layout: post
title: "[Competitive Programming] Dynamic Programming"
date: 2026-08-12 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, dynamic_programming, number_theory]
author: "Seroze"
published: true
---

*A running collection of DP patterns. First up: DP on residues, and why writing transitions in "push" style — `dp[i+1] += dp[i]` — keeps the implementation clean.*

---

## DP on residues

Some problems ask you to count assignments subject to a **divisibility** constraint: build a number divisible by 9, pick a subset summing to a multiple of $$k$$, choose digits so the total is $$\equiv 0 \pmod m$$.

The naive state — "the running sum so far" — is unbounded. The fix is that you never need the sum itself, only the sum **mod $$m$$**, because the constraint only ever looks at the residue. That collapses an infinite state space to exactly $$m$$ buckets.

The shape is almost always:

$$
dp[i][r] = \text{number of ways to assign the first } i \text{ positions so the running total} \equiv r \pmod m
$$

with base case $$dp[0][0] = 1$$ (the empty assignment has sum 0), and the answer read off at the residue that completes the constraint. Cost is $$O(n \cdot m \cdot C)$$ for $$C$$ choices per position.

The only real modelling work is deciding what "the total" means. For divisibility by 9 there's a shortcut: a number is divisible by 9 iff its **digit sum** is, so you can track the digit sum mod 9 and never handle the number itself.

---

## The problem — CodeChef MULT9

[Multiple of 9](https://www.codechef.com/problems/MULT9) (CodeChef Starters 108).

> You're given an $$N$$-digit number as a string, with some digits replaced by `?`. Count the ways to fill in every `?` with a digit `0`–`9` so the result is a positive integer with **no leading zero** and is **divisible by 9**.

**Solution sketch.** Divisibility by 9 depends only on the digit sum, so split the digit sum into two parts: the fixed contribution from the known digits, and whatever the `?`s contribute. Let $$S$$ be the sum of the known digits and $$m$$ the number of `?`s. We need

$$
S + (\text{sum of chosen digits}) \equiv 0 \pmod 9
$$

so the `?`s must contribute exactly $$(9 - S) \bmod 9$$. Now count assignments of $$m$$ digits by their sum mod 9 — a textbook residue DP with $$m$$ positions, 9 residues, and 10 choices each. The only wrinkle is the leading-zero rule: if the first character is a `?`, that one position can't take 0.

---

## The code

```python
# cook your dish here

def solve():
    n = int(input())
    s = input()

    known_dig_sum = sum( int(ch) for ch in s if ch != '?')
    m = s.count('?')

    dp = [[0]*9 for _ in range(m+1)]
    dp[0][0] = 1

    for i in range(m):
        for r in range(9): # previous residue
            for d in range(10): # current digit

                if i == 0 and s[0] == '?' and d == 0:
                    continue

                dp[i+1][(r+d)%9] += dp[i][r]


    ans = dp[m][(9-known_dig_sum)%9]
    print(ans)


tc = int(input())

for _ in range(tc):
    solve()
```

Here $$dp[i][r]$$ is *the number of ways to assign the first $$i$$ question marks so their digits sum to $$r$$ mod 9*. Note the state indexes the `?` positions only — the known digits never enter the DP, they're folded into `known_dig_sum` once at the start.

The leading-zero rule is the `continue`. It fires only when `i == 0` and `s[0] == '?'` — and if `s[0]` is a `?` then the first `?` processed *is* `s[0]`, so exactly the right position gets constrained.

---

## The point: `dp[i+1] += dp[i]`, not `dp[i+1] = f(dp[i])`

This is the part worth internalising. There are two ways to write any DP transition.

**Pull** — sit on the state you're filling and ask where it could have come from:

```python
for r in range(9):
    for d in range(10):
        dp[i+1][r] += dp[i][(r - d) % 9]   # invert the transition
```

**Push** — sit on a state you've already computed and send it forward:

```python
for r in range(9):
    for d in range(10):
        dp[i+1][(r + d) % 9] += dp[i][r]   # follow the transition
```

Both are correct here, but push is the one that stays clean, for four reasons:

**1. It matches how you describe the problem.** You say "I'm at position $$i$$ with residue $$r$$; I choose digit $$d$$; I land at $$(r+d) \bmod 9$$." The push loop is that sentence transcribed. The pull loop makes you say it backwards.

**2. No inverting the transition.** Push uses `(r + d) % 9` — the actual rule. Pull needs `(r - d) % 9`, the inverse, which is where the off-by-one and negative-modulo bugs live. In Python `%` is safe on negatives; in C++ `(r - d) % 9` is *negative* and silently indexes out of bounds. Push never creates that trap.

**3. Constraints become a `continue` at the point of choice.** The no-leading-zero rule is one guard sitting exactly where the digit is chosen — read it and you immediately see which digit is being forbidden. In pull style the same rule becomes "skip the predecessor $$(r - 0) \bmod 9$$ when $$i = 0$$," which describes a *source state* rather than a forbidden choice. Same output, much worse to read.

**4. It still works when the transition isn't invertible.** This is the real reason. Pull requires enumerating the **preimages** of each state; push only requires enumerating the **images**. Here $$d \mapsto (r+d) \bmod 9$$ happens to be easy to invert, so pull is merely uglier. In general — transitions that jump by a computed offset, that clamp, that merge several states into one — there's no clean formula for "which states lead here," and pull stops being writable at all. Learning push as the default means the style doesn't break when the problem gets harder.

The mechanical recipe: **initialise the whole table to zero, set the base case, then loop over (state you have) × (choice you make) and `+=` into the state you land on.** You never write an explicit formula for `dp[i+1][r]`; the entry assembles itself from every path that reaches it.

---

## A caveat on the constraints

The DP above is correct — I checked it against brute force on ~18,000 random inputs and it matches everywhere — but it will not pass MULT9 at full size.

There's no modulus in this problem: you print the exact count, which for $$N \le 10^5$$ is a number with up to $$10^5$$ digits. So every `+=` is a **bignum** addition on operands that keep growing, and the $$90m$$ additions cost $$O(m^2)$$ digit operations overall. Measured on my machine:

| $$m$$ | time |
|---|---|
| 8,000 | 0.21 s |
| 16,000 | 0.81 s |
| 32,000 | 3.03 s |
| 100,000 | 28.83 s |

Clean quadratic — 4× the input for ~16× the time. Fine as a reference implementation and for checking small cases, too slow for the judge.

(A related Python trap if you do print numbers this big: since 3.11, `str()` on an int over 4,300 digits raises `ValueError` unless you call `sys.set_int_max_str_digits(...)` first.)

---

## TODO — the closed form

MULT9 has a **closed-form solution**: you can write down the answer directly from $$m$$, whether `s[0]` is a `?`, and the residue of the known digit sum — no DP, no bignum loop, $$O(N)$$ to construct the output string. That's the intended solution and it's what actually passes.

Writing up the derivation is a TODO for a follow-up post.

---

## Quick reference

| Idea | Form |
|---|---|
| Residue state | $$dp[i][r]$$ = ways to assign first $$i$$ items with total $$\equiv r \pmod m$$ |
| Base case | $$dp[0][0] = 1$$ |
| Divisibility by 9 | track the digit sum mod 9, not the number |
| Push transition | `dp[i+1][(r + d) % m] += dp[i][r]` |
| Pull transition | `dp[i+1][r] += dp[i][(r - d) % m]` — avoid; needs the inverse |
| Local constraint | a `continue` guard at the point of choice |
