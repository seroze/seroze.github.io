---
layout: post
title: "[LeetCode] Weekly Contest 514 — Maximum Area of Two Non-Overlapping Square Submatrices: only the extremes can witness a valid pair"
date: 2026-08-09 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, leetcode, binary_search, prefix_sums, dynamic_programming, invariants]
author: "Seroze"
published: true
---

Problem: [Maximum Area of Two Non-Overlapping Square Submatrices](https://leetcode.com/problems/maximum-area-of-two-non-overlapping-square-submatrices/) (Weekly Contest 514)

---

Given a binary matrix, find the largest `k` such that there exist **two non-overlapping** `k × k` submatrices consisting entirely of ones. Return `k * k` — the area of one of them.

The implementation is short. The interesting part is a claim in the accepted solution that looks like it can't possibly be enough information:

> While scanning all candidate squares, remember only three numbers: the smallest row seen, the smallest column seen, and the largest column seen.

Three numbers, for a set of up to a million squares. That deserves an actual argument, so this post is mostly that argument — and the reusable idea it's an instance of.

## The one geometric fact

Everything follows from a single observation about axis-aligned boxes:

> Two axis-aligned rectangles are disjoint **iff** their row intervals are disjoint or their column intervals are disjoint.

Equivalently: any two non-overlapping axis-aligned squares can be separated by a horizontal line or by a vertical line. There's no third way for them to miss each other — if their rows overlap *and* their columns overlap, then some cell is in both.

That's weaker than it's tempting to assume. My first instinct in contest was the stronger statement — fix a horizontal strip, compress it to a 1D array, find two disjoint intervals, then repeat on the transpose. That quietly requires **both squares to share the same row interval** (or, after transposing, the same column interval), which the problem never asks for. On

```
1110
1111
0011
```

the optimum is

```
AA10
AA11
00BB
```

where `A` occupies rows `[0,1]` and `B` occupies rows `[1,2]`. Their row intervals overlap and their column intervals are disjoint — so the vertical separator exists, but no common strip does. Answer: `4`.

The separator framing is the faithful one. Don't fix the strip; fix the *wall*.

## Binary search on the side length

Monotonicity is easy: if two disjoint `k × k` all-ones squares exist, take the top-left `t × t` sub-square of each for any `t < k`. They're still all ones and still disjoint. So `check(k)` is monotone and we can binary search `k` over `[0, min(n, m)]`.

For a fixed `k`, a 2D prefix sum answers "is this `k × k` square all ones?" in `O(1)`:

```python
pref[r + k][c + k] - pref[r][c + k] - pref[r + k][c] + pref[r][c] == k * k
```

So `check(k)` becomes: enumerate every valid `k × k` square in row-major order, and decide whether any two of them are disjoint. Naively that's a quadratic pairwise comparison over up to `nm` squares. This is where the three numbers come in.

## The extremes are the only witnesses you need

Process candidate squares in row-major order by their top-left corner. When we reach a valid square at `(i, j)`, every valid square already seen is "earlier," so it has row `r <= i`. Maintain, over the squares seen so far:

- `tr` — the **smallest** row of any valid square
- `lc` — the **smallest** column of any valid square
- `rc` — the **largest** column of any valid square

and check exactly three conditions:

```python
if tr + k <= i:   # some earlier square is entirely above me
if lc + k <= j:   # some earlier square is entirely to my left
if j + k <= rc:   # some earlier square is entirely to my right
```

If any holds, a disjoint pair exists and `check(k)` is `True`.

### Why three numbers suffice

Suppose *some* earlier square `(r, c)` is disjoint from `(i, j)`. By the geometric fact, one of these holds:

- **rows disjoint.** Since `r <= i`, the only possibility is `r + k <= i`. And `tr <= r`, so `tr + k <= r + k <= i`. The `tr` test fires.
- **columns disjoint, earlier square on the left**, i.e. `c + k <= j`. Since `lc <= c`, we get `lc + k <= c + k <= j`. The `lc` test fires.
- **columns disjoint, earlier square on the right**, i.e. `j + k <= c`. Since `rc >= c`, we get `j + k <= c <= rc`. The `rc` test fires.

In every case the extreme is *at least as good a witness* as the actual square. Each test is monotone in the stored value — smaller `tr` makes `tr + k <= i` easier, smaller `lc` makes `lc + k <= j` easier, larger `rc` makes `j + k <= rc` easier — so replacing the real witness by the extreme can never turn a satisfied condition into an unsatisfied one. The extremes **dominate** every witness, which is why discarding all the other squares loses nothing.

Note the "on the right" case is not redundant. Row-major order means an earlier square can sit to the *right* of the current one, if it's in a higher row:

```
.....BBBB
AAAA.....
```

When we reach `A`, the disjoint partner `B` is both earlier in scan order and to the right. Drop the `rc` test and this case is missed.

One implementation detail: `lc` and `rc` are updated immediately, including for squares in the current row, which is correct because those are genuinely earlier in scan order. `tr` is only committed at the end of a row. That's also fine — squares in the same row can never be row-disjoint (`r + k <= i` fails when `r == i`), so a same-row value would never fire the test anyway.

## Implementation

```python
class Solution:
    def maxArea(self, mat: List[List[int]]) -> int:
        n, m = len(mat), len(mat[0])

        pref = [[0] * (m + 1) for _ in range(n + 1)]
        for i in range(n):
            for j in range(m):
                pref[i + 1][j + 1] = (pref[i + 1][j] + pref[i][j + 1]
                                      - pref[i][j] + mat[i][j])

        def all_ones(r: int, c: int, k: int) -> bool:
            return (pref[r + k][c + k] - pref[r][c + k]
                    - pref[r + k][c] + pref[r][c]) == k * k

        def check(k: int) -> bool:
            if k == 0:
                return True
            tr, lc, rc = -1, m, -1
            found = False
            for i in range(n - k + 1):
                for j in range(m - k + 1):
                    if not all_ones(i, j, k):
                        continue
                    if tr != -1 and tr + k <= i:      # earlier square above
                        return True
                    if lc != m and lc + k <= j:       # earlier square to my left
                        return True
                    if rc != -1 and j + k <= rc:      # earlier square to my right
                        return True
                    lc = min(lc, j)
                    rc = max(rc, j)
                    found = True
                if found and tr == -1:
                    tr = i
            return False

        lo, hi, best = 0, min(n, m), 0
        while lo <= hi:
            mid = (lo + hi) // 2
            if check(mid):
                best = mid
                lo = mid + 1
            else:
                hi = mid - 1
        return best * best
```

`O(nm log(min(n, m)))` time, `O(nm)` space.

## Sweeping the wall instead: dropping the log

Once the separator is the object you're thinking about, the binary search starts to look optional. Instead of asking "does size `k` work," sweep the separating wall and ask "what's the best square on each side of it."

Two standard DPs:

- `br[i][j]` — largest all-ones square with **bottom-right** corner at `(i, j)`
- `tl[i][j]` — largest all-ones square with **top-left** corner at `(i, j)`

Both are the classic `1 + min(three neighbours)` recurrence, one scanning forward and one backward.

Now for a horizontal wall between rows `r` and `r + 1`: a square lies entirely above it iff its bottom-right row is `<= r`, so a prefix max of `br` over rows gives `above[r]`. A square lies entirely below iff its top-left row is `>= r + 1`, so a suffix max of `tl` gives `below[r + 1]`. Since squares shrink freely, two disjoint squares of side `min(above[r], below[r + 1])` exist. Take the max over all `r`, repeat with the matrix transposed for vertical walls, and square the result.

```python
def sweep(mat):
    n, m = len(mat), len(mat[0])
    br = [[0] * m for _ in range(n)]
    for i in range(n):
        for j in range(m):
            if mat[i][j]:
                br[i][j] = 1 + min(br[i - 1][j] if i else 0,
                                   br[i][j - 1] if j else 0,
                                   br[i - 1][j - 1] if i and j else 0)

    tl = [[0] * m for _ in range(n)]
    for i in range(n - 1, -1, -1):
        for j in range(m - 1, -1, -1):
            if mat[i][j]:
                tl[i][j] = 1 + min(tl[i + 1][j] if i + 1 < n else 0,
                                   tl[i][j + 1] if j + 1 < m else 0,
                                   tl[i + 1][j + 1] if i + 1 < n and j + 1 < m else 0)

    def best_split(rows, cols, transposed):
        get_br = (lambda r, c: br[c][r]) if transposed else (lambda r, c: br[r][c])
        get_tl = (lambda r, c: tl[c][r]) if transposed else (lambda r, c: tl[r][c])

        above, run = [0] * rows, 0
        for r in range(rows):
            for c in range(cols):
                run = max(run, get_br(r, c))
            above[r] = run

        below, run = [0] * rows, 0
        for r in range(rows - 1, -1, -1):
            for c in range(cols):
                run = max(run, get_tl(r, c))
            below[r] = run

        return max((min(above[r], below[r + 1]) for r in range(rows - 1)), default=0)

    k = max(best_split(n, m, False), best_split(m, n, True))
    return k * k
```

`O(nm)`, no binary search. I checked both implementations against a brute force over all pairs of equal-sized all-ones squares on 4000 random matrices up to `5 × 5`; they agree everywhere, and both give `4` on the sample above.

The two solutions are the same insight wearing different clothes. `above` / `below` are prefix and suffix *extrema* of square sizes on either side of the wall; `tr` / `lc` / `rc` are extrema of positions among squares of one fixed size. Both throw away everything except the extreme.

## The lesson: to find a valid pair, look only at the extremes

The reusable takeaway isn't prefix sums or binary search. It's this:

> When you're searching for **a pair** of objects satisfying a condition, and the condition is monotone in some coordinate of each object, you don't need to remember the objects — only the extreme values of that coordinate. If any valid pair exists, the extremes form one.

That collapses a quadratic pairwise search into a single linear scan carrying a couple of scalars. The two things to check before applying it:

1. **Enumerate the ways the condition can be met.** Here that was the geometric fact — disjointness decomposes into exactly three cases relative to scan order (above, left, right; never below). Miss the "right" case and the `rc` test never gets written.
2. **Verify each case is monotone in the stored extreme**, so the extreme dominates any real witness. That's the three-line proof above, and it's what licenses throwing the rest away.

Get those two right and the implementation is mechanical. The same shape shows up all over: max difference in an array (keep the running min), two disjoint subarrays with a best combined property (keep prefix/suffix bests), any "does there exist a separated pair" question. The hard step is never the code — it's noticing that a set of a million candidates has only three that can ever matter.
