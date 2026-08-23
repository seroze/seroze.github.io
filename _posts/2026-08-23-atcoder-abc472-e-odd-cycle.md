---
layout: post
title: "[AtCoder] ABC472 E — Odd Cycle: depth parity, and two bugs in reconstructing the cycle"
date: 2026-08-23 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, atcoder, graphs, bfs_tree, cycles, bipartite]
author: "Seroze"
published: true
---

Problem: [ABC472 E — Odd Cycle](https://atcoder.jp/contests/abc472/tasks/abc472_e) (450 points)

Given a simple connected undirected graph, find a cycle with an odd number of *distinct* vertices, or report `-1`. Up to $$2 \times 10^5$$ test cases, with $$\sum N$$ and $$\sum M$$ both bounded by $$2 \times 10^5$$.

The detection half of this problem is a one-liner if you know the bipartite characterisation. The reconstruction half is where the actual work is, and it has two traps that both produce output that *looks* like a cycle. I hit both, so this is a writeup of the wrong turns as much as the answer.

## The instinct, and what's wrong with it

My first sketch was: run a BFS, keep parent pointers, and when you hit an edge back to an already-visited vertex, check whether the distance between the two endpoints is even. If it is, you've closed an odd cycle, so walk the parent pointers back to reconstruct it.

The shape of that is right. The flaw is the phrase "check the distance between that vertex and this" — **parent pointers don't give you the distance between two arbitrary vertices.** They give you the path from a vertex to the root, nothing more.

Concretely, take this BFS tree with a non-tree edge $$(4,5)$$:

```
      1
     / \
    2   3
   /     \
  4 ----- 5
```

Here $$\mathrm{depth}(4) = \mathrm{depth}(5) = 2$$, so the naive "difference of depths" is $$0$$ — but the actual tree path from 4 to 5 is $$4 \to 2 \to 1 \to 3 \to 5$$, which has length 4. The two vertices sit in different branches. To get the true tree distance you need their lowest common ancestor:

$$d(u,v) = \bigl(\mathrm{depth}(u) - \mathrm{depth}(\ell)\bigr) + \bigl(\mathrm{depth}(v) - \mathrm{depth}(\ell)\bigr)$$

where $$\ell = \mathrm{LCA}(u,v)$$, and the cycle formed by adding the non-tree edge has length $$d(u,v) + 1$$.

## The insight: you never need the distance

Look at that formula again and ask only about parity. The LCA term appears **twice**, so it contributes $$2\,\mathrm{depth}(\ell)$$ — always even, and therefore invisible to parity. What's left is

$$d(u,v) \equiv \mathrm{depth}(u) + \mathrm{depth}(v) \pmod 2$$

So $$d(u,v)$$ is even exactly when $$\mathrm{depth}(u)$$ and $$\mathrm{depth}(v)$$ have the same parity, and the cycle length $$d(u,v)+1$$ is odd exactly then. **The LCA cancels out of the parity question entirely.** You need it to build the cycle, but not to decide whether one exists.

That reduces detection to a single comparison per edge:

```python
if depth[u] % 2 == depth[v] % 2:   # odd cycle exists
```

This is just bipartiteness wearing a different hat. Colouring each vertex by $$\mathrm{depth} \bmod 2$$ is a proper 2-colouring precisely when no edge joins two same-parity vertices, and a graph is bipartite iff it has no odd cycle. So the scan is both sound and complete: if it finds nothing, `-1` is genuinely correct, not just "my search failed". The graph being connected is what lets a single BFS from vertex 0 settle it.

### A BFS-specific simplification

Worth noticing, because it makes the reconstruction cheaper than the general case. In a BFS tree of an undirected graph, every edge — tree or not — joins vertices whose depths differ by at most one:

$$\mathrm{depth}(v) \le \mathrm{depth}(u) + 1 \quad\text{and}\quad \mathrm{depth}(u) \le \mathrm{depth}(v) + 1$$

Combine that with "same parity" and the difference can't be 1, so it must be 0. **For a BFS tree, the same-parity test is equivalent to $$\mathrm{depth}(u) = \mathrm{depth}(v)$$.** The two endpoints are always at the same level, the two branches climb in lockstep, and the cycle length is exactly $$2(\mathrm{depth}(u) - \mathrm{depth}(\ell)) + 1$$.

I still wrote the general depth-equalising version below, because it costs three lines and makes the same code work on a DFS tree — the parity argument only ever used tree depths, never anything BFS-specific.

## Don't skip your own parent

One small thing that bites in undirected graphs: when you scan `u`'s neighbours, you will constantly see already-visited vertices, and one of them is `u`'s own parent. That edge is a tree edge, not a cycle — traversing it and coming back is a walk of length 2, not a cycle of length 2.

```python
elif v != parent[u]:
    # a genuine non-tree edge, worth testing
```

Since the graph is simple there's exactly one edge to the parent, so a plain `!=` is enough. With multi-edges you'd have to skip by edge id instead, because a doubled edge really is a valid 2-cycle... though still not an odd one.

## Bug 1: assuming one endpoint is an ancestor of the other

My first reconstruction was this:

```python
cycle = []
x = u
while x != v:
    cycle.append(x)
    x = parent[x]
    if x == -1:
        break
cycle.append(v)
```

This walks from `u` up the tree until it bumps into `v`. It works only if **`v` is an ancestor of `u`**, which is exactly what the earlier example shows is false in general. Starting from 4 you get $$4 \to 2 \to 1 \to -1$$ and never reach 5, because 5 lives in a different subtree.

The `if x == -1: break` guard makes this especially nasty. Without it you'd crash on `parent[-1]` and know immediately something was wrong. With it, you walk off the top of the tree, silently append `v`, and print a vertex list that is the right *shape* — plausible length, plausible numbers — but has a non-existent edge joining the root to `v`. A wrong answer that looks like a right answer.

What you actually need is the tree path from `u` to `v`, which means meeting at the LCA:

```python
path_u, path_v = [], []
x, y = u, v

while depth[x] > depth[y]:      # equalise depths
    path_u.append(x); x = parent[x]
while depth[y] > depth[x]:
    path_v.append(y); y = parent[y]

while x != y:                   # climb together
    path_u.append(x); path_v.append(y)
    x = parent[x]; y = parent[y]

path_u.append(x)                # x == y == LCA
```

Note the LCA gets appended to `path_u` only. Appending it to both would duplicate a vertex, and the problem requires all $$v_i$$ distinct.

## Bug 2: joining the two halves the wrong way

With the paths built correctly, my next version did:

```python
cycle = path_u + path_v
```

On the running example that gives `path_u = [4, 2, 1]` and `path_v = [5, 3]`, so the output is

```
4 2 1 5 3
```

and there is no edge $$1 \to 5$$. Wrong again, and again in a way that passes a casual eyeball.

The reason is direction. `path_u` runs *upward*, from `u` to the LCA. `path_v` also runs upward, from `v` to the LCA. But to trace the cycle you need to go up one branch and back **down** the other:

$$u \rightarrow \cdots \rightarrow \ell \rightarrow \cdots \rightarrow v \rightarrow u$$

so the second branch has to be reversed:

```python
cycle = path_u + path_v[::-1]
```

giving `[4, 2, 1, 3, 5]`, i.e. $$4 \to 2 \to 1 \to 3 \to 5 \to 4$$, where the closing step is the original non-tree edge. Every consecutive pair is now a real edge.

## Why the vertices are guaranteed distinct

This is the condition the problem states explicitly and the one I never actually checked while debugging — I was busy making the edges exist. It's worth a moment because it's what makes the whole approach valid rather than merely plausible.

The two branches are $$u \to \cdots \to \ell$$ and $$v \to \cdots \to \ell$$. Suppose some vertex $$w \ne \ell$$ appeared on both. Then $$w$$ is a common ancestor of $$u$$ and $$v$$, and since it lies strictly below $$\ell$$ on both paths it is a *deeper* common ancestor than $$\ell$$ — contradicting $$\ell$$ being the lowest. So the branches are vertex-disjoint apart from $$\ell$$, which we deliberately included only once.

The same reasoning gives $$K \ge 3$$. We have $$u \ne v$$ and, by the parity test, $$\mathrm{depth}(u) \equiv \mathrm{depth}(v)$$, so neither can be the other's parent, so $$\ell$$ is a strict ancestor of both and each branch contributes at least one vertex beyond it. And $$K$$ is odd by the parity argument. All three of the problem's conditions, discharged.

One thing this does *not* give you is the shortest odd cycle. BFS finds shortest *paths from the root*, which is a different claim; the first same-parity edge you happen to scan is just whichever one the adjacency order surfaced first. The problem accepts any odd cycle, so this doesn't matter here — but the "BFS means shortest" reflex is worth suppressing.

## The I/O trap

With $$T$$ up to $$2 \times 10^5$$, a per-line `input()` call is its own failure mode independent of the algorithm. The graph work is $$O(N + M)$$ overall, but $$4 \times 10^5$$ interpreter-level `input()` calls will dominate everything and time out. Read the whole stream once and index into it:

```python
data = sys.stdin.buffer.read().split()
```

Likewise, buffer the output and emit it with one `write` at the end rather than printing per test case. And note it's safe to `break` out of the BFS the instant a cycle is found, because all $$M$$ edges for the test case were consumed during the build — there's no unread input left to desynchronise the parser.

## Full solution

I've used a flat linked-list adjacency (`head`/`nxt`/`to`) instead of a list of lists. With the sum bounds it isn't strictly necessary, but it avoids allocating $$N$$ small lists per test case across up to $$2\times10^5$$ cases, which is real time in Python.

```python
import sys
from collections import deque

def main():
    data = sys.stdin.buffer.read().split()
    pos = 0
    t = int(data[pos]); pos += 1
    out = []

    for _ in range(t):
        n = int(data[pos]); m = int(data[pos + 1]); pos += 2

        head = [-1] * n
        nxt = [0] * (2 * m)
        to = [0] * (2 * m)
        for i in range(m):
            a = int(data[pos]) - 1; b = int(data[pos + 1]) - 1; pos += 2
            to[2*i] = b; nxt[2*i] = head[a]; head[a] = 2*i
            to[2*i+1] = a; nxt[2*i+1] = head[b]; head[b] = 2*i+1

        parent = [-1] * n
        depth = [-1] * n
        depth[0] = 0
        q = deque([0])
        found = None

        while q and found is None:
            u = q.popleft()
            e = head[u]
            while e != -1:
                v = to[e]
                if depth[v] == -1:
                    depth[v] = depth[u] + 1
                    parent[v] = u
                    q.append(v)
                elif v != parent[u] and (depth[u] & 1) == (depth[v] & 1):
                    found = (u, v)
                    break
                e = nxt[e]

        if found is None:
            out.append("-1")
        else:
            u, v = found
            pu, pv = [], []
            x, y = u, v
            while depth[x] > depth[y]:
                pu.append(x); x = parent[x]
            while depth[y] > depth[x]:
                pv.append(y); y = parent[y]
            while x != y:
                pu.append(x); pv.append(y)
                x = parent[x]; y = parent[y]
            pu.append(x)
            cyc = pu + pv[::-1]
            out.append(str(len(cyc)))
            out.append(" ".join(str(c + 1) for c in cyc))

    sys.stdout.write("\n".join(out) + "\n")

main()
```

$$O(N + M)$$ per test case, and $$O(\sum N + \sum M)$$ overall.

On the official sample this prints `3 / 3 1 2`, `-1`, `5 / 4 5 1 2 3`, `5 / 4 5 1 2 3` — different cycles from the expected output for cases 3 and 4, which the problem explicitly allows. I also ran it against a checker on 400 random connected graphs, verifying that every emitted cycle has odd $$K \ge 3$$, no repeated vertices, and a real edge between each consecutive pair, and that `-1` came out exactly when an independent 2-colouring said the graph was bipartite. Zero failures.

## What I'd take away

The detection insight — that the LCA term cancels mod 2, so parity of depths is all you need — is the elegant part, and it generalises: any time a quantity appears twice with the same sign in a formula, it's invisible to parity arguments.

But the part I actually got wrong twice was reconstruction, and both bugs shared a signature. Neither crashed. Both emitted a well-formed list of the correct length. The only way to catch them was to check the property the problem actually asked for — *is there an edge between every consecutive pair?* — rather than the property I was implicitly checking, which was *does this look like a cycle?* Writing the five-line verifier first would have been faster than reasoning about it twice.
