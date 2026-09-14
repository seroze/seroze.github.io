---
layout: post
title: "[CodeChef] Starters 88 — Minimize the Bits: the one I couldn't solve"
date: 2026-09-14 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, greedy, bit_manipulation, python, TODO]
author: "Seroze"
published: true
---

Problem: [CodeChef — Minimize the Bits](https://www.codechef.com/problems/MINBITS) (Starters 88,
difficulty 2594). Official editorial:
[MINBITS editorial](https://discuss.codechef.com/t/minbits-editorial) — as usual the link from the
problem page 404s, but the discuss thread is alive.

I did not solve this one. I want to write it up anyway, because I got to within one sentence of the
right algorithm and then stopped, and the sentence I was missing is the kind of thing I'd like to
recognise faster next time. The gap between my greedy and the correct greedy is about four lines of
code and one idea.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

You're given a binary string $$A$$ of length $$N$$ — possibly a gigantic number, up to $$10^5$$
bits. Find two binary strings $$B$$ and $$C$$, **each also of length exactly $$N$$**, such that

$$(A)_{10} = (B)_{10} - (C)_{10}$$

and the total number of 1s across $$B$$ and $$C$$ is as small as possible. Any optimal pair is
accepted. The sum of $$N$$ over all test cases is at most $$5 \cdot 10^5$$, so the intended
solution is linear.

Stripped of the string dressing, the question is: *write $$A$$ as a sum of as few powers of two as
possible, where you're allowed to subtract as well as add* — the added ones go into $$B$$, the
subtracted ones into $$C$$. The length restriction matters: you may not use $$2^N$$ or anything
above it, because $$B$$ has only $$N$$ bits.

Throughout the rest of this post I'll talk about the strings **reversed and 0-indexed**, so that
position $$i$$ means the coefficient of $$2^i$$. That's how the editorial does it too, and it makes
"scan from the low bits upward" mean "scan left to right". In the actual implementation you reverse
$$A$$ on the way in and reverse $$B$$ and $$C$$ on the way out.

## The identity I did find

Without subtraction the answer is forced: you just take the bits of $$A$$, and the cost is
$$\operatorname{popcount}(A)$$. So the only question is how much subtraction buys you, and the one
thing it buys you is collapsing a *block* of consecutive ones. A run of ones from position $$x$$ up
to position $$y$$ is

$$2^x + 2^{x+1} + \cdots + 2^y = 2^{y+1} - 2^x,$$

which turns $$y - x + 1$$ ones into exactly two. Worth doing whenever the run has length at least 2,
pointless when $$x = y$$ since that would turn one 1 into two.

I found this part on my own, and I found it quickly. On the sample I was staring at,

```
A = 1101110111
B = 1110000000
C = 0000001001
```

which checks out: $$896 - 9 = 887$$, and the cost is $$3 + 2 = 5$$ ones instead of the naive 8.

So far so good. Where it went wrong is what I did with the identity.

## My greedy, and why it's wrong

What I wrote was: walk the runs of ones **in $$A$$**, and for each run of length $$\ge 2$$ spanning
$$[L, R]$$, set $$B_{R+1} = 1$$ and $$C_L = 1$$. One pass over the original string, each run handled
independently, done.

This is wrong, and the reason is the thing I want to remember. Setting $$B_{R+1} = 1$$ *creates a
new one bit*, and that new bit can be adjacent to the next run — which means the two runs merge into
a longer run that could have been collapsed together. By processing the runs of the original $$A$$
independently I never see the merge.

The smallest example is six bits. Take the number $$27$$, which is $$A = \texttt{011011}$$, or
$$\texttt{110110}$$ in the reversed view I'm using:

```
position:  0 1 2 3 4 5
reversed:  1 1 0 1 1 0
```

There are two runs, $$[0,1]$$ and $$[3,4]$$. My algorithm handles each one where it sits:

$$B = \texttt{001001}, \qquad C = \texttt{100100}$$

for a cost of 4. But if you process the low run first and then *re-read what you just wrote*, the
new bit at position 2 sits right on top of the run at $$[3,4]$$:

```
start:   B = 110110   C = 000000
step 1:  B = 001110   C = 100000     (collapse [0,1], write B_2 = 1)
step 2:  B = 000001   C = 101000     (collapse [2,4], write B_5 = 1)
```

Cost 3. The new bit at position 2 was not in $$A$$ at all; it only exists because of the first
collapse, and it's what makes the second, bigger collapse possible. My version was looking at a
snapshot of the input while the real state of the world was $$B$$, which changes as you go.

That's also why the scan direction is not a detail. Low-to-high works because every bit you create
lands *ahead* of where you are, so you'll walk into it later. High-to-low creates bits behind you
and you never come back for them.

## A detour that cost me an hour

Before the wrong answer I had a runtime error — SIGHUP on CodeChef, an `IndexError` locally — and I
spent a while convinced the indexing in my run-walking loop was off by one. It wasn't. I'd pasted
the sample into a local file with a trailing space after the binary string, so `input()` handed me
an 11-character string while $$N$$ said 10, and every index derived from the run lengths ran one
past the end of my output buffer.

The fix is `a = input().strip()`, which I now just write by default. The lesson isn't really about
whitespace though — it's that I let a crash pull my attention onto the loop bounds for an hour when
the actual defect was in the algorithm, one level up. The crash and the bug had nothing to do with
each other.

## The correct greedy

Same identity, applied to the evolving string instead of the input:

1. Reverse $$A$$. Start with $$B = A$$ and $$C$$ all zeros.
2. Scan $$i$$ from low to high. When you hit a maximal run of ones in **$$B$$** spanning $$[L, R]$$,
   and $$R > L$$, set $$C_L = 1$$, zero out $$B_L \ldots B_R$$, and set $$B_{R+1} = 1$$.
3. Continue the scan from $$R+1$$ — the bit you just wrote is the next thing you look at, so it gets
   a chance to join the run above it.

Runs of length 1 are skipped. Every position is visited a constant number of times, so this is
$$O(N)$$.

## The one edge case: a run at the very top

Collapsing $$[L, R]$$ needs position $$R+1$$ to exist. If the run of ones runs all the way to
position $$N-1$$ — that is, if $$A$$ *starts* with a block of ones in normal reading order — there's
no bit above it to borrow, and the identity is unavailable. Those ones have no alternative
representation: they must be set in $$B$$ and clear in $$C$$.

The clean way to handle it, and what the editorial does, is to chop that top block off before you
start, solve the remaining prefix with no special cases at all, then paste the block back onto
$$B$$ (and the matching zeros onto $$C$$) at the end. Much nicer than checking `R + 1 < N` inside
the loop, and it also guarantees the shortened string ends in a zero, so `B[j] = 1` is always in
bounds.

## Code

```python
import sys

def solve(n, a):
    s = list(a[::-1])              # s[i] is the coefficient of 2^i
    suf = 0
    while s and s[-1] == '1':      # leading ones of A: nothing above to borrow from
        s.pop()
        suf += 1
    m = n - suf

    b = s[:]
    c = ['0'] * m
    i = 0
    while i < m:
        if b[i] == '0':
            i += 1
            continue
        j = i
        while j < m and b[j] == '1':
            j += 1
        if j - i > 1:              # 2^i + ... + 2^(j-1) == 2^j - 2^i
            c[i] = '1'
            for k in range(i, j):
                b[k] = '0'
            b[j] = '1'
        i = j                      # resume at the bit we just wrote

    b = ''.join(b) + '1' * suf
    c = ''.join(c) + '0' * suf
    return b[::-1], c[::-1]

def main():
    data = sys.stdin.buffer.read().split()
    t = int(data[0])
    out = []
    idx = 1
    for _ in range(t):
        n = int(data[idx]); a = data[idx + 1].decode(); idx += 2
        B, C = solve(n, a)
        out.append(B)
        out.append(C)
    sys.stdout.write('\n'.join(out) + '\n')

main()
```

I ran this against a brute force over all $$B, C$$ pairs for every $$A$$ with $$N \le 8$$ and it
matches the optimal count everywhere. On the sample it produces the `1110000000` / `0000001001`
pair from earlier.

## What I'm taking away

Two things.

The first is the specific pattern: when a greedy *writes into the same structure it's reading*, the
scan order stops being a stylistic choice and becomes part of the algorithm. My instinct was to
precompute the runs of $$A$$ and loop over them, which felt tidier, and tidiness is exactly what
threw away the cascade. If a step can create new work, iterate over the live state, not a snapshot.

The second is about debugging altitude. I had a crash and a wrong algorithm at the same time, and I
let the crash decide what I thought about for an hour. Fixing the crash told me nothing, because it
was a stray space in my own test file. Worth asking early: if this crash were fixed right now, would
I believe the answer?

## TODO

- Re-solve this from a blank file without looking, and see whether the low-to-high argument comes to
  me on its own this time.
- Look for other problems where the fix is "iterate over the mutating state, not the input" — I
  suspect this is a small recurring family and I only have one example of it.
