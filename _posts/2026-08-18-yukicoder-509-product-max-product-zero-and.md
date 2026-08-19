---
layout: post
title: "[yukicoder] Contest 509 — Product: the answer is always 2^k times 2^k-1"
date: 2026-08-18 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, yukicoder, bitmasks, greedy]
author: "Seroze"
published: true
---

Problem: [yukicoder No.3624 Product](https://yukicoder.me/problems/no/3624)

Given $$L \le R$$, maximise $$a \cdot b$$ over pairs with $$L \le a, b \le R$$ and $$a \,\&\, b = 0$$, or print $$-1$$ if no such pair exists. Up to $$10^5$$ queries, $$R \le 10^9$$.

The whole thing collapses to one candidate pair. Let $$k$$ be the index of the top set bit of $$R$$. If $$L \ge 2^k$$ the answer is $$-1$$; otherwise it is $$2^k (2^k - 1)$$.

## Proof structure

The argument has three legs, and skipping any one of them leaves a real gap.

**1. Disjointness turns addition into OR.** If $$a \,\&\, b = 0$$ there are no carries anywhere, so $$a + b = a \mathbin{\vert} b$$. This holds for *every* legal pair, not just the optimal one — it is a consequence of the constraint, not of maximising.

**2. Bound the sum.** Both numbers are at most $$R < 2^{k+1}$$, so neither has a bit above position $$k$$. They cannot both hold bit $$k$$, since that would make the AND nonzero. Hence $$a + b = a \mathbin{\vert} b \le 2^k + (2^k - 1) = S$$ where $$S = 2^{k+1} - 1$$.

**3. Bound the product, and close the gap.** Max sum alone does *not* imply max product — $$1 \cdot 99$$ beats nothing, while $$25 \cdot 25 = 625$$ wins with half the sum. AM–GM only compares pairs *within* a fixed sum, so you need both halves. At $$a + b = S$$ (odd), the most balanced integer split is exactly $$2^k (2^k - 1) = (S^2 - 1)/4$$. And any pair with a smaller sum is capped at $$((S-1)/2)^2 = (S-1)^2/4$$, which loses because $$(S-1)^2 < (S-1)(S+1) = S^2 - 1$$. So even a perfectly balanced smaller-sum pair cannot sneak past.

Then feasibility, which is the step that is easy to wave at: $$2^k \le R$$ by definition of $$k$$, and $$2^k - 1 \ge L$$ is precisely the non-$$-1$$ condition. The other two containments follow for free, so the candidate really is in range whenever we print it.

The test $$L \ge 2^k$$ is just "$$L$$ and $$R$$ have the same bit length" in disguise, so there is no separate MSB comparison to write. Two edge cases: $$R = 0$$ forces $$L = 0$$, and $$0 \,\&\, 0 = 0$$ is legal, so the answer is $$0$$ rather than $$-1$$ — and the MSB is undefined there anyway. Also $$2^{29}(2^{29}-1) \approx 2.9 \times 10^{17}$$ overflows 32 bits, so use 64-bit (or Python).

```python
for _ in range(int(input())):
    L, R = map(int, input().split())
    k = R.bit_length() - 1
    hi = 1 << k
    print(0 if R == 0 else (-1 if L >= hi else hi * (hi - 1)))
```

With $$T$$ up to $$10^5$$ the I/O dominates the arithmetic, so in a real submission read everything with `sys.stdin.buffer.read()` and emit one joined write. `bit_length()` gives the MSB directly — no `math.log2` float precision to worry about.
