
---
layout: post
title: "June 21, 2025"
date: 2025-06-21 10:00:00 +0530
categories: introduction personal
tags: [cp, dynamic-programming]
author: "Seroze"
published: true
---

Todo:

1. prove that this covers all valid cases
2. prove that sum should only be taken if (r-l)%(k-1) == 0

```python

from functools import lru_cache

"""
dp(l, r) = minimum cost to merge stones[l...r] into the smallest possible number of piles, where:

If (r-l) % (k-1) == 0, it can merge down to 1 pile (and we add the sum).

Otherwise, it merges down to (r-l+1) % (k-1) + 1 piles (and we don't add the sum).



"""
class Solution:
    def mergeStones(self, stones, k):
        n = len(stones)
        if (n - 1) % (k - 1): return -1

        prefix = [0] * (n + 1)
        for i in range(n):
            prefix[i + 1] = prefix[i] + stones[i]

        @lru_cache(None)
        def dp(l, r):
            if r - l + 1 < k: return 0  # No merge needed
            res = float('inf')
            for m in range(l, r, k - 1):  # Ensure left part can merge to 1
                res = min(res, dp(l, m) + dp(m + 1, r))
            if (r - l) % (k - 1) == 0:  # Can merge to 1 pile
                res += prefix[r + 1] - prefix[l]
            return res

        return dp(0, n - 1)
```
