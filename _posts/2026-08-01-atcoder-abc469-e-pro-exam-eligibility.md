---
layout: post
title: "[AtCoder] ABC469 E — Pro Exam Eligibility"
date: 2026-08-01 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, atcoder, binary_search, prefix_sums, two_pointers]
author: "Seroze"
published: true
---

*[AtCoder Beginner Contest 469 — Problem E: Pro Exam Eligibility](https://atcoder.jp/contests/abc469/tasks/abc469_e).*

## Problem

You're given a string `S` of length `N` made of `'o'` (win) and `'x'` (loss), and an integer `K`. Pick a contiguous substring containing **at least `K` wins**, and maximize the win rate

$$
\frac{\text{wins}}{\text{length}}.
$$

Constraints: `N` up to `10^6`, and `S` is guaranteed to contain at least `K` wins.

This looks intimidating because the objective is a **ratio**. But whenever I see an optimization over a ratio, the first thing to reach for now is:

> **Can I binary search on the answer?**

That one question turns a nonlinear optimization problem into a prefix-sum problem.

---

## Step 1: Binary search the answer

Instead of *maximizing* the rate, guess a value `p` and ask a yes/no question:

> Is there a valid substring whose win rate is at least `p`?

If the answer is yes for `p`, it's also yes for anything smaller — so the predicate is monotone and binary search applies.

The condition is

$$
\frac{W}{L}\ge p
$$

where `W` is the number of wins and `L` the length. Since `L > 0`, multiply through and move everything to one side:

$$
W - pL \ge 0.
$$

That's the whole trick. The denominator is gone.

---

## Step 2: Per-character contributions

`W - pL` is a *sum over characters*, because each character contributes independently to both `W` and `L`:

| Character | wins | length | contribution to `W - pL` |
|-----------|------|--------|--------------------------|
| `'o'`     | +1   | +1     | `1 - p`                  |
| `'x'`     | 0    | +1     | `-p`                     |

So for `o x o o x` the transformed values are `1-p, -p, 1-p, 1-p, -p`, summing to `3 - 5p` — exactly `W - pL` with `W = 3`, `L = 5`.

Checking `W/L ≥ p` is now just checking that a **contiguous sum is non-negative**.

---

## Step 3: Prefix sums

Define two prefix arrays over the first `i` characters:

- `cnt[i]` — number of wins
- `score[i]` — transformed sum, which is just `cnt[i] - p*i`

For the interval `(l, r]`:

$$
\text{wins} = cnt[r] - cnt[l], \qquad \text{transformed sum} = score[r] - score[l].
$$

Note `score` never needs to be materialized — it's a one-line expression in `cnt[i]` and `i`, recomputed each binary search round.

---

## Step 4: The "at least K wins" constraint

For each right endpoint `r`, a left endpoint `l` is legal when

$$
cnt[r] - cnt[l] \ge K \quad\Longleftrightarrow\quad cnt[l] \le cnt[r] - K,
$$

and among the legal ones we want the **smallest `score[l]`**, since that maximizes `score[r] - score[l]`. If that maximum is `≥ 0` for any `r`, then `p` is feasible.

### The mental shift

I first got stuck trying to compare prefixes as *pairs* `(cnt, score)` and define which pair was "smaller". That's the wrong frame. The two coordinates play completely different roles:

- `cnt[l]` is **only a filter** — it decides which prefixes are eligible.
- `score[l]` is **the objective** — it's what we minimize over the eligible set.

The query isn't "find the smallest pair". It's:

> Among all prefixes with win count at most `X`, return the minimum `score`.

Separating the constraint from the objective is what made the solution click.

### And then the constraint collapses

Once phrased that way, there's a further simplification I nearly missed: **`cnt` is non-decreasing**. So `{ l : cnt[l] ≤ cnt[r] - K }` is not some arbitrary subset — it's a *prefix of indices* `[0, L(r)]`. And `L(r)` is itself non-decreasing in `r`.

So no segment tree, no sorted structure. A single forward pointer that only ever moves right, carrying a running minimum of `score`, answers every query in amortized O(1).

---

## Code

```cpp
#include <bits/stdc++.h>
using namespace std;

int n, K;
string s;
vector<int> cnt;

// is there a substring with >= K wins and win rate >= p ?
bool feasible(double p) {
    double minScore = 1e18;
    int j = 0;
    for (int r = 1; r <= n; r++) {
        int need = cnt[r] - K;
        // absorb every prefix that is now eligible; j never moves backwards
        while (j <= n && cnt[j] <= need) {
            minScore = min(minScore, cnt[j] - p * j);
            j++;
        }
        if (minScore < 1e17 && (cnt[r] - p * r) - minScore >= 0) return true;
    }
    return false;
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);
    cin >> n >> K >> s;
    cnt.assign(n + 1, 0);
    for (int i = 0; i < n; i++) cnt[i + 1] = cnt[i] + (s[i] == 'o');

    double lo = 0.0, hi = 1.0;
    for (int it = 0; it < 60; it++) {
        double mid = (lo + hi) / 2;
        if (feasible(mid)) lo = mid; else hi = mid;
    }
    printf("%.12f\n", lo);
}
```

`j` is never reset across the loop, so `feasible` is O(N). With 60 binary search rounds that's about `6 * 10^7` operations at `N = 10^6` — under 0.1s in practice. The answer lies in `[0, 1]`, so 60 halvings land far inside the `10^-6` tolerance.

One thing that falls out for free: `j` can never pass `r`, because `cnt[j] ≤ cnt[r] - K < cnt[r]` forces `j < r` whenever `K ≥ 1`. No explicit bound check needed.

---

## The pattern

The reusable takeaway:

1. Objective is a ratio or an average.
2. Binary search the answer `p`.
3. Rewrite `A/B ≥ p` as `A - pB ≥ 0`.
4. Give every element its own contribution to `A - pB`.
5. Convert to prefix sums.
6. Solve the remaining feasibility problem — and check whether monotonicity collapses it into something simpler than the data structure you were about to reach for.

Once I saw the transformation, this stopped looking like a math optimization problem and started looking like a prefix-sum problem in disguise. That's a shape I'll be watching for.
