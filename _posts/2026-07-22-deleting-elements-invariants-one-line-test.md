---
layout: post
title: "[Codechef] Starters 248 — Deleting Elements (Easy)"
date: 2026-07-22 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, invariants, problem_solving]
author: "Seroze"
published: true
---

I recently worked through a nice array problem where the real work wasn't the code — it was finding the right invariant. The final solution is ~15 lines, but the path to it is worth writing down because the *process* generalizes to a lot of "can this configuration be reduced?" problems.

## The problem

Problem link: [DELELE2 on CodeChef](https://www.codechef.com/problems/DELELE2)

An array is **deletable** if it can be reduced to ≤ 2 elements using this operation any number of times:

- Choose an interior index `i` (so `1 < i < |A|`) with `A[i-1] + A[i+1] >= A[i]`
- Distribute `A[i]`'s value to its two neighbors: add `X` to `A[i+1]` and `Y` to `A[i-1]` where `X, Y >= 0` and `X + Y = A[i]`
- Delete index `i`

Given an array of size `N <= 2000`, count the number of deletable subarrays.

Example: `[2, 3, 2, 3]` is deletable, `[2, 4, 1]` is not (no operation is possible: `2 + 1 < 4`).

## Observation 1: The sum is invariant

The deleted element's value doesn't vanish — it moves to the neighbors. So the total sum `S` never changes. This is the first thing I noticed, and it turned out to be half the answer.

It's actually stronger than "sum is constant": mass only ever flows to *adjacent* elements, and elements only ever **grow**. No operation ever decreases anything. A big element never gets smaller — it can only hope its neighbors catch up.

## Observation 2: The endpoints are immortal

Read the operation constraint again: `1 < i < |A|`. The first and last elements can **never** be deleted. They're the two survivors. This is easy to skim past, but it changes how you think about the whole problem: only *interior* elements ever need to satisfy anything.

## Combining the two: a necessary condition

Suppose some interior element has value `a`. To delete it, at some point its two neighbors must sum to at least its current value. But:

- the element itself only ever grows, so its current value is `>= a`
- the neighbors' sum is at most "everything else", i.e. at most `S - a`

So deletion is only ever possible if `S - a >= a`, i.e. **`2a <= S`**. If any interior element has `2a > S`, the subarray is doomed. That element is more than half the total mass — nothing can ever catch up to it.

## Probing the boundary with examples

Is the condition sufficient too? I tested families of arrays to find the exact crossover:

| Array | Sum | 2 × interior max | Deletable? |
|---|---|---|---|
| `[1, 3, 1]` | 5 | 6 | ❌ |
| `[1, 3, 2]` | 6 | 6 | ✅ (barely) |
| `[1, 5, 1, 2]` | 9 | 10 | ❌ |
| `[1, 5, 1, 3]` | 10 | 10 | ✅ (barely) |
| `[1, 2, 1]` | 4 | 4 | ✅ |

The crossover happens *exactly* at `2 · max = S`, and equality is on the deletable side — which matches the operation using `>=` rather than `>`. Non-strict operation ⇒ non-strict test. (I almost introduced a bug here by rewriting the check as `max > ceil(S/2)` — for odd `S` that's not equivalent. Stick to the multiplication form `2*max <= S`; no division, no rounding, no off-by-one.)

## Why it's sufficient: a strategy sketch

The conjecture: a subarray is deletable iff every interior element `a` satisfies `2a <= S`.

The key strategic insight — **always shovel mass toward the ends**. Here's why it matters. Take `[1, 3, 3, 1]` (both 3s pass the test, `S = 8`):

- Delete the first `3` and dump its mass **inward**: `[1, 6, 1]` — dead. We created a violator.
- Delete it and dump the mass **outward**: `[4, 3, 1]` — alive, finishes trivially.

So the invariant `2a <= S` for interior elements is something you must actively *preserve*, and dumping onto endpoints preserves it for free — endpoints don't care how big they get.

Sketch of the full argument:

1. Always delete the **minimum interior element**. For length ≥ 4, at least one of its neighbors is also interior, hence `>=` the minimum, so the deletion condition `A[i-1] + A[i+1] >= A[i]` holds automatically. For length 3, the condition `2a <= S` *is* the deletion condition.
2. After deleting, push the freed mass to an endpoint (or split carefully when the minimum sits between two interior elements — using `A[i-1] + A[i] + A[i+1] <= S` you can always split `X, Y` so neither neighbor crosses `S/2`).
3. Repeat. The invariant survives every step, so you never get stuck.

For a contest, I verified the conjecture cheaply instead of proving it rigorously: on the third sample there are 28 subarrays and the expected answer is 21, so exactly 7 must fail the test — and exactly the right 7 do.

## Counting in O(N²)

With a closed-form test, no simulation is needed. Fix `L`, extend `R`, and maintain two running values: the sum, and the max of the *interior* elements. The one subtle mechanical detail: when you extend `R -> R+1`, the element `A[R]` that was previously the right endpoint becomes interior — *that's* the moment it enters the running max. Getting this timing wrong is the classic bug in this pattern.

```python
import sys
input = sys.stdin.readline

def solve():
    n = int(input())
    a = list(map(int, input().split()))
    ans = 0
    for l in range(n):
        s = a[l]
        interior_max = 0  # max of a[l+1..r-1]
        for r in range(l, n):
            if r > l:
                s += a[r]
                if r - 1 > l:            # a[r-1] just became interior
                    interior_max = max(interior_max, a[r - 1])
            if r - l + 1 <= 2 or 2 * interior_max <= s:
                ans += 1
    print(ans)

t = int(input())
for _ in range(t):
    solve()
```

Subarrays of length ≤ 2 have no interior, so they're always deletable — handled explicitly.

## Takeaways

- **Find what doesn't change.** The sum invariant plus "elements only grow" turned an operational puzzle into a static inequality.
- **Read the constraints on the operation literally.** `1 < i < |A|` (endpoints immortal) and `>=` (equality allowed) each directly shaped the final test.
- **Hunt for the crossover.** Parameterized families like `[1, 5, 1, k]` locate the exact boundary and turn a vague conjecture into an equation.
- **Necessary conditions are often sufficient in these problems** — but verify with a strategy sketch and a cheap sample-count check before believing it.
- **Match strictness.** A non-strict operation condition means the boundary case belongs on the "possible" side. And avoid `ceil` when `2*x <= S` says the same thing exactly.

## TODO

There's a [hard version of this problem](https://www.codechef.com/problems/DELELE) with `N, ΣN <= 2 * 10^5`, where the O(N²) enumeration is far too slow (~4 × 10¹⁰ pairs). The characterization stays the same — only the counting has to get smarter. Try to come up with the optimization: think about counting the complement, and about what special role the element violating `2a > S` must play within its subarray.
