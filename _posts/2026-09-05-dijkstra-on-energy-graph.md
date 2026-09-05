---
layout: post
title: "[CodeChef] Starters 93 — Thank U, Next: dijkstra on energy graph"
date: 2026-09-05 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, graph, dijkstra, shortest_paths, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Thank U, Next](https://www.codechef.com/problems/MAIL_DELIVER) (Starters 93, difficulty 2268)

This one looks like a plain reachability question and turns into a nice little lesson about what
Dijkstra actually needs to be Dijkstra. I solved it, my solution passed, and then I spent longer
than I'd like to admit arguing with myself about a single line of the relaxation step — the
`e - 1 > best[w]` check. Is it load-bearing or is it decoration? The answer turned out to be
"neither, exactly", and chasing it down led me to Dial's algorithm, which removes the heap from
this problem entirely.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

You get an undirected graph with $$N$$ nodes and $$M$$ edges, and $$K$$ mail carriers. Carrier
$$i$$ starts on node $$X_i$$ and can deliver to any node at distance at most $$D_i$$ from
$$X_i$$.

The statement defines distance in a slightly unusual way: it's the number of *nodes* on the
shortest path, not the number of edges. So two nodes joined by a single edge are at distance
$$2$$, and a node is at distance $$1$$ from itself. Output `YES` if every node in the graph gets
mail from somebody, `NO` otherwise.

Constraints are the usual multi-test shape — $$T$$ up to $$10^5$$, with $$N$$ and $$M$$ each up
to $$10^5$$ per test and, crucially, the sums of $$N$$ and of $$M$$ across all tests also capped
at $$10^5$$. Remember that last part; it comes back later.

## Energy, not distance

The node-counting definition of distance is annoying to reason about directly, so the first thing
I did was reframe it. Give each carrier a tank of fuel. Carrier $$i$$ starts at $$X_i$$ holding
$$D_i$$ units. Crossing one edge burns one unit. A node is covered if some carrier can arrive
there with at least $$1$$ unit still in the tank.

Check it against the definition: the carrier sits on $$X_i$$ with $$D_i \ge 1$$, so its own node
is covered. A neighbour costs one unit and is reached with $$D_i - 1$$, so it's covered exactly
when $$D_i \ge 2$$ — which is what "distance $$2$$" means here. The reframing is exact, and now
everything is in units of edges, which is how I'd rather think.

So the quantity to compute for every node $$v$$ is

$$\text{best}[v] = \max_{i} \big( D_i - \text{dist}_{\text{edges}}(X_i, v) \big)$$

the most fuel anyone can still have on arrival, and the answer is `YES` iff every node has
$$\text{best}[v] \ge 1$$.

I like this framing because it turns $$K$$ separate range queries into a single global quantity.
Nobody cares *which* carrier covers a node, only that somebody does, and the maximum is exactly
the thing that's easiest to propagate.

## Why plain multi-source BFS is wrong

The obvious first move is multi-source BFS: throw all the carriers into a queue, propagate
outwards, mark visited nodes as you go. That fails, and the failure mode is worth naming because
it's the exact reason this problem is rated where it is.

Ordinary multi-source BFS is correct when all sources are equivalent — every source starts at
distance $$0$$ and every node's first visit is its best visit. Here the sources are *not*
equivalent. A carrier with $$D = 2$$ might reach node $$v$$ first and mark it visited with one
unit of fuel left, blocking a carrier with $$D = 50$$ that arrives a step later with $$47$$ units
to spare. The visited flag throws away the fuel that would have kept the search going.

The fix is not to visit nodes in the order they're *reached* but in the order of how much fuel
they're reached *with* — richest first. Once you say that out loud you've described Dijkstra, run
on maximum rather than minimum. The values decrease monotonically along every edge, so the
greedy argument survives intact: when the fullest tank in the queue comes out, nothing still in
the queue can ever improve it.

## The Dijkstra

Seed `best[X_i] = D_i` for each carrier — taking the max when two carriers share a node — put
every seeded node into a max-heap, and run:

```python
import heapq

best = [0] * (n + 1)
for x, d in carriers:
    best[x] = max(best[x], d)

heap = [(-best[v], v) for v in range(1, n + 1) if best[v]]
heapq.heapify(heap)

seen = bytearray(n + 1)
covered = 0
while heap:
    ne, v = heapq.heappop(heap)
    if seen[v]:
        continue
    seen[v] = 1
    covered += 1
    e = -ne
    if e > 1:                       # nothing left to give a neighbour
        for w in adj[v]:
            if not seen[w] and e - 1 > best[w]:
                best[w] = e - 1
                heapq.heappush(heap, (-(e - 1), w))

print("YES" if covered == n else "NO")
```

`heapq` is a min-heap, so the energies go in negated. There's no `decrease-key`, so I use the
standard lazy-deletion trick: push a new entry every time a node improves and discard stale pops
with the `seen[v]` guard at the top of the loop.

## Does the `e - 1 > best[w]` check matter?

This is the line I got stuck on. What happens if I write the relaxation the lazy way instead —
skip already-finalised neighbours and push everything else, no comparison against `best[w]`?

```python
for w in adj[v]:
    if seen[w]:
        continue
    heapq.heappush(heap, (-(e - 1), w))
```

The honest answer is that this is still correct. It passes. I submitted it and it got AC.

That surprised me at first, and then it didn't. Correctness in this loop comes entirely from the
`seen[v]` guard on *pop*, not from anything on push. Extra entries in the heap are stale by
construction: they carry an energy no better than the one that finalised the node, so when they
surface they hit `seen[v]` and get thrown away. You can push as much garbage as you like and the
output doesn't move. What moves is the size of the heap, and that's a complexity question, not a
style question.

### What it costs

Without the check, node $$w$$ receives one push from every neighbour that gets finalised before
it, so the total number of pushes is $$\sum_w \deg(w) = 2M$$. With the check, a push into $$w$$
only happens when it strictly improves $$\text{best}[w]$$, and improvements form a strictly
increasing sequence bounded above by $$B = \max_i D_i$$. So the bound becomes
$$\min(\deg(w), B)$$ per node.

On the shapes where $$\deg$$ is small those two bounds are the same number and the check buys
nothing. On dense graphs they diverge hard. I measured it, running both versions on the same
adjacency lists:

| graph | with check | without check |
|---|---|---|
| random tree, $$N = 10^5$$ | 100,000 pushes, 0.09 s | 100,000 pushes, 0.07 s |
| path, $$N = 10^5$$, one source | 100,000 pushes, 0.02 s | 100,000 pushes, 0.02 s |
| $$N = 10^3$$, $$M = 10^5$$, 200 sources | 1,163 pushes, 0.005 s | 100,185 pushes, 0.07 s |

The dense row is the whole argument: 1,163 pushes against 100,185, and a 14× difference in wall
clock. Every one of those extra 99,000 entries costs a $$\log$$ on the way in and a $$\log$$ on
the way out, to be discarded on arrival.

The tree row is the honest counterweight. There the check is pure overhead — an extra array read
*and* an extra array write on every edge, buying nothing, and it shows up as a consistent 30%
slowdown. If you knew your graphs were always sparse you could drop it and win a little.

### The part that isn't about speed

There's a second cost to dropping the check, and it's the one that actually decided it for me.
In the unguarded version `best[]` is never written to during the search. It keeps whatever the
seeding step put there and nothing else. That's fine for this problem, where the only question is
`YES` or `NO` and all the real state lives in `seen`. But the array's name is now a lie — it's
`initial_carrier_fuel`, not `best`. Anything that reads it mid-search, and any variant of the
problem that asks for the actual fuel remaining at each node, quietly gets garbage.

So the check stays. It costs one array read, which is cheaper than the $$\log N$$ push it usually
avoids, and it keeps the invariant that makes this code legible as Dijkstra rather than as "a BFS
that happens to work."

### Why the lazy version survives here anyway

Worth being precise about why the unguarded submission passes, because it's a property of the
constraints and not of the code. The sum of $$M$$ over all test cases is capped at $$10^5$$, so
the unguarded bound of $$2M$$ pushes is $$2 \times 10^5$$ *across the entire input*. The heap
can't blow up because the input isn't allowed to make it. Lift that cap, or move to a problem
where edges can be relaxed repeatedly, and the same code degrades.

## An optimisation that didn't work

With the heap settled I went looking for the next thing, and the obvious suspect was

```python
adj = [[] for _ in range(n + 1)]
```

which allocates $$N$$ list objects, once per test case, with $$T$$ up to $$10^5$$. That smells
expensive. The standard replacement is a flat CSR adjacency — one counting pass for the degrees,
a prefix sum for the row starts, one pass to fill — so that the entire graph is three flat
integer arrays and nothing per-node gets allocated at all:

```python
deg = [0] * (n + 2)
for i in range(m):
    deg[us[i]] += 1
    deg[vs[i]] += 1

head = [0] * (n + 2)
s = 0
for i in range(1, n + 1):
    head[i] = s
    s += deg[i]
head[n + 1] = s

pos = head[:]
adj = [0] * (2 * m)
for i in range(m):
    u, v = us[i], vs[i]
    adj[pos[u]] = v; pos[u] += 1
    adj[pos[v]] = u; pos[v] += 1
```

Neighbours of `v` are then the slice `adj[head[v]:head[v+1]]`, or a bare index range if you want
to skip the slice allocation too.

It made things slower. On a worst-case input of $$10^5$$ two-node test cases the list-of-lists
build ran in 0.11 s and CSR in 0.13 s; on a single $$N = M = 10^5$$ graph it was 0.13 s against
0.15 s. Consistently, in both directions.

In hindsight it's obvious why. CSR trades allocations for *three Python-level passes over the
edges* where the naive build does one, and in CPython an interpreted loop iteration costs far
more than a small list allocation. CSR is a real win in C++, where the loop is free and the
cache behaviour is the whole story. Here the cost model is inverted, and I'd been optimising
someone else's machine. Worth knowing before you rewrite a working graph build.

## Dial's algorithm: throwing the heap away

Here's the thing that had been nagging at me. Every edge in this graph has weight $$1$$. Dijkstra
with a heap costs $$O((N + M)\log N)$$, and the $$\log$$ exists to sort keys that can be
arbitrary reals. Mine can't. They're integers in $$[1, B]$$, and they only ever move by one.

That's exactly the situation Dial's algorithm was invented for. Robert Dial published it in 1969,
working on transportation networks where travel times were small integers. The observation is
simple: if edge weights are integers bounded by $$C$$, then at any moment during Dijkstra every
key sitting in the queue lies in a window of width $$C$$ above the current minimum. So you don't
need a heap at all — you need $$C + 1$$ buckets, reused cyclically, indexed by key. Insert is
`append`. Decrease-key is a splice. Extract-min is "walk forward to the next non-empty bucket".
Total cost $$O(M + N \cdot C)$$, with no logarithms anywhere.

The sanity check that the idea is sound: set $$C = 1$$ and it degenerates into ordinary BFS,
which is exactly what BFS is — Dijkstra where the bucket structure is a single queue.

Where it turns up in practice:

- **0-1 BFS.** Weights are only $$0$$ or $$1$$, so the bucket array collapses to two buckets,
  which is just a deque — push-front for a zero edge, push-back for a one edge. Most competitive
  programmers know this trick without knowing it's Dial's. It's the standard answer for
  "minimum number of edges to flip", or grids where some moves are free.
- **Small integer weights generally.** Road networks with times rounded to seconds; anything
  where the weight alphabet is tiny.
- **Min-cost flow and Johnson's algorithm.** After reweighting, the costs are small nonnegative
  integers, and Dial's is a standard inner-loop choice.

The descendant worth knowing about is the radix heap — buckets with exponentially growing widths,
giving $$O(M + N \log C)$$, which removes the dependence on $$C$$ being tiny. Thorup's
$$O(M)$$ undirected shortest paths is where that line of work ends up.

### This problem is the easy case

Our graph has uniform weight $$1$$ plus a one-time non-uniform offset at the sources — carrier
$$i$$ enters the process at level $$B - D_i$$. Since all those offsets are known before the
search starts, they can be placed into buckets up front, and no cyclic wraparound is ever needed:
relaxation from level $$t$$ only ever writes into level $$t + 1$$.

Which means the whole bucket array collapses to two lists and a pointer into the sources sorted
by fuel:

```python
seeds = sorted(((best[v], v) for v in range(1, n + 1) if best[v]), reverse=True)

seen = bytearray(n + 1)
covered = 0
i, cur = 0, []
e = seeds[0][0] if seeds else 0

while e >= 1:
    while i < len(seeds) and seeds[i][0] == e:   # carriers joining at this level
        cur.append(seeds[i][1])
        i += 1

    nxt = []
    for v in cur:
        if seen[v]:
            continue
        seen[v] = 1
        covered += 1
        if e > 1:
            for w in adj[v]:
                if not seen[w] and e - 1 > best[w]:
                    best[w] = e - 1
                    nxt.append(w)

    cur = nxt
    if not cur:
        if i >= len(seeds):
            break
        e = seeds[i][0]     # jump straight to the next carrier's level
    else:
        e -= 1
```

It reads like a BFS with staggered start times, which is precisely what it is. No heap, no
negation, $$O(N + M)$$ after the seed sort. The `if not cur` branch matters: without it, a test
with $$B = 10^5$$ and two nodes would spin through 100,000 empty levels one at a time. Clamping
$$D_i$$ to $$N$$ at read time is worth doing for the same reason — no path visits more than
$$N$$ nodes, so fuel beyond that is unspendable.

Measured against the heap version on the same graphs:

| graph | heap | level sweep |
|---|---|---|
| path, $$N = 10^5$$ | 0.017 s | 0.015 s |
| random tree, $$N = 10^5$$ | 0.069 s | 0.031 s |
| $$N = 10^3$$, $$M = 10^5$$, 200 sources | 0.006 s | 0.005 s |

Better everywhere, and a bit more than 2× on the tree, which is the shape where the heap has the
most nodes to shuffle.

The one shape where it loses is the degenerate multi-test case — $$10^5$$ graphs of two nodes
each, where the per-test `sorted()` over the seeds is most of the work and there's no search to
speak of. There the heap version came in at 0.13 s and the level sweep at 0.16 s. Not enough to
matter against a 1.5 s limit, but it's the reminder that the seed sort isn't free and the
$$O(N + M)$$ only kicks in once there's an actual graph to walk.

One thing I tried and would skip next time: the textbook version with a real array of $$B + 1$$
buckets. On the path test that allocates 100,001 lists to hold 100,000 nodes and came out at
0.039 s — slower than the heap it was supposed to beat. The two-list version has the same
asymptotics without the allocation, and that difference is the entire story in CPython.

## Takeaways

- When sources aren't equivalent — different budgets, different start times, different offsets —
  multi-source BFS is wrong and multi-source Dijkstra is right. The tell is a visited flag that
  discards information the later arrival would have needed.
- Correctness in lazy-deletion Dijkstra lives in the `seen` guard on pop. Everything on the push
  side is about queue size. Knowing which is which stops you from being scared of the wrong line.
- But keep the relaxation guard anyway. It's near-free, it's the difference between $$\deg(w)$$
  and $$\min(\deg(w), B)$$ pushes on dense inputs, and it's what keeps `best[]` honest.
- If your keys are bounded small integers and increase monotonically, you don't need a heap.
  That's 0-1 BFS, that's this problem, and that's Dial's algorithm — worth recognising by shape
  rather than by name.
