---
layout: post
title: "[Codeforces] Round 1103 (Div. 3) F1 — Elections in Saransk (Easy Version): Prime-wise Counting"
date: 2026-07-10 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, number_theory, codeforces]
author: "Seroze"
published: true
---

*[Codeforces Round 1103 (Div. 3) — Problem F1: Elections in Saransk (easy version)](https://codeforces.com/contest/2246/problem/F1) (rated 1700, $$x = 1$$ in this version). The condition looks like it's about LCM, but the real trick is to stop thinking about numbers entirely and think prime by prime.*

---

## The problem

There are $$n$$ voters. Voter $$i$$ brings a number $$a_i$$ and, in the voting booth, chooses any divisor $$p_i$$ of $$a_i$$ as their candidate. This produces an array of votes $$[p_1, p_2, \ldots, p_n]$$.

A voting is **ideal** if

$$x \cdot \operatorname{lcm}(p_1, p_2, \ldots, p_n) = p_1 \cdot p_2 \cdots p_n.$$

In this version $$x = 1$$, so the condition simplifies to

$$\operatorname{lcm}(p_1, p_2, \ldots, p_n) = p_1 \cdot p_2 \cdots p_n.$$

Count the number of distinct ideal arrays $$p$$, modulo $$10^9 + 7$$. Constraints: sum of $$n$$ up to $$10^5$$, $$a_i \le 5 \times 10^5$$.

At first glance this looks hard because it involves the LCM of all chosen divisors simultaneously. The way in is to fix a single prime and see what the condition forces.

## Key observation: work prime by prime

Fix a prime $$q$$. Let the exponent of $$q$$ in the chosen divisors be

$$f_1, f_2, \ldots, f_n.$$

Then:

- the exponent of $$q$$ in the **product** $$p_1 \cdots p_n$$ is $$f_1 + f_2 + \cdots + f_n$$,
- the exponent of $$q$$ in the **LCM** is $$\max(f_1, f_2, \ldots, f_n)$$.

For $$\operatorname{lcm} = \text{product}$$ to hold, every prime must satisfy

$$\max(f_i) = \sum_i f_i.$$

Since all $$f_i \ge 0$$, a max can only equal a sum of non-negative terms if **at most one term is positive**. So for every prime, at most one voter is allowed to contribute a nonzero exponent of that prime — everyone else must choose exponent $$0$$ for it.

## Counting choices for one prime

Suppose prime $$q$$ appears in the original numbers with exponents $$e_1, e_2, \ldots, e_n$$ (i.e. $$q^{e_i} \| a_i$$). Voter $$i$$'s chosen exponent for $$q$$ can be anything from $$0$$ to $$e_i$$, since it must divide $$a_i$$.

To satisfy the "at most one positive exponent" rule, the valid choices are:

- everyone picks exponent $$0$$ — **1 way**,
- only voter $$1$$ picks a positive exponent — $$e_1$$ ways (exponent $$1$$ through $$e_1$$),
- only voter $$2$$ picks a positive exponent — $$e_2$$ ways,
- $$\ldots$$
- only voter $$n$$ picks a positive exponent — $$e_n$$ ways.

These cases are mutually exclusive, so prime $$q$$ contributes a factor of

$$1 + \sum_i e_i$$

to the total count.

## Independence between primes

Exponents of different primes are chosen completely independently — voter $$i$$'s choice for prime $$q$$ doesn't constrain their choice for prime $$q'$$. So the final answer is just the product over all primes of each prime's contribution:

$$\prod_{q \text{ prime}} \left( 1 + \sum_i v_q(a_i) \right)$$

where $$v_q(a_i)$$ is the exponent of $$q$$ in $$a_i$$. Primes that don't divide any $$a_i$$ contribute a factor of $$1$$, so they're free to ignore.

## Implementation

All that's left is computing, for every prime up to $$5 \times 10^5$$, the total exponent summed across all $$a_i$$ in the test case.

Precompute the **smallest prime factor (SPF)** sieve once, up to $$5 \times 10^5$$. Then for each $$a_i$$:

- repeatedly divide by its SPF,
- count how many times each prime divides it,
- accumulate that count into a per-prime total.

Finally, multiply $$(\text{totalExponent}_q + 1)$$ over every prime $$q$$ with a nonzero total, modulo $$10^9 + 7$$.

```python
import sys

def solve():
    input_data = sys.stdin.buffer.read().split()
    idx = 0
    def nxt():
        nonlocal idx
        v = input_data[idx]
        idx += 1
        return v

    MOD = 10**9 + 7
    MAXA = 5 * 10**5 + 1

    # smallest prime factor sieve
    spf = list(range(MAXA))
    for i in range(2, int(MAXA**0.5) + 1):
        if spf[i] == i:
            for j in range(i * i, MAXA, i):
                if spf[j] == j:
                    spf[j] = i

    t = int(nxt())
    out = []
    for _ in range(t):
        n = int(nxt())
        x = int(nxt())  # always 1 in the easy version
        a = [int(nxt()) for _ in range(n)]

        total_exp = {}
        for v in a:
            while v > 1:
                p = spf[v]
                cnt = 0
                while v % p == 0:
                    v //= p
                    cnt += 1
                total_exp[p] = total_exp.get(p, 0) + cnt

        ans = 1
        for exp_sum in total_exp.values():
            ans = (ans * (exp_sum + 1)) % MOD

        out.append(str(ans))

    print('\n'.join(out))

solve()
```

Sanity-checking against the sample:

- `4 1 / 2 3 1 4` → prime 2 has exponents $$1, 0, 0, 2$$ (sum $$3$$, contributes $$4$$); prime 3 has exponents $$0,1,0,0$$ (sum $$1$$, contributes $$2$$). Answer: $$4 \times 2 = 8$$. ✓
- `2 1 / 2 4` → prime 2 exponents $$1, 2$$ (sum $$3$$, contributes $$4$$). Answer: $$4$$. ✓

Both match the expected output.

## Complexity

- SPF sieve preprocessing: $$O(M \log \log M)$$ where $$M = 5 \times 10^5$$, computed once.
- Factoring all numbers: $$O(\sum \log a_i)$$ per test case.

Well within the limits for sum of $$n \le 10^5$$.

## What I learned

The biggest takeaway from this problem is that identities involving LCM and product become much simpler once you stop treating numbers as monolithic quantities and instead decompose them into prime exponents. The relation $$\operatorname{lcm} = \text{product}$$ looks like a global, entangled constraint on $$n$$ numbers — but viewed prime-wise, it collapses into an independent, almost trivial counting problem for each prime. Whenever a problem mixes GCD/LCM with multiplicative structure, it's worth asking: *what does this constraint look like one prime at a time?*
