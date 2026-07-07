---
layout: post
title: "[Repovive] Starter Round 4 C — Corner Meeting: Minimizing the Max of an Increasing and a Decreasing Function"
date: 2026-07-06 00:00:00 +0530
categories: competitive-programming
tags: [cp, math, repovive]
author: "Seroze"
published: true
---

*[Repovive Starter Round 4 — Problem C: Corner Meeting](https://repovive.com/contests/15/problems/C) (rated 1500). A neat observation completely simplifies this problem, and it generalizes into a pattern worth keeping in your toolbox.*

---

## The problem

On an $$(n+1) \times (n+1)$$ grid (coordinates $$0$$ to $$n$$), two pieces move simultaneously each turn:

- **Piece A** starts at $$(0,0)$$ and may stay put or move to a cell sharing a **side** with its current cell.
- **Piece B** starts at $$(n,n)$$ and may stay put or move to a cell sharing exactly one **corner** (diagonal moves only).

Neither piece may leave the board. Find the minimum number of moves for both pieces to occupy the same cell. Constraints: up to $$10^4$$ test cases with $$n \le 10^9$$ — so we need a closed form, not a search.

## Key insight: the meeting cell is on the main diagonal

Look at what each piece needs to reach a cell $$(x, y)$$, given that both can wait:

- **A** moves one side-step per turn, so it needs the Manhattan distance: $$x + y$$ moves.
- **B** changes *both* coordinates by $$\pm 1$$ every move, so it needs $$\max(n-x,\; n-y)$$ moves. (Its very first move is forced to $$(n-1, n-1)$$ — the other three diagonal neighbours of the corner are off the board.)

Now fix the sum $$s = x + y$$: A's cost depends only on $$s$$, while B's cost $$\max(n-x, n-y)$$ is minimized by *balancing* the coordinates, $$x = y = s/2$$. So among all cells with the same cost for A, the best one for B sits on the **main diagonal**. The meeting point can be assumed to be $$(d, d)$$ for some $$0 \le d \le n$$ — B just walks straight down the diagonal $$(n,n) \to (n-1,n-1) \to \dots$$

(One parity check: B's moves change $$x+y$$ by $$0$$ or $$\pm 2$$, so it can only ever stand on cells with $$x+y$$ even — and $$(d,d)$$ always qualifies.)

## Time taken by each piece

If they meet at $$(d, d)$$:

- **Piece A** needs Manhattan distance $$d + d = 2d$$, so it arrives in $$2d$$ moves.
- **Piece B** needs $$n - d$$ diagonal moves.

Since both pieces are allowed to **wait**, they meet after $$\max(2d,\; n-d)$$ moves, and the problem reduces to

$$\min_{0 \le d \le n} \; \max(2d,\; n-d).$$

## Finding the optimum

Notice:

- $$2d$$ is an **increasing** function of $$d$$.
- $$n - d$$ is a **decreasing** function of $$d$$.

Whenever we minimize the maximum of one increasing and one decreasing function, the optimum occurs where they are as close as possible. Equating them:

$$2d = n - d \quad\Longrightarrow\quad 3d = n \quad\Longrightarrow\quad d = \frac{n}{3}.$$

Since $$d$$ must be an integer, checking $$\lfloor n/3 \rfloor$$ and $$\lceil n/3 \rceil$$ is sufficient, and either yields the elegant closed-form answer:

$$\left\lceil \frac{2n}{3} \right\rceil.$$

## Solution

```python
t = int(input())
for _ in range(t):
    n = int(input())
    print((2 * n + 2) // 3)   # ceil(2n / 3)
```

O(1) per test case. Quick sanity checks: $$n=1$$ gives $$1$$ — they meet at $$(0,0)$$: A waits while B makes its single forced diagonal move, $$\max(0, 1) = 1$$. $$n=3$$ gives $$2$$ — meet at $$(1,1)$$: A takes $$2$$ side-steps, B takes $$2$$ diagonal steps. $$n=4$$ gives $$3$$ — meet at $$(1,1)$$: $$\max(2, 3) = 3$$.

## General CP pattern

The reusable trick here:

> If you encounter
>
> $$\min_x \; \max(f(x),\; g(x))$$
>
> where $$f(x)$$ is **increasing** and $$g(x)$$ is **decreasing**, the optimum is almost always attained near the crossing point $$f(x) = g(x)$$.

The max of an increasing and a decreasing function is "valley-shaped" (it decreases while $$g$$ dominates, increases once $$f$$ takes over), so the minimum sits at the crossover — solve $$f(x) = g(x)$$ analytically when you can, or binary search on it when you can't. This shows up constantly in optimization, scheduling, greedy proofs, and binary-search-on-answer problems.
