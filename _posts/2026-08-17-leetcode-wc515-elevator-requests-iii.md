---
layout: post
title: "[LeetCode] Weekly Contest 515 — Elevator Requests III: Held–Karp, a poisoned sentinel, and a duplicate-floor scare"
date: 2026-08-17 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, leetcode, dynamic_programming, bitmask, greedy]
author: "Seroze"
published: true
---

Problem: [Elevator Requests III](https://leetcode.com/problems/elevator-requests-iii/) (Weekly Contest 515, hard)

---

A building has `n` floors numbered `0 .. n-1`. The elevator starts at floor `start` at time `0` and each second may move up one floor, down one floor, or stay put. You're given `requests[i] = [arrival_i, floor_i]`: request `i` is fulfilled the instant the elevator is on floor `floor_i` at any time `>= arrival_i`. Return the minimum time to fulfill all of them.

The constraint that gives the game away is `requests.length <= 16`. That's the universal signal for a bitmask DP over subsets, and this one turns out to be Held–Karp — the TSP DP — with a `max` bolted onto the transition to handle waiting.

Two things in this post are worth more than the recurrence: an initialization bug that fails an official sample while looking completely innocent, and a correctness worry about duplicate floors that took me a while to talk myself out of. The second one is the interesting one, because the reason it's a non-issue is a property of the *metric*, not of the DP.

## Reducing a continuous route to a permutation

The elevator's actual behaviour is a second-by-second walk on a line, which is not a thing you can put in a DP table when `n` can be $$10^9$$. The reduction is:

> An optimal route is fully described by the **order** in which requests get fulfilled.

Given an order, the schedule writes itself — never dawdle, never detour. If you finish request `i` at time `t` on floor `floor_i`, the earliest you can finish request `j` next is

$$\max\bigl(t + |floor_i - floor_j|,\; arrival_j\bigr)$$

travel there directly, and if you arrive before the request exists, wait. There are $$16!$$ orders, which is far too many, but the cost of extending a prefix depends only on *which* requests are done (they can't be done twice) and *where you are now* (the last one you did). That's the classic Held–Karp state:

$$dp[\text{mask}][i] = \text{earliest time you can have fulfilled exactly the requests in mask, standing on } floor_i$$

Base case, going straight from `start` to request `i`:

$$dp[\{i\}][i] = \max\bigl(arrival_i,\; |start - floor_i|\bigr)$$

Transition, appending `j` to a prefix ending at `i`:

$$dp[\text{mask} \cup \{j\}][j] \;=\; \min\Bigl(dp[\text{mask} \cup \{j\}][j],\; \max\bigl(dp[\text{mask}][i] + |floor_i - floor_j|,\; arrival_j\bigr)\Bigr)$$

And the answer is $$\min_i dp[\text{full}][i]$$ — the times along any order are non-decreasing, so the finish time of the last request *is* the completion time of the whole set.

## The sentinel that eats the answer

Here's the version I first wrote, with one line that costs you the problem:

```python
last_time = max(request[0] for request in requests) + 1
dp = [[last_time] * n for _ in range(1 << n)]
```

It reads like a reasonable bound — "no answer can exceed the latest arrival" — and it is flatly false. Arrival times bound *waiting*; they say nothing about **travel**. With `start = 0` and one request `[0, 10**9]` the answer is $$10^9$$ while the sentinel is `1`.

The single-request case actually survives, because the base case *assigns* rather than `min`s. The damage starts at the first real transition:

```python
dp[mask | (1 << j)][j] = min(dp[mask | (1 << j)][j], finish)
```

If the sentinel is smaller than every legitimate `finish`, that `min` keeps the sentinel, and a garbage value now sits in the table masquerading as a completed subset. It propagates, and the final `min` happily returns it.

This isn't a contrived-input problem. It fails **sample 3** of the problem statement:

```
n = 7, start = 3, requests = [[0,5],[0,1],[6,3]]
expected 8, buggy version returns 7
```

`max(arrival) + 1` is `7` there, and the true answer is `8`, so the sentinel is smaller than the answer by exactly one — enough to win the `min`. A bug that undershoots by 1 on a sample is far more annoying to find than one that blows up, because your eye goes to the recurrence, which is correct.

The fix is to use a sentinel that is actually unreachable:

```python
INF = float("inf")
```

The general lesson: **an initialization sentinel in a minimizing DP is part of the correctness argument, not a formality.** It has to be a genuine upper bound on any achievable value. If you want a finite one here you'd need something like `max(arrival) + n * len(requests)`, and at that point `float("inf")` is both shorter and obviously right.

## The duplicate-floor scare

Now the part I got wrong in the other direction — by being too careful.

Nothing in the constraints says the floors are distinct. Two requests can name the same floor. And notice what the state actually is:

> `last` is the **last request**, not the **last floor**.

Those are the same thing only when floors are unique. So here's the worry. Take `start = 0` and

```
A = (arrival=0,  floor=5)
B = (arrival=10, floor=5)
```

Suppose you reach floor 5 at time 12. *Physically*, both requests are fulfilled at that instant — one visit, two requests. But the DP has a state

```
mask = {A}, last = A, time = 12
```

which claims only `A` is done. The mask is describing a world that doesn't exist. Worse, the transition

$$\text{mask} \longrightarrow \text{mask} \cup \{j\}$$

adds exactly one bit, while reality can add many. Whenever a single action can satisfy several items at once, the honest update is

```python
new_mask = mask | {every request whose floor == current_floor and arrival <= t}
```

which is a *different DP*. That's a real phenomenon and it does break bitmask DPs — set-cover-flavoured problems live and die on it.

It just doesn't break this one.

The reason is that the extra bits are **free to acquire**. Continue the example: the DP reaches `dp[{A}][A] = 12`, and then takes the transition to `B`, whose cost is

$$\text{travel} = |5 - 5| = 0, \qquad \text{finish} = \max(12 + 0,\; 10) = 12$$

The mask gains its second bit at zero cost and zero elapsed time. Three requests on the same floor, all with arrivals already passed, chain the same way:

```
{} → {A} → {A,B} → {A,B,C}      all at time 12
```

So the DP does not model the one-visit-many-requests move *directly*; it simulates it as a run of zero-cost transitions and lands on exactly the same time. The mask undercounting reality is a bookkeeping artifact that the recurrence pays nothing to repair.

### The property that actually saves it

Zero-distance self-loops are the visible symptom. The underlying reason is that the cost function is a **metric on a line**, and points on a line satisfy the triangle inequality *with equality* when they're collinear in the right order:

$$|a - b| + |b - c| = |a - c| \quad \text{whenever } b \text{ lies between } a \text{ and } c$$

That kills both objections at once:

- **duplicate floors** — `b == a`, so inserting the extra visit costs `0`;
- **fulfilled in passing** — if the elevator rides from floor 0 to floor 10 and sweeps past floor 5 at time 5, that's again "one action, several requests". But the DP's route `0 → 5 → 10` costs `5 + 5 = 10`, exactly what `0 → 10` costs. The pass-through is free too.

A permutation DP is lossless precisely when detouring through an intermediate point is free, and on a line it always is. Change the geometry — put the elevator on a graph where the shortest path between two floors doesn't pass through the third — and this argument stops working; you'd have to run the DP on all-pairs shortest paths instead of raw distances to recover it.

### Making that argument airtight

The zero-cost story above is enough to convince yourself and start typing, but the actual proof is short, so here it is.

Take any real route — the elevator physically moving, second by second — that fulfills everything. For each request `i`, write $$t_i$$ for the moment it *first* gets fulfilled, and sort the requests by that. You get an order; call it $$\pi$$. The claim is that the DP, handed this particular order, finishes no later than the real route did.

Start with whichever request came first. The DP charges

$$dp[\{\pi_1\}][\pi_1] = \max\bigl(arrival_{\pi_1},\; \lvert start - floor_{\pi_1} \rvert\bigr)$$

and the real route had to pay both of those too: it couldn't reach that floor in fewer than $$\lvert start - floor_{\pi_1} \rvert$$ seconds, and it certainly couldn't fulfill the request before the request existed. So the DP's number is already at most $$t_{\pi_1}$$.

Then the step. Between $$t_{\pi_{k-1}}$$ and $$t_{\pi_k}$$ the real elevator physically got from one floor to the other, and that costs what it costs:

$$t_{\pi_k} - t_{\pi_{k-1}} \;\ge\; \lvert floor_{\pi_{k-1}} - floor_{\pi_k} \rvert$$

We also know $$t_{\pi_k} \ge arrival_{\pi_k}$$, because you can't fulfill a request early. Feed those two facts plus the induction hypothesis into the DP's $$\max(\text{previous} + \text{travel},\; arrival)$$ and it can't come out above $$t_{\pi_k}$$ either.

So the DP's optimum is at most the true optimum. The other direction takes no work: every schedule the DP produces is a route you can literally drive, so it can't beat reality.

What I like about this proof is what it never uses. At no point did I assume the floors are distinct. When two requests share a floor the travel term is simply `0` and the step goes through unchanged — the duplicate-floor worry I'd been chewing on for twenty minutes, dissolved in one line.

## Implementation

```python
class Solution:
    def elevatorRequests(self, n: int, start: int, requests: list[list[int]]) -> int:
        m = len(requests)

        arrival = [a for a, _ in requests]
        floor = [f for _, f in requests]

        INF = float("inf")
        dp = [[INF] * m for _ in range(1 << m)]

        # Go straight from `start` to request i, waiting if you beat its arrival.
        for i in range(m):
            dp[1 << i][i] = max(arrival[i], abs(start - floor[i]))

        for mask in range(1 << m):
            for i in range(m):
                if not (mask >> i) & 1:
                    continue

                for j in range(m):
                    if (mask >> j) & 1:
                        continue

                    travel = abs(floor[i] - floor[j])
                    finish = max(dp[mask][i] + travel, arrival[j])

                    dp[mask | (1 << j)][j] = min(dp[mask | (1 << j)][j], finish)

        return min(dp[(1 << m) - 1])
```

Notes on the cleanup from my contest version:

- `m = len(requests)` — don't shadow `n`, the floor count. (`n` is unused by the algorithm; only the *relative* positions matter.)
- Unpacking `arrival` and `floor` up front turns `abs(requests[i][1] - requests[j][1])` into `abs(floor[i] - floor[j])`, which is the difference between reading the line and decoding it.
- The guard `if (mask >> j) & 1 or j == i` has a redundant half. The outer loop already established that `i` is in `mask`, so `(mask >> j) & 1` is true whenever `j == i`.
- `min(dp[(1 << m) - 1])` — the last row is already a list, no generator needed.
- Adding `or dp[mask][i] == INF` to the outer guard skips unreachable states. It's not needed for correctness (`INF + travel` is still `INF`), but it's free and keeps `float("inf")` arithmetic out of the inner loop.

**Complexity.** $$2^m \cdot m$$ states, $$m$$ transitions each, so $$O(m^2 2^m)$$ time and $$O(m 2^m)$$ memory. At `m = 16` that's $$16^2 \cdot 2^{16} \approx 1.7 \times 10^7$$ — fine even in Python.

## Verification

I stress-tested against two independent brute forces on 20,000 random cases:

1. a **permutation brute force** over all orderings, which checks the DP's bookkeeping;
2. a **second-by-second BFS** over `(floor, mask)` states, which moves the elevator one floor at a time and, on every tick, auto-fulfills *every* request on the current floor whose arrival has passed. This one makes no permutation assumption at all — it's the physical process, and it captures both duplicate-floor batching and fulfilled-in-passing.

The generator used floor ranges of 5–7 with 4 requests, so duplicate floors appeared in most cases. Zero mismatches across all three, and the DP gives `9`, `7`, `8` on the three samples.

## Takeaways

1. **A sentinel in a minimizing DP is a proof obligation.** `max(arrival) + 1` looks like a bound and isn't one — it bounds waiting, not travel. When in doubt use `float("inf")`; a finite sentinel that's too small doesn't crash, it silently returns a smaller, wrong answer.
2. **"One action satisfies several items" genuinely does break `mask | (1 << j)`** — just not when the extra items are reachable at zero cost. Check whether the redundant transitions are free before rewriting the DP.
3. **Permutation DPs are lossless exactly when intermediate stops are free.** On a line the triangle inequality is tight for in-between points, which is why both duplicate floors and pass-through fulfillment need no special handling. On a general graph, run Held–Karp on all-pairs shortest paths and you get the property back.
4. **When you suspect a corner case, try to build the counterexample.** I spent longer worrying about duplicate floors than the fix would have taken, and the attempt to construct a failing input is what showed there wasn't one.
