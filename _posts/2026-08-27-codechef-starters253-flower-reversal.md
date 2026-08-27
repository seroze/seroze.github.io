---
layout: post
title: "[CodeChef] Starters 253 — Flower Reversal: only the two boundaries move"
date: 2026-08-27 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, codechef, strings, greedy, ad_hoc, cp_cases]
author: "Seroze"
published: true
---

Problem: [CodeChef — Flower Reversal](https://www.codechef.com/problems/FLREV) (Starters 253, rated 1537)

You're given a binary string $$S$$ of length $$N$$. Its *beauty* is the number of adjacent equal
pairs — the count of $$i$$ with $$S_i = S_{i+1}$$. You may reverse at most one contiguous range
$$[L, R]$$, once. Maximise the beauty.

I got the easy half of this immediately and then spent far too long on the other half, so this
writeup is mostly about the part I got wrong.

## The part that's obvious

Reversing $$[L, R]$$ doesn't disturb anything strictly inside the range. If two positions were
adjacent inside the segment before, they're still adjacent after — the whole block just gets read
backwards. The only pairs that can possibly change are the two seams:

$$(L-1,\ L) \qquad\text{and}\qquad (R,\ R+1)$$

Two pairs, each worth at most one, so the beauty can go up by at most $$2$$. That much I had within a
minute.

I also had the $$+2$$ case. If you can find two `01` transitions, or two `10` transitions, you can
merge them:

```
0101  ->  reverse the middle two  ->  0011
```

Beauty goes from $$0$$ to $$2$$. So `seen_01 >= 2 or seen_10 >= 2` gives you $$+2$$.

## The part I flailed on

That leaves $$+1$$, and I went hunting for it the wrong way — by staring at short strings and trying
to collect the patterns that admit it. `010`, `101`, `0010`, `1101`, and so on. My submission ended
up checking whether the string *ended* in `10` while a `01` had been seen earlier, which is a
condition I basically pattern-matched into existence rather than derived. It's wrong:

```
0010
```

has beauty $$1$$, and reversing $$[2,3]$$ gives `0100` with beauty $$2$$. The winning reversal doesn't
touch the last character at all, so the check never fires.

The fix isn't more patterns. It's to write down what the seams actually do.

## Writing down the delta

Name the four characters that matter:

$$a = S_{L-1}, \quad b = S_L, \quad c = S_R, \quad d = S_{R+1}$$

After the reversal, position $$L$$ holds what used to be at $$R$$, and position $$R$$ holds what used
to be at $$L$$. So the two seams change from $$(a,b)$$ and $$(c,d)$$ into $$(a,c)$$ and $$(b,d)$$, and
the change in beauty is

$$\Delta = [a = c] + [b = d] - [a = b] - [c = d]$$

Now suppose the reversal is *internal*, meaning $$L > 1$$ and $$R < N$$ so both seams exist. There's
no point starting at a seam that's already a match — you can only lose there — so take both seams to
be transitions: $$a \ne b$$ and $$c \ne d$$. The last two terms vanish and we're left with

$$\Delta = [a = c] + [b = d]$$

Here's the thing that closes the problem. The alphabet is binary. Given $$a \ne b$$ and $$c \ne d$$,
knowing $$a = c$$ forces $$b = d$$, and knowing $$b = d$$ forces $$a = c$$. The two indicators are the
same indicator. So for an internal reversal

$$\Delta \in \{0, 2\}$$

and $$+1$$ is not merely hard to find, it is impossible. Every pattern I'd been collecting was a
prefix or suffix reversal in disguise.

## So where does +1 live

Only at the ends, where one of the seams doesn't exist.

Reverse a prefix, $$L = 1$$. The left seam is gone and only $$[b = d] - [c = d]$$ survives, where
$$b = S_1$$ is the first character of the whole string. Pick $$R$$ at a transition so $$[c = d] = 0$$,
and you gain exactly when the first character matches the character just past that transition.

Reverse a suffix, $$R = N$$. Symmetrically the gain is $$[a = c] - [a = b]$$ with $$c = S_N$$ the last
character, so you gain when the last character matches the character just before a transition.

That's the whole case analysis, and it's an $$O(N)$$ scan:

```python
gain = 0
if seen_01 >= 2 or seen_10 >= 2:
    gain = 2
else:
    for i in range(n - 1):
        if s[i] == s[i + 1]:
            continue
        if s[0] == s[i + 1]:   # reverse the prefix ending at this transition
            gain = 1
        if s[-1] == s[i]:      # reverse the suffix starting after it
            gain = 1
```

Take `0010` again: the transition is at $$i = 2$$, and `s[0] == s[3] == '0'`, so the prefix branch
catches it. Good.

## The submitted solution

```python
import sys

def solve(n, s):
    if n == 1:
        return 0

    ans = sum(1 for i in range(n - 1) if s[i] == s[i + 1])
    seen_01 = sum(1 for i in range(n - 1) if s[i:i+2] == '01')
    seen_10 = sum(1 for i in range(n - 1) if s[i:i+2] == '10')

    gain = 0
    if seen_01 >= 2 or seen_10 >= 2:
        gain = 2
    else:
        for i in range(n - 1):
            if s[i] == s[i + 1]:
                continue
            if s[0] == s[i + 1]:
                gain = 1
            if s[-1] == s[i]:
                gain = 1

    return ans + gain

def main():
    data = sys.stdin.buffer.read().split()
    t = int(data[0])
    out = []
    for i in range(t):
        n = int(data[1 + 2*i])
        s = data[2 + 2*i].decode()
        out.append(solve(n, s))
    sys.stdout.write("\n".join(map(str, out)) + "\n")

main()
```

Accepted, `0.01`s on the samples. Sum of $$N$$ is $$2 \times 10^5$$, so three linear passes is nothing.

## It collapses much further than that

Once the analysis was done I noticed the answer barely depends on the string at all. Let $$k$$ be the
number of transitions — positions where $$S_i \ne S_{i+1}$$. Every adjacent pair is either a match or
a transition, so

$$\text{beauty} = (N - 1) - k$$

and maximising beauty is just minimising transitions. Now, transition types must alternate: after a
`01` you're inside a block of ones, so the next transition has to be `10`. That means two transitions
of the same type exist **exactly when $$k \ge 3$$**.

And the $$+1$$ case falls out too. If $$k = 2$$ the string looks like $$x^p \bar{x}^q x^r$$, so the
last character equals the first, and the prefix condition fires on the second transition — always. If
$$k = 1$$ the two ends disagree and neither end condition can fire. So the entire gain is a function
of $$k$$ alone:

$$\text{answer} = (N - 1) - k + \begin{cases} 2 & k \ge 3 \\ 1 & k = 2 \\ 0 & k \le 1 \end{cases}$$

which is a two-line solution:

```python
k = sum(1 for i in range(n - 1) if s[i] != s[i + 1])
print((n - 1) - k + (2 if k >= 3 else (1 if k == 2 else 0)))
```

I don't regret submitting the longer one — I had it working and the clock was running — but it's a
reminder that the case analysis was doing work the counting argument does for free.

## Checking it

Both versions went through a brute force that tries every $$(L, R)$$ pair on every binary string of
length $$1$$ through $$14$$ — about $$32{,}000$$ strings — and they agree with it everywhere. That's
cheap to write and it's the only reason I trust the $$\Delta \in \{0,2\}$$ claim enough to publish it.

## The takeaway

When an operation is expensive to reason about, don't enumerate the patterns it produces. Ask which
parts of the structure the operation can even touch, write the delta as a formula over just those
parts, and let the algebra tell you which outcomes are reachable. Here the formula had four
indicators, two of them cancelled by construction and the other two turned out to be the same
indicator — and that single observation killed a whole afternoon's worth of pattern-hunting.
