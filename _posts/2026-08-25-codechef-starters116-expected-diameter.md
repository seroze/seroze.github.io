---
layout: post
title: "[CodeChef] Starters 116 — Expected Diameter: two extra nodes and the vertices that matter"
date: 2026-08-25 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, trees, bfs, graph_theory, counting]
author: "Seroze"
published: true
---

Problem: [CodeChef — Expected Diameter](https://www.codechef.com/problems/EXEPDIAM) (Starters 116)

You're given a tree with $$N$$ nodes and two extra labelled nodes $$a$$ and $$b$$. Attach them so the
result is still a tree, and count how many of those attachments have diameter strictly greater than
the original. Constraints: $$N \le 10^5$$, $$\sum N \le 10^6$$, so the whole thing has to be linear.

The name says "expected" but there's no probability anywhere — it's a straight count.

## How many ways are there to attach at all?

The new tree has $$N+2$$ nodes, so it has $$N+1$$ edges, so exactly two edges get added. Both $$a$$
and $$b$$ have to end up connected, which leaves three shapes:

- $$a$$ hangs off some node $$u$$ of the tree and $$b$$ off some node $$v$$ — possibly the same node.
  That's $$N^2$$ ordered choices.
- $$a$$ hangs off some $$u$$, and $$b$$ hangs off $$a$$: a two-node tail. $$N$$ choices.
- The same tail with the roles swapped. Another $$N$$.

So $$N^2 + 2N$$ configurations, and we want the ones that stretch the diameter.

## The two-pendant case

Write $$D$$ for the original diameter and $$\text{ecc}(x)$$ for the eccentricity of $$x$$, the
distance to the farthest node from it. Hanging $$a$$ off $$u$$ and $$b$$ off $$v$$ gives a new
diameter of

$$\max\bigl(D,\; \text{ecc}(u)+1,\; \text{ecc}(v)+1,\; d(u,v)+2\bigr)$$

and we need that to exceed $$D$$. Since every eccentricity is at most $$D$$, the term
$$\text{ecc}(u)+1$$ beats $$D$$ exactly when $$\text{ecc}(u) = D$$ — that is, when $$u$$ is an
endpoint of some diameter. Call such vertices *peripheral*. The last term beats $$D$$ when
$$d(u,v) \ge D-1$$.

Two separate conditions, then. Except the second one is redundant, which is the observation the
whole problem turns on:

> If $$d(u,v) \ge D-1$$ then at least one of $$u, v$$ is peripheral.

Suppose not. Then $$\text{ecc}(u)$$ and $$\text{ecc}(v)$$ are both at most $$D-1$$, and since
eccentricity is at least the distance to anything, $$d(u,v) = D-1$$ exactly. Now take a diametral
pair $$e_1, e_2$$ and look at the three ways to pair up $$\{u, v, e_1, e_2\}$$:

$$d(u,v) + d(e_1,e_2) = (D-1) + D = 2D-1$$

$$d(u,e_1) + d(v,e_2) \le (D-1) + (D-1) = 2D-2$$

$$d(u,e_2) + d(v,e_1) \le (D-1) + (D-1) = 2D-2$$

In a tree metric the largest of those three sums is always attained at least twice — that's the
four-point condition, and it's what "this metric came from a tree" means. Here the first sum is
strictly the largest. Contradiction.

So the two-pendant case reduces to *at least one of $$u, v$$ is peripheral*. If $$X$$ is the number
of peripheral vertices, complementary counting gives

$$N^2 - (N-X)^2.$$

## The tail case

Hanging $$b$$ off $$a$$ off $$u$$ pushes one node out to distance $$\text{ecc}(u)+2$$, so the new
diameter is $$\max(D, \text{ecc}(u)+2)$$, which exceeds $$D$$ when $$\text{ecc}(u) \ge D-1$$. That
admits the peripheral vertices *and* the ones one step short of it. With $$Y$$ counting vertices of
eccentricity exactly $$D-1$$, and a factor of two for which new node sits on the outside:

$$2(X+Y).$$

Notice $$d(u,v)$$ never appears here, which is the whole reason this case is easier — a tail only
ever reaches away from a single anchor.

## Getting X and Y

Both counts need every eccentricity, and in a tree there's a shortcut: the farthest vertex from any
$$x$$ is an endpoint of some diameter, so for a *fixed* diametral pair $$e_1, e_2$$,

$$\text{ecc}(x) = \max\bigl(d(x,e_1),\, d(x,e_2)\bigr).$$

That's three BFS passes. One from an arbitrary node to land on $$e_1$$, one from $$e_1$$ to find
$$e_2$$ and record $$d_1$$, one from $$e_2$$ to record $$d_2$$. Then one sweep buckets every vertex
into $$X$$, $$Y$$, or neither. The first BFS isn't optional — starting from an arbitrary node gives
you no guarantee, and it's only the *second* pass onward that's anchored to the diameter.

## The code

```python
import sys
from collections import deque

def bfs(src, n, adj):
    dist = [-1] * (n + 1)
    dist[src] = 0
    q = deque([src])
    while q:
        u = q.popleft()
        for v in adj[u]:
            if dist[v] == -1:
                dist[v] = dist[u] + 1
                q.append(v)
    return dist

def farthest(dist, n):
    best, node = -1, 1
    for v in range(1, n + 1):
        if dist[v] > best:
            best, node = dist[v], v
    return node

def solve(n, it):
    adj = [[] for _ in range(n + 1)]
    for _ in range(n - 1):
        u = int(next(it)); v = int(next(it))
        adj[u].append(v)
        adj[v].append(u)

    if n == 1:
        return 3                      # D = 0, X = 1, Y = 0

    e1 = farthest(bfs(1, n, adj), n)  # one endpoint of a diameter
    d1 = bfs(e1, n, adj)
    e2 = farthest(d1, n)              # the other endpoint
    d2 = bfs(e2, n, adj)
    D = d1[e2]

    X = Y = 0
    for v in range(1, n + 1):
        ecc = d1[v] if d1[v] > d2[v] else d2[v]
        if ecc == D:
            X += 1
        elif ecc == D - 1:
            Y += 1

    return n * n - (n - X) * (n - X) + 2 * (X + Y)

def main():
    it = iter(sys.stdin.buffer.read().split())
    t = int(next(it))
    out = []
    for _ in range(t):
        n = int(next(it))
        out.append(solve(n, it))
    sys.stdout.write("\n".join(map(str, out)) + "\n")

main()
```

The single-node case falls outside the derivation — there's no diameter to compare against — but it
works out anyway: $$D = 0$$, the one vertex is peripheral, and all three configurations produce a
path of length $$2$$. Reading the input through one iterator instead of a running index costs
nothing and removes an entire category of off-by-one.

## Checking it

Small trees first: $$N=1 \to 3$$, $$N=2 \to 8$$, the sample chain $$\to 24$$. A $$4$$-node star is
the interesting one, since it's the smallest case where a vertex counted by $$Y$$ isn't a leaf —
$$D=2$$, the three leaves are peripheral, the centre has eccentricity $$1$$, so
$$16 - 1 + 8 = 23$$.

Then the real check. I generated every labelled tree on up to $$7$$ vertices from its Prüfer
sequence — $$16807$$ of them at $$n=7$$ — and for each one brute-forced all $$N^2+2N$$ attachments,
recomputing the diameter from scratch every time. The formula agreed on all of them, which is
enough to trust both the peripheral-vertex collapse and the factor of two on the tail case.

On speed, the honest answer is that this is borderline in CPython against a 1–2 second limit. At
$$\sum N = 10^6$$ I measured about $$1.0$$s on ten path-shaped tests and $$2.1$$s on ten random
ones. Parsing is only $$0.17$$s of that; the rest is three BFS passes over a million nodes, and the
random trees are slower purely because the distance array gets accessed out of order.

I also tried the usual rewrite — CSR adjacency via a degree prefix sum into one flat array, plus a
preallocated list as the queue instead of `deque` — expecting the usual large speedup. It came out
the same, $$1.0$$s and $$2.1$$s. `deque.popleft` and list-of-lists adjacency simply weren't the
bottleneck; the per-node Python overhead is. If this TLEs, the fix is PyPy or C++, not micro-tuning
the BFS.
