---
layout: post
title: "Palindromic Subarray Sum with Rolling Hashes"
date: 2026-07-05 00:00:00 +0530
categories: competitive-programming
tags: [cp, rolling_hashing, leetcode]
author: "Seroze"
published: true
---

*[LeetCode — Palindromic Subarray Sum](https://leetcode.com/problems/palindromic-subarray-sum/description/). Find the maximum sum of a subarray that reads the same forwards and backwards. The solution is a nice combo of rolling hashes + binary search on the palindrome radius, but the real takeaway for me was about **indexing discipline** in the rolling hash implementation.*

---

## The idea

Every palindromic subarray has a center — either a single element (odd length) or a pair of equal adjacent elements (even length). For a fixed center, palindromicity is **monotone in the radius**: if `[c-m, c+m]` is a palindrome, then stripping the outer pair leaves `[c-(m-1), c+(m-1)]`, which is also a palindrome. Monotone predicate ⇒ binary search on the largest radius.

Since the values are positive, the best palindrome at each center is the *widest* one — extending a palindrome only adds to its sum. So the algorithm is:

1. For each center, binary search the maximum palindromic radius.
2. Check "is `[l, r]` a palindrome?" in O(1) by comparing a rolling hash of the subarray against a rolling hash of the same window in the reversed array.
3. Take the subarray sum via an ordinary prefix-sum array; answer is the max over all centers.

That's O(n log n) total.

## The takeaway: always use n+1 style indexing

Rolling hashes are one of those things where off-by-one errors breed. The convention that keeps it clean: **make `pref` and `pow` arrays of size `n+1`, and always query a window `(l, r)` as `pref[r+1] - pref[l] * pow[r-l+1]`.**

This mirrors the ordinary prefix-sum pattern — sum of `[l, r]` is `pref[r+1] - pref[l]` — except the left part has to be *shifted up* by the window length before subtracting, because hashes are positional.

```python
MOD = (1 << 61) - 1
BASE = 911382323

class RollingHash:
    def __init__(self, arr):
        n = len(arr)
        # always use n+1 style: (l, r) => pref[r+1] - pref[l]
        self.pow = [1] * (n + 1)
        self.pref = [0] * (n + 1)

        for i in range(n):
            self.pow[i+1] = (self.pow[i] * BASE) % MOD
            self.pref[i+1] = (self.pref[i] * BASE + arr[i] + 1) % MOD

    def get(self, l, r):
        return (
            self.pref[r+1]
            - self.pref[l] * self.pow[r - l + 1]
        ) % MOD
```

Two small details worth remembering:

- **`arr[i] + 1`**: shift every value so nothing maps to 0. A raw 0 contributes nothing to the hash, making e.g. `[0, 5]` and `[5]` collide.
- **`MOD = 2^61 - 1`**: a Mersenne prime, large enough that birthday collisions are a non-issue for contest sizes, and Python's big ints don't overflow anyway.

## Why `get` works — the algebra

This is the part worth internalizing so you can rederive `get` instead of memorizing it. The recurrence

$$\text{pref}[i+1] = \text{pref}[i] \cdot B + (a_i + 1)$$

unrolls into a polynomial in the base $$B$$ where the **first element gets the highest power**:

$$\text{pref}[k] = \sum_{i=0}^{k-1} (a_i + 1)\, B^{\,k-1-i}$$

The hash we *want* for the window $$[l, r]$$ is the same polynomial computed as if the window were its own array:

$$H(l, r) = \sum_{i=l}^{r} (a_i + 1)\, B^{\,r-i}$$

Now expand the two prefix values. First, $$\text{pref}[r+1]$$ covers indices $$0$$ through $$r$$ — split it at $$l$$:

$$\text{pref}[r+1] = \underbrace{\sum_{i=0}^{l-1} (a_i + 1)\, B^{\,r-i}}_{\text{unwanted prefix part}} + \underbrace{\sum_{i=l}^{r} (a_i + 1)\, B^{\,r-i}}_{H(l,r)}$$

Second, $$\text{pref}[l]$$ covers indices $$0$$ through $$l-1$$, but with powers relative to position $$l-1$$:

$$\text{pref}[l] = \sum_{i=0}^{l-1} (a_i + 1)\, B^{\,l-1-i}$$

Multiplying by $$B^{\,r-l+1}$$ shifts every exponent up by exactly the window length:

$$\text{pref}[l] \cdot B^{\,r-l+1} = \sum_{i=0}^{l-1} (a_i + 1)\, B^{\,(l-1-i) + (r-l+1)} = \sum_{i=0}^{l-1} (a_i + 1)\, B^{\,r-i}$$

— which is *exactly* the unwanted prefix part. Subtracting kills it:

$$\text{pref}[r+1] - \text{pref}[l] \cdot B^{\,r-l+1} = H(l, r)$$

So the mental model: `pref[l]` holds the hash of everything before the window, but "too low" in the exponent scale; multiplying by `pow[r-l+1]` lifts it into alignment with `pref[r+1]`, and the difference is the window's hash. The `r - l + 1` is just the window length — same quantity you'd use for its element count.

## Palindrome check via a reversed hash

To test whether `[l, r]` is a palindrome, hash the reversed array too and map indices: position `i` in the original is position `n-1-i` in the reversal, so window `[l, r]` maps to `[n-1-r, n-1-l]`.

```python
def is_pal(l, r) -> bool:
    h1 = fh.get(l, r)                      # forward hash
    h2 = rh.get(n - 1 - r, n - 1 - l)      # same window in reversed array
    return h1 == h2
```

## Full solution

```python
from typing import List

MOD = (1 << 61) - 1
BASE = 911382323

class RollingHash:
    def __init__(self, arr):
        n = len(arr)
        # always use n+1 style (l, r) => pref[r+1] - pref[l]
        self.pow = [1] * (n + 1)
        self.pref = [0] * (n + 1)

        for i in range(n):
            self.pow[i+1] = (self.pow[i] * BASE) % MOD
            self.pref[i+1] = (self.pref[i] * BASE + arr[i] + 1) % MOD

    def get(self, l, r):
        return (
            self.pref[r+1]
            - self.pref[l] * self.pow[r - l + 1]
        ) % MOD

class Solution:
    def getSum(self, nums: List[int]) -> int:

        n = len(nums)

        pref = [0]
        for x in nums:
            pref.append(pref[-1] + x)

        fh = RollingHash(nums)
        rh = RollingHash(nums[::-1])

        def is_pal(l, r) -> bool:
            assert l <= r

            h1 = fh.get(l, r)

            rl = n - 1 - r
            rr = n - 1 - l

            h2 = rh.get(rl, rr)

            return h1 == h2

        ans = max(nums)

        # Odd-length palindromes
        for c in range(n):

            lo = 0
            hi = min(c, n - 1 - c)

            while lo < hi:

                mid = (lo + hi + 1) // 2
                if is_pal(c - mid, c + mid):
                    lo = mid
                else:
                    hi = mid - 1

            l = c - lo
            r = c + lo
            ans = max(ans, pref[r+1] - pref[l])

        # Even-length palindromes
        for c in range(n - 1):

            if nums[c] != nums[c+1]:
                continue

            lo = 1
            hi = min(c + 1, (n - 1) - (c + 1) + 1)

            while lo < hi:

                mid = (lo + hi + 1) // 2
                if is_pal(c - mid + 1, c + mid):
                    lo = mid
                else:
                    hi = mid - 1

            l = c - lo + 1
            r = c + lo

            ans = max(ans, pref[r+1] - pref[l])

        return ans
```

## Summary

- Palindromic radius at a fixed center is a monotone predicate → binary search, with O(1) hash comparison per probe → O(n log n).
- Use **n+1 style indexing** for rolling hashes: `pow` and `pref` of size `n+1`, window `(l, r)` = `pref[r+1] - pref[l] * pow[r-l+1]`. Same shape as prefix sums, plus one exponent shift.
- The `get` formula isn't magic: `pref[l]` times $$B^{\text{window length}}$$ reproduces exactly the unwanted leading part of `pref[r+1]`, so subtracting isolates the window's hash.
- Shift values by `+1` so zeros participate in the hash, and use the Mersenne prime $$2^{61} - 1$$ as the modulus.
