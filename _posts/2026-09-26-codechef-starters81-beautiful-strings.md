---
layout: post
title: "[CodeChef] Starters 81 — Beautiful Strings: the DP state I didn't need"
date: 2026-09-26 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, counting, new_pattern, combinatorics, dynamic_programming, python]
author: "Seroze"
published: true
---

Problem: [CodeChef — Beautiful Strings](https://www.codechef.com/problems/BSTRING) (Starters 81
Division 1). Official editorial: [BSTRING — Editorial](https://discuss.codechef.com/t/bstring-editorial/105534).

A binary string is *beautiful* if it contains as many `01` substrings as `10` substrings. Given
$$S$$, count its non-empty beautiful **subsequences** modulo $$10^9 + 7$$. Two subsequences are
different if the sets of kept indices differ, so `1` from index 1 and `1` from index 2 count twice.
$$N$$ goes up to $$10^6$$, and the sum of $$N$$ over all tests too.

I got this one wrong in two different ways before it fell apart in my hands, and the pattern at
the end is one I had genuinely never seen before — a two-dimensional DP that collapses into two
running integers. Worth writing down properly.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Two false starts

The first was a plain misread: I read the condition as counting `01` *subsequences* inside the
chosen subsequence, not `01` *substrings*. That makes the problem a different and much nastier
one. Read the word "substring" twice when the object you're choosing is itself a subsequence —
the two words are in the same sentence on purpose.

The second mistake is the interesting one. Once I had the condition right, I set up the obvious
DP. Walking a binary string left to right, the only thing that matters is where the bit changes:

- `0` followed by `1` is worth $$+1$$
- `1` followed by `0` is worth $$-1$$
- `00` and `11` are worth $$0$$

So "beautiful" means the net transition count of the chosen subsequence is zero, and the state
writes itself: let $$dp(i, j)$$ be the number of subsequences ending at index $$i$$ whose net
transition count is $$j$$. The transition is easy enough from the last kept character. The
problem is that $$j$$ ranges over roughly $$-N/2$$ to $$N/2$$, so the table is $$O(N^2)$$ and
$$N$$ is a million. Dead on arrival.

That's usually the moment to ask a different question, and it's the one I skipped: *do I actually
need the value of $$j$$, or only whether it is zero?*

## The invariant: only the first and last bit matter

Look at those $$+1$$ and $$-1$$ transitions again. They have to **alternate**. Once you go up
with a `01` you are sitting on a `1`, so the next change has to be a `10`, and vice versa. The
sequence of transitions in any binary string is therefore $$+1, -1, +1, -1, \ldots$$ or
$$-1, +1, -1, +1, \ldots$$ — never two of the same sign in a row.

An alternating $$\pm 1$$ sequence sums to zero exactly when it has even length, i.e. when it ends
with the opposite sign to the one it started with. The sign it starts with is decided by the first
character, and the sign it ends with is decided by the last. So a string starting at $$0$$ and
ending at $$0$$ must have gone up and come back down the same number of times; the same for
$$1 \ldots 1$$. Start at $$0$$ and end at $$1$$ and there is one extra `01` left over, and
$$1 \ldots 0$$ leaves one extra `10`. All four cases at once:

$$\text{cnt}_{01}(A) - \text{cnt}_{10}(A) = [\,A_{\text{last}} = 1\,] - [\,A_{\text{first}} = 1\,]$$

The editorial gets there a slightly different way — compress runs so that $$A$$ looks like
$$0101\ldots$$, then observe that a string starting with $$0$$ is balanced only if it also ends
with $$0$$ — but it's the same fact:

$$A \text{ is beautiful} \iff A_{\text{first}} = A_{\text{last}}$$

The whole $$j$$ dimension is gone. Not shrunk, not compressed — gone, because the condition never
depended on anything but two characters.

My own intuition landed here in stages: first "if the first and last char are the same then there
is a chance the net is zero", then the realisation that it isn't a chance, it's an equivalence.
The interior is completely unconstrained. `0110`, `00110100` and plain `00` are all beautiful,
and nothing about the middle can break it.

## Count by the two endpoints

Now the counting. My instinct was still to think recursively — find an earlier position with net
zero and extend it with a `010` or a `101` — and immediately I was worrying about double counting.
That worry is the signal that the parametrisation is wrong.

Every beautiful subsequence of length $$\ge 2$$ has exactly one first kept index and exactly one
last kept index, and those two indices carry equal bits. So index the count by that pair and
duplicates are impossible by construction. Fix $$i < j$$ with $$S_i = S_j$$. Nothing before $$i$$
or after $$j$$ can be kept — they'd become the new endpoints. Everything strictly between them is
free, because whatever you keep in the middle, the subsequence still begins and ends with the
same bit. There are $$j - i - 1$$ such positions, so this pair contributes

$$2^{\,j-i-1}$$

subsequences. Add the $$N$$ single-character subsequences, which are beautiful trivially and have
no second endpoint, and the answer is

$$\text{ans} = N + \sum_{\substack{i < j \\ S_i = S_j}} 2^{\,j-i-1}$$

Quick check on $$S = $$ `010`: the only matching pair is $$(0, 2)$$, contributing
$$2^{2-0-1} = 2$$, namely `00` and `010`. Plus three single characters gives 5. And `11111`
gives $$5 + \binom{5}{2}$$-worth of pairs summing to $$26$$, total $$31$$ — which has to be
right, since every one of the $$2^5 - 1$$ non-empty subsequences of an all-ones string is
beautiful.

## Making the sum $$O(N)$$

That formula is $$O(N^2)$$ as written. Fix the right endpoint $$j$$ and look at what the earlier
matching positions $$i_1, i_2, i_3, \ldots$$ contribute:

$$2^{\,j-i_1-1} + 2^{\,j-i_2-1} + 2^{\,j-i_3-1} = 2^{\,j-1}\left(2^{-i_1} + 2^{-i_2} + 2^{-i_3}\right)$$

The bracket doesn't mention $$j$$ at all. So keep two running sums,

$$P_b \;=\; \sum_{\substack{i \,<\, j \\ S_i \,=\, b}} 2^{-i}$$

one for $$b = 0$$ and one for $$b = 1$$. At position $$j$$, add $$2^{\,j-1} P_{S_j}$$ to the
answer, then fold $$2^{-j}$$ into $$P_{S_j}$$. One pass, $$O(N)$$.

Modulo a prime, $$2^{-1}$$ is just $$500000004$$, so the negative powers are a running product by
that constant and no explicit inverse is ever needed.

## Dropping the inverse powers entirely

There is a cleaner version, and it's the part I like most. The only reason the $$2^{-i}$$ show up
is that we factored out a $$j$$-dependent term and left the leftover behind. Instead, define the
accumulator *with* the factor already inside it:

$$A_b(j) \;=\; \sum_{\substack{i \,<\, j \\ S_i \,=\, b}} 2^{\,j-1-i}$$

This is exactly the contribution of a right endpoint at $$j$$ carrying bit $$b$$. Stepping
$$j \to j+1$$ multiplies every exponent by one more factor of two and admits index $$j$$ itself
as a new candidate:

$$A_b(j+1) \;=\; 2\,A_b(j) \;+\; [\,S_j = b\,]$$

Both accumulators double on every step; the one matching the current character also gains a
$$1$$. No powers, no inverses, no precomputation — two integers and a doubling. That recurrence
is the whole solution.

## The code

```python
import sys

MOD = 10**9 + 7

def main():
    data = sys.stdin.buffer.read().split()
    t = int(data[0])
    pos = 1
    out = []
    for _ in range(t):
        pos += 1                      # N is never needed
        s = data[pos]
        pos += 1

        ans = 0
        a0 = a1 = 0                   # a_b = sum of 2^(j-1-i) over earlier i with S[i] == b
        for ch in s:
            if ch == 48:              # ord('0'); iterating bytes gives ints
                ans += 1 + a0         # the single character, plus every pair ending here
                a0 = (a0 * 2 + 1) % MOD
                a1 = a1 * 2 % MOD
            else:
                ans += 1 + a1
                a0 = a0 * 2 % MOD
                a1 = (a1 * 2 + 1) % MOD
            ans %= MOD
        out.append(ans)

    sys.stdout.write('\n'.join(map(str, out)) + '\n')

main()
```

Two practical notes for Python here. With $$T$$ up to $$10^5$$, calling `input()` per line is
enough to lose on its own, so read the whole of stdin once and walk a token list. And iterating a
`bytes` object yields integers, which is why the comparison is against `48` rather than `'0'` —
it saves building a million one-character strings. On my machine both worst cases (one string of
length $$10^6$$, and $$10^5$$ strings of length $$10$$) run in about 0.23 s against a 1 s limit.

For the record, the version that came out of my own derivation, with the explicit $$2^{-i}$$:

```python
INV2 = (MOD + 1) // 2

ans = 0
sum0 = sum1 = 0
pow2 = 1          # 2^j
inv_pow2 = 1      # 2^(-j)

for c in s:
    ans += 1
    factor = pow2 * INV2 % MOD        # 2^(j-1)
    if c == '0':
        ans += factor * sum0
        sum0 = (sum0 + inv_pow2) % MOD
    else:
        ans += factor * sum1
        sum1 = (sum1 + inv_pow2) % MOD
    ans %= MOD
    pow2 = pow2 * 2 % MOD
    inv_pow2 = inv_pow2 * INV2 % MOD
```

It is the same algorithm and equally fast; the doubling accumulator is just less machinery to get
wrong. The setter's C++ solution is the inverse-powers one too.

## Checking it

Both versions agree with all four sample answers (`2`, `4`, `31`, `122`) and with a
bitmask brute force — enumerate every one of the $$2^n - 1$$ non-empty subsequences, count
adjacent `01` and `10` pairs, compare — over 400 random strings of length up to 13:

```python
def brute(s):
    n = len(s)
    total = 0
    for mask in range(1, 1 << n):
        t = [s[i] for i in range(n) if mask >> i & 1]
        c01 = sum(1 for a, b in zip(t, t[1:]) if a == '0' and b == '1')
        c10 = sum(1 for a, b in zip(t, t[1:]) if a == '1' and b == '0')
        total += (c01 == c10)
    return total % MOD
```

Writing the brute force is worth the two minutes even when you trust the derivation, because the
one thing a clean formula can silently get wrong is the off-by-one in the exponent, and `010`
versus `0110` catches that immediately.

<div class="note-red" markdown="1">
**What I'm taking away.** When a DP state is a running *count* and the answer only checks that
count against a single value, stop and look for a closed form for it. Here the net transition
count of a binary string depends on nothing but its first and last character, which turned an
$$O(N^2)$$ table into two accumulators. The second habit: when "extend a previous solution"
brings a duplicate-counting worry with it, re-parametrise instead of patching. Counting each
object by something it has exactly one of — here the pair (first index, last index) — makes
double counting impossible rather than merely handled.
</div>
