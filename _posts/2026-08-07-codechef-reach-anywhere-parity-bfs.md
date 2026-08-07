---
layout: post
title: "[CodeChef] Starters 106 — Reach Anywhere: finding shortest odd and even parity distances"
date: 2026-08-07 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, graphs, bfs, shortest_paths]
author: "Seroze"
published: true
---

Problem: [CodeChef — Reach Anywhere](https://www.codechef.com/problems/FIZZBUZZ2309?tab=statement) (difficulty 2554)

> Given a simple undirected graph with `N` vertices and `M` edges, find the smallest
> non-negative `K` such that for **every** vertex `u`, there is a walk of length
> **exactly** `K` from `1` to `u`. Print `-1` if no such `K` exists.

Walks, not paths — you may repeat vertices and edges freely.

This one took me a while, and the interesting part wasn't the final algorithm. It was
that I spent three rounds of thinking on an object that turned out to be completely
irrelevant. Writing that part down is the point of this post.

---

## The observations that were actually right

I got the first few quickly, and they hold up:

1. Compute shortest distances from vertex `1`. Then `K >= max(dist[u])`, since you
   can't reach a vertex faster than its shortest path.
2. If you can reach `u` in `L` steps, you can reach it in `L + 2` — walk to `u`, then
   bounce along any incident edge and come back. So also `L + 4`, `L + 6`, ...
3. Therefore, for each vertex, the set of achievable walk lengths is eventually
   periodic with period 2. **Parity is the only thing that matters.**

That third point is the real reduction. An infinite set of achievable lengths per
vertex collapses to just two numbers:

- the minimum **even**-length walk from `1` to `u`
- the minimum **odd**-length walk from `1` to `u`

If I had those two numbers for every vertex, the problem would be over. Pick a parity,
take the max over all vertices for that parity, and you have a `K` that everyone can
pad up to with `+2` bounces.

So the whole problem became: *how do I compute min-even and min-odd for every vertex?*

---

## The rabbit hole

Here is where I went wrong, and I want to be precise about the shape of the mistake.

My first instinct was **second-shortest path**. If `dist[u]` is even, surely the
second-shortest path gives me the odd one? Then I could binary search on even `K` and
odd `K` separately.

That's wrong, and the reason is worth stating: the shortest walk of the *opposite
parity* is not the second-shortest path, and it isn't necessarily `dist[u] + 1` either.
The shortest walk to `u` might be 10, there might be no walk of length 11, but there
might be one of length 13 — and 13 is perfectly fine, because it gives you 15, 17, 19
too. The final `K` doesn't care whether the first odd walk is 11 or 13.

I kept fixating on `dist[u] + 1`. Once I let that go, I moved to **odd cycles** —
correctly, since an odd cycle is exactly what flips parity. I even worked out the
mechanism properly:

> If a cycle touches your path, it has two legs between the entry and exit points, one
> of each parity. You took the shorter leg `a`; take the other leg `b` instead and your
> total shifts by `b - a`, flipping parity.

That argument is *correct*. It's also useless as an algorithm. Because immediately after
writing it I was stuck on: what if the odd cycle isn't on the `1 → u` path? What if
there are many of them? Which detour is cheapest? How do I enumerate cycles at all?

**That difficulty was the signal.** When the object you've picked forces you to
enumerate things that are numerous, overlapping, and awkward to compare, the usual
conclusion isn't "this problem is hard." It's "I picked the wrong object."

The meta-lesson: I kept jumping from *what do I need* to *how do I detect it* before
the *what* was nailed down. Once you're asking "how do I compute second-shortest
efficiently," you've silently committed to second-shortest mattering, and you stop
auditing that assumption. Cheap fix I'm trying to internalize — before asking "how do I
compute X," spend thirty seconds trying to *break* X. One counterexample would have
killed the second-shortest line in under a minute instead of three rounds.

---

## The hint that unlocked it

The nudge I got was, roughly:

> BFS computes the shortest distance to a **state**. Every time you've used BFS, "state"
> and "vertex" happened to coincide, so you stopped distinguishing them. Is a vertex
> actually the complete description of where your walk stands right now?

It isn't. A walk sitting at `u` also carries the **parity of how it got there**, and
that parity determines what's reachable next. Two walks ending at the same vertex with
different parities are in genuinely different situations.

So the state is `(vertex, parity)`. Build a graph on `2N` states where every edge
`(u, v)` gives:

```
(u, 0) -> (v, 1)
(u, 1) -> (v, 0)
```

Every transition flips parity, unconditionally. Start a plain BFS from `(1, 0)`. All
edges cost 1, so BFS gives the shortest distance to every state in `O(N + M)`.

And that's min-even and min-odd for every vertex, directly. **No cycle detection. No
bipartiteness test. Nothing about odd cycles anywhere in the code.** The odd cycles
don't need to be found — they need to be made irrelevant. In a bipartite component the
BFS simply never reaches half the states, and that falls out for free.

---

## Reading off the answer

An answer exists iff there is **some** parity `p` such that `dist[(u, p)]` is finite for
*every* `u`. You need one fully populated column, not both.

I initially thought "if some state is unreachable, it's impossible" — that's wrong.
In a connected bipartite graph, every vertex has exactly one reachable parity, so half
the states are unreachable and an answer can still exist.

Given a complete column `p`, take `K_p = max_u dist[(u, p)]`. This works because every
vertex can pad `+2` up to `K_p`, and `K_p` has parity `p`, so it's compatible with every
entry in that column. Answer is the min over qualifying columns, `-1` if neither
qualifies.

Worth checking against sample 2 — the star `1-2`, `1-3`:

| vertex | even | odd |
|--------|------|-----|
| 1      | 0    | ∞   |
| 2      | ∞    | 1   |
| 3      | ∞    | 1   |

Neither column is complete, so `-1`. This is the "connected but still impossible" case,
and it's exactly the bipartite obstruction — handled without ever testing for it.

And sample 1, the triangle: even column `{0, 2, 2}` → 2, odd column `{3, 1, 1}` → 3, so
the answer is 2. Vertex 1's odd entry being 3 rather than 1 is a nice sanity check that
the BFS is tracking states rather than vertices.

---

## The code

```python
from collections import deque

def solve():
    n, m = map(int, input().split())
    g = [[] for _ in range(n + 1)]

    for _ in range(m):
        u, v = map(int, input().split())
        g[u].append(v)
        g[v].append(u)

    dist = {}
    dq = deque()
    dq.append((1, 0, 0))

    # BFS over (vertex, parity) states
    while dq:
        u, uparity, udist = dq.popleft()

        for v in g[u]:
            vparity = 1 ^ uparity
            vdist = 1 + udist

            if (v, vparity) in dist:
                continue

            dist[(v, vparity)] = vdist
            dq.append((v, vparity, vdist))

    odd_dists  = [dist[(i, 1)] for i in range(1, n + 1) if (i, 1) in dist]
    even_dists = [dist[(i, 0)] for i in range(1, n + 1) if (i, 0) in dist]

    inf = float('inf')
    k = inf

    if len(odd_dists) == n:
        k = max(odd_dists)

    if len(even_dists) == n:
        k = min(k, max(even_dists))

    print(k if k != inf else -1)

tc = int(input())
for _ in range(tc):
    solve()
```

`O(N + M)` per test case — the state graph has `2N` nodes and `4M` directed edges.

Two notes on this submission, since it passed but isn't quite airtight:

**The start state is never explicitly marked.** I push `(1, 0, 0)` onto the queue but
never set `dist[(1, 0)] = 0`. It gets filled in later only if some walk returns to `1`
with even length. It happens to be safe here: if any other vertex is reachable at even
parity `d`, then walking out and back gives `1 → 1` in `2d` steps, so `(1, 0)` does get
marked — and the value stored is at least 2, which can never raise the column max above
what it already is (every other even distance is at least 2). Since `M >= 1` forces
`N >= 2`, there's always another vertex. But this is luck, not design. `dist[(1, 0)] = 0`
up front is the correct line.

**`input()` per line is slow** at `N, M` up to `10^5`. A `sys.stdin.buffer.read().split()`
bulk read is the safer habit. It passed within the 1s limit, but I wouldn't rely on that.

---

## What I'm taking away

The algorithm here is short. What made the problem hard was that I had the right
*reduction* (parity is all that matters) and then spent all my effort trying to compute
it with the wrong *machinery*.

Two habits I want to build:

- When a chosen object forces enumeration of many awkward overlapping structures, treat
  that as evidence against the object, not as the difficulty of the problem.
- When BFS feels insufficient, ask whether the vertex is really the state. Very often
  the answer is to widen the state and keep the algorithm you already know.
