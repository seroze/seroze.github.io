---
layout: post
title: "[Codechef] Starters 248 — Merging Parity"
date: 2026-07-22 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, dynamic_programming, problem_solving]
author: "Seroze"
published: true
---

I've seen this class of problem N times: you're given an array, an operation that merges/deletes/transforms elements, and you're asked to count the number of distinct reachable states. And N times I've attacked it the same way — hunt for an invariant, hope the invariant *is* the answer. This time I want to write down the full ladder I climbed for one such problem, because the interesting lesson wasn't the solution — it was noticing exactly where my usual approach falls short and what fills the gap.

## The problem

Problem link: [MERGEPAR on CodeChef](https://www.codechef.com/START248A/problems/MERGEPAR)

You're given an array of N positive integers. Repeatedly, you may pick two **adjacent elements of the same parity**, replace the left one with their sum, and delete the right one. Count the distinct arrays reachable, mod 998244353. (N up to 2·10⁵, sum over tests up to 2·10⁵, 1 second.)

Example: from `[1, 1, 2]` you can reach `[1,1,2]`, `[2,2]`, and `[4]` — answer 3.

## Where invariants get you (and where they don't)

My first instincts:

1. The total sum is invariant.
2. odd + odd → even, even + even → even. So each operation reduces the count of odd elements by exactly 0 or 2. **Parity of the odd-count is invariant.**

Both true. Both useful. Neither counts anything.

Here's the distinction I want to burn into memory: **invariants tell you what *can't* happen; counting reachable states needs a bijection to a combinatorial family you can count.** Invariants prune, they bound, they sanity-check — but they're necessary conditions, rarely sufficient ones. Jumping from "I found an invariant" to "let me count things satisfying the invariant" silently assumes sufficiency, and that assumption is exactly what this problem punishes.

The ladder that actually works, in order:

1. **Invariants** — prune the space, sanity-check later answers.
2. **Structural characterization** — "every reachable state has shape X."
3. **Achievability predicate** — which X's are actually reachable (usually a local, per-piece condition).
4. **Count the X's** — DP or combinatorics.

I was jumping from 1 to 4. The missing move is step 2.

## Step 2: What shape does a final array have?

Forget parity entirely for a moment. Every operation merges two *adjacent* elements. So every element of every reachable array is the sum of a **contiguous segment** of the original. Reachable arrays are exactly the block-sum arrays of some partition of the original into contiguous segments — subject to constraints.

This is *the* canonical form for merge-adjacent problems. It converts a dynamic process ("what sequences of operations exist?") into a static object ("which partitions are valid?").

Two follow-ups you should always check and usually skip:

**Injectivity.** Could two different partitions produce the same array? Not here: all elements are ≥ 1, so block sums are strictly positive, so the partial sums of the output array recover the partition boundaries uniquely. (On a variant where elements can be 0 or negative, this breaks and you'd be overcounting — worth the 30 seconds.)

**Independence.** Merges inside one block never interact with another block. So achievability decomposes per-segment: the whole problem reduces to *"when can a single segment be collapsed to one element?"*

## Step 3: The predicate — and the counterexample that kills the naive invariant

My invariant says a collapsible multi-element segment needs an even number of odds. Is that sufficient? Try `[1, 2, 1]`: two odds, but the even element in the middle can never merge with either odd, and the odds can never become adjacent. Stuck. The count is right; the *positions* are wrong.

The correct characterization:

> A segment of size ≥ 2 collapses to a single element **iff every maximal run of consecutive odd elements inside it has even length.**

*Necessity:* evens between two odds never disappear — they can only blob into a bigger even. So odds can only pair off within their own run; an odd-length run strands one odd forever.

*Sufficiency:* pair up each run left to right, everything becomes even, and an all-even segment collapses trivially.

The sufficiency direction is 30 seconds of work, but it's what upgrades your count from "upper bound" to "exact." Don't skip it.

**The vacuous-but-not-vacuous case.** A singleton block needs zero operations, so it's always valid — *including a lone odd element*, which violates the run condition read literally. Mathematically this feels vacuous. In code it is anything but: a `block_valid` function without an explicit `l == r` branch returns `False` for `[3]`, and suddenly `[1,2,3,4]` (whose only valid partition is all-singletons) comes out 0 instead of 1. The condition is a statement about segments you must do work on; singletons are reachable for free and live outside it. One explicit line beats an implicit hope.

## Step 4a: The O(N²) DP — as an oracle, and as a state-discovery tool

`dp[i]` = number of valid partitions of the first `i` elements; brute-force the last block:

```python
MOD = 998244353

def solve(A):
    n = len(A)
    dp = [0] * (n + 1)
    dp[0] = 1
    for i in range(1, n + 1):
        # last block = A[j..i-1]; extend leftward, maintain validity incrementally
        broken = False   # a finalized interior odd-run had odd length -> dead forever
        left_run = 0     # length of the odd-run touching the current left boundary
        for j in range(i - 1, -1, -1):
            if A[j] % 2 == 1:
                left_run += 1
            else:
                if left_run % 2 == 1:
                    broken = True
                left_run = 0
            if broken:
                break
            if j == i - 1 or left_run % 2 == 0:
                dp[i] = (dp[i] + dp[j]) % MOD
    return dp[n]
```

Note the inner loop runs **leftward** and maintains validity incrementally — re-checking each block from scratch would be O(N³), a distinction that's easy to miss when the check "feels" O(1).

I submitted this. Test 5: TLE at 4.99s. Deserved — sum of N is 2·10⁵, so a single test can be N = 2·10⁵, and O(N²) is 4·10¹⁰ operations against a 1-second limit. I knew this going in and submitted anyway. Sometimes you pay the wrong-complexity tax just to confirm the characterization against hidden tests; the earlier subtasks passing told me the math was right before I invested in the fast version.

But here's the underrated payoff of writing the incremental O(N²) *before* attempting O(N): **the incremental version's loop state IS the fast version's design.** Look at what the inner loop actually tracks:

- `broken` — monotone; once true for some `j`, true for all smaller `j`. That's a **barrier** that only moves rightward.
- `left_run % 2` — the only fluctuating quantity, and it's a function of where `j` sits inside its odd run.

Most people try to guess the O(N) state directly and flail. Deriving it by running the slow version backwards is faster — and you get a fuzzing oracle for free.

## Step 4b: Decomposing the predicate → O(N)

Fix `i` and ask what the *set* of valid left endpoints `j` looks like. Let `s` = start of the odd run containing element `i-1` (when that element is odd). Split:

**Case B, `j ≥ s`:** the block lives entirely inside one odd run — all odd, one run. Valid iff its length `i − j` is even, i.e. `j ≡ i (mod 2)`. That's a range sum of `dp[j]` filtered by index parity → two prefix arrays split by `j & 1`.

**Case A, `j < s`:** the right-cut piece `[s..i-1]` has the same length `i − s` for every such `j` — a single per-`i` gate. And the left-cut condition becomes a **static property of `j` alone**: if `A[j]` is odd, its run's full-array end is already fixed (the run ends before `s`), so `ok(j) := A[j] even, or j's run-tail has even length` is precomputable upfront. Range sum of `dp[j]·ok(j)` → one prefix array.

**Barrier `L`:** when an odd-length run gets sealed by an even element, every `j` strictly left of its start is dead forever. `L` = max start over sealed bad runs; monotone; O(1) updates. Only Case A clips against it (a Case B block contains no other run).

**Singleton:** `dp[i-1]`, unconditional, kept outside both cases.

Putting it together:

```
dp[i] = dp[i-1]
      + [right-cut even] · (P[s] − P[L])                 # case A
      + Σ_{j ∈ [s, i-2], j ≡ i (mod 2)} dp[j]            # case B
```

Everything is O(1) per `i` with three running prefix arrays. The pattern, named for my future self:

> **DP where the last-block predicate decomposes into (monotone barrier) × (static per-j class) × (per-i gate) → prefix sums bucketed by the class, clipped at the barrier.**

Full submission-ready code:

```python
import sys

def main():
    data = sys.stdin.buffer.read().split()
    ptr = 0
    T = int(data[ptr]); ptr += 1
    out = []
    MOD = 998244353
    for _ in range(T):
        n = int(data[ptr]); ptr += 1
        par = [int(data[ptr + k]) & 1 for k in range(n)]
        ptr += n

        # static: ok[j] = A[j] even, or left-cut of j's odd run is even-length
        ok = [False] * n
        j = 0
        while j < n:
            if par[j] == 0:
                ok[j] = True; j += 1
            else:
                k = j
                while k + 1 < n and par[k + 1]: k += 1
                for t in range(j, k + 1):
                    ok[t] = ((k - t) & 1) == 1     # (k - t + 1) even
                j = k + 1

        dp_prev = 1                  # dp[0]
        P  = [0] * (n + 1)           # prefix of dp[j]*ok[j]
        Q0 = [0] * (n + 1)           # prefix of dp[j], even j
        Q1 = [0] * (n + 1)           # prefix of dp[j], odd j
        L = 0; cur_s = -1

        for i in range(1, n + 1):
            x = par[i - 1]
            if x:
                if i - 1 == 0 or par[i - 2] == 0:
                    cur_s = i - 1
            elif i - 2 >= 0 and par[i - 2]:
                if (i - 1 - cur_s) & 1:          # bad run sealed -> barrier
                    L = max(L, cur_s)

            v = dp_prev                          # singleton, always
            if x:
                s = cur_s
                if (i - s) & 1 == 0 and L <= s - 1:   # case A gate + range
                    v += P[s] - P[L]
                if s <= i - 2:                        # case B
                    q = Q1 if (i & 1) else Q0
                    v += q[i - 1] - q[s]
            else:
                if L <= i - 2:                        # case A only
                    v += P[i - 1] - P[L]

            jm1 = i - 1
            P[i] = (P[jm1] + (dp_prev if ok[jm1] else 0)) % MOD
            if jm1 & 1:
                Q1[i] = (Q1[jm1] + dp_prev) % MOD; Q0[i] = Q0[jm1]
            else:
                Q0[i] = (Q0[jm1] + dp_prev) % MOD; Q1[i] = Q1[jm1]
            dp_prev = v % MOD

        out.append(str(dp_prev))
    sys.stdout.write("\n".join(out) + "\n")

main()
```

Timing on my machine: a single n = 2·10⁵ test in ~0.24s, and T = 10⁴ small tests in ~0.14s. Comfortable in Python even against a 1s limit.

## The bugs the fuzzer earned its keep on

The lazy-invalidation-plus-bucketed-prefix-sums shape has a lot of off-by-one surface area at run boundaries. Two spots that bit or nearly bit:

1. **Barrier update ordering.** The barrier must update *before* computing `dp[i]`: the run sealed by `A[i-1]` being even is already interior for blocks ending at `i-1`. Update it after and you accept dead blocks for exactly one index.
2. **Case A's upper bound differs by case.** It's `s − 1` when the right end is odd, but `i − 2` when it's even — the latter specifically to avoid double-counting the singleton, which is added unconditionally.
3. **(From the O(N²) version:)** the trailing-run check. A block ending mid-run has no even element to flush the run counter; forgetting the final parity check silently accepts bad blocks. The same logic re-materializes at block boundaries in the fast version.

My verification stack, in order of construction: hand-verify the characterization on the samples → O(N²) DP checked against all four samples (sample 4, an 8-element array with answer 48 and mixed run structure, is the one that actually discriminates between hypotheses — the first three are small enough that wrong predicates also pass them) → fuzz the fast version against the slow one on thousands of random small arrays. Only parity matters, so values from `{1, 2}` suffice for fuzzing — small alphabets hit boundary structure far more often than random 10⁹ values do.

## The checklist I'm keeping

For "operation on array, count reachable states" problems:

1. **Invariants first, but only to prune** — sum, parity counts, whatever's conserved. They're necessary conditions, not the answer.
2. **Characterize the shape of any reachable state.** Merge-adjacent ops → contiguous partitions. Other ops → permutations, intervals, bracket sequences. Ask "what does a final state look like in terms of the original?" before asking "what's conserved?"
3. **Check injectivity** of shape → state (positivity usually saves you; zeros/negatives don't).
4. **Find the local achievability predicate.** Independence across pieces is what makes it local. Hunt for the counterexample that separates your invariant from the true condition — small alphabet, 3 elements, all arrangements.
5. **Handle the do-nothing cases explicitly.** Singletons, empty ops. Vacuous in the math, load-bearing in the code.
6. **Write the incremental O(N²) even though it'll TLE.** Its loop state is the O(N) design document, and it's your fuzzing oracle.
7. **Decompose the predicate**: monotone barrier × static per-j class × per-i gate → bucketed prefix sums.
8. **Fuzz before submitting the fast version.** Trust the fuzzer over your eyeballs at run boundaries.

The one-line summary: I knew to look for canonical forms; what I'd been missing is that the canonical form comes from the *structure of the operation* (step 2), not from the *invariant* (step 1) — and that the slow DP isn't a throwaway, it's the derivation.
