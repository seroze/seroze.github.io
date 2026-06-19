---
layout: post
title: "Möbius Function in Competitive Programming"
date: 2026-06-18 00:00:00 +0530
categories: competitive-programming
tags: [competitive-programming, number-theory, mobius]
author: "Seroze"
published: true
---

*The Möbius function is a scalpel for problems that look like inclusion-exclusion but are too slow to brute force.*

---

## Definition

The Möbius function $$\mu(n)$$ is defined as:

$$
\mu(n) = \begin{cases}
1 & \text{if } n = 1 \\
(-1)^k & \text{if } n \text{ is a product of } k \text{ distinct primes} \\
0 & \text{if } n \text{ has a squared prime factor}
\end{cases}
$$

Examples:

| n | factorization | $$\mu(n)$$ |
|---|---|---|
| 1 | — | 1 |
| 2 | prime | -1 |
| 3 | prime | -1 |
| 4 | $$2^2$$ | 0 |
| 6 | $$2 \cdot 3$$ | 1 |
| 12 | $$2^2 \cdot 3$$ | 0 |
| 30 | $$2 \cdot 3 \cdot 5$$ | -1 |

The zero entries are the key — any number divisible by a perfect square is "killed." This is what makes Möbius useful for square-free counting and inclusion-exclusion.

---

## The key identity

$$
\sum_{d \mid n} \mu(d) = [n = 1]
$$

The sum of $$\mu(d)$$ over all divisors $$d$$ of $$n$$ equals 1 if $$n = 1$$ and 0 otherwise. This is the engine behind almost every Möbius application — it lets you isolate exactly the $$n = 1$$ case from a sum.

---

## Computing μ(n) — linear sieve

You can compute $$\mu$$ for all numbers up to $$N$$ in $$O(N)$$ using a linear sieve.

```cpp
const int MAXN = 1e6 + 5;
int mu[MAXN];
bool is_composite[MAXN];
vector<int> primes;

void compute_mobius(int n) {
    mu[1] = 1;
    for (int i = 2; i <= n; i++) {
        if (!is_composite[i]) {
            primes.push_back(i);
            mu[i] = -1;          // i is prime: mu = -1
        }
        for (int p : primes) {
            if ((long long)i * p > n) break;
            is_composite[i * p] = true;
            if (i % p == 0) {
                mu[i * p] = 0;   // i*p has p^2 as factor
                break;
            } else {
                mu[i * p] = -mu[i]; // i*p gets one more distinct prime
            }
        }
    }
}
```

After this, `mu[i]` holds $$\mu(i)$$ for every $$i$$ from 1 to $$n$$.

---

## Möbius inversion

The inversion formula lets you recover $$g$$ from $$f$$ when $$f$$ is a sum of $$g$$ over divisors.

**Forward:** if $$f(n) = \displaystyle\sum_{d \mid n} g(d)$$

**Inverse:** then $$g(n) = \displaystyle\sum_{d \mid n} \mu\!\left(\frac{n}{d}\right) f(d)$$

Think of it as the multiplicative analogue of prefix sums and difference arrays. $$f$$ is the "prefix sum" over divisors, and applying $$\mu$$ recovers the original $$g$.

---

## Application 1 — counting coprime pairs

**Problem:** count pairs $$(a, b)$$ with $$1 \le a \le n$$, $$1 \le b \le m$$, and $$\gcd(a, b) = 1$$.

The trick is to express the gcd condition using the key identity:

$$
[\gcd(a,b) = 1] = \sum_{d \mid \gcd(a,b)} \mu(d)
$$

So the count becomes:

$$
\sum_{a=1}^{n} \sum_{b=1}^{m} \sum_{d \mid \gcd(a,b)} \mu(d)
$$

Swap the order — sum over $$d$$ first, then count pairs where $$d \mid a$$ and $$d \mid b$$:

$$
= \sum_{d=1}^{\min(n,m)} \mu(d) \cdot \left\lfloor \frac{n}{d} \right\rfloor \cdot \left\lfloor \frac{m}{d} \right\rfloor
$$

This runs in $$O(N)$$ after precomputing $$\mu$$.

```cpp
long long count_coprime_pairs(int n, int m) {
    long long ans = 0;
    for (int d = 1; d <= min(n, m); d++) {
        if (mu[d] != 0) {
            ans += (long long)mu[d] * (n / d) * (m / d);
        }
    }
    return ans;
}
```

Skipping `mu[d] == 0` gives a small constant speedup since roughly 40% of integers are square-free.

---

## Application 2 — counting integers in [1, n] coprime to m

**Problem:** given $$n$$ and $$m$$, count integers in $$[1, n]$$ that are coprime to $$m$$.

Only the prime factors of $$m$$ matter (squared factors contribute 0 via $$\mu$$). So iterate over divisors of $$m$$:

$$
\text{answer} = \sum_{d \mid m} \mu(d) \cdot \left\lfloor \frac{n}{d} \right\rfloor
$$

```cpp
long long count_coprime_to_m(int n, int m) {
    // get all divisors of m
    vector<int> divs;
    for (int d = 1; (long long)d * d <= m; d++) {
        if (m % d == 0) {
            divs.push_back(d);
            if (d != m / d) divs.push_back(m / d);
        }
    }

    long long ans = 0;
    for (int d : divs) {
        ans += (long long)mu[d] * (n / d);
    }
    return ans;
}
```

Note: $$m$$ can be large here — $$\mu$$ is only needed for divisors of $$m$$, not all integers up to $$n$$, so you don't need a full sieve.

---

## Application 3 — sum of gcd over all pairs

**Problem:** compute $$\displaystyle\sum_{a=1}^{n} \sum_{b=1}^{n} \gcd(a, b)$$.

Write $$\gcd(a,b)$$ as a sum over its divisors:

$$
\gcd(a, b) = \sum_{d \mid \gcd(a,b)} \phi(d)
$$

where $$\phi$$ is Euler's totient. This gives:

$$
\sum_{d=1}^{n} \phi(d) \cdot \left\lfloor \frac{n}{d} \right\rfloor^2
$$

$$\phi$$ and $$\mu$$ are related: $$\phi(n) = \displaystyle\sum_{d \mid n} \mu(d) \cdot \frac{n}{d}$$, so both can be computed in the same sieve.

```cpp
int phi[MAXN];

void compute_phi_and_mobius(int n) {
    phi[1] = 1; mu[1] = 1;
    // ... same sieve structure, fill phi alongside mu
}

long long sum_of_gcd(int n) {
    long long ans = 0;
    for (int d = 1; d <= n; d++) {
        ans += (long long)phi[d] * (n / d) * (n / d);
    }
    return ans;
}
```

---

## The mental model

Most Möbius problems follow the same pattern:

1. You want to count something with a divisibility or gcd condition.
2. That condition is hard to enforce directly.
3. Replace the condition with $$\displaystyle\sum_{d \mid \gcd} \mu(d)$$ using the key identity.
4. Swap summation order to put $$d$$ on the outside.
5. The inner sum collapses to a floor division: $$\left\lfloor n/d \right\rfloor$$.

The swap is the whole trick. Once $$d$$ is on the outside, you're just iterating over integers and multiplying floor values — which is fast.

---

## Quick reference

| What you need | Formula |
|---|---|
| $$[\gcd(a,b) = 1]$$ | $$\displaystyle\sum_{d \mid \gcd(a,b)} \mu(d)$$ |
| Count pairs with $$\gcd = 1$$ | $$\displaystyle\sum_d \mu(d) \lfloor n/d \rfloor \lfloor m/d \rfloor$$ |
| Count integers in $$[1,n]$$ coprime to $$m$$ | $$\displaystyle\sum_{d \mid m} \mu(d) \lfloor n/d \rfloor$$ |
| Recover $$g$$ from $$f = \sum_{d \mid n} g(d)$$ | $$g(n) = \displaystyle\sum_{d \mid n} \mu(n/d)\, f(d)$$ |
| $$\phi(n)$$ via $$\mu$$ | $$\displaystyle\sum_{d \mid n} \mu(d) \cdot (n/d)$$ |
