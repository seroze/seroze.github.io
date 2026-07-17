---
layout: post
title: "[Codeforces] Round 1103 (Div. 3) F2 — Elections in Saransk (Hard Version): Sum-minus-Max DP"
date: 2026-07-17 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, number_theory, dynamic_programming, codeforces]
author: "Seroze"
published: true
---

*[Codeforces Round 1103 (Div. 3) — Problem F2: Elections in Saransk (hard version)](https://codeforces.com/contest/2246/problem/F2). The hard version initially looked much more difficult than the [easy version]({% post_url 2026-07-10-elections-in-saransk %}), but after rewriting the condition in terms of prime exponents, the problem boils down to a surprisingly small DP.*

---

## Problem restatement

We need to count the number of arrays $$p$$ such that

- $$p_i \mid a_i$$,
- and

$$x \cdot \operatorname{lcm}(p_1, p_2, \ldots, p_n) = \prod_{i=1}^{n} p_i.$$

The important observation is that divisors are completely determined by the exponent chosen for each prime. Therefore, every prime can be processed independently, and the final answer is simply the product of the answers for each prime.

---

## Step 1: Look at a single prime

Fix one prime $$q$$.

Let

- $$k = v_q(x)$$,
- $$c_i = v_q(a_i)$$,
- $$e_i = v_q(p_i)$$.

Then

$$v_q(x \cdot \operatorname{lcm}) = k + \max(e_i),$$

while

$$v_q\left(\prod p_i\right) = \sum e_i.$$

Hence the condition becomes

$$k + \max(e_i) = \sum e_i,$$

or equivalently,

$$\boxed{\sum e_i - \max(e_i) = k.}$$

This equation is the only condition we have to satisfy.

---

## Easy version

For the easy version,

$$k = 0,$$

so

$$\sum e_i = \max(e_i).$$

This is only possible when exactly one person contributes this prime, which is exactly the observation behind the easy solution.

---

## First DP idea

Once I reached

$$\sum - \max = k,$$

my first instinct was to simulate the assignment of exponents.

A natural DP state is

```text
dp(i, mx, sum)
```

where

- `i` = voters processed,
- `mx` = maximum exponent chosen so far,
- `sum` = total exponent chosen so far.

Initially

```text
dp(0, 0, 0) = 1.
```

When processing the next voter, suppose we choose exponent `e`.

Since every exponent must satisfy

```text
0 <= e <= c_i,
```

the transition is simply

```text
dp(i+1,
   max(mx, e),
   sum + e)
```

After processing everyone, we accept only states satisfying

```text
sum - mx == k.
```

This DP is completely correct.

---

## Can we compress the state?

While implementing this DP, one thing stood out:

The answer never depends on the total sum itself.

It only depends on

$$\boxed{\sum - \max.}$$

Since

$$\sum = (\sum - \max) + \max,$$

the total sum can always be reconstructed if we know

- the current maximum,
- and the difference

$$s = \sum - \max.$$

So instead of storing

```text
(sum, mx)
```

we can store

```text
(mx, s)
```

where

```text
s = sum - mx.
```

This immediately cuts the state space almost in half.

Even better,

- $$mx \le 18$$,
- $$s \le k \le 18$$,

because exponents never exceed 18 for numbers up to $$5 \cdot 10^5$$.

So the DP only has

```text
19 × 19
```

states.

---

## Final DP

The state becomes

```text
dp(i, mx, s)
```

where

- `i` = processed voters,
- `mx` = current maximum exponent,
- `s = sum - mx`.

Initially,

```text
dp(0, 0, 0) = 1.
```

Now consider choosing exponent `e`.

There are two cases.

### Case 1: The maximum does not change

If

```text
e <= mx,
```

then

```text
newMx = mx
```

and only the total sum increases.

Therefore

```text
newS = (sum + e) - mx
     = s + e.
```

Transition:

```text
(mx, s)
    |
    | choose e <= mx
    |
(mx, s + e)
```

### Case 2: A new maximum appears

Suppose

```text
e > mx.
```

Now the new maximum becomes

```text
newMx = e.
```

The old total sum is

```text
sum = s + mx.
```

After choosing `e`,

```text
newSum = s + mx + e.
```

Therefore,

```text
newS
=
newSum - newMx
=
(s + mx + e) - e
=
s + mx.
```

Notice something beautiful:

**the new state does not depend on the value of `e` except for deciding that `e` becomes the new maximum.**

The transition is simply

```text
(mx, s)
    |
    | choose e > mx
    |
(e, s + mx)
```

This is much cleaner than updating the total sum directly.

---

## Complexity

For every prime,

- `mx` has only 19 values,
- `s` has only 19 values,
- each exponent ranges from 0 to 18.

The state space is therefore tiny:

```text
19 × 19
```

and transitions are also bounded by a small constant.

Since every number up to $$5 \cdot 10^5$$ contains only a few distinct prime factors, solving every prime independently is easily fast enough.

---

## Takeaway

The most satisfying part of this problem wasn't the DP — it was identifying the right quantity to track.

The original condition

$$k + \max = \sum$$

naturally suggests

$$\boxed{\sum - \max = k.}$$

Once this invariant is recognized, the original DP

```text
dp(i, mx, sum)
```

can be compressed into

```text
dp(i, mx, s)
```

where

```text
s = sum - mx.
```

The resulting transitions become simpler, the state space becomes smaller, and the entire solution feels much more natural.
