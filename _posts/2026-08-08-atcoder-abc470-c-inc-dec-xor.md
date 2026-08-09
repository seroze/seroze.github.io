---
layout: post
title: '[AtCoder] ABC470 C — Inc, Dec, Xor: the "pay with tokens you already minted" trick'
date: 2026-08-08 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, atcoder, amortized_analysis, xor, rust]
author: "Seroze"
published: true
---

Problem: [ABC470 C — Inc, Dec, Xor](https://atcoder.jp/contests/abc470/tasks/abc470_c)

---

An array `A` of length `N`, initially all zeros. `Q` queries, two kinds:

- `1 x` — increase `A[x]` by 1
- `2` — for every `i`, if `A[i] >= 1`, decrease it by 1

After each query, output the XOR of the whole array.

Constraints: `N, Q ≤ 5×10^5`, 2 second limit. The naive "touch every element, every query" approach is the obvious first instinct — and it's wrong in a subtle way that's worth picking apart, because the *fix* is not what I expected either.

## The trap: two different O(N) costs, only one of them matters

My first attempt looked roughly like this:

```rust
for _ in 0..q {
    // ... read query ...
    if t == 2 {
        for x in active_indices() {
            arr[x] -= 1;
            if arr[x] == 0 { remove(x); }
        }
    }
    let mut xor_value = 0;
    for a in &arr {
        xor_value ^= a;   // recompute from scratch, every query
    }
    println!("{}", xor_value);
}
```

This TLE'd hard — some test cases ran past 2000ms. My assumption going in was that the `for x in active_indices()` loop was the expensive part, since a `2` query can in principle touch every element. That assumption was wrong, and it's worth being precise about *why*, because there are two separate `O(N)`-shaped costs here and only one of them is actually a problem.

## Cost #1: recomputing the XOR from scratch — genuinely O(N) per query, no way around it

```rust
for a in &arr {
    xor_value ^= a;
}
```

This runs **unconditionally**, on every query, regardless of what changed. `Q` queries × `O(N)` each = up to `2.5 × 10^11` operations. This alone is enough to blow the time limit by several orders of magnitude, independent of anything else in the program.

The fix is standard: maintain a running `ans` and update it incrementally at the exact point where a value changes — XOR out the old value, XOR in the new one:

```rust
ans ^= old_value;
// ... mutate ...
ans ^= new_value;
```

Since `v XOR v = 0`, XOR-ing a value out and back in later exactly cancels, so this correctly maintains "the XOR of everything that's currently in the array" without ever touching elements that didn't change. This turns every `1 x` query into strict `O(1)`.

## Cost #2: touching every active element on a `2` query — looks like O(N), is actually amortized O(Q)

This is the part I was sure was the bottleneck, and it isn't. Here's the loop in question:

```rust
active.retain(|&x| {
    ans ^= arr[x];
    arr[x] -= 1;
    if arr[x] == 0 {
        false          // drop it — no longer active
    } else {
        ans ^= arr[x];
        true           // keep it
    }
});
```

A single `2` query *can* touch up to `N` elements. But the claim is that summed across **every** `2` query for the entire run, the total number of element-touches is bounded by `Q`, not `N × Q`. That needs an actual argument, not just a shrug at "amortized."

### The token argument

This trick has a name: it's the **potential method**. You define a potential function Φ over
the data structure's state — here, Φ = the total number of tokens outstanding, which is just
the sum of all `A[i]` — and instead of bounding each operation's real cost, you bound its
*amortized* cost, real cost plus the change in Φ. A `1 x` query does `O(1)` real work and
raises Φ by 1, so it's `O(1)` amortized. A `2` query does work proportional to the number of
elements it touches, but drops Φ by exactly that amount, so its amortized cost is `0` — the
work was already paid for when Φ went up. Since Φ starts at 0 and never goes negative, the
total real cost is bounded by the total amortized cost, which is `O(Q)`.

The token framing below is the same argument in more concrete language — tokens *are* the
potential, and "spending a token" is Φ decreasing by one. It's worth being able to move
between the two, since the informal version is faster to see and the formal version is what
actually proves the bound.

Think of every `1 x` query as **minting one token** and handing it to element `x`. A token represents one unit of value the element is currently holding — a debt that has to be paid off one unit at a time before the element can go back to zero.

Now look at what happens inside the `2`-query loop: every time an active element gets touched, it's decremented by exactly 1. **That decrement spends exactly one token.** An element can only be in the active set if it's holding at least one token (that's literally the condition for being active), and once its tokens run out it's removed and stops being touched by future `2` queries.

Two things fall out of this immediately:

1. Every touch, in every `2` query, across the whole program, spends exactly one token.
2. A token can only be spent once — there's no way to decrement the same unit of value twice.

So: **total touches across all `2` queries ≤ total tokens minted = total number of `1 x` queries ≤ Q.**

### Working through it by hand

```
1 1     mint 1 token for x=1        (x=1 now holds 1)
1 1     mint 1 token for x=1        (x=1 now holds 2)
1 2     mint 1 token for x=2        (x=2 now holds 1)
2       retain touches {1, 2}: x=1 → 1 left, x=2 → 0, removed   [2 touches]
2       retain touches {1}:    x=1 → 0, removed                 [1 touch]
2       retain touches {}:    nothing to do                     [0 touches]
```

3 tokens minted. 3 touches spent. Exactly matches — no `2` query can overcharge you, because it's mechanically impossible to touch an element that isn't holding a token.

### Why one expensive `2` query doesn't break the bound

You absolutely can construct a single `2` query that touches all `500,000` active elements — that's a legal, `O(N)`-cost call. But paying for it required `500,000` tokens to already exist, meaning `500,000` prior `1 x` queries already happened. Since `Q ≤ 5×10^5` total, minting that many tokens already spent most of your query budget — there's no room left in the input to have *many* such expensive calls, because each one needs its own freshly-minted tokens and tokens can't be reused.

This is the same shape as the classic **stack-with-multipop** amortized analysis from CLRS (`push` costs 1, `multipop(k)` costs `k` but can't pop more than was pushed), or the binary-counter increment argument. The general move: **charge an expensive operation to the cheap operations that made it possible**, then bound the total by the cheap operation count. Whenever an operation's cost is proportional to "how much stuff is currently sitting around," and that stuff can only have been put there by earlier `O(1)`-costed operations, this kind of argument is usually the right lens.

## Putting it together

```rust
use proconio::input;
use std::io::{self, Write, BufWriter};

fn main() {
    let stdout = io::stdout();
    let mut out = BufWriter::new(stdout.lock());

    input! {
        n: usize,
        q: usize,
    }

    let mut arr: Vec<u64> = vec![0; n + 1];
    let mut active: Vec<usize> = Vec::new();
    let mut ans: u64 = 0;

    for _ in 0..q {
        input! { t: usize }
        if t == 1 {
            input! { x: usize }
            let old = arr[x];
            ans ^= old;
            arr[x] += 1;
            ans ^= arr[x];
            if old == 0 {
                active.push(x);
            }
        } else {
            active.retain(|&x| {
                ans ^= arr[x];
                arr[x] -= 1;
                if arr[x] == 0 {
                    false
                } else {
                    ans ^= arr[x];
                    true
                }
            });
        }
        writeln!(out, "{}", ans).unwrap();
    }
}
```

- `1 x`: strict `O(1)` — one incremental XOR update.
- `2`: amortized `O(1)` per query, `O(Q)` total across the whole run, by the token argument.
- Overall: `O(N + Q)`, well inside the 2 second limit.

`Vec<usize>::retain` is doing the heavy lifting mechanically here — one linear pass that compacts kept elements in place and drops the rest, so there's no second allocation or extra pass for "things to remove." It's also a better fit than a `HashSet` for this specific case: membership is already known for free via `arr[x] == 0`, so there's no need to pay hashing overhead just to ask "is x active" — a plain `Vec` with `retain` is faster and simpler here.

## The general lesson

"This loop *can* be O(N)" and "this loop *is* O(N) per query" are different claims, and the gap between them is exactly what amortized analysis is for. The instinct to eyeball a loop's worst case and assume it repeats every query is reasonable, but it's worth actually asking: *what does this operation consume, and how much of that thing can possibly exist?* If the answer is "it consumes something that only cheap operations can produce, and there's a hard budget on cheap operations," you very likely have an amortized bound hiding in plain sight — and it's worth deriving the token/potential argument explicitly rather than trusting the vibe, because (as this problem showed) the *actual* bottleneck can be sitting somewhere else entirely.
