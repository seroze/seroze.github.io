---
layout: post
title: "[Repovive] Starter Round 4 D — Distant Transfers: Deriving Invariants Instead of Constructing Moves"
date: 2026-07-06 00:00:00 +0530
categories: competitive-programming
tags: [cp, binary-search, greedy, repovive]
author: "Seroze"
published: true
---

*[Repovive Starter Round 4 — Problem D: Distant Transfers](https://repovive.com/contests/15/problems/D). This problem looked like a greedy at first glance, but it turned out to be a lesson in deriving invariants rather than constructing moves.*

## Problem

We are given an array `a`.

An operation allows us to choose `l < r` such that

```
r - l >= k
```

and transfer one unit from `a[l]` to `a[r]`.

The goal is to find the **maximum** `k` for which it is possible to make the entire array zero.

---

## Observation 1: Binary Search

The first useful observation is that the answer is monotonic.

If some `k` is feasible, then every smaller value is also feasible.

Why?

Because decreasing `k` only **adds more allowed operations**.

```
r - l >= k
⇒
r - l >= k'   (for every k' < k)
```

So the solution is naturally

* Binary search on `k`
* Design an `O(n)` feasibility check.

---

## My First Wrong Idea

Initially I tried treating positive and negative positions separately.

The intuition was:

* Keep lists of positive and negative indices.
* Match the leftmost positive with the leftmost negative.
* The minimum distance among these pairings determines the answer.

Although intuitive, this is incorrect.

The problem is that one positive position may need to supply multiple negatives, and greedy pairing ignores these global constraints.

This was a useful reminder that **movement problems are often flow problems, not matching problems.**

---

## Prefix Sum Invariant (`k = 1`)

Before thinking about arbitrary `k`, it helps to understand the easier case.

When `k = 1`, every operation moves one unit **to the right**.

For any fixed prefix,

```
[1 ... i]
```

an operation can only

* keep the prefix sum unchanged, or
* decrease it by one.

A prefix sum can **never increase**, because no operation can bring mass from the right into the prefix.

Therefore,

```
prefix_sum(i) >= 0
```

for every prefix is necessary.

Together with

```
total sum = 0
```

these conditions are also sufficient.

A simple greedy proves this:

Process from left to right.

Whenever `a[i] > 0`, push all of it to `i+1`.

If we ever encounter `a[i] < 0`, the configuration is impossible because nothing from the right can move backwards.

---

## Trying to Generalize

My next thought was:

For arbitrary `k`

* the first `k` positions cannot receive anything
* the last `k` positions cannot send anything

So perhaps

```
first k elements >= 0
last k elements <= 0
```

plus the prefix condition would be sufficient.

Unfortunately, this is not enough.

The greedy proof for `k = 1` breaks because we can no longer move from `i` to `i+1`.

For example, when `k = 2`, position `2` cannot send to position `3`.

The beautiful local invariant disappears.

---

## Another Wrong Attempt

I then considered the following greedy.

Process left to right.

If

```
a[i] < 0
```

return impossible.

Otherwise transfer everything from

```
i -> i+k
```

This almost feels like the natural extension of the `k=1` solution.

The problem is that a positive position may need to split its supply among several future positions.

Example:

```
k = 2

[2, 0, -1, -1]
```

The correct solution is

```
1 -> 3
1 -> 4
```

Sending everything to position `3` fails.

---

## The Editorial Insight

The key insight is to stop thinking about **moving positives**.

Instead, think about **supplying negatives**.

Suppose we want to satisfy all negative positions up to some index `x`.

Which positions can possibly supply them?

Every demand in

```
[1 ... x]
```

must receive units from positions at most

```
x-k
```

because every transfer satisfies

```
r - l >= k.
```

This naturally defines

* `P(x)` = total positive supply in the first `x` positions.
* `D(x)` = total demand (sum of `-a[i]`) in the first `x` positions.

Immediately we obtain the necessary condition

```
D(x) <= P(x-k)
```

for every prefix.

What surprised me was that this condition is also sufficient.

---

## Why Is It Sufficient?

Process negative positions from left to right.

When processing position `i`, all previous demands have already been satisfied.

Initially the available supply before `i` is

```
P(i-k)
```

The amount already consumed is

```
D(i-1)
```

Therefore the remaining supply equals

```
P(i-k) - D(i-1)
```

The editorial condition says

```
D(i) <= P(i-k)
```

Since

```
D(i) = D(i-1) + need
```

we obtain

```
P(i-k) - D(i-1) >= need
```

which means there is always enough unused supply to satisfy the current negative.

By induction, the greedy never gets stuck.

---

## What I Learned

The biggest lesson from this problem wasn't the inequality.

It was the thought process.

Initially I kept asking

> "How do I move the positive values?"

The editorial instead asks

> "Who can supply each negative?"

That small change in perspective completely changes the problem.

Many 1900–2200 rated problems become much easier once you stop trying to construct a solution immediately and instead ask:

* Who can help this element?
* What resources are available?
* What must be true in every valid solution?

Very often, the feasibility check appears naturally from these questions.

---

## Takeaway

When faced with movement or transfer constraints:

1. Check whether the answer is monotonic.
2. Derive a feasibility check instead of constructing the final sequence.
3. Identify **supplies** and **demands**.
4. Ask which supplies are capable of satisfying each demand.
5. Convert that into a prefix (or interval) invariant.

This problem was a great reminder that sometimes the hardest part is not finding the algorithm—it's finding the right way to think about the problem.

A useful way to remember it: many problems of this flavor boil down to the same template.

1. Define the resources (`P`).
2. Define the requirements (`D`).
3. Show that every prefix has enough resources.
4. Process requirements greedily in order.
5. Use induction to show you never run out.
