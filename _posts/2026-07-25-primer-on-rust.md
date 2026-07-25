---
layout: post
title: "A primer on Rust"
date: 2026-07-25 00:00:00 +0530
categories: rust
tags: [rust, cargo]
author: "Seroze"
published: true
---

*A running collection of Rust concepts worth knowing cold.*

## Cargo

Cargo is Rust's build tool and package manager. It handles compiling your code, downloading and managing dependencies (crates), running tests, and publishing packages — all through one CLI.

### Basic use cases

**Create a new project**

```bash
cargo new my_project      # new directory with a binary crate
cargo new my_lib --lib    # new directory with a library crate
```

**Initialize Cargo in an existing directory**

```bash
cargo init
```

Before creating anything, `cargo init` walks up the directory tree looking for an existing `Cargo.toml` — checking the current directory, then its parent, then its parent's parent, and so on — to find out whether it's being run inside an existing workspace. If it finds one, it treats the new package as a member of that workspace (and looks for the workspace's `src/bin` layout) instead of creating a standalone package.

**Build the project**

```bash
cargo build            # debug build, output in target/debug
cargo build --release  # optimized build, output in target/release
```

**Run the project**

```bash
cargo run               # builds (if needed) and runs the binary
cargo run --release
```

**Check for compile errors without producing a binary**

```bash
cargo check
```

This is much faster than `cargo build` since it skips code generation — useful as a tight feedback loop while writing code.

**Run tests**

```bash
cargo test
```

**Add a dependency**

```bash
cargo add serde
```

This adds the crate to `Cargo.toml` and fetches it from [crates.io](https://crates.io).

**Format and lint**

```bash
cargo fmt     # auto-format code
cargo clippy  # lint for common mistakes and non-idiomatic patterns
```

### Package names can't start with a digit

`cargo init` picks the current directory name as the package name by default. If that name starts with a digit, Cargo refuses to create the package:

```
     Creating binary (application) package
error: invalid character `1` in package name: `1-basic-syntax`, the name cannot start with a digit
If you need a package name to not match the directory name, consider using --name flag.
If you need a binary with the name "1-basic-syntax", use a valid package name, and set the binary name to be different from the package. This can be done by setting the binary filename to `src/bin/1-basic-syntax.rs` or change the name in Cargo.toml with:

    [[bin]]
    name = "1-basic-syntax"
    path = "src/main.rs"
```

This comes up often if you're organizing practice exercises into numbered folders (`1-basic-syntax`, `2-ownership`, etc.) and run `cargo init` inside them directly. The fix is either of:

- Pass an explicit package name: `cargo init --name basic_syntax`
- Keep the directory name but override the binary name in `Cargo.toml` via a `[[bin]]` section, as shown above.

## What is a workspace?

A Cargo workspace is a way to manage multiple related crates (packages) under a single umbrella.

- A **crate** is one Rust package (library or executable).
- A **workspace** is a collection of crates that are developed together.

For example, suppose you're building a distributed database. Instead of one huge crate, you might organize it like this:

```
mydb/
├── Cargo.toml          <-- workspace
├── storage/
│   ├── Cargo.toml
│   └── src/
├── raft/
│   ├── Cargo.toml
│   └── src/
├── cli/
│   ├── Cargo.toml
│   └── src/
└── server/
    ├── Cargo.toml
    └── src/
```

Here `storage` is the storage engine, `raft` is the consensus library, `cli` is the command-line tool, and `server` is the database server — each its own crate.

The top-level `Cargo.toml` just declares the workspace:

```toml
[workspace]
members = [
    "storage",
    "raft",
    "cli",
    "server",
]
```

Notice there's no `[package]` section here — the workspace root isn't a crate itself.

### Why use a workspace?

**1. Shared `target/` directory.** Without a workspace, each crate compiles its dependencies separately (`storage/target/`, `raft/target/`, `server/target/`, ...). With a workspace, everyone shares a single `mydb/target/`, so build artifacts aren't duplicated and builds are much faster.

**2. Shared dependencies.** Suppose every crate uses Tokio. Without a workspace, each `Cargo.toml` repeats `tokio = "1.48"`. With a workspace, the version is declared once:

```toml
# workspace Cargo.toml
[workspace.dependencies]
tokio = "1.48"
```

and each crate just writes:

```toml
tokio.workspace = true
```

Now every crate automatically uses the same version.

**3. Build and test everything together.** Instead of `cd`-ing into each crate to run `cargo test`, running `cargo test` from the workspace root tests every member crate.

**4. Easy local dependencies.** Suppose `server` uses `raft`. Inside `server/Cargo.toml`:

```toml
[dependencies]
raft = { path = "../raft" }
```

No publishing to crates.io needed.

### `src/bin` vs. a workspace

These solve different problems.

`src/bin` gives you **multiple executables inside one crate**:

```
calculator/
├── Cargo.toml
└── src/
    ├── main.rs
    └── bin/
        ├── add.rs
        └── multiply.rs
```

There's still one package. `cargo run --bin add` just picks one executable from it.

A workspace is different — `add` and `multiply` become completely separate crates:

```
calculator/
├── Cargo.toml      <-- workspace
├── add/
│   ├── Cargo.toml
│   └── src/
└── multiply/
    ├── Cargo.toml
    └── src/
```

**Rule of thumb:** one crate with multiple executables → use `src/bin/`. Multiple libraries or applications that should evolve independently but belong to the same project → use a workspace.

Many large projects — web frameworks, database engines, developer tools — are organized as workspaces, since they naturally split into several reusable crates.

## `if` is an expression, not a statement

A natural first attempt at a "which is bigger" function, coming from C/C++/Java, looks like this:

```rust
fn bigger(a: i32, b: i32) -> bool {
    if (a > b) { True }
    False
}
```

This has a few problems, in increasing order of subtlety.

**1. Booleans are lowercase.** Rust uses `true` and `false`, not `True` and `False`.

**2. Parentheses around the `if` condition are unnecessary.** `if a > b { ... }` is preferred over `if (a > b) { ... }` — the compiler will even warn about it (`unnecessary parentheses around if condition`).

**3. The real bug: an `if` without `else` has type `()`.** Fixing the two issues above still doesn't compile:

```rust
fn bigger(a: i32, b: i32) -> bool {
    if a > b {
        true
    }
    false
}
```

The error is a type mismatch: `expected () , found bool`. The reason is that `if` in Rust is an **expression**, and every expression has a type. An `if` with no `else` might not run its body at all, so the only type Rust can consistently give it is `()` — the unit type. Since the `then` branch here evaluates to `true` (a `bool`), it conflicts with the `()` the compiler expects from an else-less `if`.

This is different from `if` in C/C++/Java, where it's a *statement* with no value at all, and `if (a > b) { return true; }` reads naturally. In Rust, `if a > b { true }` doesn't mean "return true" — it means "the value of this branch is `true`," and without an `else`, that value has nowhere consistent to go.

**The rule:** you cannot have a branch of an `if` (with no `else`) produce a value other than `()`, unless you use `return` to exit the function early instead of trying to yield a value from the `if` expression itself.

### Three ways to fix it

```rust
// Fix 1: return early, so the if doesn't need to produce a value
fn bigger(a: i32, b: i32) -> bool {
    if a > b {
        return true;
    }
    false
}

// Fix 2: add an else, so the whole if expression has type bool
fn bigger(a: i32, b: i32) -> bool {
    if a > b {
        true
    } else {
        false
    }
}

// Fix 3: idiomatic — a > b is already a bool, no if needed
fn bigger(a: i32, b: i32) -> bool {
    a > b
}
```

Fix 3 is what most Rust code would actually use — since `a > b` already evaluates to a `bool`, wrapping it in an `if` is redundant. It also relies on another Rust rule: **the last expression in a function is automatically returned if it doesn't end with a semicolon.**

### Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_biggers() {
        assert!(bigger(20, 10));
        assert!(!bigger(10, 20));
    }
}
```

Run with `cargo test`. The compiler error for the broken version looks like:

```
error[E0308]: mismatched types
  --> src/bin/02.rs:12:9
   |
11 | /     if a> b {
12 | |         true
   | |         ^^^^ expected `()`, found `bool`
13 | |     }
   | |_____- expected this to be `()`
   |
help: you might have meant to return this value
   |
12 |         return true;
   |         ++++++     +
```

The `help` line is the compiler nudging you toward Fix 1 — but Fix 3 is the one worth internalizing. Expression-oriented control flow, where `if`/`match`/blocks all produce values, is one of the biggest conceptual shifts coming from statement-oriented languages, and it's worth getting comfortable with early.

## Finding the min and max of an array

Given an array, how do you find its largest and smallest element? There's a spectrum from manual loops to idiomatic iterator methods — worth knowing all of them, since production code leans heavily on the iterator versions.

### 1. Manual loop (good for building intuition)

```rust
fn main() {
    let input = [23, 82, 16, 45, 21, 94, 12, 34];

    let mut largest = i32::MIN;
    let mut smallest = i32::MAX;

    for &x in &input {
        if x > largest {
            largest = x;
        }
        if x < smallest {
            smallest = x;
        }
    }

    println!("{largest} is largest and {smallest} is smallest");
}
```

Why `for &x in &input`? `&input` iterates over `&i32`, and the `&x` pattern dereferences each one automatically, so `x` ends up being a plain `i32`. The equivalent, slightly more verbose form is:

```rust
for x in input.iter() {
    if *x > largest {
        largest = *x;
    }
}
```

### 2. Iterate by value

Arrays implement `IntoIterator`, so this also works directly:

```rust
for x in input {
    println!("{x}");
}
```

Here `x` is an `i32` because arrays of `Copy` types are copied into the loop.

### 3. `.iter().max()` / `.min()` (idiomatic)

Cleanest when you only need the result:

```rust
fn main() {
    let input = [23, 82, 16, 45, 21, 94, 12, 34];

    let largest = input.iter().max().unwrap();
    let smallest = input.iter().min().unwrap();

    println!("{largest} is largest and {smallest} is smallest");
}
```

Note these are `&i32`. Dereference with `*` if you want owned values: `*input.iter().max().unwrap()`.

### 4. Both in one pass with `fold`

More advanced, but only traverses the array once:

```rust
let (smallest, largest) = input.iter().fold(
    (i32::MAX, i32::MIN),
    |(min, max), &x| (min.min(x), max.max(x)),
);

println!("{largest} {smallest}");
```

### 5. `i32::min` / `i32::max` methods

Integers themselves have `.min()`/`.max()` methods, which many Rust developers prefer over explicit `if`s:

```rust
let mut smallest = i32::MAX;
let mut largest = i32::MIN;

for &x in &input {
    smallest = smallest.min(x);
    largest = largest.max(x);
}
```

### Common ways to iterate

```rust
// Values
for x in input { println!("{x}"); }

// References (x: &i32)
for x in input.iter() { println!("{x}"); }

// Mutable references
let mut input = [1, 2, 3];
for x in input.iter_mut() { *x *= 2; }

// Index and value
for (i, x) in input.iter().enumerate() { println!("{i}: {x}"); }

// Just indices — less idiomatic unless you actually need the index
for i in 0..input.len() { println!("{}", input[i]); }
```

### Which approach is idiomatic?

| Task | Idiomatic approach |
|---|---|
| Print elements | `for x in &input` |
| Need the index | `iter().enumerate()` |
| Find maximum | `iter().max()` |
| Find minimum | `iter().min()` |
| Find both in one pass | `fold()` or a manual loop |
| Modify elements | `iter_mut()` |

The iterator methods worth becoming fluent in early: `iter()`, `iter_mut()`, `into_iter()`, `enumerate()`, `map()`, `filter()`, `fold()`, `collect()`, `find()`, `any()`, `all()`, `max()`, `min()`. These form the core of idiomatic Rust and show up throughout production code.
