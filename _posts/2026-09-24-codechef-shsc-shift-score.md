---
layout: post
title: "[CodeChef] SHSC — Shift Score: I reached for rerooting when counting edges was enough"
date: 2026-09-24 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, trees, contribution_technique, unnessary_introduction_of_complexity, todo]
author: "Seroze"
published: true
---

Problem: [CodeChef — Shift Score](https://www.codechef.com/problems/SHSC) (difficulty 2049).

A short post. I haven't solved this one yet. I'm writing it up because I made two mistakes in
the first ten minutes, and both are worth remembering.

## The problem

You're given a tree rooted at $$1$$, with every vertex colored white or black. The **score** is
the sum of $$d(u, v)$$ over all pairs of vertices that have the same color. You may do one
operation, or none: pick a vertex $$u \ne 1$$, cut the edge $$(u, par(u))$$, and reattach $$u$$
to some **ancestor** $$v$$ of $$u$$. Minimise the score.

## Mistake 1: rerooting to get the initial score

My first plan for the score with no operation was tree rerooting. For every vertex, compute the
sum of distances to all black vertices and to all white vertices, using subtree DP and then the
reroot step $$ALL_1[v] = ALL_1[u] + B - 2\cdot cnt_1[v]$$. Then add up over same-colored vertices
and divide by $$2$$.

That's correct, but it's far more work than the question needs. The **contribution trick**
does it in one line. An edge lies on the path between two vertices exactly when they are on
opposite sides of it. If the subtree below an edge has $$b$$ black and $$w$$ white vertices:

$$\text{score} = \sum_{\text{edges}} \Big[\, b\,(B - b) + w\,(W - w) \,\Big]$$

That's one DFS for subtree counts, with no rerooting and no halving. Checking sample 2
(edges $$1\!-\!2, 2\!-\!3, 2\!-\!4, 4\!-\!5$$, colors `0 1 0 1 1`): the four edges contribute
$$1 + 1 + 2 + 2 = 6$$, which matches the statement.

The rule for next time: if the quantity is a **sum of path lengths**, count how many paths use
each edge before building per-vertex distance sums.

## Mistake 2: ignoring the "ancestor" constraint

Next I split the score into three parts: pairs inside the moved subtree, pairs outside it, and
pairs that cross between them. The first two parts don't change, so

$$\text{new} = \text{old} - \text{CROSS}_{\text{old}} + \text{CROSS}_{\text{new}}$$

That's correct. Then I got stuck on why the cross contribution would change at all. I was
picturing the subtree being moved to an arbitrary place. The statement says $$v$$ has to be an
**ancestor** of $$u$$, and that constraint is the whole structure of the problem.

With $$k = depth[u] - depth[v]$$, take any vertex $$x$$ in the moved subtree:

- **Outside vertices that aren't on the path $$v \to par(u)$$** get exactly $$k$$ closer to $$x$$.
- **Vertices on the path $$v \to par(u)$$** (the ancestors you skip over) get *farther* from $$x$$.

So "always move to the root" is **not** the answer. Every edge you move up saves distance to
the rest of the tree, but it adds distance to the chain of ancestors you skip. The best
ancestor is the point where those two effects balance.

## TODO

- [ ] Write the exact $$\Delta(u, v)$$ in terms of color counts. Moving up one edge at a time
      looks like the clean way to do it.
- [ ] Find the best $$v$$ for every $$u$$ in total $$O(N)$$ or $$O(N \log N)$$.
- [ ] Write a brute force (try every $$(u, v)$$, recompute the score) and check it against all 5 samples.
- [ ] Write the fast solution and verify it against the brute force.

<div class="note-red" markdown="1">
**Two lessons.** (1) For a sum of pairwise distances, count each edge's contribution before
reaching for rerooting. (2) Read every word of the operation. "Reattach to an *ancestor*" is
not the same as "reattach anywhere", and the difference changes which pair distances go down
and which go up.
</div>
