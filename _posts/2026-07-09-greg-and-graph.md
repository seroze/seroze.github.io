---
layout: post
title: "[Codeforces] Round 179 (Div. 1) B — Greg and Graph: Learning to Think in Reverse"
date: 2026-07-09 00:00:00 +0530
categories: competitive-programming
tags: [cp, graphs, shortest_paths, floyd_warshall, codeforces]
author: "Seroze"
published: true
---

Today I solved one of the classic Codeforces problems, [**"Greg and Graph"**](https://codeforces.com/contest/295/problem/B), and it taught me a beautiful algorithmic technique: **sometimes the easiest way to process deletions is to reverse time and process additions instead.**

## The Problem

We are given a complete weighted directed graph with `n` vertices.

A sequence of vertices is deleted one by one. Before each deletion, we need to compute the **sum of shortest path distances between every pair of remaining vertices**.

Constraints:

* `n ≤ 500`

A straightforward solution is too slow.

---

## My First Thought

At every deletion:

1. Remove the vertex.
2. Run Floyd-Warshall again.
3. Sum all shortest path distances.

This costs:

* Floyd-Warshall: `O(n³)`
* Done `n` times

Overall complexity:

```
O(n⁴)
```

With `n = 500`, this is completely infeasible.

The bottleneck isn't computing the sum — it's recomputing all-pairs shortest paths after every deletion.

---

## The Key Observation

Deleting vertices is difficult because removing a vertex can invalidate many shortest paths.

Instead, process the operations **in reverse**.

If the deletion order is

```
4 1 2 3
```

reverse it:

```
3 2 1 4
```

Now we're no longer deleting vertices.

We're **adding** them.

Initially:

```
{}
```

then

```
{3}
```

then

```
{3,2}
```

then

```
{3,2,1}
```

finally

```
{3,2,1,4}
```

Every step introduces exactly one new vertex.

This looks suspiciously similar to Floyd-Warshall.

---

## Floyd-Warshall's Hidden Invariant

The Floyd recurrence is

```text
dist[i][j] =
min(dist[i][j],
    dist[i][k] + dist[k][j])
```

After processing vertex `k`, every shortest path whose intermediate vertices belong to the processed set has already been computed.

When we add one new vertex, we simply perform **one Floyd relaxation using that vertex**.

Instead of recomputing APSP from scratch, we reuse everything we already know.

Overall complexity becomes

```
O(n³)
```

which easily fits the constraints.

---

## The Invariant That Finally Clicked

At first I had a doubt.

Suppose adding vertex `k` creates a path like

```
i -> k -> j -> r
```

How can a single relaxation

```
dist[i][r]
=
min(dist[i][r],
    dist[i][k] + dist[k][r])
```

discover this?

The answer is subtle.

`dist[i][k]` and `dist[k][r]` are **not necessarily direct edges**.

They are already the shortest paths using previously processed intermediate vertices.

So

```
dist[k][r]
```

may already equal

```
k -> j -> r
```

Likewise,

```
dist[i][k]
```

may already represent

```
i -> p -> q -> k
```

Therefore one relaxation through `k` is actually considering

```
(i ... k) + (k ... r)
```

where both halves are already optimal.

That is exactly the invariant Floyd-Warshall maintains.

---

## Bugs I Encountered

### 1. 1-based indexing

The deletion order in the input is 1-indexed.

I forgot to convert it to 0-based indexing.

Simple bug.

---

### 2. Overwriting distances

Initially I wrote

```cpp
dist[i][k] = a[i][k];
dist[k][i] = a[k][i];
```

This turned out to be incorrect for my implementation because previous Floyd relaxations may already have found a shorter path to or from `k`.

The fix was

```cpp
dist[i][k] = min(dist[i][k], a[i][k]);
dist[k][i] = min(dist[k][i], a[k][i]);
```

Ironically, I had originally written the `min()` version correctly, then removed it while debugging.

---

### 3. Computing the answer before adding the vertex

I was summing the distances before activating the current vertex.

The order should be:

1. Activate vertex.
2. Run Floyd relaxation.
3. Compute the answer.

---

### 4. Time Limit Exceeded

Even after fixing correctness, I got TLE.

The main culprit was unnecessary work while computing the answer.

Instead of iterating over all vertices and checking whether they were active,

```cpp
for (i = 0; i < n; i++)
    for (j = 0; j < n; j++)
        if (active[i] && active[j])
```

it's better to iterate only over the active vertices.

Small constant-factor optimizations matter when you're already performing around `O(n³)` operations.

---

## The Solution

```python
n = int(input())

a = [[] for _ in range(n)]
inf = float('inf')

for i in range(n):
    a[i] = list(map(int, input().split()))

xl = list(map(int, input().split()))
xl = [x-1 for x in xl]
ans = [] # case where all vertices are removed
dist = [[inf for _ in range(n)] for _ in range(n)]
active = set()

for k in reversed(xl):

    active.add(k)
    # enable edges surrounding k to the graph
    for i in range(n):
        dist[i][k] = min(dist[i][k], a[i][k])
        dist[k][i] = min(dist[k][i], a[k][i])

    for i in range(n):
        for j in range(n):
            dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])

    cur = 0
    for i in range(n):
        for j in range(n):
            if dist[i][j] != inf and i in active and j in active:
                cur += dist[i][j]

    ans.append(cur)

ans.reverse()
print(*ans)
```

---

## What I Learned

This problem wasn't really about Floyd-Warshall.

It was about recognizing that:

> **Sometimes deletions are hard, but additions are easy.**

Whenever operations remove information, it's worth asking:

* Can I process them backwards?
* Can I transform deletions into insertions?
* Does the reverse direction allow me to reuse previous work?

This "reverse the process" trick appears in many graph, dynamic programming, and offline query problems.

It's one of those ideas that, once you see it once, starts showing up everywhere.

---

## Final Thoughts

This problem reminded me that the biggest improvement often isn't a clever optimization.

It's changing the direction in which you think.

Instead of asking:

> "How do I efficiently handle deletions?"

ask:

> "What happens if I never delete anything at all?"

Sometimes, that's the entire solution.
