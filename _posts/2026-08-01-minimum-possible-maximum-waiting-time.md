---
layout: post
title: "[Leetcode] Minimum Possible Maximum Waiting Time"
date: 2026-08-01 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, leetcode, dynamic_programming, binary_search, scheduling]
author: "Seroze"
published: true
---

*[LeetCode — Minimum Possible Maximum Waiting Time](https://leetcode.com/problems/minimum-possible-maximum-waiting-time/description/). I spent a while stuck on this one, and the interesting part wasn't the code — it was figuring out **which shape** of solution it wanted.*

---

## The setup

Two fuel dispensers, each with a fixed amount of fuel. A queue of cars, each needing a specific amount. Cars unlock in order: car 0 starts available at time 0, and car `i` becomes available the moment car `i-1` **starts** refueling — not when it finishes. A car takes `demand[i]` seconds to fill and drains that much from whichever dispenser it used. If both dispensers are free and neither has enough fuel, everything stops.

Two objectives, in priority order: serve as many cars as possible, and among those schedules, minimize the worst waiting time any car experiences.

## Where I got stuck

"Minimize the maximum X" is a loud signal for binary search on the answer. That part I recognized immediately. What I couldn't decide was what the feasibility check looked like — it smelled like it could be meet-in-the-middle (you're splitting cars across two dispensers, which feels like a subset problem), but it also smelled like DP.

The thing that settled it: **meet-in-the-middle works when the two halves are independent given some summary statistic.** Here they aren't. Car `i`'s waiting time depends on when car `i-1` started, which depends on the entire prefix. There's no clean summary you can hand from the first half to the second — you'd have to pass along essentially the full state anyway. That's a DP, not a split-and-merge.

## Articulating the DP

Once you frame the question correctly the state writes itself. The question is:

> Can I assign the first `n` cars to dispensers such that every car's wait is at most `X`?

To answer that at each step I need to know:

- which car I'm on
- how much fuel each dispenser has left
- when each dispenser next becomes free
- when the current car became allowed to start

So:

```text
(car_idx, fuel_0, fuel_1, free_time_0, free_time_1, allowed_time)
```

Two branches per car — dispenser 0 or dispenser 1 — and the timing arithmetic falls out:

```text
start = max(allowed_time, free_time_of_chosen_dispenser)
wait  = start - allowed_time
```

Prune the branch if `wait > X`. The next car's `allowed_time` becomes this car's `start` (that's the rule that makes this problem interesting — the handoff is on start, not completion), and the chosen dispenser's `free_time` becomes `start + demand[i]`.

## The two monotonicities

The outer structure relies on two facts worth stating explicitly, because they're what make the search valid:

1. If you can serve `n` cars, you can serve `n-1` — any prefix of a valid schedule is a valid schedule. So finding the max car count is a linear scan that stops at the first failure.
2. If a schedule works with wait cap `X`, it works with cap `X+1` — you're only relaxing a constraint. So the feasibility predicate is monotonic and binary search applies.

Find the max servable count first, then binary search the wait cap while holding that count fixed.

## The code

```python
from typing import List

class Solution:
    def minMaxWaitingTime(self, demand: List[int], fuel: List[int]) -> int:
        def canServeNCars(n: int, max_waiting: int) -> bool:
            memo = {}

            def dp(car_idx, fuel_0, fuel_1, free_0, free_1, allowed):
                if car_idx == n:
                    return True

                key = (car_idx, fuel_0, fuel_1, free_0, free_1, allowed)
                if key in memo:
                    return memo[key]

                result = False

                if fuel_0 >= demand[car_idx]:
                    start = max(allowed, free_0)
                    if start - allowed <= max_waiting:
                        if dp(car_idx + 1, fuel_0 - demand[car_idx], fuel_1,
                              start + demand[car_idx], free_1, start):
                            result = True

                if not result and fuel_1 >= demand[car_idx]:
                    start = max(allowed, free_1)
                    if start - allowed <= max_waiting:
                        if dp(car_idx + 1, fuel_0, fuel_1 - demand[car_idx],
                              free_0, start + demand[car_idx], start):
                            result = True

                memo[key] = result
                return result

            return dp(0, fuel[0], fuel[1], 0, 0, 0)

        max_cars = 0
        for n in range(len(demand) + 1):
            if canServeNCars(n, float('inf')):
                max_cars = n
            else:
                break

        if max_cars == 0:
            return -1

        left, right, answer = 0, 10**9, 10**9
        while left <= right:
            mid = (left + right) // 2
            if canServeNCars(max_cars, mid):
                answer = mid
                right = mid - 1
            else:
                left = mid + 1

        return answer
```

Worth noting that the greedy "always use the dispenser that's free soonest" instinct is wrong here, and the search is what saves you. On `demand = [3, 2, 5]`, `fuel = [6, 6]`, sending car 1 to the *idle* dispenser looks obviously right — but it strands car 2, which needs 5 and now can't get it from either. Putting car 1 behind car 0 on dispenser 0 instead costs it a wait of 3 and serves all three cars. Fuel and time pull in opposite directions.

## An honest note on complexity

The state has three time-valued dimensions, and times run up to the sum of all demands. Multiplying the dimensions out gives an ugly number. But the reachable state space is far smaller than that product — `free_0`, `free_1`, and `allowed` are all derived from the same prefix of decisions, so they're heavily correlated rather than independent, and the fuel dimensions shrink monotonically. With the given constraints it's comfortable. If the bounds were larger I'd want a tighter encoding — probably expressing the times as offsets from `allowed` rather than absolute values, which collapses one dimension entirely.

## The takeaway

The heuristic I'm keeping: **when two halves of a problem share a dependency you can't summarize, it's a DP, not a meet-in-the-middle.** The tell here was that car `i` reaches back to car `i-1`'s start time — a chain, not a partition.

And the general move for "minimize the maximum" stands: turn the optimization into a yes/no feasibility question, confirm the predicate is monotonic, and binary search it. The hard part is almost never the binary search. It's writing the feasibility check honestly.
