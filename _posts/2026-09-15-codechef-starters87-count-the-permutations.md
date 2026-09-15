---
layout: post
title: "[CodeChef] Starters 87 — Count the Permutations (always)"
date: 2026-09-15 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, combinatorics, counting, permutations, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Count the Permutations (always)](https://www.codechef.com/problems/COUNT_PERM)
(Starters 87, difficulty 2532). Official editorial:
[COUNT_PERM editorial](https://discuss.codechef.com/t/count_perm-editorial/105968).

This is a counting problem whose answer turns out to be a one-line product, and the fun part is
that the product has almost nothing to do with the structure you start out thinking about. I
started by reasoning about *gaps between consecutive maxima* — how many positions each gap has,
which values are allowed in it, how many ways to order them — and none of that survives into the
final formula. The gaps were the scaffolding, not the building.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

The prefix maximum array of an array $$B$$ is the subsequence of elements that are strictly bigger
than everything before them. For $$P = [2, 1, 4, 3]$$ it's $$[2, 4]$$: the 2 starts the array, the
4 beats it, and 1 and 3 never lead.

You're given $$A$$ of size $$K$$ with $$1 \le A_1 < A_2 < \cdots < A_K = N$$, and you have to count
the permutations $$P$$ of $$\{1, \ldots, N\}$$ whose prefix maximum array is exactly $$A$$, modulo
$$998244353$$. Constraints are $$N \le 10^6$$ with the sum of $$N$$ over tests also $$10^6$$, so
whatever you do has to be about linear per test.

Two sample answers to keep in your head: $$N = 4$$ with $$A = [2, 4]$$ gives 3, and $$N = 3$$ with
$$A = [3]$$ gives 2.

## What actually constrains a permutation

Forget positions for a moment and ask, for a single value $$v$$ that is *not* one of the $$A_i$$,
what the condition on $$v$$ is.

Let $$A_j$$ be the smallest element of $$A$$ that is bigger than $$v$$. I claim $$v$$ must appear
somewhere after $$A_j$$, and that's the whole constraint on $$v$$.

It's necessary: everything in $$A$$ before $$A_j$$ is smaller than $$v$$, by the choice of $$A_j$$.
So if $$v$$ sat anywhere to the left of $$A_j$$, every element before it would be one of
$$A_1, \ldots, A_{j-1}$$ (all smaller than $$v$$) or a non-maximum (smaller still), and $$v$$ would
become a prefix maximum itself. Not allowed, since $$v \notin A$$.

It's sufficient too, which is the part worth checking rather than assuming. Suppose every value
outside $$A$$ sits after its own $$A_j$$, and the elements of $$A$$ appear in increasing order.
Then no value outside $$A$$ can be a prefix maximum, because $$A_j > v$$ is already in front of it.
And each $$A_i$$ *is* a prefix maximum: anything to its left is either some earlier $$A_{j} < A_i$$
or some $$v$$ whose own $$A_{j}$$ is also to the left, which forces $$j < i$$ and hence
$$v < A_j \le A_{i-1} < A_i$$.

So the set of valid permutations is described entirely by "each small value lands after one
specific big value". In the concrete case $$N = 7$$, $$A = [3, 5, 7]$$ that reads: 1 and 2 go after
the 3, the 4 goes after the 5, and the 6 goes after the 7. Nothing else is restricted — in
particular, 1 and 2 are free to sit after the 7 if they like, and the relative order of the small
values is entirely free.

## Filling slots in increasing order

Now count. Lay out $$N$$ empty slots and place the values in this order:

$$A_1, \; 1, 2, \ldots, A_1 - 1, \; A_2, \; A_1+1, \ldots, A_2 - 1, \; A_3, \; \ldots$$

that is, each maximum first, then all the values below it that haven't been placed yet. Two things
happen, and both are pleasantly rigid.

**Every $$A_i$$ has exactly one legal slot: the leftmost free one.** When it's $$A_i$$'s turn, the
values already placed are $$A_1, \ldots, A_{i-1}$$ together with *every* value below $$A_{i-1}$$.
So every value still waiting is bigger than $$A_{i-1}$$, and by the rule from the previous section
every one of them has to land after $$A_i$$. All the remaining slots are therefore to the right of
$$A_i$$, which pins $$A_i$$ to the first free slot. One way, no choice, no factor.

**Every other value can go in any free slot at all.** When it's $$v$$'s turn, its gatekeeper
$$A_j$$ has already been placed, and by the same argument every free slot at that moment lies to
the right of $$A_j$$. So all of them are legal, and if $$L$$ values have been placed so far there
are exactly $$N - L$$ choices.

The process is reversible — given a valid permutation, replaying it in this order recovers the
choices — so multiplying the counts is legitimate, not just suggestive.

## The product collapses

Track $$L$$ through the process. Take a value $$v \notin A$$ with gatekeeper $$A_j$$, and list what
is on the board when $$v$$'s turn comes. Every value smaller than $$v$$ is already placed: the ones
below $$A_{j-1}$$ went down in earlier batches, $$A_{j-1}$$ itself is a maximum from an earlier
round, and the ones between $$A_{j-1}$$ and $$v$$ are in $$v$$'s own batch, which runs upward. The
only value *bigger* than $$v$$ that's down is $$A_j$$, placed at the head of this batch — the
maxima above it haven't had their turn yet. So

$$L = (v - 1) + 1 = v,$$

and the number of free slots for $$v$$ is $$N - v$$, independent of where the gaps fall.

Every value contributes, except the ones in $$A$$, which contribute a forced 1. So

$$\text{answer} = \prod_{v \notin A} (N - v) \pmod{998244353}.$$

That's it. No gap lengths, no binomials choosing which values go in which gap, no factorials for
ordering within a gap. The array $$A$$ enters the answer only through *which factors it deletes*
from the product $$(N-1)(N-2)\cdots 1$$.

Checks:

- $$N = 4$$, $$A = [2, 4]$$: missing values 1 and 3, so $$3 \cdot 1 = 3$$. ✓
- $$N = 3$$, $$A = [3]$$: missing 1 and 2, so $$2 \cdot 1 = 2$$. ✓
- $$N = 7$$, $$A = [3, 5, 7]$$: missing 1, 2, 4, 6, so $$6 \cdot 5 \cdot 3 \cdot 1 = 90$$. I brute
  forced all $$5040$$ permutations of length 7 and there are indeed 90.

A couple of instant sanity reads fall out of the formula. $$A = [N]$$ deletes nothing, giving
$$(N-1)!$$ — the permutations starting with $$N$$, which is obviously right. And $$A_1 = 1$$ forces
$$A = [1, 2, \ldots, N]$$, which deletes every factor and leaves 1: the sorted permutation, the
only one whose prefix maxima are everything.

## Why the answer is never zero

The title of the problem is "Count the Permutations (always)" and the parenthetical is a hint at
this: the count is never 0. Look at the product — the only factor that could vanish is $$N - v$$
with $$v = N$$, and $$N$$ is always in $$A$$ because the constraints say $$A_K = N$$. So every
factor is at least 1 and some valid permutation always exists. If the problem had allowed
$$A_K < N$$ the answer would have been 0 for all such inputs, since the maximum of a permutation is
unavoidably a prefix maximum.

## A second derivation, from the top down

There's another angle that makes the $$N - v$$ factor feel less like bookkeeping. Build the
permutation by inserting values in *decreasing* order, $$N, N-1, \ldots, 1$$, into a growing
sequence.

When you're about to insert $$v$$, the sequence holds exactly the $$N - v$$ values bigger than
$$v$$. If $$v \in A$$, it has to precede every value bigger than itself — its own gatekeeper
argument, run in reverse — so it goes at the very front: one way. If $$v \notin A$$, its gatekeeper
$$A_j$$ is the smallest placed value bigger than $$v$$, and since the $$A$$ elements keep going to
the front, $$A_j$$ is sitting at the head of the sequence right now. So $$v$$ can go into any of
the $$N - v$$ gaps that follow the first element.

Same product, and this time $$N - v$$ is literally "the number of values bigger than $$v$$" rather
than a running slot counter.

## Code

```python
import sys

def main():
    data = sys.stdin.buffer.read().split()
    MOD = 998244353
    t = int(data[0])
    idx = 1
    out = []
    for _ in range(t):
        n = int(data[idx]); k = int(data[idx + 1]); idx += 2
        a = data[idx:idx + k]; idx += k

        in_a = bytearray(n + 1)
        for x in a:
            in_a[int(x)] = 1

        ans = 1
        for v in range(1, n):        # v = n contributes a zero factor, but n is always in A
            if not in_a[v]:
                ans = ans * (n - v) % MOD
        out.append(ans)

    sys.stdout.write('\n'.join(map(str, out)) + '\n')

main()
```

Linear in $$N$$ per test, and the `bytearray` is reallocated per test rather than cleared globally
so the total work stays tied to the sum of $$N$$.

## The wrong turn I took

For the record, the bug I wrote while formalising this was not in the combinatorics — it was a
loop that computed a separate `ans` for each gap and then *added* the gaps together. Adding is what
you do over disjoint cases; here the gaps are independent choices made simultaneously, so it's a
product. I had the right derivation on paper and typed the wrong operator, which is a much more
embarrassing failure mode than being confused, and much easier to catch: the first sample would
have printed $$3 + 1 = 4$$ instead of 3.

## What I'm taking away

The thing I want to remember is the move that unlocked it: **stop reasoning about positions and
start reasoning about one value at a time.** My first framing was "for each gap between consecutive
maxima, which values can fill it, and in how many orders" — a question about regions, with the
regions interacting through a shared pool of values. The framing that worked was "for each value,
what is the one element it must appear after", which turns a tangled global condition into $$N$$
independent local ones. Once the conditions are independent, multiplying is allowed, and the
formula writes itself.

I suspect that's a general reflex worth building for permutation counting: find the per-element
constraint, find an insertion order that makes each element's count depend only on how many are
already placed, and the product is the answer.

## TODO

- Do the same exercise for counting permutations by the *number* of prefix maxima rather than an
  exact prefix maximum array — that's unsigned Stirling numbers of the first kind, and the
  insertion argument above should derive their recurrence almost for free.
- Find a problem where the per-value constraint is "after at least one of several elements" instead
  of "after one specific element", and see what breaks.
