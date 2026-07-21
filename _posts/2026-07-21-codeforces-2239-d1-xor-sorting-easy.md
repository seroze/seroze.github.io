---
layout: post
title: "[Codeforces] Round 2239 D1 — XOR Sorting (Easy)"
date: 2026-07-21 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codeforces, graphs, bit_manipulation, xor]
author: "Seroze"
published: true
---

*[Codeforces Round 2239 — Problem D1: XOR Sorting (Easy)](https://codeforces.com/contest/2239/problem/D1).*

This was one of those problems where the algorithm is hidden behind an unusual graph defined on **indices** rather than on the values themselves.

At first glance, the condition

> We may swap indices `i` and `j` only if `i XOR j <= k`

looks difficult to reason about. The trick is to completely ignore the array for a while and study the graph induced by this condition.

---

## Step 1: Think of indices as a graph

For a fixed `k`, create an undirected graph:

- Vertices = indices `0 ... n-1`
- Edge between `i` and `j` iff `i XOR j <= k`

Since we may perform **any number of swaps**, what matters is not the individual edges but the **connected components**.

Any value can move anywhere **inside its connected component**, but it can never leave it.

Therefore:

> An array is sortable iff every element's current index and its final sorted index belong to the same connected component.

---

## Step 2: Understanding the connected components

Let's examine small values of `k`.

### `k = 1`

Components:

```
{0,1}
{2,3}
{4,5}
...
```

---

### `k = 2`

New edges merge adjacent pairs:

```
{0,1,2,3}
{4,5,6,7}
...
```

---

### `k = 3`

Nothing new happens.

Components remain

```
{0,1,2,3}
{4,5,6,7}
...
```

---

### `k = 4`

The previous groups merge again:

```
{0,1,2,3,4,5,6,7}
{8,9,10,11,12,13,14,15}
...
```

A clear pattern emerges.

If the highest set bit of `k` is `b`, then the connected components are contiguous blocks of size

```
2^(b+1)
```

This means two indices belong to the same component **iff** they lie inside the same block.

---

## Step 3: Where should every element go?

Let

```
a = current array
b = sorted(a)
```

For every element, determine the index where it should finally appear.

For duplicate values, we must be careful to match occurrences consistently.

A convenient implementation is:

```python
pos = defaultdict(list)

for i in range(n - 1, -1, -1):
    pos[b[i]].append(i)
```

Then

```python
j = pos[a[i]].pop()
```

returns the correct destination index for each occurrence.

---

## Step 4: What constraint does one element impose?

Suppose an element must move from index

```
i -> j
```

These two indices must lie inside the same connected component.

Instead of thinking about blocks directly, consider

```
i XOR j
```

The important observation is:

> Only the **highest differing bit** matters.

If

```
i XOR j = 13 = 1101₂
```

then the highest differing bit is

```
8 = 1000₂
```

Therefore this move requires the answer to be at least `8`.

Notice that we **do not** require

```
i XOR j <= k
```

directly.

The element may travel through intermediate indices.

---

## Step 5: Combining all constraints

Every element contributes one required move.

We compute

```python
answer_mask |= (current_index ^ destination_index)
```

At the end,

```python
highest_power_of_two(answer_mask)
```

is exactly the minimum valid answer.

In Python:

```python
if answer_mask == 0:
    print(0)
else:
    print(1 << (answer_mask.bit_length() - 1))
```

---

## Complete Python Solution

```python
from collections import defaultdict

t = int(input())

for _ in range(t):
    n, q = map(int, input().split())
    a = list(map(int, input().split()))

    b = sorted(a)

    if a == b:
        print(0)
        continue

    pos = defaultdict(list)

    for i in range(n - 1, -1, -1):
        pos[b[i]].append(i)

    mask = 0

    for i in range(n):
        j = pos[a[i]].pop()
        mask |= i ^ j

    if mask == 0:
        print(0)
    else:
        print(1 << (mask.bit_length() - 1))
```

---

## Complexity

Sorting:

```
O(n log n)
```

Matching indices:

```
O(n)
```

Overall:

```
O(n log n)
```

with linear extra memory.

---

## TODO: Hard Version (D2)

The hard version introduces up to **10⁶ point updates**.

Recomputing the sorted order and all destination indices after every update is far too slow.

The key observation from the easy version still holds:

- every element contributes a destination index,
- every move contributes its highest differing bit,
- the answer is determined by the maximum active bit.

The remaining challenge is to **maintain these constraints dynamically** after each update.

**TODO:** Derive an efficient data structure that supports updates while maintaining the answer in sublinear time.
