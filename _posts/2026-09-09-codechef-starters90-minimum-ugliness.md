---
layout: post
title: "[CodeChef] Starters 90 — Minimum Ugliness: the diameter of a subset"
date: 2026-09-09 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, trees, lca, graph_theory, numpy, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Minimum Ugliness](https://www.codechef.com/problems/MIN_UGLY) (Starters 90,
difficulty 2714)

You get a tree on $$N$$ nodes and $$Q$$ queries. Each query hands you a set $$A$$ of $$K$$ nodes.
The *ugliness* of a node $$x$$ is its distance to the farthest member of $$A$$, and you have to
report the smallest ugliness over all $$N$$ nodes of the tree — not just over $$A$$. The limits are
$$\sum N, \sum Q \le 2\cdot 10^5$$ and $$\sum K \le 4\cdot 10^5$$, with a 2 second limit.

I got this down to the right reduction fairly quickly, wrote it up in Python, and scored 13/100.
This post is about the reduction, the two proofs that make it safe, and the two very different
reasons the first submission failed — only one of which I had guessed correctly.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The answer is half the diameter of A

Write $$D$$ for the diameter of the queried set,

$$D = \max_{u,v \in A} \operatorname{dist}(u,v),$$

and note this is a diameter *of the subset* — the tree around it is irrelevant except as the metric.
The claim is that the answer is always

$$\left\lceil \frac{D}{2} \right\rceil.$$

The lower bound falls out immediately. Pick $$u, v \in A$$ realising $$D$$. For any node $$x$$
whatsoever, the triangle inequality gives $$\operatorname{dist}(x,u) + \operatorname{dist}(x,v) \ge
D$$, so one of the two is at least $$D/2$$, so the ugliness of $$x$$ is at least
$$\lceil D/2 \rceil$$. That holds for every $$x$$, so no node can do better.

The upper bound needs an actual witness. Take the path from $$u$$ to $$v$$ and let $$c$$ be the
vertex on it at distance $$\lfloor D/2 \rfloor$$ from $$u$$ — the midpoint of the diametral path.
I want to show no member of $$A$$ is farther than $$m = \lceil D/2 \rceil$$ from $$c$$.

Take any $$y \in A$$ and let $$w$$ be the point where $$y$$ attaches to the $$u$$–$$v$$ path, so
that $$y$$'s route to anything on the path goes through $$w$$. Put $$a = \operatorname{dist}(u,w)$$
and $$t = \operatorname{dist}(w,y)$$. Then $$\operatorname{dist}(v,w) = D - a$$, and the two
distances from $$y$$ to the endpoints are

$$\operatorname{dist}(y,u) = t + a, \qquad \operatorname{dist}(y,v) = t + D - a.$$

Here is where the diameter hypothesis earns its keep: $$y$$, $$u$$ and $$v$$ are all in $$A$$, so
both of those are at most $$D$$. That is exactly $$t \le a$$ and $$t \le D - a$$. Meanwhile the
distance we care about is $$\operatorname{dist}(c,y) = \lvert a - \lfloor D/2 \rfloor \rvert + t$$.
If $$a \ge \lfloor D/2 \rfloor$$, substituting $$t \le D - a$$ gives

$$\operatorname{dist}(c,y) \le a - \lfloor D/2 \rfloor + D - a = \lceil D/2 \rceil,$$

and if $$a < \lfloor D/2 \rfloor$$, substituting $$t \le a$$ gives

$$\operatorname{dist}(c,y) \le \lfloor D/2 \rfloor - a + a = \lfloor D/2 \rfloor.$$

Either way $$\operatorname{dist}(c,y) \le m$$, so $$c$$ achieves ugliness $$m$$ and the bound is
tight.

The thing worth staring at for a second is that $$c$$ generally is **not** in $$A$$. The smallest
case that shows it: a path $$4 - 2 - 1 - 3 - 5$$ with $$A = \{4, 5\}$$. The diameter is 4, the
answer is 2, and the only node achieving it is node 1, which nobody asked about. So "minimum over
all nodes of the tree" really does mean all nodes, and the reduction is what quietly handles that.

## Two sweeps still find the diameter of a subset

The classic way to find a tree's diameter is to walk to the farthest vertex from anywhere, then walk
to the farthest vertex from *there*. The same recipe works here — pick any $$s \in A$$, let $$u$$ be
the farthest member of $$A$$ from $$s$$, then $$D$$ is the distance from $$u$$ to the farthest
member of $$A$$ — but it is not obvious that restricting every "farthest" to $$A$$ leaves the
argument intact. It does, and the proof is short enough to be worth writing down rather than
trusting.

The tool is the four-point condition, the property that characterises tree metrics: for any four
vertices, of the three ways to split them into two pairs, the two largest sums of distances are
equal. So a strict unique maximum among the three pairings is impossible.

Let $$(p,q)$$ be a genuine diametral pair of $$A$$, and suppose $$u$$ — the farthest element of
$$A$$ from $$s$$ — were an endpoint of no diametral pair, meaning both
$$\operatorname{dist}(u,p)$$ and $$\operatorname{dist}(u,q)$$ are strictly less than $$D$$. Line up
the three pairings of $$\{s, u, p, q\}$$:

$$S_1 = \operatorname{dist}(s,u) + \operatorname{dist}(p,q)$$

$$S_2 = \operatorname{dist}(s,p) + \operatorname{dist}(u,q)$$

$$S_3 = \operatorname{dist}(s,q) + \operatorname{dist}(u,p)$$

Because $$u$$ is the farthest element of $$A$$ from $$s$$, we have $$\operatorname{dist}(s,u) \ge
\operatorname{dist}(s,p)$$ and $$\operatorname{dist}(s,u) \ge \operatorname{dist}(s,q)$$. Because
$$D$$ is the diameter of $$A$$, we have $$\operatorname{dist}(p,q) = D$$ which dominates the other
two terms — and by assumption it dominates them *strictly*. So $$S_1 > S_2$$ and $$S_1 > S_3$$,
a unique strict maximum, which a tree metric cannot produce. Contradiction, so $$u$$ is a diametral
endpoint of $$A$$ after all, and the second sweep from $$u$$ reports $$D$$.

Every step of that used only distances between the four vertices, and all four are in $$A$$ — which
is precisely why nothing breaks when $$A$$ is a sparse handful of nodes scattered around a huge
tree. (The same four-point condition turned up in the
[Expected Diameter writeup]({% post_url 2026-08-25-codechef-starters116-expected-diameter %}) for
a completely different purpose; it is a genuinely reusable hammer for tree problems.)

Before trusting any of this I brute-forced both claims over 4000 random trees on up to 9 vertices,
checking every subset choice against a full all-pairs BFS. No mismatches, which is what I wanted
before spending time on an implementation.

So the algorithm is settled: root the tree, build any structure that answers
$$\operatorname{dist}(a,b)$$, and run two passes over each query's list.

## Why the first submission scored 13/100

The natural implementation is binary lifting: precompute $$2^j$$-th ancestors, get the LCA in
$$O(\log N)$$, and read off

$$\operatorname{dist}(a,b) = \operatorname{depth}[a] + \operatorname{depth}[b] - 2\operatorname{depth}[\operatorname{lca}(a,b)].$$

That is $$O(N \log N)$$ preprocessing and $$O(K \log N)$$ per query, comfortably inside the budget
on paper. My submission did exactly that and came back Wrong Answer with 13% — the first subtask
correct, everything after it wrong.

The reduction was fine. The bug was four lines from the bottom, in the output:

```python
for _ in range(T):
    ...
    out = []
    for _ in range(Q):
        ...
        out.append(str((diameter + 1) // 2))

    sys.stdout.write("\n".join(out))     # inside the T loop, no trailing newline
```

`out` is rebuilt per test case and flushed per test case, and `"\n".join` puts separators *between*
elements only. So the last answer of one test case and the first answer of the next end up
concatenated on the same line. Feeding it two test cases whose answers should be `0`, `2`, `2`:

```
$ python3 orig.py < two.txt | cat -A
0$
22
```

The official sample has $$T = 1$$, which is the one situation where a missing trailing newline is
harmless — hence a clean pass on subtask 0 and a wall of Wrong Answers behind it. I had spent my
debugging effort re-checking the two-sweep argument on subsets, which was the interesting part and
also the part that was never wrong.

Moving the write outside the loop and appending a final `"\n"` fixes it. I re-ran the corrected
version against the brute force on 4000 random multi-test inputs and it agrees everywhere.

## But it is too slow anyway

With the answers now correct I timed the fixed version on worst-case inputs — $$N = 10^5$$,
$$Q = 10^5$$, $$\sum K = 4\cdot 10^5$$:

| shape of the tree | time |
|---|---|
| path (depth $$10^5$$) | 1.67 s |
| random | 1.21 s |
| star | 0.85 s |
| $$10^5$$ tiny test cases | 0.37 s |

Against a 2 second limit, on my machine, with the judge visibly slower than my machine — the WA
submission had already reported 2.59 s. That is not a solution, that is a coin flip.

The instinct is to blame I/O or the lifting table, so I measured them on the path case. Parsing and
building the adjacency lists is 0.09 s, the DFS is 0.04 s, and the 17-level lifting table is
0.09 s. All of the preprocessing is 0.22 s of the 1.67 s. Switching from `readline` to reading the
whole input at once moved the total from 1.75 s to 1.67 s, which is noise.

The remaining 1.45 s is the $$8 \cdot 10^5$$ LCA calls themselves — two sweeps over $$4 \cdot
10^5$$ vertices, each call running a depth-alignment loop and a 17-step descent, all of it in
interpreted Python. There is no rearrangement of that loop that buys an order of magnitude. The
work is real and it is per-vertex.

## Doing all the sweeps in one batch

The way out is to notice what the two sweeps actually ask for. Sweep one wants
$$\operatorname{dist}(s, x)$$ for every $$x$$ in a query, against a fixed $$s$$. Sweep two wants the
same thing against a different fixed vertex. Those are not $$8 \cdot 10^5$$ independent questions —
they are two array operations. Which means numpy, if the distance computation can be phrased
without a Python-level loop per pair.

Two changes make that work.

**Euler tour instead of binary lifting.** Walk the tree and record the node at every step, entering
and re-entering. For any two vertices, the shallowest node in the Euler segment between their first
occurrences is their LCA. And since the distance formula only needs
$$\operatorname{depth}[\operatorname{lca}(a,b)]$$, never the LCA's identity, it is enough to build a
sparse table over the *depths* along the Euler tour and answer a range minimum. That collapses each
distance to a handful of numpy operations — two table lookups and some arithmetic — instead of a
17-iteration descent.

**One forest instead of $$T$$ trees.** Batching per query is a trap: with up to $$10^5$$ test cases
the per-call numpy overhead of a few microseconds, multiplied by a dozen operations and $$10^5$$
queries, costs more than the interpreted loop it replaced. So offset every test case's vertices into
a single global numbering, treat the whole input as one forest with several roots, build one
adjacency structure, one Euler tour, one sparse table, and concatenate every query from every test
case into one flat array. Then the entire input is a couple of dozen numpy calls total, regardless
of how the test cases were shaped.

The per-query argmax that sweep one needs is the only fiddly part. `np.maximum.reduceat` gives the
maximum over each segment but not where it occurred, so pack the distance and the index into one
64-bit integer — distance in the high bits, position in the low 32 — and the maximum carries its own
argmax along in the bottom half.

```python
import sys
import numpy as np


def main():
    data = np.array(sys.stdin.buffer.read().split(), dtype=np.int64)
    p = 1
    T = int(data[0])

    src, dst, roots = [], [], []
    qnodes, qstart = [], []
    base = total_k = 0

    for _ in range(T):
        N = int(data[p]); Q = int(data[p + 1]); p += 2
        roots.append(base)
        if N > 1:
            e = data[p:p + 2 * (N - 1)]
            p += 2 * (N - 1)
            src.append(e[0::2] + (base - 1))     # shift into the global numbering
            dst.append(e[1::2] + (base - 1))
        for _ in range(Q):
            K = int(data[p]); p += 1
            qstart.append(total_k)
            qnodes.append(data[p:p + K] + (base - 1))
            p += K
            total_k += K
        base += N

    M = base
    eu = np.concatenate(src) if src else np.empty(0, np.int64)
    ev = np.concatenate(dst) if dst else np.empty(0, np.int64)

    # CSR adjacency for the whole forest
    a = np.concatenate([eu, ev])
    b = np.concatenate([ev, eu])
    adj = b[np.argsort(a, kind='stable')].tolist()
    head = np.zeros(M + 1, np.int64)
    np.cumsum(np.bincount(a, minlength=M), out=head[1:])
    head = head.tolist()

    # one iterative DFS over every root -> Euler tour
    par, depth, tin = [0] * M, [0] * M, [0] * M
    ptr = head[:M]
    euler = []
    ea = euler.append

    for r in roots:
        par[r] = r
        tin[r] = len(euler)
        ea(r)
        stack = [r]
        while stack:
            u = stack[-1]
            i, end, pu = ptr[u], head[u + 1], par[u]
            while i < end:
                v = adj[i]
                i += 1
                if v != pu:
                    ptr[u] = i
                    par[v] = u
                    depth[v] = depth[u] + 1
                    tin[v] = len(euler)
                    ea(v)
                    stack.append(v)
                    break
            else:
                ptr[u] = i
                stack.pop()
                if stack:
                    ea(stack[-1])

    depth = np.array(depth, np.int32)
    tin = np.array(tin, np.int64)
    E = len(euler)
    ed = depth[np.array(euler, np.int64)]

    # sparse table of minimum depth over an Euler range
    LOG = max(1, E.bit_length())
    sp = np.empty((LOG, E), np.int32)
    sp[0] = ed
    for k in range(1, LOG):
        half = 1 << (k - 1)
        n = E - (1 << k) + 1
        if n <= 0:
            sp[k] = sp[k - 1]
            continue
        np.minimum(sp[k - 1, :n], sp[k - 1, half:half + n], out=sp[k, :n])
        sp[k, n:] = sp[k - 1, n:]

    log2 = np.zeros(E + 1, np.int64)
    if E >= 2:
        log2[2:] = np.floor(np.log2(np.arange(2, E + 1))).astype(np.int64)

    def dist(x, y):
        """Distance for two whole arrays of vertices at once."""
        lo = np.minimum(tin[x], tin[y])
        hi = np.maximum(tin[x], tin[y])
        k = log2[hi - lo + 1]
        lca_depth = np.minimum(sp[k, lo], sp[k, hi - (1 << k) + 1])
        return depth[x] + depth[y] - 2 * lca_depth

    # both sweeps, over every query of every test case simultaneously
    nodes = np.concatenate(qnodes) if qnodes else np.empty(0, np.int64)
    qstart = np.array(qstart, np.int64)
    counts = np.diff(np.append(qstart, total_k))

    d1 = dist(np.repeat(nodes[qstart], counts), nodes).astype(np.int64)
    far = np.maximum.reduceat((d1 << 32) | np.arange(total_k), qstart) & 0xFFFFFFFF
    u = nodes[far]

    d2 = dist(np.repeat(u, counts), nodes)
    D = np.maximum.reduceat(d2, qstart)

    sys.stdout.write("\n".join(map(str, ((D + 1) >> 1).tolist())) + "\n")


main()
```

`K = 1` needs no special case: the single vertex is its own anchor, its distance to itself is zero,
the segment maximum is zero, and $$\lceil 0/2 \rceil = 0$$.

## What it costs

Same inputs as before, both versions on the same machine:

| shape of the tree | binary lifting | batched numpy |
|---|---|---|
| path, $$N = 10^5$$ | 1.67 s | 0.45 s |
| random, $$N = 10^5$$ | 1.21 s | 0.44 s |
| star, $$N = 10^5$$ | 0.85 s | 0.32 s |
| $$10^5$$ tiny test cases | 0.37 s | 0.72 s |
| 4 queries of $$K = 10^5$$ | 0.64 s | 0.37 s |

Worst case 0.72 s against a 2 second limit, peak memory 225 MB against 1.5 GB, and the two versions
produce byte-identical output on all of them.

The last row of the table is the interesting one, and the one that nearly caught me out. The
$$10^5$$-tiny-test-cases input is the *only* case where numpy is slower, and it is slower for a
reason that has nothing to do with the algorithm: the parsing loop still runs once per test case and
once per query in Python, which is $$3 \cdot 10^5$$ interpreted iterations that no amount of
vectorisation touches. It is also the case that would have been catastrophic under the naive
per-query batching I nearly wrote. Vectorising only pays when the batch is big; the whole design
here is arranging for there to be exactly one batch.

## What I would do differently

Two lessons, and they point in opposite directions.

The mathematical part of this problem — the reduction to $$\lceil D/2 \rceil$$ and the fact that two
sweeps survive being restricted to a subset — is the part that looks risky and was in fact correct
on the first try. I spent most of my debugging time re-examining it because it was the interesting
part, and every minute of that was wasted. When a submission passes the sample and fails everything
else, the shape of the failure is telling you it is about input handling, not about the argument.
Test with $$T = 2$$ before anything else.

And separately: the complexity being right is not the same as the constant being right. $$O(K \log
N)$$ with $$\sum K = 4 \cdot 10^5$$ is a completely reasonable budget in any compiled language, and
in CPython it is 1.67 s of pure interpreter overhead in the LCA inner loop. The fix was not a better
algorithm — it is the same two sweeps and the same distance formula — but a restructuring so that
the per-vertex work happens in C instead of in the interpreter. Reformulating the LCA as a range
minimum was what made that phrasing possible, and merging every test case into one forest was what
made the batch large enough to be worth it.
