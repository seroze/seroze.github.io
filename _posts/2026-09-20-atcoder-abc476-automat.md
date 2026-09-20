---
layout: post
title: "[AtCoder] ABC 476 D — Automat: equal money, unequal wallets"
date: 2026-09-20 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, atcoder, greedy, prefix_sums, two_pointers, python]
author: "Seroze"
published: true
---

Problem: [AtCoder ABC 476 D — Automat](https://atcoder.jp/contests/abc476/tasks/abc476_d)
(JIJ Programming Contest 2026, ABC 476). Official editorial:
[English editorial for D](https://atcoder.jp/contests/abc476/editorial/25812).

I wrote a greedy for this one. Buy things cheapest-first, keep the wallet updated as you go, count
what you managed to afford. It felt obviously correct, which in hindsight is the tell — the whole
difficulty of this problem is hiding in the phrase "keep the wallet updated", because the wallet
here has two denominations and they are *not* interchangeable. Two wallets holding the same number
of dollars can buy different sets of items.

This is a writeup of how I got there: the two separate bugs in my greedy, why the second one is
unfixable rather than just wrong, and the reframe that makes the problem fall over.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The problem

You arrive at an automated cafeteria carrying $$X$$ one-dollar bills and $$Y$$ $$K$$-dollar bills.
There are two vending machines:

- the **dessert** machine sells $$N$$ desserts, dessert $$i$$ costing $$A_i$$, and accepts both
  one-dollar and $$K$$-dollar bills;
- the **drink** machine sells $$M$$ drinks, drink $$j$$ costing $$B_j$$, and accepts **only**
  $$K$$-dollar bills.

Both machines give change exclusively in one-dollar bills, and you can buy each product at most
once. Maximise the number of products you buy.

Constraints: $$N, M \le 2 \cdot 10^5$$, $$2 \le K \le 10^9$$, $$X \le 10^{15}$$, $$Y \le 10^9$$,
and prices up to $$10^9$$.

So the drink machine is the picky one. To buy a drink costing $$B_j$$ you must insert

$$\left\lceil \frac{B_j}{K} \right\rceil$$

$$K$$-dollar bills — nothing else is accepted — and you get the overpayment back as ones.

## My first attempt: cheapest first

Merge desserts and drinks into one list, sort by price, and walk it paying for whatever you can
afford:

```python
import math

n, m, k = map(int, input().split())
x, y = map(int, input().split())
a = list(map(int, input().split()))
b = list(map(int, input().split()))

items = [[cost, 0] for cost in a] + [[cost, 1] for cost in b]
items.sort()

cnt = 0
for cost, kind in items:
    if x + y * k < cost:
        break                       # can't afford anything from here on

    if kind == 0:                   # dessert: spend ones first, then K-bills
        if x >= cost:
            x -= cost
            cnt += 1
        else:
            cost -= x
            x = 0
            k_dollars = math.ceil(cost / k)
            one_dollars = math.ceil(cost / k) * k - math.floor(cost / k) * k
            y -= k_dollars
            x = one_dollars
            cnt += 1
    else:                           # drink: K-bills only
        k_dollars = math.ceil(cost / k)
        if y < k_dollars:
            continue
        one_dollars = math.ceil(cost / k) * k - math.floor(cost / k) * k
        y -= k_dollars
        x += one_dollars
        cnt += 1

print(cnt)
```

Two things are wrong with this. One is an arithmetic slip I could have fixed in place. The other is
the reason the whole shape of the approach can't work.

## Bug one: that change formula invents money

Look closely at

```python
one_dollars = math.ceil(cost / k) * k - math.floor(cost / k) * k
```

If $$\lceil c/K \rceil$$ and $$\lfloor c/K \rfloor$$ are equal — that is, when $$K$$ divides $$c$$ —
this is 0. Otherwise the ceiling is exactly one more than the floor, so the expression is $$K$$. It
has nothing to do with $$c$$ beyond "is it a multiple of $$K$$":

$$\text{one\_dollars} = \begin{cases} 0 & K \mid c \\ K & \text{otherwise.} \end{cases}$$

With $$c = 5$$ and $$K = 3$$ it hands back $$3$$. But paying $$6$$ for a $$5$$ item gets you $$1$$
in change, not $$3$$. The change you actually receive is the overpayment,

$$K \left\lceil \frac{c}{K} \right\rceil - c \;=\; (-c) \bmod K,$$

which in Python is just `(-cost) % k`, or the more legible `(k - cost % k) % k`.

The direction of this error matters. The buggy formula always returns at least as much as the true
change, so the simulation quietly *gains* money out of nowhere, and can report more items than the
optimum rather than fewer. Concretely, with

$$K = 7, \quad X = 2, \quad Y = 2, \quad A = [15, 4, 14, 10], \quad B = [4, 12],$$

total wealth is $$2 + 2 \cdot 7 = 16$$ dollars, and the buggy greedy prints 3 — it buys the $$4$$
dessert, the $$4$$ drink and the $$10$$ dessert, spending $$18$$ dollars it never had. The true
answer is 2.

That's an easy fix. The next one isn't.

## Bug two: price order is the wrong order

The real problem is the sort. Walking items cheapest-first assumes something like

> if I can afford this item now, buying it can't hurt me later,

which is true when money is fungible. Spend $$4$$ out of $$10$$ and you have $$6$$; there is nothing
else to say about your position. Here there *is* something else to say, because these two wallets

$$(X, Y) = (10, 0) \qquad \text{and} \qquad (X, Y) = (0, 2), \quad K = 5$$

both hold ten dollars and cannot buy the same things. The second one can buy a drink; the first one
can't buy a single drink at any price.

So the state isn't a number, it's a pair, and a purchase changes the pair's *composition* as well as
its total. Here's the smallest counterexample I found by brute force:

$$K = 6, \quad X = 7, \quad Y = 3, \quad A = [11], \quad B = [13].$$

The greedy sees the $$11$$ dessert first. It has $$7$$ ones, needs $$4$$ more, so it breaks a
$$K$$-bill: pays $$7 + 6 = 13$$, gets $$2$$ back. Wallet is now $$(2, 2)$$, worth $$14$$ dollars —
plenty in absolute terms, but the $$13$$ drink needs $$\lceil 13/6 \rceil = 3$$ $$K$$-bills and only
two are left. One item.

Do it in the other order and the drink goes first: three $$K$$-bills pay $$18$$, change is $$5$$,
wallet becomes $$(12, 0)$$, and $$12 \ge 11$$ buys the dessert. Two items.

Nothing about "cheapest first" is salvageable here, and neither is "most expensive first" — the
ordering that matters isn't about price at all. It's that **desserts can consume $$K$$-bills and
drinks can't**, so every $$K$$-bill a dessert eats is a drink you may have just given up. Sorting by
price can't see that.

## Drinks are denomination converters

The framing that unlocked it for me: a drink purchase is not only a purchase, it's a currency
exchange.

$$\left\lceil B_j / K \right\rceil \; K\text{-bills}
\;\longrightarrow\;
\text{drink } j \;+\; \big((-B_j) \bmod K\big) \text{ ones}$$

$$K$$-bills flow one way only. No machine ever gives you one back, so $$Y$$ is a strictly depleting
resource and drinks are the only thing that competes for it. Desserts don't need $$K$$-bills, they
merely *accept* them, which is precisely how my greedy managed to spend a scarce resource on the one
thing that didn't need it.

Two consequences drop out immediately:

**Buy all your drinks first.** Drinks only consume $$K$$-bills and desserts can only destroy them,
so doing every drink up front maximises the $$K$$-bills available for drinks, and costs the desserts
nothing (they care about total value, see below).

**A dessert only cares about total value.** If your wallet holds $$V$$ dollars in any mix of
denominations and $$V \ge A_i$$, you can buy dessert $$i$$: shove every bill you own into the
machine and take $$V - A_i$$ back in ones. Which means that once the drinks are done, the wallet's
composition stops mattering entirely.

## What a feasible set looks like

Put those together and a set of products is buyable if and only if two conditions hold, with no
mention of order or wallet state at all:

1. the total price is at most $$X + KY$$, your entire wealth;
2. the $$K$$-bills the chosen drinks demand, $$\sum_j \lceil B_j / K \rceil$$, is at most $$Y$$.

Necessity is clear: you can't spend more than you have, and drinks accept nothing but $$K$$-bills.
Sufficiency is the drinks-first schedule from the previous section — do the drinks in any order
(every prefix is affordable since the total demand fits in $$Y$$), then the desserts cheapest-first,
each time inserting the whole wallet.

One nice detail: condition 2 implies half of condition 1. The $$K$$-bills spent on drinks cover at
least their prices,

$$\sum_j B_j \;\le\; \sum_j K \left\lceil \frac{B_j}{K} \right\rceil \;\le\; KY \;\le\; X + KY,$$

so a drink selection that passes the bill test is never unaffordable on its own. Only the desserts
can push you over the total.

I checked this characterisation against a genuine wallet simulation — a search over every purchase
order and every way of stuffing bills into a machine — on a few hundred tiny random cases, and they
agree. Worth doing, because the entire solution rests on it.

## The algorithm

With feasibility reduced to two numeric tests, sort both price lists and enumerate the one thing
that couples them: how many drinks you buy.

For a fixed count $$i$$, take the $$i$$ **cheapest** drinks. This is an exchange argument: sorted
ascending, the cheapest $$i$$ are element-wise no more expensive than any other $$i$$, so they cost
no more in total, and since $$\lceil \cdot / K \rceil$$ is non-decreasing they demand no more
$$K$$-bills either. Dominant on both constraints, so never worse.

Then the desserts don't interact with $$Y$$ at all — you just want as many as possible under the
money that's left,

$$\text{remaining} = X + KY - \sum_{j < i} B_j,$$

and for a fixed count the cheapest desserts are again optimal. So find the largest $$j$$ with
$$\text{pa}[j] \le \text{remaining}$$, where $$\text{pa}$$ is the prefix-sum array of sorted dessert
prices, and the answer is the best $$i + j$$ over all $$i$$.

Since `remaining` only shrinks as $$i$$ grows, $$j$$ only moves left — one backwards pointer,
amortised $$O(N + M)$$ after the sort. Binary search per $$i$$ is fine too.

## The off-by-one that cost me a sample

My second attempt implemented exactly that, and printed this on the samples:

```
sample 1 -> 4    (expected 4)
sample 2 -> 0    (expected 1)
sample 3 -> 22   (expected 22)
```

Sample 2 is the giveaway:

```
1 7 67
677677677766666 0
777666777
20 12 24 67 67 67 67
```

$$Y = 0$$, so not a single drink is buyable — but $$X$$ is enormous and the lone dessert costs a
piddling $$777{,}666{,}777$$. The answer is 1.

My enumeration lived entirely inside the loop over drinks:

```python
for i, price in enumerate(b, 1):
    need += math.ceil(price / k)
    if need > y:
        break
    ...
    ans = max(ans, i + last_pointer + 1)
```

With `enumerate(b, 1)` the smallest $$i$$ I ever consider is 1, and here the very first iteration
breaks — so `ans` was never assigned at all. The search space I needed was $$i \in [0, M]$$ and the
one I wrote was $$i \in [1, M]$$.

This is the mistake I'd most like to remember, because it isn't really about this problem. When you
solve something by enumerating a parameter, **the zero case is a value of the parameter, not an edge
case**, and a loop that can `break` on its first iteration will silently skip it. The fix is to
settle $$i = 0$$ before the loop starts, which also initialises the pointer the loop wants:

```python
j = n
while j > 0 and pa[j] > total:
    j -= 1
ans = j          # buy no drinks at all
```

## The solution

```python
import sys

def main():
    data = sys.stdin.buffer.read().split()
    p = 0
    n, m, k = int(data[p]), int(data[p + 1]), int(data[p + 2]); p += 3
    x, y = int(data[p]), int(data[p + 1]); p += 2
    a = sorted(map(int, data[p:p + n])); p += n
    b = sorted(map(int, data[p:p + m])); p += m

    total = x + y * k

    pa = [0] * (n + 1)                  # pa[j] = cost of the j cheapest desserts
    for i, price in enumerate(a, 1):
        pa[i] = pa[i - 1] + price

    j = n                               # i = 0: no drinks, all the money for desserts
    while j > 0 and pa[j] > total:
        j -= 1
    ans = j

    need = 0                            # K-bills the chosen drinks demand
    spent = 0                           # their total price
    for i, price in enumerate(b, 1):
        need += -(-price // k)
        if need > y:                    # need only grows, so nothing later fits either
            break
        spent += price
        left = total - spent
        while j > 0 and pa[j] > left:
            j -= 1
        ans = max(ans, i + j)

    print(ans)

main()
```

All three samples pass, and it agrees with an exhaustive subset search over a few thousand random
small cases. `-(-price // k)` is integer ceiling division; with prices up to $$10^9$$ and
$$Y \le 10^9$$, `need` fits comfortably in Python's ints and the `> y` guard keeps it from running
away.

The `break` is safe because `need` is a running sum of positive terms, so once it exceeds $$Y$$ no
larger $$i$$ can help. And the pointer `j` is never reset between iterations, which is the whole
point of the two-pointer sweep.

## What I'd take away

The bug I actually shipped was an off-by-one, but the interesting failure was earlier and bigger, so
in rough order of how much they're worth:

**When your state has two components, a greedy on one of them is guessing.** I sorted by price
because price is what "affordable" seemed to be about. The state here is a pair — ones and
$$K$$-bills — and no ordering of prices can encode a decision about denominations. The moment you
notice that two states with equal total value behave differently, local greedy choices need a real
justification or they're just a guess.

**Look for the resource that only flows one way.** $$K$$-bills are never produced, only consumed,
and only drinks require them. That single observation is most of the solution: it says buy drinks
first, it says the constraint to watch is $$\sum \lceil B_j/K \rceil \le Y$$, and it explains why
letting a dessert eat a $$K$$-bill early was the specific thing that broke my greedy.

**Enumerate the coupling, don't simulate the state.** Sequential simulation forces you to carry the
awkward part of the state through every step. Enumerating how many drinks you buy collapses it: for
each $$i$$, both constraints become plain numbers and the desserts reduce to a prefix-sum lookup.
This is a pattern I've hit before — when the hard part is the *interaction* between two groups,
enumerate the interaction rather than interleaving the groups.

**Check whether a formula depends on what you think it depends on.** My change formula had `cost` in
it twice and still didn't depend on `cost`. Substituting one concrete pair of numbers — $$c = 5$$,
$$K = 3$$ — would have caught it in seconds, and reading the expression as "the difference between
ceiling and floor, scaled" would have caught it without any numbers at all.

**A parameter's zero case belongs in its range.** Handle $$i = 0$$ outside a loop that can `break`
immediately, or you'll lose it. Sample 2 existed precisely to find people who hadn't.

And one small piece of encouragement for the derivation I nearly threw away. My version tracked the
wallet explicitly,

$$\text{left} \;=\; X + KY - K \sum_j \left\lceil \frac{B_j}{K} \right\rceil
+ \sum_j \big((-B_j) \bmod K\big),$$

which looked clumsier than the editorial's $$X + KY - \sum_j B_j$$ until I noticed the two drink
terms collapse:

$$K \left\lceil \frac{B_j}{K} \right\rceil - \big((-B_j) \bmod K\big) \;=\; B_j.$$

Bills paid minus change received is the price. Obvious in hindsight, but seeing my messier
expression *become* the clean one is what convinced me the clean one was right, rather than just
memorising it.
