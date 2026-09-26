---
layout: post
title: "[CodeChef] Starters 81 — Good XOR: the case I ruled out with a parity argument"
date: 2026-09-26 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, missed_case, invariants, parity, greedy, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Good XOR](https://www.codechef.com/problems/ASFA) (Starters 81 Division 1,
same round as [Beautiful Strings]({% post_url 2026-09-26-codechef-starters81-beautiful-strings %})).
Official editorial: [ASFA — Editorial](https://discuss.codechef.com/t/asfa-editorial/105531).

A binary array is *good* if it has as many ones as zeros. One operation picks two distinct indices
$$i \ne j$$ and sets both $$A_i$$ and $$A_j$$ to $$A_i \oplus A_j$$. Find the minimum number of
operations to make $$A$$ good, or $$-1$$.

This one I nearly had in five minutes, and then scored 68/100 — because I declared a whole family
of inputs impossible with a parity argument that was only half true. The post is mostly about that
mistake, since the actual solution is four lines.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The state is just the number of ones

The operation looks like it cares about positions, but it doesn't. Every pair falls into one of
three cases, and the only thing that changes is the count of ones, which I'll call $$k$$:

- two zeros: $$00 \to 00$$, a no-op, $$k$$ unchanged
- a zero and a one: $$01 \to 11$$, so $$k \to k + 1$$
- two ones: $$11 \to 00$$, so $$k \to k - 2$$

So the whole problem is a walk on a single integer. From $$k$$ you may move to $$k + 1$$ (provided
there is at least one zero *and* at least one one to pair up, i.e. $$1 \le k \le N - 1$$) or to
$$k - 2$$ (provided $$k \ge 2$$). The target is $$k = N/2$$, which is why odd $$N$$ is immediately
$$-1$$.

Two things fall out right away. An all-zero array is stuck forever: $$k = 0$$ has no outgoing
moves at all, since the only pair available is $$00 \to 00$$. And when $$k$$ is below the target,
each $$+1$$ move closes the gap by exactly one, so the answer there is just $$N/2 - k$$ with no
parity condition to worry about.

## The mistake: $$k$$ above the target

Here's where I went wrong. With $$d = k - N/2 > 0$$ I need to come *down*, and the only move that
comes down is $$-2$$. So I reasoned: $$k$$ can only change by $$-2$$ on the way down, therefore
$$d$$ must be even, therefore odd $$d$$ is impossible. Print $$-1$$.

That got 68/100 — four subtasks correct, then a wrong answer.

The hole is that I quietly assumed the walk is monotone. It isn't. The $$+1$$ move is still
available when $$k$$ is above the target; nothing says I have to move towards the goal on every
step. If $$d$$ is odd, I can spend one operation going *up*, which makes the gap even, and then
come down in twos:

```text
0111   k = 3, target 2, d = 1
  ↓ 01 -> 11
1111   k = 4, d = 2
  ↓ 11 -> 00
0011   k = 2   done, 2 operations
```

So odd $$d$$ costs one extra $$+1$$ plus $$(d+1)/2$$ moves of $$-2$$:

$$\text{ops} = \begin{cases} d/2 & d \text{ even} \\ \lfloor d/2 \rfloor + 2 & d \text{ odd} \end{cases}$$

And that's optimal, not just feasible: if $$a$$ is the number of $$+1$$ moves and $$b$$ the number
of $$-2$$ moves, then $$a - 2b = -d$$, and minimising $$a + b$$ subject to that gives $$a = 0$$ for
even $$d$$ and $$a = 1$$ for odd $$d$$. You can't do better than one wasted step, and you never
need two.

The general lesson, and the reason I'm writing this up: **a parity invariant tells you what is
reachable, not what is reachable while moving in one direction.** I had the right invariant — the
$$-2$$ move preserves parity — and then used it to rule out a case that the other move fixes in a
single step. Whenever an argument sounds like "the only useful move is X, so Y is impossible",
check whether the *useless* move buys you a parity flip.

## The all-ones scare

My next worry was the array with no zeros at all. If $$k = N$$ there is no $$01$$ pair, so the
$$+1$$ move isn't available, and an odd $$d$$ looked impossible again.

It isn't, and the fix is to reorder: burn one $$-2$$ first, which manufactures the zeros you need.
For $$N = 6$$, all ones, $$d = 3$$:

```text
111111   k = 6
  ↓ 11 -> 00
111100   k = 4
  ↓ 01 -> 11
111110   k = 5
  ↓ 11 -> 00
111000   k = 3   done, 3 operations
```

Three operations, which is exactly $$\lfloor 3/2 \rfloor + 2$$. No special case needed: the formula
already counts the same number of moves, we just perform them in a different order.

## The one edge case that survives

There is exactly one input where the reordering has nowhere to go: $$N = 2$$ with $$A = [1, 1]$$.
The target is one, $$d = 1$$ is odd, so the formula wants two operations — but the only legal move
is $$11 \to 00$$, and from $$[0, 0]$$ nothing can ever happen again. The answer is $$-1$$.

The reason $$N = 2$$ is special is that the "burn a $$-2$$ first" trick needs at least one one left
over afterwards to pair with the new zeros, and $$N - 2 = 0$$ leaves none. For every even
$$N \ge 4$$ there's always a survivor.

The editorial words the same case differently — it tracks $$d$$ as ones minus zeros, so its cases
are multiples of four rather than of two, and its edge case reads "if $$d$$ is not a multiple of
$$4$$ and the number of ones is $$2$$". Same input: two ones and no zeros.

## The code

```python
import sys

def main():
    data = sys.stdin.buffer.read().split()
    t = int(data[0])
    pos = 1
    out = []
    for _ in range(t):
        n = int(data[pos]); pos += 1
        ones = 0
        for x in data[pos:pos + n]:
            ones += x == b'1'
        pos += n

        half = n // 2
        if n % 2 or ones == 0:
            ans = -1
        elif ones == half:
            ans = 0
        elif ones < half:
            ans = half - ones                  # each 01 -> 11 gains exactly one
        else:
            d = ones - half
            if d % 2 == 0:
                ans = d // 2
            elif n == 2:                       # [1, 1]: one move, then dead
                ans = -1
            else:
                ans = d // 2 + 2               # one step up, then down in twos
        out.append(ans)

    sys.stdout.write('\n'.join(map(str, out)) + '\n')

main()
```

The tester's C++ compresses the whole $$k > N/2$$ branch into one expression. With
$$d' = \text{ones} - \text{zeros}$$, which is always even here, $$d' \bmod 4$$ is either $$0$$ or
$$2$$, so

$$\text{ops} = \frac{d'}{4} + (d' \bmod 4)$$

covers both parities in one line. Cute, but I'd rather keep the two cases visible.

## Settling it with BFS instead of arguing

I went back and forth on the all-ones case twice — first convinced it was impossible, then
convinced by the $$N = 6$$ trace that it was fine — and that's a bad sign. Two plausible arguments
pointing opposite ways means stop arguing and enumerate.

Since the state is just $$k$$, the true answer is a breadth-first search on at most $$N + 1$$
nodes:

```python
from collections import deque

def bfs(n, k0):
    if n % 2:
        return -1
    target = n // 2
    dist = {k0: 0}
    q = deque([k0])
    while q:
        k = q.popleft()
        if k == target:
            return dist[k]
        nxt = []
        if 1 <= k <= n - 1:       # 01 -> 11
            nxt.append(k + 1)
        if k >= 2:                # 11 -> 00
            nxt.append(k - 2)
        for m in nxt:
            if m not in dist:
                dist[m] = dist[k] + 1
                q.append(m)
    return -1
```

That agrees with the formula for every $$(N, k)$$ with $$N \le 40$$. I also ran a slower BFS over
**actual arrays** — full tuples, every $$(i, j)$$ pair as a move, no assumption that only the count
matters — for every binary array of length up to $$8$$, and it agrees there too. That second run is
the one that matters, because it's the only check that doesn't already trust my reduction to a
single integer.

Writing the array-level BFS takes about three minutes and it would have found the $$[1, 1]$$ case
before the submission did.

<div class="note-red" markdown="1">
**Two takeaways.** A parity invariant constrains *reachability*, not the *direction* you travel —
"the only move that helps is $$-2$$, so the gap must be even" ignores that a single wasted $$+1$$
fixes the parity for one extra operation. And when a case keeps flipping between possible and
impossible in your head, BFS the state space over small inputs rather than trusting the next
argument; the state here is one integer, so the check is cheaper than the debate.
</div>
