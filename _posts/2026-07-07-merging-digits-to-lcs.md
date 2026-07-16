---
layout: post
title: "[Codeforces] Edu Round 192 D — From Merging Digits to Longest Common Subsequence"
date: 2026-07-07 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, dynamic_programming, lcs, codeforces]
author: "Seroze"
published: true
---

I recently solved a Codeforces problem that taught me one of the cleanest "change your perspective" tricks I've seen in a while.

At first glance, the problem looks like a simulation problem.

---

## Problem

We are given two strings `a` and `b`, consisting only of digits.

In one operation, we choose **two adjacent digits** and replace them with their **sum modulo 10**.

For example,

```text
57246
```

can become

```text
2246
5946
5766
5720
```

because

```text
5+7 = 12 -> 2
7+2 = 9
2+4 = 6
4+6 = 10 -> 0
```

Each operation reduces the string length by one.

We may perform any number of operations on either string.

The goal is to find the **maximum possible length** of the final strings after making them equal.

---

## Observation 1: A Necessary Condition

Consider collapsing an entire string into a single digit.

No matter how we merge adjacent digits,

```text
final digit = (sum of all digits) mod 10
```

Therefore,

```text
sum(a) % 10 == sum(b) % 10
```

is a necessary condition.

If this fails, the answer is immediately `-1`.

---

## Observation 2: Forget the Operations

Instead of thinking about individual merge operations, think about what they achieve.

Suppose we have

```text
1234567
```

If we repeatedly merge only within

```text
[123][45][67]
```

then eventually we obtain

```text
(sum(123)%10)(sum(45)%10)(sum(67)%10)
```

The exact order of merges doesn't matter.

Each final digit is simply the sum of one **contiguous block** modulo `10`.

This completely changes the problem.

Instead of performing operations, we only need to decide **how to partition each string into contiguous blocks**.

---

## Observation 3: Corresponding Blocks Must Match

Suppose

```text
a = [A₁][A₂][A₃]...
b = [B₁][B₂][B₃]...
```

Then every corresponding block must satisfy

```text
sum(Aᵢ) % 10 = sum(Bᵢ) % 10
```

The answer we want is simply the **maximum number of blocks**.

Why?

Because every block becomes exactly one digit in the resulting string.

So

```text
number of blocks = length of final string.
```

---

## Observation 4: Add the Equations

Suppose

```text
sum(A₁)%10 = sum(B₁)%10
sum(A₂)%10 = sum(B₂)%10
```

Adding them,

```text
(sum(A₁)+sum(A₂))%10
=
(sum(B₁)+sum(B₂))%10
```

Continuing this,

we get

```text
prefix_block_sum_a(k)%10
=
prefix_block_sum_b(k)%10
```

for every block boundary.

This is the key insight.

Every block boundary corresponds to a **prefix sum modulo 10**.

---

## Observation 5: Prefix Sums of the Original Strings

Now compute prefix sums modulo `10`.

For example,

```text
a : 1 2 3 4
prefix : 0 1 3 6 0
```

and similarly for `b`.

Whenever the same modulo appears in both prefix sequences,

it can represent the end of a corresponding block.

Therefore, the problem becomes:

> Find the largest sequence of matching prefix-sum modulo values while preserving order.

That is exactly the **Longest Common Subsequence (LCS)** problem.

---

## Final Algorithm

1. Check whether the total digit sums modulo `10` are equal.

   * If not, answer `-1`.

2. Compute prefix sums modulo `10` for both strings.

   * Include the initial prefix sum `0`.

3. Compute the **Longest Common Subsequence** of the two prefix-sum sequences.

4. Subtract `1` from the LCS length because the initial `0` represents the starting boundary, not an actual block.

Overall complexity:

* **Time:** `O(|a| × |b|)`
* **Space:** `O(|b|)` using the standard rolling-array optimization for LCS.

---

## Takeaway

This problem is a perfect example of how changing the abstraction can completely simplify a problem.

Initially, it looks like a complicated sequence of merge operations.

But after identifying the right invariant, the operations disappear entirely.

The problem becomes:

* Partition into contiguous blocks.
* Convert blocks into prefix-sum constraints.
* Solve an LCS.

Those are the kinds of insights that make competitive programming so rewarding.

---

# Bonus: Understanding the LCS Recurrence

Since the solution reduces to LCS, it's worth pausing on the recurrence itself. Most of us memorize it:

```python
if a[i-1] == b[j-1]:
    dp[i][j] = dp[i-1][j-1] + 1
else:
    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
```

But a natural question arises:

> **When the last characters match, why don't we write**
>
> ```python
> dp[i][j] = max(dp[i-1][j-1] + 1,
>                dp[i-1][j],
>                dp[i][j-1])
> ```
>
> **Just to be safe?**

Let's build the recurrence from first principles.

## Step 1: Define the DP state

Let

```text
dp[i][j]
```

represent the length of the Longest Common Subsequence between

```text
a[0...i-1]
b[0...j-1]
```

Notice that these are **prefixes** of the original strings.

Importantly, the LCS **does not have to include** the last character of either prefix.

## Case 1: Last characters are different

Suppose we are computing

```text
dp[i][j]
```

and

```text
a[i-1] != b[j-1]
```

The last two characters cannot both belong to the same common subsequence.

So at least one of them must be discarded.

There are only two possibilities:

* Ignore `a[i-1]`
* Ignore `b[j-1]`

Therefore,

```python
dp[i][j] = max(dp[i-1][j], dp[i][j-1])
```

This part is usually intuitive.

## Case 2: Last characters are equal

Now suppose

```text
a[i-1] == b[j-1]
```

At first glance, it feels safer to write

```python
dp[i][j] = max(dp[i-1][j-1] + 1,
               dp[i-1][j],
               dp[i][j-1])
```

Why is that unnecessary?

The answer lies in an elegant observation.

## The Key Lemma

> **If the last characters are equal, then there always exists an optimal LCS that matches these two characters.**

This is the crucial insight.

### Why?

Suppose the common character is `x`.

There are two possibilities.

### Case A

The optimal LCS already uses these last two `x`s.

Great—we're done.

### Case B

The optimal LCS matches an earlier occurrence of `x`.

For example,

```text
a = A x C D x
b = B x D E x
```

Maybe the LCS matched the **first** `x`.

But notice something:

Everything that appears before the first `x` also appears before the last `x`.

So we can simply replace the earlier matched `x` with the later one.

The order of the subsequence is preserved.

The length does not change.

In other words, we can always "shift" the match to the last occurrence.

This is a classic **exchange argument**.

Therefore, there is always an optimal solution that ends by matching

```text
a[i-1]
b[j-1]
```

## Finishing the recurrence

Once we've matched the last characters,

we remove them from both strings.

What's left?

Exactly the LCS of

```text
a[0...i-2]
b[0...j-2]
```

whose length is

```text
dp[i-1][j-1]
```

Therefore,

```python
dp[i][j] = dp[i-1][j-1] + 1
```

## But what if `dp[i-1][j]` is larger?

This is the part that often feels mysterious.

Suppose

```text
a[i-1] == b[j-1]
```

Could

```text
dp[i-1][j]
```

actually be larger?

The answer is **no**.

Why?

Adding one extra character to a string can increase the LCS by **at most one**.

So,

```text
dp[i-1][j]
≤ dp[i-1][j-1] + 1
```

Similarly,

```text
dp[i][j-1]
≤ dp[i-1][j-1] + 1
```

But

```text
dp[i-1][j-1] + 1
```

is exactly the value we compute when the last characters match.

Therefore,

```text
dp[i-1][j]
≤ dp[i][j]

dp[i][j-1]
≤ dp[i][j]
```

Neither of the other two transitions can produce a better answer.

Taking the maximum is unnecessary.

## Intuition

I like to think about it this way:

```text
........A
........A
```

When the last characters are equal, you've been handed a **free match**.

Ignoring it can never help.

Even if an optimal solution used an earlier occurrence of `A`, you can always move that match to the last `A` without breaking the order of the subsequence.

So matching the last equal characters is never a mistake—it is always part of some optimal solution.

## Final Recurrence

```python
if a[i-1] == b[j-1]:
    dp[i][j] = dp[i-1][j-1] + 1
else:
    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
```

This recurrence is not just something to memorize.

It follows from two ideas:

1. If the last characters differ, one of them must be discarded.
2. If the last characters are equal, there always exists an optimal solution that matches them.

Once you understand these two observations, the LCS recurrence becomes something you can derive rather than remember.
