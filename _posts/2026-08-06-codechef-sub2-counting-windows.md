---
layout: post
title: "[CodeChef] Starters 250 — Subsequence 2: Counting windows, one threshold at a time"
date: 2026-08-06 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, dynamic_programming, counting]
author: "Seroze"
published: true
---

[SUB2 (Subsequence 2)](https://www.codechef.com/problems/SUB2) is the sequel to
[SUB1 (Subsequence 1)](https://www.codechef.com/problems/SUB1), which I wrote up
[in the previous post]({{ site.baseurl }}/codechef-sub1-chains-not-cuts/). Same $$f$$: the largest $$L$$ such that
$$1, 2, \dots, L$$ is a subsequence of the array. But instead of splitting the array, you sum $$f$$ over
every subarray:

$$\sum_{L=1}^{N} \sum_{R=L}^{N} f(A[L \ldots R])$$

Rated ~1895, and it ends up being the SUB1 loop with one operator changed. Getting there took me
three wrong turns, which is the interesting part.

## Setting up: sum over right endpoints

The standard move for "sum over all subarrays" is to fix the right endpoint. Let

$$dp[i] = \sum_{L=1}^{i} f(A[L \ldots i])$$

so the answer is $$\sum_i dp[i]$$. The question becomes: how does $$dp[i]$$ follow from $$dp[i-1]$$?

Here the SUB1 lesson pays off immediately. Appending one element raises $$f$$ by **at most 1**, and it
raises a particular window's $$f$$ only if that window was sitting at value exactly $$a_i - 1$$. So

$$dp[i] = dp[i-1] + \#\{L : f(A[L \ldots i-1]) = a_i - 1\}$$

In words, and this is the sentence I couldn't see for far too long: **the new answer is the old
answer plus the number of left endpoints whose window just became able to reach $$a_i$$.** Not "at
least $$a_i - 1$$" — exactly. A window already at 4 gains nothing when you append a 5 if it's
already past; a window at 2 gains nothing either. Only the ones on the boundary move.

(One bookkeeping detail: at step $$i$$ there's a brand-new window $$L = i$$ that didn't exist at step
$$i-1$$. If you define $$f$$ of the empty array as 0, it obeys the same rule and needs no special case.)

So the whole problem reduces to maintaining that count.

## Wrong turn 1: a set of chain starts

My first idea was to keep, for each value $$c$$, the set of positions where a chain reaching $$c$$
begins — carried over from SUB1, where I tracked exactly that. On `1 2 3 4 1 2 3 3 4` I wrote the
set for value 3 as $$\{1, 5\}$$: the two places a `1` sits that opens a `1,2,3`.

That's the wrong quantity. The DP doesn't ask *where chains begin*, it asks *which windows contain*
one. Check `L` by `L` at index 8 on that array:

| $$L$$ | window | contains `1,2,3`? |
|---|---|---|
| 1 | `1 2 3 4 1 2 3 3` | yes |
| 2 | `2 3 4 1 2 3 3` | yes — via the `1` at 5, `2` at 6, `3` at 7 |
| 3 | `3 4 1 2 3 3` | yes, same |
| 4 | `4 1 2 3 3` | yes |
| 5 | `1 2 3 3` | yes |
| 6 | `2 3 3` | no `1` left |

The answer is $$\{1,2,3,4,5\}$$, not $$\{1,5\}$$. Storing sets is also $$O(N^2)$$ in the worst case, so it
was doomed twice over.

## The observation: $$f$$ is monotone in the left endpoint

Look at that table again. It isn't an arbitrary set — it's a prefix. And the reason is one line:

> $$A[L{+}1 \ldots i]$$ is a subarray of $$A[L \ldots i]$$, so every subsequence of the former is a
> subsequence of the latter. Hence $$v(L) := f(A[L \ldots i])$$ is **non-increasing in $$L$$**.

Moving the left endpoint right can only ever take options away. So for every threshold $$c$$, the set
$$\{L : v(L) \ge c\}$$ is a prefix $$[1, S_c]$$, and the entire function $$v(\cdot)$$ — all $$i$$ values of
it — is pinned down by the single non-increasing sequence

$$S_0 \ge S_1 \ge S_2 \ge \cdots$$

where $$S_c$$ is just a **count**: how many windows ending at $$i$$ have $$f \ge c$$. And $$S_0 = i$$
always, since every window contains the empty chain.

That's the compression. No sets, no $$O(N^2)$$.

## Wrong turn 2: adding the whole prefix

With $$S$$ in hand I wrote `dp += S[cur-1]` and got 8 on `[1,2,1]` instead of 7. The bug is the
"exactly" from the recurrence: $$S_c$$ counts windows at value $$\ge c$$, but the windows already at
$$\ge c$$ before the append didn't move. Only the ones crossing the threshold contribute.

Windows at exactly $$c$$ are a difference of adjacent prefixes, so with $$v = a_i$$:

$$\#\{L : v(L) = v - 1\} = S_{v-1} - S_v$$

read from the pre-append state. Then those windows move up, which is the update $$S_v \leftarrow S_{v-1}$$.

Equivalently: the increment is how much $$S_v$$ grew. Same number, read two ways.

## Wrong turn 3: the update order

Since the appended element is *precisely* what moves those windows from $$v-1$$ to $$v$$, reading the
count after applying $$S_v \leftarrow S_{v-1}$$ gives 0 every time — the difference you wanted to
measure has already been erased. Read first, update second. Tracing `[1,2,1]` by hand catches this
in about ten seconds — increments should be $$1, 1, 2$$, giving $$dp = 1, 2, 4$$ and total 7.

## The code

```python
import sys

def main():
    data = sys.stdin.buffer.read().split()
    p = 0
    t = int(data[p]); p += 1
    out = []
    for _ in range(t):
        n = int(data[p]); p += 1
        a = data[p:p + n]; p += n

        S = [0] * (n + 2)          # S[v] = #windows ending at i with f >= v
        ans = dp = 0
        for i in range(1, n + 1):
            v = int(a[i - 1])
            S[0] = i               # every window contains the empty chain
            dp += S[v - 1] - S[v]  # windows sitting exactly at v-1 move up to v
            S[v] = S[v - 1]
            ans += dp
        out.append(ans)
    sys.stdout.write('\n'.join(map(str, out)) + '\n')

main()
```

$$O(N)$$ time, $$O(N)$$ space. Setting `S[0] = i` inside the loop is what removes the `v == 1` special
case — a fresh chain is just an extension of the empty one. Indexing `S` by value is safe because
the constraints promise $$1 \le A_i \le N$$.

Sample 2, `[2,1,1,2,1,3,4]`: increments $$0,2,1,3,2,3,3$$, so $$dp = 0,2,3,6,8,11,14$$, total 44. And
`[2,3,4,4]` is 0 because no window contains a `1`.

The invariant that keeps it all honest: $$S_v \le S_{v-1}$$ at all times, and each $$S_v$$ is
non-decreasing across $$i$$. So the assignment never shrinks anything, never needs undoing, and a
plain array is enough.

## The punchline: it's SUB1 with one operator swapped

Put the two loop bodies side by side. SUB1:

```python
largest_chain_start[0] = i
dp[i] = max(dp[i-1], v + dp[largest_chain_start[v-1] - 1])
largest_chain_start[v] = largest_chain_start[v-1]
```

SUB2:

```python
S[0] = i
dp += S[v-1] - S[v]
S[v] = S[v-1]
```

Same structure, same update, same invariant. In SUB1, `largest_chain_start[v]` is a *pointer* — the
latest index a chain $$1..v$$ can begin at — and you use it to jump the DP. In SUB2 the identical
number is a *count* — how many left endpoints admit a chain $$1..v$$. Those are the same quantity read
two ways, because "the latest start is at position $$S$$" and "exactly $$S$$ left endpoints work" are the
same statement once you know the valid $$L$$ form a prefix.

Which is really just monotonicity again. Both problems hinge on it; SUB1 uses it to argue the
shortest closing chain dominates, SUB2 uses it to compress the whole $$f$$-profile into one array.

## What I'd take away

The thing that actually cost me the time was not seeing the recurrence in plain language:
$$dp[i] = dp[i-1] + $$ the number of new left endpoints $$L$$ whose window can now reach $$a_i$$. Once
that sentence exists, every remaining question is mechanical — how do I count those endpoints, and
in what order do I read and update.

Both wrong turns after that were the same mistake in different clothes: I tracked the *witness*
(where a chain physically starts) when the DP needed the *count* (how many windows admit one). Worth
asking directly, before reaching for a data structure — what does my recurrence literally consume?
Often it's a cardinality, and cardinalities of monotone sets collapse to a single integer.
