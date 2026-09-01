---
layout: post
title: "[CodeChef] Starters 96 — Zero Array: when the last equation is the whole problem"
date: 2026-09-01 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, linear_algebra, constructive, parity, bipartite, ad_hoc]
author: "Seroze"
published: true
---

Problem: [CodeChef — Zero Array](https://www.codechef.com/problems/ZERARR) (Starters 96, difficulty 2754)

You get a $$0$$-indexed **cyclic** array $$A$$ of $$N$$ non-negative integers. One operation is:
pick an index $$k$$ and subtract $$1$$ from both $$A_k$$ and $$A_{(k+1) \bmod N}$$ — two adjacent
elements of the cycle. Can you make every element zero?

$$N$$ goes up to $$10^6$$, summed over all test cases, and $$A_i$$ up to $$10^9$$. So anything that
simulates operations is dead on arrival: a single test case can need $$10^{15}$$ of them.

## Stop thinking about the sequence of moves

The first useful move is to stop asking *what order do I apply operations in* and start asking
*how many times is each operation used*. The operations commute — subtracting from positions
$$(2,3)$$ and then $$(5,6)$$ is the same as doing it the other way round — so the order genuinely
carries no information. Only the counts matter.

Let $$x_k \ge 0$$ be the number of times we use the operation at index $$k$$. Element $$A_i$$ is
touched by exactly two operations: the one at $$i$$ (which hits $$A_i$$ and $$A_{i+1}$$) and the one
at $$i-1$$ (which hits $$A_{i-1}$$ and $$A_i$$). Zeroing the array means each element is decremented
exactly $$A_i$$ times, so

$$a_i = x_{i-1} + x_i \qquad \text{for all } i, \text{ indices mod } N$$

That's it. The whole problem is now: does this cyclic linear system have a solution in
non-negative integers?

This is the reframing that does the real work, and it generalises far beyond this problem.
"Sequence of operations" is a search space; "how many times did I use each operation" is
a system of equations.

## The system is not really a matrix

The reflex on seeing $$Ax = b$$ with $$N = 10^6$$ is despair — Gaussian elimination is
$$O(N^3)$$ and you can't even store the matrix. But the right question isn't *how do I solve a
general system this big*, it's *what is special about this particular matrix*. Here each equation
involves only two consecutive variables, which means the system isn't a matrix at all. It's a
recurrence:

$$x_i = a_i - x_{i-1}$$

Pick $$x_0$$ and everything else falls out. Unrolling:

$$x_1 = a_1 - x_0$$

$$x_2 = a_2 - a_1 + x_0$$

$$x_3 = a_3 - a_2 + a_1 - x_0$$

$$x_4 = a_4 - a_3 + a_2 - a_1 + x_0$$

The pattern is clear enough to name. Write

$$x_i = c_i + (-1)^i x_0$$

where $$c_i$$ is the alternating sum $$a_i - a_{i-1} + \dots \pm a_1$$, with $$c_0 = 0$$. Both
pieces satisfy the same one-line recurrence, so you never actually need the closed form:

$$c_i = a_i - c_{i-1}$$

and the sign just flips every step.

## The equation you haven't used yet

Here's the part I initially walked right past. The recurrence $$x_i = a_i - x_{i-1}$$ was used for
$$i = 1, 2, \dots, N-1$$ — that's $$N-1$$ of the $$N$$ equations. The array is *cyclic*, so there's
one more, the one for $$i = 0$$:

$$a_0 = x_{N-1} + x_0$$

Every variable is already expressed in terms of $$x_0$$, so this last equation is a single
constraint on a single unknown. It's what closes the loop, and it's where the entire problem
lives. Whenever you propagate a cyclic constraint around a ring and reach the start again, the
equation waiting for you there is the answer — nothing else is left.

Substituting $$x_{N-1} = c_{N-1} + (-1)^{N-1} x_0$$:

$$a_0 = x_0 + c_{N-1} + (-1)^{N-1} x_0$$

And now the parity of $$N$$ decides what kind of problem you have, because it decides whether the
two $$x_0$$ terms add or cancel.

## Odd $$N$$: the array tells you $$x_0$$

If $$N$$ is odd then $$N-1$$ is even, the sign is $$+1$$, and the equation is

$$a_0 = 2 x_0 + c_{N-1} \quad \Longrightarrow \quad x_0 = \frac{a_0 - c_{N-1}}{2}$$

There is exactly one candidate. It has to be a non-negative integer, so $$a_0 - c_{N-1}$$ must be
even and non-negative; and then, since every other $$x_i$$ is forced, you just run the recurrence
forward and check that nothing goes negative.

A small aside on that parity test. Every term $$a_j$$ appears in $$a_0 - c_{N-1}$$ exactly once,
with some sign, and signs don't matter modulo $$2$$. So

$$a_0 - c_{N-1} \equiv \sum_j a_j \pmod 2$$

which means the integrality condition is just *the total sum must be even* — obvious in hindsight,
since every operation removes exactly $$2$$ from the sum. Nice when a mechanical condition turns
out to be a fact you already knew.

Once you have $$x_0$$ you can throw the $$c_i$$ array away and use the original recurrence
$$x_i = a_i - x_{i-1}$$ directly. Same numbers, less code, no sign bookkeeping to get wrong.

## Even $$N$$: $$x_0$$ vanishes

If $$N$$ is even then $$N-1$$ is odd, the sign is $$-1$$, and the two $$x_0$$ terms cancel:

$$a_0 = x_0 + (c_{N-1} - x_0) = c_{N-1}$$

The unknown is gone. What's left is a condition on the input alone, and unpacking $$c_{N-1}$$ it
says exactly

$$a_0 - a_1 + a_2 - a_3 + \dots - a_{N-1} = 0$$

The alternating sum of the array must be zero. Equivalently: the even-indexed elements and the
odd-indexed elements must have the same total.

If that fails, the answer is NO. If it holds, the last equation gave us nothing about $$x_0$$ —
it's free. Which sounds like good news but is actually where the remaining work is, because we
still need *some* choice of $$x_0$$ making every $$x_i$$ non-negative. Each variable turns into a
bound:

- $$i$$ even: $$x_i = c_i + x_0 \ge 0$$, so $$x_0 \ge -c_i$$ — a lower bound
- $$i$$ odd: $$x_i = c_i - x_0 \ge 0$$, so $$x_0 \le c_i$$ — an upper bound

So $$x_0$$ has to land in the intersection of $$N$$ half-lines, which is one interval. Keep the
strongest lower bound and the strongest upper bound as you sweep, start the lower bound at $$0$$
(since $$x_0$$ itself is a count), and the answer is YES exactly when the interval is non-empty.
One pass, no search.

It's worth checking that this second test isn't vacuous — that the alternating sum can be zero and
the answer still NO. The smallest example I found is

```
0 0 1 0 0 1
```

Alternating sum: $$0 - 0 + 1 - 0 + 0 - 1 = 0$$. But look at the array: $$A_2 = 1$$ and both its
neighbours are already $$0$$, so no operation can ever touch it. The bounds catch this without
knowing anything about that argument — you get $$c = [0, 0, 1, -1, 1, 0]$$, a lower bound of
$$0$$ and an upper bound of $$\min(0, -1, 0) = -1$$, an empty interval.

## What the parity split actually is

The odd/even behaviour looks like an accident of sign bookkeeping, but it isn't. Draw the problem
as a graph: vertices are array positions, edges join adjacent positions, so the graph is the cycle
$$C_N$$. Operations live on edges, elements live on vertices, and $$a_i = x_{i-1} + x_i$$ says
*the edge values around each vertex must sum to that vertex's value*. The matrix of the system is
the unsigned incidence matrix of $$C_N$$.

And there's a classical fact about unsigned incidence matrices: they are singular exactly when the
graph is bipartite. A cycle is bipartite exactly when it's even. So:

- **$$N$$ odd** — non-singular, one solution, and all the work is checking it's a legal one.
- **$$N$$ even** — singular with a one-dimensional kernel, which is precisely the alternating
  $$(+1, -1, +1, \dots)$$ vector we watched appear. A solvable system then has a whole line of
  solutions, and there's a compatibility condition on the right-hand side — our alternating sum.

That reframing is worth more than the problem. "Cyclic dependency + parity matters" is usually
bipartiteness in disguise, and once you see it you can predict the shape of the answer before
doing any algebra: odd cycle means rigid, even cycle means one free parameter plus one condition
on the input.

## Code

```python
import sys

def solve(n, a):
    # x[i] = c[i] + (-1)^i * x0, from x[i] = a[i] - x[i-1]
    c = [0] * n
    for i in range(1, n):
        c[i] = a[i] - c[i - 1]

    if n & 1:
        # a[0] = x0 + x[n-1] = 2*x0 + c[n-1]
        t = a[0] - c[-1]
        if t < 0 or t & 1:
            return False
        x = t // 2
        for i in range(1, n):          # x0 is forced, so just replay the recurrence
            x = a[i] - x
            if x < 0:
                return False
        return True

    # a[0] = x0 + (c[n-1] - x0) = c[n-1]  ->  x0 cancelled out
    if a[0] != c[-1]:
        return False
    lo, hi = 0, float('inf')
    for i in range(n):
        if i & 1:
            if c[i] < hi: hi = c[i]     # c[i] - x0 >= 0
        else:
            if -c[i] > lo: lo = -c[i]   # c[i] + x0 >= 0
    return lo <= hi

def main():
    data = sys.stdin.buffer.read().split()
    p = 1
    out = []
    for _ in range(int(data[0])):
        n = int(data[p]); p += 1
        a = list(map(int, data[p:p + n])); p += n
        out.append("YES" if solve(n, a) else "NO")
    sys.stdout.write("\n".join(out) + "\n")

main()
```

Note that the odd branch never uses `c` except for its last entry, and the even branch never uses
`a` except for its first. You could specialise further, but at $$10^6$$ total it doesn't matter.

## Checking it

I ran this against a BFS brute force that explores the state space of actual operations, over
**every** array with $$2 \le N \le 7$$ and entries in $$[0, 4]$$ — 97,650 cases, zero mismatches.
That's the kind of exhaustive check this problem deserves, because the failure modes here are all
edge cases: a sign flipped somewhere, an off-by-one on which index is even, forgetting that
$$x_0 \ge 0$$ is itself a constraint.

On timing, the whole thing is $$O(N)$$ per test with two passes and no allocation beyond the `c`
array. Locally a single $$N = 10^6$$ case runs in about 0.18 s including I/O, and $$10^5$$ test
cases summing to $$10^6$$ runs in about the same, against a 1 s limit. The judge is slower than my
laptop, so if it's tight the even branch can drop `c` entirely and track the running alternating
sum in a single loop.

## What I want to keep from this

**Count the operations, don't order them.** When operations commute, "which sequence of moves"
is the wrong question and "how many of each" is the right one. That single change turns a search
problem into algebra.

**A sparse system is a recurrence.** $$Ax = b$$ with $$N = 10^6$$ is hopeless in general and
trivial when each equation touches two adjacent variables. Before reaching for linear algebra
machinery, look at the sparsity pattern — banded systems collapse into propagation.

**Find the equation you haven't used.** I expressed everything in terms of $$x_0$$ and then stalled,
because it felt like I'd run out of information. I hadn't: there was one equation left, and in a
cyclic problem the leftover equation is always the one that closes the ring. If you've reduced
$$n$$ unknowns to one and don't know what to do next, count how many of your constraints you've
actually spent.

**Parity that changes the algebra is usually structural.** The alternating $$\pm x_0$$ wasn't just
a sign to track; it was the kernel of a singular matrix announcing itself, and the singularity was
bipartiteness. When odd and even inputs behave *qualitatively* differently — not "one has an extra
term" but "one has a free variable and the other doesn't" — there's normally a structural reason
worth finding, and it usually generalises to the next problem.
