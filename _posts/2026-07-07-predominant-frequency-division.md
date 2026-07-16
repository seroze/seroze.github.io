---
layout: post
title: "[Codeforces] Edu Round 192 B — A Small Algebra Trick That Turns an O(n²) Idea into O(n)"
date: 2026-07-07 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, prefix_sums, codeforces]
author: "Seroze"
published: true
---

While solving **Predominant Frequency Division**, I initially got stuck on one question:

> *How do I check whether the middle segment is valid efficiently?*

The problem asks us to split the array into three contiguous non-empty parts.

The conditions are:

* Left part: `#1 >= #2 + #3`
* Middle part: `#1 + #2 >= #3`
* Right part: only needs to be non-empty.

The first instinct is to think about checking every possible middle segment, but that quickly becomes quadratic.

## Step 1: Think in Prefix Sums

Let

* `p1(i)` = number of 1's in prefix `[0...i]`
* `p2(i)` = number of 2's in prefix `[0...i]`
* `p3(i)` = number of 3's in prefix `[0...i]`

The middle segment `(l+1...r)` satisfies

```
(p1(r) - p1(l)) + (p2(r) - p2(l))
>=
(p3(r) - p3(l))
```

At first glance, this still looks like a segment condition.

But rearranging gives

```
(p1(r) + p2(r) - p3(r))
>=
(p1(l) + p2(l) - p3(l))
```

Now define

```
f(i) = p1(i) + p2(i) - p3(i)
```

The entire middle condition becomes simply

```
f(r) >= f(l)
```

The segment disappeared!

## Step 2: Rewrite the Left Condition

The left segment must satisfy

```
p1(l) >= p2(l) + p3(l)
```

Using the same function,

```
f(l) = p1(l) + p2(l) - p3(l)
```

we get

```
f(l) >= 2 * p2(l)
```

So a prefix is a valid first part iff

```
f(l) >= 2 * p2(l)
```

## Step 3: The Algorithm

Now everything becomes straightforward.

Scan from left to right while maintaining:

* the minimum `f(l)` among prefixes that satisfy the left condition.

For every possible end `r` of the middle segment:

* if `f(r)` is at least this minimum,
* and there is still one element left for the third segment,

then the answer is **YES**.

The entire solution runs in **O(n)**.

## Implementation

The hints I worked through before landing on the solution:

> We can check if a prefix is valid or if a suffix is valid, but then how will you check if the middle part is valid efficiently?
>
> Actually the last part can be anything — it just has to be non-empty. What if you look for a valid end point for the second group?
>
> `1, 2, 3 ... 1, 2, 3` — `1` is the majority element in the first part, `{1, 2}` is the majority in the second part.

```python
def solve():
    n = int(input())
    a = list(map(int, input().split()))

    fl = float("inf")
    c1, c2, c3 = 0, 0, 0
    for r in range(n):
        if a[r] == 1:
            c1 += 1
        elif a[r] == 2:
            c2 += 1
        else:
            c3 += 1

        fr = c1 + c2 - c3
        if fr >= fl and r + 1 < n:
            print("YES")
            return

        if fr < fl and fr >= 2 * c2:
            fl = fr

    print("NO")


tc = int(input())
for _ in range(tc):
    solve()
```

## What I Learned

The biggest takeaway wasn't the implementation—it was the algebra.

Many segment problems become much easier after expressing them using prefix sums and then rearranging the inequalities.

A condition that initially looks like

```
condition(segment)
```

often transforms into

```
g(r) >= g(l)
```

or

```
g(r) - g(l) >= constant
```

Once that happens, the problem usually reduces to maintaining prefix minima or maxima instead of checking every segment.

This is a pattern I'll definitely watch for in future contest problems.
