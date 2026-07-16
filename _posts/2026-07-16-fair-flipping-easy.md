---
layout: post
title: "[CodeChef] Starters 247 — Fair Flipping (Easy): What This Constructive Proof Taught Me"
date: 2026-07-16 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, constructive_algorithms, codechef]
author: "Seroze"
published: true
---

*[CodeChef Starters 247 — Fair Flipping (Easy)](https://www.codechef.com/problems/FLIP2K). A reflection on the constructive proof behind this problem. The interesting part isn't the problem itself — it's the technique of composing imperfect operations so that everything unwanted cancels out.*

---

I recently solved (or rather, studied) the **Fair Flipping (Easy)** problem from CodeChef. At first glance, the editorial looked almost magical:

> Show that you can swap any `0` and any `1` using two operations. Therefore, every permutation with the same number of zeros and ones is reachable.

My first reaction was:

**"How on earth does someone come up with that?"**

After spending some time with the proof, I realized the interesting part isn't the problem itself — it's the technique.

## The goal isn't the operation

Suppose I want to swap

```text
i : 0
j : 1
```

If I could do that, I could sort the string, giving the lexicographically smallest answer.

The problem is that the allowed operation doesn't let me touch only two positions. Every move must flip **$$K$$ zeros and $$K$$ ones**.

So the question changes from

> "How do I swap these two positions?"

to

> "How do I make everything *except* these two positions cancel out?"

That change in perspective is the key insight.

## Think in terms of parity

Every position only cares whether it has been flipped an odd number of times or an even number of times.

- Flipped once → changes.
- Flipped twice → back to where it started.
- Flipped four times → still unchanged.

Instead of designing **one** perfect operation, we can design **two** imperfect ones whose unwanted effects cancel each other.

This immediately suggests a strategy:

- Include almost the same positions in both operations.
- Any common position gets flipped twice.
- Only the positions that appear in exactly one operation remain changed.

The proof suddenly feels much less mysterious.

## The extra element isn't random

The editorial introduces an extra index $$e$$.

At first it feels like a trick.

It isn't.

That extra position acts as temporary storage.

During the first move, its value changes so that the second move can satisfy the "choose exactly $$K$$ zeros and $$K$$ ones" constraint.

At the end, it gets flipped again and returns to its original value.

It's like using a spare register while swapping variables in assembly language.

The condition $$2K < N$$ is exactly what guarantees that this spare position always exists.

## The bigger lesson

This problem reminded me of a pattern I've seen in many constructive problems:

> Don't try to perform the desired transformation directly.

Instead,

1. Allow yourself multiple operations.
2. Make the unwanted effects happen an even number of times.
3. Ensure only the desired positions are affected an odd number of times.

Once I started thinking in terms of **cancellation** instead of **individual operations**, the proof became almost inevitable.

## What I'm taking away

The most valuable lesson wasn't the solution itself.

It was learning a new way to think:

> **When an operation affects too many things, don't fight it. Compose multiple operations so that everything you don't want cancels automatically.**

That's a technique I expect to see again — not just in constructive algorithms, but anywhere parity, XOR, or reversible operations are involved.

This was one of those editorials that didn't just solve a problem; it expanded the toolbox I use to approach future ones.

## Follow-up: Fair Flipping (Hard)

If you enjoyed this, try the hard version: [Fair Flipping (Hard)](https://www.codechef.com/problems/FLIP2KHD) (difficulty 2295).

The setup is identical — a binary string $$A$$ of length $$N$$ and an integer $$K$$ ($$1 \le 2K \le N$$), and each operation picks a subsequence of length $$2K$$ containing exactly $$K$$ zeros and $$K$$ ones and flips all of it. You still have to output the lexicographically smallest reachable string, but now you must **also output the minimum number of operations** needed to reach it.

A couple of the sample cases capture the flavor:

- `1010` with $$K = 2$$: one operation on all four indices flips everything to `0101` — optimal in a single move.
- `000101` with $$K = 2$$: the optimal string `000011` needs **two** operations, so greedy "one big flip" reasoning isn't enough.

The easy version only asks *whether* the sorted string is reachable — the two-operation swap trick settles that. The hard version forces you to think about *how efficiently* you can get there, which means counting how much useful work a single flip can do instead of just proving reachability. Constraints: $$N \le 2 \cdot 10^5$$ with sum of $$N$$ over all tests bounded by the same, so the count has to come from a formula or greedy argument, not search.
