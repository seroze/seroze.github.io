---
layout: post
title: "[Competitive Programming] Number Theory"
date: 2026-08-12 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, number_theory, palindromes, divisibility]
author: "Seroze"
published: true
---

*A running collection of number theory facts that turn a search problem into a one-liner. First up: every even-length palindrome is divisible by 11 — which means 11 is the only palindromic prime with an even number of digits.*

---

## Every even-length palindrome is divisible by 11

Take any palindrome with an even number of digits:

$$
11, \quad 22, \quad 1221, \quad 4554, \quad 987789
$$

Every single one is a multiple of 11:

| palindrome | factorization |
|---|---|
| 22 | $$11 \cdot 2$$ |
| 1221 | $$11 \cdot 111$$ |
| 4554 | $$11 \cdot 414$$ |
| 987789 | $$11 \cdot 89799$$ |

This is not a coincidence, and the proof is three lines.

### The divisibility rule for 11

Everything follows from one congruence:

$$
10 \equiv -1 \pmod{11}
$$

Write a number by its digits, indexing from the **least significant** digit:

$$
n = \sum_{i=0}^{k-1} d_i \cdot 10^{i}
$$

Reducing mod 11 and using $$10^i \equiv (-1)^i$$:

$$
n \equiv \sum_{i=0}^{k-1} (-1)^i d_i \pmod{11}
$$

So $$11 \mid n$$ exactly when the **alternating sum of the digits** is zero mod 11. That's the familiar rule: add the digits in even positions, subtract the digits in odd positions, check if the result is a multiple of 11.

### The palindrome argument

Let $$n$$ be a palindrome with $$2m$$ digits. Palindromicity says

$$
d_i = d_{2m-1-i} \quad \text{for all } i
$$

Now look at the two indices in each pair. They sum to

$$
i + (2m - 1 - i) = 2m - 1
$$

which is **odd**. Two integers summing to an odd number must have opposite parity. So each pair consists of one even index and one odd index — carrying the *same* digit.

The map $$i \mapsto 2m-1-i$$ has no fixed point (a fixed point would need $$2i = 2m-1$$, impossible for an integer), so it partitions all $$2m$$ positions into exactly $$m$$ disjoint pairs. Each pair contributes $$+d_i - d_i = 0$$ to the alternating sum. Therefore

$$
\sum_{i=0}^{2m-1} (-1)^i d_i = 0 \implies 11 \mid n
$$

$$\blacksquare$$

Concretely, for $$4554$$:

$$
4 - 5 + 5 - 4 = 0
$$

The palindrome hands you the cancellation for free.

### Why odd length is different

For odd length the same pairing leaves one digit stranded in the middle, and it pairs $$i$$ with $$2m-i$$ — indices of the **same** parity, so they add instead of cancelling. Nothing collapses:

- $$121 = 11^2$$ — divisible by 11, but by accident
- $$131$$ — prime
- $$151$$ — prime
- $$313$$ — prime

Odd-length palindromes are unconstrained, which is exactly why all the interesting palindromic primes live there.

### The corollary that matters

An even-length palindrome $$n$$ satisfies $$11 \mid n$$ and $$n \ge 11$$. If $$n$$ is also prime, its only divisors are 1 and itself, so $$n = 11$$.

> **11 is the only palindromic prime with an even number of digits.**

The full list of palindromic primes starts:

$$
2,\; 3,\; 5,\; 7,\; 11,\; 101,\; 131,\; 151,\; 181,\; 191,\; 313,\; \dots
$$

One even-length entry, then never again — no matter how far you go.

---

## Where this shows up: CodeChef MD_RIEV

[Palindromic Prime Numbers](https://www.codechef.com/problems/MD_RIEV) (CodeChef Starters 108) asks:

> Consider the first $$N$$ palindromic prime numbers. How many of them have an even number of digits, and how many have an odd number of digits?

Without the fact above this looks like it needs a sieve, a palindrome check, and some bound on how far you have to search to collect $$N$$ of them — and $$N$$ can be large enough that you can't actually generate them.

With the fact, the answer is a case split on where 11 sits in the ordering. The palindromic primes in order are $$2, 3, 5, 7, 11, 101, \dots$$ — so 11 is the **5th** one, and it is the only even-length one that will ever appear.

- $$N \le 4$$: you haven't reached 11 yet → `0` even, `N` odd
- $$N \ge 5$$: you have exactly one even-length one → `1` even, `N - 1` odd

```cpp
#include <bits/stdc++.h>
using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    int t;
    cin >> t;
    while (t--) {
        long long n;
        cin >> n;
        if (n <= 4) cout << 0 << " " << n << "\n";
        else        cout << 1 << " " << n - 1 << "\n";
    }
    return 0;
}
```

$$O(1)$$ per test case. No sieve, no palindrome check, no precomputation.

The lesson generalises past this problem: when a counting problem is about primes *and* some digit structure, check whether the digit structure forces a divisor. If it does, the "primes" half of the problem usually collapses to a handful of small cases.

---

## The generalisation to other bases

Nothing about the argument was specific to base 10. In base $$b$$:

$$
b \equiv -1 \pmod{b + 1}
$$

so the identical alternating-sum argument gives:

> In base $$b$$, every even-length palindrome is divisible by $$b + 1$$.

Which means in base $$b$$, the only even-length palindromic prime is $$b + 1$$ itself — and only when $$b+1$$ is prime.

| base | even-length palindromes divisible by | only even-length palindromic prime |
|---|---|---|
| 2 | 3 | $$11_2 = 3$$ |
| 8 | 9 | none ($$9 = 3^2$$) |
| 10 | 11 | $$11$$ |
| 16 | 17 | $$11_{16} = 17$$ |

Binary is a nice sanity check: $$11_2 = 3$$, $$1001_2 = 9$$, $$1111_2 = 15$$, $$100001_2 = 33$$ — all multiples of 3.

---

## The same trick powers every divisibility rule

Every schoolbook divisibility rule is the same move: find what $$10$$ (or a power of it) is congruent to, mod your target.

| modulus | key congruence | resulting rule |
|---|---|---|
| 3, 9 | $$10 \equiv 1$$ | sum of digits |
| 11 | $$10 \equiv -1$$ | alternating sum of digits |
| 7, 11, 13 | $$10^3 \equiv -1 \pmod{1001}$$ | alternating sum of 3-digit groups |
| 2, 5 | $$10 \equiv 0$$ | last digit |
| 4, 25 | $$10^2 \equiv 0$$ | last two digits |
| $$2^k, 5^k$$ | $$10^k \equiv 0$$ | last $$k$$ digits |

The $$1001 = 7 \cdot 11 \cdot 13$$ row is the underused one. Since $$10^3 \equiv -1 \pmod{1001}$$, group the digits in threes from the right and alternate:

$$
1{,}234{,}567 \to 1 - 234 + 567 = 334
$$

and $$334$$ is not divisible by 7, 11, or 13 — so neither is $$1234567$$. One computation resolves three moduli at once.

---

## Quick reference

| Fact | Statement |
|---|---|
| Rule for 11 | $$n \equiv \sum (-1)^i d_i \pmod{11}$$ |
| Even-length palindromes | always divisible by 11 |
| Even-length palindromic primes | only 11 |
| Odd-length palindromes | no forced divisor |
| Base $$b$$ version | even-length palindromes divisible by $$b+1$$ |
| MD_RIEV answer | $$N \le 4 \to (0, N)$$; else $$(1, N-1)$$ |
