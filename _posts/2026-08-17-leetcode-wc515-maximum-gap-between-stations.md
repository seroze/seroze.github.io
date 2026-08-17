---
layout: post
title: "[LeetCode] Weekly Contest 515 — Maximum Gap Between Stations: greedy extremes, and the max-of-max trap"
date: 2026-08-17 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, leetcode, greedy, binary_search, two_pointers]
author: "Seroze"
published: true
---

Problem: [Maximum Gap Between Stations](https://leetcode.com/problems/maximum-gap-between-stations/) (Weekly Contest 515)

---

You're given two strings `skill` (length `n`) and `station` (length `m`). You must pick strictly increasing indices $$j_0 < j_1 < \dots < j_{n-1}$$ into `station` with `station[j_i] == skill[i]` — in other words, embed `skill` into `station` as a subsequence. Among all valid embeddings, maximize

$$\max_{1 \le i < n} (j_i - j_{i-1})$$

the largest step between consecutive workers. Return `0` if `n == 1`.

The solution is two greedy scans and a one-line combine. The reason this post exists is that I spent the first few minutes of the contest solving a different problem, because I read the word "maximum" and my hands started typing a binary search.

## The wrong reflex

Every CP-brain has this reflex burned in:

> "maximize the minimum" / "minimize the maximum" → binary search on the answer

So when I saw *maximize the maximum gap*, the pattern-matcher fired anyway. I started writing:

```python
def feasible(T):          # can I make every gap >= T?
    j = -1
    for ch in skill:
        lo = 0 if j < 0 else j + T
        while lo < m and station[lo] != ch:
            lo += 1
        if lo >= m: return False
        j = lo
    return True
```

That check is fine. It's just not this problem's check. `feasible(T)` asks whether **every** adjacent gap can be at least `T`, so binary searching it computes

$$\max_{\text{assignments}} \; \min_i (j_i - j_{i-1})$$

which is a genuinely different quantity. On `skill = "xyz"`, `station = "xyzz"` the only two embeddings are `[0,1,2]` and `[0,1,3]`, with gap lists `[1,1]` and `[1,2]`. Max-of-max is `2`; max-of-min is `1`. On the bigger example below they differ by a factor of two. I wrote the max-min solver, it failed sample 2, and I stared at it for a while before noticing I'd solved the neighbouring problem.

### Why the reflex misfires, precisely

It's tempting to say "the predicate isn't monotone, so binary search doesn't apply." That's not actually true here, and it's worth being exact about, because the real reason is more useful.

Define $$P(T)$$ = "there exists a valid assignment with **some** gap $$\ge T$$." This *is* monotone: if you can achieve a gap of `7`, the same assignment achieves a gap of `6`. So binary searching $$P$$ is formally valid. It's just completely useless, because evaluating $$P(T)$$ once is exactly as hard as computing the answer outright. Binary search bought you nothing.

The distinction that actually matters isn't monotonicity, it's the **quantifier**:

| objective | predicate | quantifier | check |
|---|---|---|---|
| max-of-min | all gaps ≥ `T` | ∀ | greedy left-to-right |
| min-of-max | all gaps ≤ `T` | ∀ | greedy left-to-right |
| **max-of-max** | **some** gap ≥ `T` | **∃** | as hard as the original |
| min-of-min | some gap ≤ `T` | ∃ | as hard as the original |

Binary search on the answer is only *profitable* when the predicate is a **universal** constraint. A "for all" constraint is local: it applies independently at every step, which is what lets you sweep left to right making the locally-greediest choice and never backtrack. An **existential** constraint is global — "somewhere, one pair is far apart" gives you nothing to enforce at position `i`, so there's no greedy to write and no cheaper check than solving the problem.

So the rule I'd been carrying ("max-of-min → binary search") was right, but I'd memorised it in the wrong shape. The rule is really:

> Binary search on the answer when the feasibility test is a **∀**-constraint over the structure. If the objective optimises in the *same* direction as the aggregation (max-of-max, min-of-min), the test flips to **∃** and binary search degenerates.

Max-of-max and min-of-min are the "vice versa" cases, and they nearly always want a direct construction instead.

## Second wrong turn: solving each letter independently

The other thing I tried: for each letter, find the two occurrences of it in `station` that can be pushed furthest apart, and combine somehow. This fails because the letters are not independent — the strictly-increasing constraint couples them.

Take

```
skill   = "aba"
station = "aaabbbba"
           01234567
```

Looking at `'a'` alone, you'd love to use stations `0` and `7` for a gap of `7`. But the `'b'` has to sit strictly between them, and every `'b'` is at index `3..6`. The moment you commit `a → 0` and `a → 7`, the `'b'` has to land somewhere in the middle, and the two gaps become something like `[3, 4]` or `[6, 1]` — you can't get `7` as a single step, because the `'b'` splits it. The true answer here is `6` (assignment `[0, 6, 7]`).

Choosing an extreme position for one letter constrains what every other letter can do. There's no per-letter quantity that composes.

## Greedy extremes

Here's the actual idea, and it's the part worth keeping.

Forget global structure. Look at one adjacent pair $$(i-1, i)$$ at a time and ask: **how far apart can these two specific workers be, over all valid assignments?** Obviously

$$j_i - j_{i-1} \le \max(j_i) - \min(j_{i-1})$$

so define, for every worker:

- `L[i]` — the **earliest** station index worker `i` can ever occupy
- `R[i]` — the **latest** station index worker `i` can ever occupy

Both are one greedy scan each:

- `L` is the standard subsequence match, left to right: walk `station` forward and take the first available character for each worker in order. Placing everyone as early as possible is exactly what makes each individual position minimal.
- `R` is the mirror image: walk `station` backward, matching `skill` from the end.

Then the answer is

```python
ans = max(R[i + 1] - L[i] for i in range(n - 1))
```

### Why the bound is tight

The upper bound is immediate — `L[i]` and `R[i+1]` are extremes, so no assignment can beat `R[i+1] - L[i]` on that pair. The content is that it's **achievable**: you can simultaneously put the prefix at its leftmost and the suffix at its rightmost.

Concretely, take the assignment

$$L[0],\; L[1],\; \dots,\; L[i],\; R[i+1],\; R[i+2],\; \dots,\; R[n-1]$$

It's valid if (a) `L` is strictly increasing, (b) `R` is strictly increasing, and (c) `L[i] < R[i+1]` at the seam. The first two hold by construction. For the seam: the problem guarantees *some* valid assignment $$j$$ exists, and by definition of the extremes $$L[i] \le j_i$$ and $$R[i+1] \ge j_{i+1}$$. Chaining,

$$L[i] \;\le\; j_i \;<\; j_{i+1} \;\le\; R[i+1]$$

so `L[i] < R[i+1]` always. The two greedies never conflict, because the earliest prefix leaves the most room for the suffix and the latest suffix leaves the most room for the prefix — they're pulling in opposite directions.

So each pair's maximum is attained independently, and the overall answer is just the max over pairs. The interaction between letters that killed the per-letter idea is fully absorbed by `L` and `R`: `L[i]` already knows about every worker before `i`, and `R[i+1]` already knows about every worker after `i+1`.

I'd call the technique **greedy extremes**:

> Compute the leftmost and rightmost feasible placement of every element with two greedy sweeps, then read the answer off the extremal pair.

It's not specific to this problem. Any time you want the max separation between two coupled objects, ask whether "push one as far left as possible, the other as far right as possible" is simultaneously realisable — usually the two greedies are constructed so that they are.

## Implementation

```python
class Solution:
    def maximumGap(self, skill: str, station: str) -> int:
        n, m = len(skill), len(station)

        # L[i] = earliest index worker i can occupy: match skill into
        # station left-to-right, taking the first opportunity every time.
        L = [-1] * n
        j = 0
        for i, ch in enumerate(skill):
            while station[j] != ch:
                j += 1
            L[i] = j
            j += 1

        # R[i] = latest index worker i can occupy: the same scan mirrored.
        R = [m] * n
        j = m - 1
        for i in range(n - 1, -1, -1):
            ch = skill[i]
            while station[j] != ch:
                j -= 1
            R[i] = j
            j -= 1

        return max((R[i + 1] - L[i] for i in range(n - 1)), default=0)
```

No bounds guards are needed inside the loops: the problem guarantees a valid embedding exists, so both scans always find a match before running off the end. `default=0` handles `n == 1`.

Each `while` advances `j` monotonically across the whole string, so both scans are `O(m)` total, not `O(nm)`. Overall `O(n + m)` time, `O(n)` space.

I stress-tested this against a brute force over all $$\binom{m}{n}$$ embeddings on 20,000 random cases with `m ≤ 9` over 2- and 3-letter alphabets — no mismatches, and it gives `3`, `2`, `4` on the three samples.

## The max-min sibling, for contrast

Since I wrote the binary search anyway, here's the problem it *does* solve — same input, but maximize the **minimum** gap:

```python
def max_min_gap(skill, station):
    n, m = len(skill), len(station)
    if n == 1:
        return 0

    def feasible(T):                     # every gap >= T ?
        j = -1
        for ch in skill:
            lo = 0 if j < 0 else j + T
            while lo < m and station[lo] != ch:
                lo += 1
            if lo >= m:
                return False
            j = lo
        return True

    lo, hi, best = 1, m - 1, 0
    while lo <= hi:
        mid = (lo + hi) // 2
        if feasible(mid):
            best, lo = mid, mid + 1
        else:
            hi = mid - 1
    return best
```

The greedy inside `feasible` is correct by the usual exchange argument: by induction its position for worker `i` is `<=` that of any valid `T`-assignment, so if any valid assignment exists the greedy finds one. `O(m log m)`. I stress-tested this one too, against a brute force over all embeddings, on another 20,000 random cases.

On `skill = "aba"`, `station = "aaabbbba"` it returns `3` (assignment `[0,3,7]`, gaps `[3,4]`) where the max-of-max answer is `6` (assignment `[0,6,7]`, gaps `[6,1]`). Same input, different assignment, different answer — a useful reminder that these are unrelated problems that happen to share a sentence structure.

## Takeaways

1. **Read the aggregation direction before reaching for binary search.** "Maximize the maximum" and "minimize the minimum" are the cases where the reflex misfires. The tell is that the feasibility check becomes existential, and existential checks don't decompose into a greedy.
2. **When a pair's separation is what you want, compute per-element extremes.** Two greedy sweeps give you the leftmost and rightmost feasible placement of everything; if the prefix-left and suffix-right constructions are compatible at the seam — and they usually are by construction — every pair's bound is tight and the answer is a single scan.
3. **Coupling doesn't mean you need global search.** The letters here interact, but `L` and `R` already encode all of that interaction, which is why the final combine is one line.
