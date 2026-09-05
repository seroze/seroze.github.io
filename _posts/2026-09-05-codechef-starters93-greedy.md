---
layout: post
title: "[CodeChef] Starters 93 — Greedy: the problem is called Greedy and the answer is a DP"
date: 2026-09-05 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, dynamic_programming, subset_sum, strings, bitmask, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Greedy](https://www.codechef.com/problems/LASTRBS) (Starters 93)

The problem code is `LASTRBS`, the display name is *Greedy*, and the intended solution is a
dynamic program. I don't know whether that title is a joke at the solver's expense or just a
leftover, but I fell for it anyway: I spent the first ten minutes hunting for a sweep that would
decide each character on the spot, and there isn't one. Writing this up mostly because the way
I got the state wrong is a mistake I make often — I remembered a constraint as being stronger
than it is, and then carried the extra baggage around in my DP state.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

You're given a string $$S$$ of length $$N$$ over the lowercase alphabet. You have to produce a
string $$T$$ of the same length, over $$\{\texttt{(}, \texttt{)}\}$$, such that:

- $$T$$ is a regular bracket sequence — balanced, and never closing more than it has opened;
- for every $$i$$, if $$S_i = S_{i+1}$$ then $$T_i = T_{i+1}$$.

Print `YES` and any such $$T$$, or `NO`. Constraints: $$N \le 2000$$, and the sum of $$N$$ over
all test cases is also $$\le 2000$$.

Two samples, both small and both instructive:

- `abcd` → `YES`, e.g. `()()`
- `abbb` → `NO`

## Reading the constraint correctly

Here is the mistake, and it happened in the first thirty seconds of reading.

The condition is an *implication in one direction*: equal neighbours in $$S$$ force equal
neighbours in $$T$$. It says nothing whatsoever about what happens when
$$S_i \ne S_{i+1}$$. I read it as if it were an equivalence — as if different neighbours in $$S$$
required different brackets in $$T$$ — and that misreading survived long enough to poison the
state I designed.

Once you have it right, the structure falls out immediately. Collapse $$S$$ into maximal runs of
equal characters. Every character inside a run is chained to its neighbours, so a whole run must
get one single bracket symbol. And between two adjacent runs there is no constraint at all —
consecutive runs are completely independent. So `abbb` becomes runs of lengths $$[1, 3]$$, and
`abcd` becomes $$[1, 1, 1, 1]$$.

The problem is now: given block lengths $$a_1, \ldots, a_m$$ with $$\sum a_i = N$$, assign each
block a sign, $$+$$ for a block of `(` and $$-$$ for a block of `)`, such that the running total
never goes negative and ends at zero.

That's it. That's the whole problem. Everything after this is bookkeeping.

## The state I didn't need

My first DP state was `dp[i][balance][last_symbol]` — which block am I on, what's my running
balance, and what did I assign to the previous block.

The third component is pure residue from the misreading. It's there to enforce an adjacency rule
between consecutive blocks, and there is no adjacency rule between consecutive blocks; the
collapse into runs already consumed the entire constraint. Block $$i+1$$ may freely repeat block
$$i$$'s symbol or flip it.

The test I should have applied, and now try to apply every time: **does the future depend on this
component?** Given that the first $$i$$ blocks are decided, what do the remaining decisions
actually care about? Only the running balance. Two different assignments of the first $$i$$ blocks
that arrive at the same balance are completely interchangeable from there on — nothing
distinguishes them for any future block. So the state is

$$dp[i][b] = \text{is balance } b \text{ reachable after deciding the first } i \text{ blocks?}$$

with the transition

$$dp[i][b] \;=\; dp[i-1][b - a_i] \;\lor\; dp[i-1][b + a_i]$$

and the answer is $$dp[m][0]$$.

Carrying an unnecessary component isn't just wasted memory. It splits states that should have been
merged, which is exactly the thing a DP exists to avoid, and it makes the recurrence harder to
stare at and believe.

## Why block boundaries are the only place to check

The one thing that genuinely needs an argument is the non-negativity condition. It's a constraint
on *every prefix* of $$T$$, but the DP only ever looks at balances at block boundaries. Isn't that
skipping most of the string?

It isn't, and the reason is monotonicity. Inside a block assigned `(`, the balance only rises, so
the smallest value it takes over that block is at the block's *start* — which is the previous
boundary, already checked. Inside a block assigned `)`, the balance only falls, so its smallest
value is at the block's *end* — which is the next boundary, about to be checked. Either way the
minimum over a block sits on a boundary.

So checking $$b \ge 0$$ at boundaries is not an approximation, it's exactly equivalent to checking
it everywhere, and each block transition stays $$O(1)$$. This is the sort of observation that
makes a DP go from "obviously too slow" to "obviously fine", and it's worth learning to look for
it: whenever a constraint applies at every step but the steps within a group move monotonically,
you only have to test the group's endpoints.

There's a free early exit too: if $$N$$ is odd, print `NO` and move on. No bracket sequence of odd
length is balanced.

## Complexity

There are at most $$N$$ blocks and at most $$N+1$$ balance values, with two transitions each, so
the DP is $$O(N^2)$$ states and transitions. With $$N \le 2000$$ and the sum of $$N$$ bounded by
$$2000$$ as well, the worst case is a single test with $$N = 2000$$: four million boolean
operations. Comfortable.

The upper bound on balance can be $$N$$ and nothing is ever lost by capping there, because the
block lengths sum to $$N$$ — the balance physically cannot exceed $$N$$, so the cap never truncates
a reachable state.

## The implementation

I wrote the transition as a *push* rather than a pull — for each reachable state at layer $$i$$,
mark the two states it can reach at layer $$i+1$$ — because it skips dead states for free and the
bounds checks read more naturally in that direction.

```python
import sys

def solve(n, s):
    if n % 2 == 1:
        return None

    # collapse into maximal runs of equal characters
    a = []
    for i, ch in enumerate(s):
        if i and ch == s[i - 1]:
            a[-1] += 1
        else:
            a.append(1)

    m = len(a)
    B = n  # balance can never exceed n

    # layers[i][b] = balance b is reachable after deciding the first i blocks
    layers = [[False] * (B + 1) for _ in range(m + 1)]
    layers[0][0] = True

    for i in range(m):
        cur, nxt, w = layers[i], layers[i + 1], a[i]
        for b in range(B + 1):
            if not cur[b]:
                continue
            if b + w <= B:
                nxt[b + w] = True      # block i -> '('
            if b - w >= 0:
                nxt[b - w] = True      # block i -> ')'

    if not layers[m][0]:
        return None

    # walk backwards from balance 0
    parts = []
    b = 0
    for i in range(m - 1, -1, -1):
        w = a[i]
        if b - w >= 0 and layers[i][b - w]:
            parts.append('(' * w)      # came from b - w by opening
            b -= w
        else:
            parts.append(')' * w)      # so it must have been b + w
            b += w
    parts.reverse()
    return ''.join(parts)


def main():
    data = sys.stdin.buffer.read().split()
    t = int(data[0])
    idx = 1
    out = []
    for _ in range(t):
        n = int(data[idx]); idx += 1
        s = data[idx].decode(); idx += 1
        res = solve(n, s)
        out.append("NO" if res is None else "YES\n" + res)
    sys.stdout.write("\n".join(out) + "\n")

main()
```

Note the non-negativity check hides inside the array bounds. `b - w >= 0` is the guard that stops
a `)` block from taking the balance below zero, and because there simply is no cell for a negative
balance, the constraint enforces itself. That's a nice property of writing the reachable set as an
array indexed by balance — a whole class of invalid states becomes unrepresentable.

## Reconstruction is where I'd have lost the points

The natural instinct with a layered DP is to keep two rows and swap them, since the recurrence only
reaches back one layer. Do that here and you'll get the `YES`/`NO` right and then have nothing to
print. The problem asks for a witness, so **all** the layers have to survive — either the full
table, or a per-layer choice array.

Memory is not a concern: blocks $$\times$$ balances is $$2000 \times 2001$$ bits in the worst case,
and the sum of $$N$$ bound means only one test can be that big.

The backward walk is the part worth slowing down on. Going forward, block $$i$$ with symbol `(`
moves $$b_{\text{prev}} \to b_{\text{prev}} + a_i$$. So walking backward from balance $$b$$ at
layer $$i+1$$, that block was `(` exactly when $$b - a_i$$ was reachable at layer $$i$$. If it
wasn't, then $$b + a_i$$ must have been, because `layers[i+1][b]` got set by one of the two and
there are only two ways in. No third case to handle, no ambiguity to break — and when both are
reachable, either choice extends to a full solution, so taking the first is safe.

## Making it fast, for free

The inner loop is a shift in disguise. Hold each layer as a single Python integer used as a
bitmask, bit $$b$$ meaning "balance $$b$$ is reachable", and the whole layer transition becomes two
shifts and an `or`:

```python
mask = (1 << (B + 1)) - 1
layers = [0] * (m + 1)
layers[0] = 1
for i in range(m):
    layers[i + 1] = ((layers[i] << a[i]) | (layers[i] >> a[i])) & mask
```

`<< a[i]` is every `(` transition at once, `>> a[i]` is every `)` transition at once. The mask
drops anything above $$B$$, and negative balances need no handling at all — the right shift walks
them off the bottom end and they're gone. Feasibility is `layers[m] & 1`, and reconstruction is
the same walk with `(layers[i] >> (b - w)) & 1` in place of the array lookup.

Measured on the worst case I could build for the list version — $$N = 2000$$ with $$S =
\texttt{ababab}\ldots$$, so 2000 blocks of length 1 and no early exits anywhere:

| version | time | peak memory |
|---|---|---|
| list of lists | 0.099 s | 32.2 MB |
| integer bitmask | < 0.001 s | 0.37 MB |

Two orders of magnitude on time and nearly two on memory, for four lines of code. Python's big
integers are C-level bit operations, so a shift over a 2000-bit number is a handful of word
operations, while the list version pays interpreter overhead per cell. Neither version is anywhere
near the limit here, but the pattern — *a boolean reachability layer is a bitmask, and an
add-or-subtract transition is a shift* — generalises to every subset-sum-flavoured DP you'll meet,
and there it's often the difference between TLE and AC.

## What about greedy, though?

Given the title, I did go back afterwards and ask whether the DP is avoidable. It isn't, and it's
worth seeing why, because the plausible shortcuts are all wrong.

**The reachable set is not an interval of the right parity.** My first thought was to track only
the minimum and maximum reachable balance after each block and check whether $$0$$ falls in the
range with matching parity. That's false. Take $$a = [5, 1]$$, i.e. $$S = \texttt{aaaaab}$$: after
the first block only $$+5$$ survives, so the final balances are exactly $$\{4, 6\}$$. Not
$$\{0, 2, 4, 6\}$$, which is what a min/max-plus-parity argument would have predicted. The
reachable set genuinely has holes, and finding out whether $$0$$ is one of them is subset sum.

**And you can't drop the prefix condition either.** The other tempting reduction is "ignore
non-negativity, just ask whether the blocks split into two groups of equal sum" — a plain
partition problem. Also false. Take $$S = \texttt{abba}$$, blocks $$[1, 2, 1]$$: the signings
$$+,-,+$$ and $$-,+,-$$ both total zero, and both dip negative on the way — the first at
$$1 - 2 = -1$$, the second immediately at $$-1$$. The answer is `NO` even though the partition
exists. The prefix constraint is doing real work.

So the honest description of this problem is: *subset sum with a prefix constraint, over the run
lengths of the input*. Which is a DP. The name is a lie, or a joke.

## What I want to keep from this

**Read implications in the direction they're written.** "If $$S_i = S_{i+1}$$ then
$$T_i = T_{i+1}$$" is not "$$S_i = S_{i+1}$$ if and only if $$T_i = T_{i+1}$$". I invented a
constraint that wasn't there, and it cost me a dimension of state and a fair bit of confusion.
When a condition is one-directional, it's usually one-directional on purpose.

**Design state by asking what the future depends on.** Not "what have I decided so far" — that's
the transcript, and it's always too much — but "what's the smallest summary of my decisions that
determines everything from here". Here the answer is one integer.

**Collapse the input before designing the DP.** The run-length collapse is what turns a
per-character problem into a per-block one, and it takes four lines. It also *consumes the
constraint entirely*, which is why the leftover state was leftover. Whenever a rule says
"neighbours must agree", the first move is to merge the things forced to agree and re-read the
problem in terms of what's left.

**If the problem asks for a witness, keep the layers.** The rolling two-row optimisation is
reflexive for me and it silently destroys the ability to reconstruct. Decide which one you need
before you write the loop, not after the DP already works.

<div class="note-red" markdown="1">
**Monotone inside a group means you only check the boundaries.** The non-negativity condition is
a constraint on all $$N$$ prefixes, but the DP tests it at $$m \le N$$ block boundaries and that is
*exactly* equivalent, not an approximation — inside a block the balance is monotone, so its minimum
over the block is attained at one end or the other, and both ends are boundaries. This is a
reusable move. Any time a per-step constraint has to be checked but the steps come in groups that
move in one direction, the group endpoints carry all the information, and a transition that looked
$$O(\text{group size})$$ collapses to $$O(1)$$. Look for it whenever a DP's state is a running
quantity and its transitions are runs of identical updates.
</div>
