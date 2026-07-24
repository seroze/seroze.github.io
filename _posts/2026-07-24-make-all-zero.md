---
layout: post
title: "[CodeChef] Starters 115 — Make All Zero: Only Prefix Minima Can Be Eliminated"
date: 2026-07-24 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, binary_search, greedy, codechef]
author: "Seroze"
published: true
---

*[CodeChef Starters 115 — Make All Zero](https://www.codechef.com/problems/MAKE0?tab=statement). A problem where the entire difficulty lives in one structural observation: only prefix minima can ever be eliminated by prefix operations. After that, it's binary search.*

---

## The Problem

Given an array $$A$$ of size $$N$$, make every element zero using the minimum number of operations. Two operations are allowed:

- **Prefix operation:** choose $$x$$ and decrement $$A_1, \dots, A_x$$ by 1 — allowed only while no element in that prefix is already zero.
- **Point operation:** choose $$x$$ and set $$A_x = 0$$ directly.

Constraints: $$N \le 2 \times 10^5$$, $$A_i \le 10^9$$.

## Setup

Build the **prefix minimum array** — the elements $$A_i$$ that are strictly at most every element before them. This array is non-increasing, so the prefix minima with value at most $$x$$ form a *suffix* of it.

Define

$$Z(x) = \text{number of prefix minima with value} \le x$$

so $$Z(x)$$ is simply the length of that suffix. Binary search gives $$O(\log N)$$ per query. Trying every possible $$x = 0 \dots N-1$$ results in $$O(N \log N)$$, which easily fits the constraints.

## Algorithm

1. Construct the prefix minimum array.
2. For every $$x$$ from $$0$$ to $$N-1$$:
   - Binary search to count prefix minima $$\le x$$.
   - Compute

$$\text{cost} = x + N - Z(x)$$

3. Output the minimum cost.

## Correctness Proof

We prove that the algorithm always finds the optimal answer.

### Lemma 1

*All point operations can be postponed until after every prefix operation.*

**Proof.** A point operation only turns one element into zero. Doing it earlier never enables additional prefix operations; in fact, it may prevent using prefixes containing that index. Therefore moving every point operation to the end cannot increase the number of operations.

### Lemma 2

*If an element is not a prefix minimum, it cannot become zero using only prefix operations.*

**Proof.** Suppose $$A[j] < A[i]$$ for some $$j < i$$. Every prefix affecting $$i$$ also affects $$j$$. Since $$A[j]$$ is smaller, it reaches zero first. After that, no prefix including $$i$$ can be chosen, so $$i$$ can never reach zero.

Hence every non-prefix-minimum requires a point operation.

### Lemma 3

*After performing exactly $$x$$ prefix operations, precisely the prefix minima whose values are at most $$x$$ can become zero.*

**Proof.** A prefix minimum with value $$v$$ needs exactly $$v$$ decrements. If $$v \le x$$, enough prefix operations exist to eliminate it. If $$v > x$$, it cannot reach zero. By Lemma 2, no non-prefix-minimum can become zero. Therefore exactly $$Z(x)$$ elements become zero.

### Theorem

For every possible number of prefix operations $$x$$, the total cost is

$$x + N - Z(x)$$

Taking the minimum over all $$x$$ therefore produces the optimal answer.

## Complexity

- Building the prefix minimum array: $$O(N)$$
- Binary searching for every $$x$$: $$N \times O(\log N)$$
- Overall: $$O(N \log N)$$
- Space complexity: $$O(N)$$

## Reference Implementation (Python)

```python
for _ in range(int(input())):
    n = int(input())
    a = list(map(int, input().split()))

    mins = []
    for x in a:
        if not mins or x <= mins[-1]:
            mins.append(x)

    def count_zeroable(x):
        m = len(mins)

        if mins[-1] > x:
            return 0
        if mins[0] <= x:
            return m

        l, r = 0, m - 1
        while l < r:
            mid = (l + r) // 2
            if mins[mid] <= x:
                r = mid
            else:
                l = mid + 1

        return m - l

    ans = n
    for x in range(n):
        ans = min(ans, x + n - count_zeroable(x))

    print(ans)
```

## Takeaway

The hardest part of this problem is not the binary search or the implementation. It's recognizing the structural property:

> **Only prefix minima can ever be eliminated using prefix operations.**

Once that observation is made, the optimization reduces to choosing how many prefix operations to perform and evaluating the resulting cost. The rest is a straightforward application of binary search over the prefix minima array.
