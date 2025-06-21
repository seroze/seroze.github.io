---
layout: post
title: "June 21, 2025"
date: 2025-06-21 10:00:00 +0530
categories: introduction personal
tags: [cp]
author: "Seroze"
published: true
---

How do count number of unique permutations you can generate from a given list
There's this trick, I should call it as track_prev trick. But one should sort
the input list before applying this trick.

Two things to prove
1. Does it cover all valid cases
2. Does it avoid duplicates (you avoid by not branching into a duplicate case)



```python

https://leetcode.com/problems/number-of-squareful-arrays/description/

from math import sqrt

class Solution:
    def numSquarefulPerms(self, nums: List[int]) -> int:
        # digit dp
        n = len(nums)
        nums.sort()  # Sort to handle duplicates

        def is_perfect_square(x):
            sq = int(sqrt(x))
            return sq * sq == x

        def solve(mask, last):
            if mask == (1 << n) - 1:
                return 1
            cnt = 0
            prev = -1  # To track the previous number to skip duplicates
            for i in range(n):
                if (mask >> i) & 1:
                    continue
                if nums[i] == prev:
                    continue  # Skip duplicates
                if last == -1 or is_perfect_square(nums[i] + nums[last]):
                    prev = nums[i]
                    cnt += solve(mask | (1 << i), i)
            return cnt

        return solve(0, -1)

```
