---
layout: post
title: "Rust for competitive programming"
date: 2026-07-28 00:00:00 +0530
categories: rust
tags: [rust, competitive_programming]
author: "Seroze"
published: false
---

*A running collection of Rust patterns for competitive programming.*

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## I/O

The single biggest friction point when using Rust for CP is input parsing. The algorithmic performance is excellent, but the standard library's I/O is far more verbose than C++ or Python.

### The problem

Reading two integers:

```cpp
// C++
int a, b;
cin >> a >> b;
```

```python
# Python
a, b = map(int, input().split())
```

```rust
// Rust, without any helper
use std::io;

let mut input = String::new();
io::stdin().read_line(&mut input).unwrap();

let mut iter = input.split_whitespace();
let a: i32 = iter.next().unwrap().parse().unwrap();
let b: i32 = iter.next().unwrap().parse().unwrap();
```

That's six lines for what C++ does in two.

### The fix: a scanner

Nobody writes that repeatedly. The standard practice is to keep a small scanner and paste it into every submission:

```rust
use std::io::{self, Read};

struct Scanner {
    input: Vec<String>,
}

impl Scanner {
    fn new() -> Self {
        let mut s = String::new();
        io::stdin().read_to_string(&mut s).unwrap();

        Self {
            input: s.split_whitespace().rev().map(String::from).collect(),
        }
    }

    fn next<T: std::str::FromStr>(&mut self) -> T {
        self.input.pop().unwrap().parse().ok().unwrap()
    }
}
```

The whole input is slurped once, split on whitespace, and reversed so that `pop()` hands back tokens in the original order. `next::<T>()` is generic over `FromStr`, so the type annotation at the call site drives the parse.

The solution then reads about as tersely as C++:

```rust
fn main() {
    let mut sc = Scanner::new();

    let t: usize = sc.next();

    for _ in 0..t {
        let n: i32 = sc.next();
        println!("{}", n * 2);
    }
}
```

### Why there's no `cin >>`

Not an oversight — a philosophy difference. Parsing an integer out of a text stream involves UTF-8 handling, a fallible parse, ownership of the buffer, and a generic target type (`T: FromStr`). The standard library exposes each of those steps explicitly rather than hiding them behind a stream operator aimed at one niche. CP is exactly the niche where you'd rather have them hidden, hence the copy-paste scanner.

One more thing worth doing: `println!` locks and flushes stdout on every call, which is slow when you're printing 10^5 lines. Wrap stdout in a `BufWriter` and `write!` into it instead.
