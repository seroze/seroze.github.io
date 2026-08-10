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

For a worked example of taking this somewhere else, see [Calling Rust from Python with PyO3](/rust-python-interop-pyo3/).

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

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

Imagine you're writing an essay. `cargo fmt` is like a teacher fixing your indentation, spacing, and punctuation so the essay looks neat. `cargo clippy` is like an editor saying, "This sentence is awkward," "You repeated yourself," or "There's a simpler way to say this."

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

### Hyphens in package names, underscores in code

Related trap, and one that's usually explained badly. Say your package is named `fizzbuzz-3`:

```toml
[package]
name = "fizzbuzz-3"
```

```rust
use fizzbuzz-3::solve;   // syntax error
use fizzbuzz_3::solve;   // the only spelling that compiles
```

The reason is worth being precise about, because the usual "hyphens get converted to underscores" phrasing suggests a conversion you could opt out of:

- **The package name in `Cargo.toml` is just a string identifier** for Cargo and crates.io. Hyphens are perfectly fine there.
- **Rust source identifiers can't contain `-` at all.** It isn't a valid identifier character — the parser reads it as subtraction. `fizzbuzz-3` in a `use` statement is a *syntax error*, not a valid-but-wrong name.
- **Cargo derives the crate's Rust identifier from the package name** by replacing every `-` with `_`. That derived identifier is what you reference in code, always and unconditionally.

So it isn't "if I use a hyphen it gets converted." You can never legally type `-` in that position in a `.rs` file. Cargo does the conversion on its side, package name → identifier, and your source has to already be written in the underscore form to compile at all.

The same asymmetry shows up with dependencies — hyphenated in the manifest, underscored at the `use` site:

```toml
[dependencies]
async-trait = "0.1"
tokio-util = "0.7"
```

```rust
use async_trait::async_trait;
use tokio_util::codec::Framed;
```

Hyphens are the more common convention for published crate names, so most of the ecosystem's `use` statements are spelled differently from the crate names you search for on crates.io. That's expected, not a mistake.

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

## Initializing objects

Rust has no constructors. There's no special method the compiler calls, no `new` keyword, no initializer lists. A struct is built by writing out its fields, and everything else is convention layered on top of that.

```rust
struct Point {
    x: i32,
    y: i32,
}

let p = Point { x: 1, y: 2 };   // struct literal — this is the only primitive
```

Every field must be given a value. There's no partial initialization and no implicit zeroing, which is why "uninitialized field" bugs don't exist.

**Field init shorthand.** When a local variable has the same name as the field, write it once:

```rust
let x = 1;
let y = 2;
let p = Point { x, y };   // same as Point { x: x, y: y }
```

### `new()` is a convention, not a keyword

`String::new()`, `Vec::new()`, `HashMap::new()` — these are just associated functions someone chose to name `new`. Nothing in the language treats them specially:

```rust
impl Point {
    fn new(x: i32, y: i32) -> Self {
        Point { x, y }
    }
}

let p = Point::new(1, 2);
```

`Self` is an alias for the type you're in, so `Point { x, y }` and `Self { x, y }` are interchangeable here. Since it's an ordinary function, you can have as many as you want with names that actually describe what they do — `Point::origin()`, `Vec::with_capacity(n)`, `String::from("hi")`.

The `::` is doing the work described in the section on `::` below: there's no value to call a method on yet, so you go through the type.

### `Default` and struct update syntax

For a struct with many fields where most have an obvious zero value, derive `Default`:

```rust
#[derive(Default)]
struct Config {
    host: String,      // ""
    port: u16,         // 0
    verbose: bool,     // false
    retries: u32,      // 0
}

let c = Config::default();
```

The derive requires every field's type to be `Default` itself. To override defaults per-field, use `#[derive(Default)]` together with **struct update syntax** — `..expr` fills in every field you didn't name:

```rust
let c = Config {
    port: 8080,
    verbose: true,
    ..Default::default()
};
```

The `..` must come last, and it moves out of the source value for any non-`Copy` field, so the thing on the right is usually a fresh `Default::default()` rather than a struct you still want to use.

If the derived zero values are wrong for your type, write the impl by hand:

```rust
impl Default for Config {
    fn default() -> Self {
        Config { host: "localhost".into(), port: 8080, verbose: false, retries: 3 }
    }
}
```

### Other shapes

```rust
struct Meters(f64);          // tuple struct — constructed like a function call
let d = Meters(3.5);
let raw = d.0;

struct Marker;               // unit struct — the name is the value
let m = Marker;

enum Shape {                 // enum variants construct the same way
    Circle { r: f64 },
    Square(f64),
    Empty,
}
let s = Shape::Circle { r: 1.0 };
```

Tuple structs are the idiom for newtypes — wrapping a primitive to get a distinct type, so `Meters` and `Seconds` can't be swapped by accident even though both are an `f64` underneath.

### Converting instead of constructing

The other common way to get a value is to convert an existing one. Implement `From` and you get `Into` for free:

```rust
impl From<(i32, i32)> for Point {
    fn from(t: (i32, i32)) -> Self {
        Point { x: t.0, y: t.1 }
    }
}

let p = Point::from((1, 2));
let p: Point = (1, 2).into();   // same thing, type driven by the annotation
```

This is why `String::from("hi")` and `"hi".to_string()` and `"hi".into()` all exist and all work — one `From<&str> for String` impl, reached three ways.

### When the field list gets long

If construction has many optional parameters, the ecosystem's answer is a builder: a separate struct that accumulates settings and produces the real value at the end.

```rust
let c = Config::builder().port(8080).verbose(true).build();
```

Each method takes `self` and returns `Self`, which is what makes the chaining work. Worth knowing it exists, but don't reach for it early — `..Default::default()` covers most of what a builder would, with none of the boilerplate.

**Rule of thumb:** struct literal by default, `new()` when there's real work or invariants to enforce, `Default` + `..` when most fields have sensible zeros, `From` when you're converting, builder only when the parameter list is genuinely unwieldy.

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

## Arrays, slices, and `Vec`

Most languages give you one list type. Rust gives you three, and the distinction between them is the first place ownership becomes concrete rather than theoretical.

| Type | Written | Size | Lives on | Owns its data? |
|---|---|---|---|---|
| Array | `[T; N]` | Fixed at compile time | Stack | Yes |
| Vector | `Vec<T>` | Grows at runtime | Heap | Yes |
| Slice | `&[T]` / `&mut [T]` | Known at runtime | Borrowed view | No |

```rust
let arr: [i32; 4] = [1, 2, 3, 4];   // length is part of the type
let vec: Vec<i32> = vec![1, 2, 3];  // can push/pop
let sl:  &[i32]   = &arr[1..3];     // a window into arr — [2, 3]
```

The length being *part of the type* is the key thing about arrays. `[i32; 3]` and `[i32; 4]` are different types, so a function taking `[i32; 3]` will not accept a four-element array. That's why arrays are rare in function signatures and slices are everywhere.

### The slice is the unifying view

A slice is a fat pointer: a pointer to some elements plus a length. It doesn't care whether those elements came from an array, a `Vec`, or another slice — which makes `&[T]` the type you want in signatures:

```rust
fn sum(xs: &[i32]) -> i32 {
    xs.iter().sum()
}

let arr = [1, 2, 3];
let vec = vec![4, 5, 6];

sum(&arr);        // &[i32; 3] → &[i32]
sum(&vec);        // &Vec<i32> → &[i32]
sum(&vec[1..]);   // already a slice
```

All three calls work because of deref coercion (covered below). The practical rule: **take `&[T]`, return `Vec<T>`.** Borrow the most general thing you can, hand back the thing you own.

Almost every method in this section is actually defined on `[T]` — the slice type — and `Vec<T>` and arrays inherit them by deref. That's why `vec.sort()` and `arr.sort()` and `slice.sort()` are all the same function.

### Creating them

```rust
let a = [0; 10];                       // ten zeros, [i32; 10]
let v = vec![0; 10];                   // ten zeros, Vec<i32>
let v = Vec::new();                    // empty, type inferred from later use
let v = Vec::with_capacity(1000);      // empty but pre-allocated
let v: Vec<i32> = (1..=5).collect();   // from an iterator
let v = "a b c".split(' ').collect::<Vec<_>>();
```

`with_capacity` matters more than it looks. A `Vec` that outgrows its buffer allocates a new one (typically double) and copies everything across. Amortised that's O(1) per push, but if you know the final size, saying so up front avoids the copies entirely.

### Reading elements

```rust
let v = vec![10, 20, 30];

v[0]              // 10 — panics if out of bounds
v.get(0)          // Some(&10)
v.get(99)         // None — the non-panicking version
v.first()         // Some(&10)
v.last()          // Some(&30)
v.len()           // 3
v.is_empty()      // false
v.contains(&20)   // true
```

Indexing with `[]` panics on an out-of-bounds access; `.get()` returns an `Option`. Use `[]` when an out-of-range index means your logic is broken, `.get()` when the index came from outside your control.

**Minimum and maximum.** Reach for the iterator methods rather than a hand-rolled loop:

```rust
let largest  = v.iter().max().unwrap();
let smallest = v.iter().min().unwrap();
```

They return `Option<&T>` — `None` for an empty slice — so you get a `&i32` here. Dereference with `*` if you want an owned value.

That's two traversals. If you want both in one pass, `fold` carries the pair along:

```rust
let (smallest, largest) = v.iter().fold(
    (i32::MAX, i32::MIN),
    |(min, max), &x| (min.min(x), max.max(x)),
);
```

The `.min()`/`.max()` inside the closure are `i32`'s own methods, not the iterator ones — worth knowing separately, since `a.max(b)` reads better than an explicit `if`.

**Iterating.** The three iterator constructors differ only in what they hand you:

```rust
for x in v.iter()     { }  // x: &i32     — borrow
for x in v.iter_mut() { *x *= 2; }  // x: &mut i32 — borrow mutably
for x in v            { }  // x: i32      — consumes v (IntoIterator)

for x in &v  { }  // shorthand for v.iter()
for &x in &v { }  // pattern destructures the reference, so x: i32

for (i, x) in v.iter().enumerate() { println!("{i}: {x}"); }
```

`for &x in &v` is the one that confuses people at first: the `&` on the left is a *pattern* that unwraps the reference, so `x` comes out as a plain `i32` instead of `&i32`. It only works for `Copy` types.

Indexing by range — `for i in 0..v.len()` — works but is the least idiomatic option unless you genuinely need the index for something other than lookup.

The iterator methods worth becoming fluent in early: `iter()`, `iter_mut()`, `into_iter()`, `enumerate()`, `map()`, `filter()`, `fold()`, `collect()`, `find()`, `any()`, `all()`, `max()`, `min()`. These form the core of idiomatic Rust and show up throughout production code.

### Growing and shrinking (`Vec` only)

These need ownership and a resizable buffer, so they exist on `Vec` but not on slices or arrays:

```rust
let mut v = vec![1, 2, 3];

v.push(4);              // [1, 2, 3, 4]
v.pop();                // Some(4), leaves [1, 2, 3]
v.insert(1, 99);        // [1, 99, 2, 3] — O(n), shifts everything right
v.remove(1);            // returns 99, [1, 2, 3] — O(n)
v.swap_remove(0);       // returns 1, O(1) but does not preserve order
v.extend([7, 8]);       // append an iterator's items
v.append(&mut other);   // move all of other's items in, emptying it
v.truncate(2);          // keep the first 2
v.clear();              // empty it, keeping the allocation
v.retain(|&x| x % 2 == 0);   // keep only elements matching a predicate
v.drain(1..3);          // remove a range, yielding the removed items
```

`swap_remove` is the one worth remembering: `remove` shifts every later element left, but `swap_remove` just moves the last element into the hole. If you don't care about order, it turns an O(n) removal into O(1).

`retain` is the idiomatic filter-in-place. Reaching for `v = v.into_iter().filter(...).collect()` does the same thing with an extra allocation.

### Sorting and searching

```rust
let mut v = vec![3, 1, 2];

v.sort();                              // ascending, stable
v.sort_unstable();                     // faster, no stability guarantee
v.sort_by(|a, b| b.cmp(a));            // descending
v.sort_by_key(|s| s.len());            // sort by a derived key
v.reverse();                           // in place

v.binary_search(&2);                   // Ok(idx) or Err(insert_position)
v.iter().position(|&x| x == 2);        // Some(idx) — linear scan
v.iter().find(|&&x| x > 1);            // Some(&value)
```

Two things trip people up here. First, `sort` needs `Ord`, which floats don't implement — for `f64` you need `sort_by(|a, b| a.partial_cmp(b).unwrap())` or `total_cmp`. Second, `binary_search` returns a `Result` where the `Err` carries the index the element *would* go at, which is exactly what you want for an insertion:

```rust
let pos = v.binary_search(&x).unwrap_or_else(|e| e);
v.insert(pos, x);
```

Use `sort_unstable` by default for primitives — it's faster and stability rarely matters. Use `sort` when equal elements have distinguishable identity you want preserved.

### Deduplication

```rust
let mut v = vec![1, 1, 2, 2, 3, 1];
v.dedup();          // [1, 2, 3, 1] — only removes *consecutive* duplicates
v.sort();
v.dedup();          // [1, 2, 3] — sort first for true dedup
```

### Slicing and splitting

```rust
let v = vec![1, 2, 3, 4, 5];

&v[1..3]            // [2, 3]
&v[..2]             // [1, 2]
&v[3..]             // [4, 5]

v.split_at(2);      // ([1, 2], [3, 4, 5])
v.chunks(2);        // [1,2], [3,4], [5] — non-overlapping
v.windows(2);       // [1,2], [2,3], [3,4], [4,5] — overlapping
v.split_first();    // Some((&1, &[2, 3, 4, 5]))
v.concat();         // flatten a Vec<Vec<T>> or Vec<&str>
```

`windows` is the one to reach for whenever you're comparing adjacent pairs — checking whether a sequence is sorted, computing differences, and so on:

```rust
let sorted = v.windows(2).all(|w| w[0] <= w[1]);
```

Note that `windows` and `chunks` exist on slices, so they work on arrays and `Vec`s alike.

### Mutating in place

```rust
let mut v = vec![1, 2, 3];

v.swap(0, 2);                    // [3, 2, 1]
v.fill(0);                       // [0, 0, 0]
v.rotate_left(1);                // shift elements left, wrapping
for x in v.iter_mut() { *x *= 2; }
```

### Conversions

```rust
let v: Vec<i32> = arr.to_vec();          // array/slice → owned Vec
let s: &[i32]   = v.as_slice();          // Vec → slice (usually implicit)
let a: [i32; 3] = v.try_into().unwrap(); // Vec → array, fails if length differs
let joined = ["a", "b"].join("-");       // "a-b"
```

### 2D vectors

There's no dedicated matrix type in the standard library. The usual idiom is a `Vec` of `Vec`s:

```rust
let mut grid = vec![vec![0; cols]; rows];
grid[r][c] = 1;
```

That's `rows` separate heap allocations. For anything performance-sensitive, a flat `Vec` with manual indexing is meaningfully faster since it's one allocation and one contiguous cache-friendly block:

```rust
let mut grid = vec![0; rows * cols];
grid[r * cols + c] = 1;
```

### Quick reference

| Task | Method |
|---|---|
| Add to end / remove from end | `push()` / `pop()` |
| Remove by index, keep order | `remove(i)` — O(n) |
| Remove by index, order irrelevant | `swap_remove(i)` — O(1) |
| Safe indexed access | `get(i)` → `Option<&T>` |
| Smallest / largest element | `iter().min()` / `iter().max()` |
| Both in one traversal | `fold()` |
| Iterate with the index | `iter().enumerate()` |
| Modify every element | `iter_mut()` |
| Filter in place | `retain(\|x\| ...)` |
| Sort | `sort_unstable()` / `sort_by_key()` |
| Remove duplicates | `sort()` then `dedup()` |
| Search a sorted slice | `binary_search()` |
| Search an unsorted slice | `iter().position()` |
| Compare adjacent elements | `windows(2)` |
| Fixed-size batches | `chunks(n)` |
| Build from an iterator | `collect()` |

## What is `::`?

Coming from C++, `::` looks like the scope resolution operator. Rust calls it the **path separator**, and it's used to navigate into modules, types, traits, and enums. Take a line you'll write constantly:

```rust
use std::io::{self, Write};

io::stdout().flush()?;
```

There are two different operators at work in that one expression.

**`::` goes through a namespace or a type.** `io::stdout()` means "the function `stdout` inside the module `io`." The full path is `std::io::stdout()`; the `use std::io;` import is what lets you shorten it.

**`.` operates on a value you already have.** `io::stdout()` returns a `Stdout` value, and `.flush()` is a method called on that value. So the expression switches modes halfway through:

```
io::stdout()   ::  module → function
    .flush()   .   value  → method
```

That's the whole mental model: **`::` starts from a namespace or type, `.` operates on a particular value.**

### What can appear on the left of `::`

| Left side | Example | Meaning |
|---|---|---|
| Module | `std::io::stdout()` | Function inside a module |
| Type | `String::new()` | Associated function |
| Type | `u32::MAX` | Associated constant |
| Enum | `Option::Some(5)` | Enum variant |
| Trait | `<Dog as Animal>::sound()` | Associated item via a trait |

The type cases are the ones that surprise people. In `String::new()`, `String` is not a module — it's a type, and `new` is an **associated function** (Rust's equivalent of a static method). It uses `::` precisely because there's no `String` value to call it on yet:

```rust
let mut s = String::new();  // :: — no value exists yet
s.push_str("hello");        // .  — operating on s
```

Generics slot into the path too. `Vec::<i32>::new()` has two `::`: one to pin the generic parameter, one to reach the associated function.

Chaining the two operators is the pattern you'll see everywhere — start from a type or module, then work on the value it produces:

```rust
String::new()   // :: create a String
    .trim()     // .  operate on it
    .len();     // .  operate on the result
```

## Traits

A trait is a set of behaviours a type can implement — closest to an interface in Java or a concept in C++. The part that matters day to day is **trait bounds**: when a generic function writes `T: SomeTrait`, it's saying "this only works for types that can do this particular thing."

Reading bounds fluently is most of what makes standard library signatures stop looking cryptic.

### The traits you'll actually meet

Open any real Rust codebase and the same few dozen traits account for nearly everything. Worth knowing by name, grouped by what they're for:

**Derivable — you'll see these in `#[derive(...)]` constantly**

| Trait | What it gives you |
|---|---|
| `Debug` | `{:?}` formatting. Derive it on essentially every type. |
| `Clone` | Explicit, possibly-expensive duplication via `.clone()` |
| `Copy` | Implicit bitwise duplication (no `.clone()` call needed) |
| `Default` | `T::default()` and `..Default::default()` |
| `PartialEq` / `Eq` | `==` and `!=` |
| `PartialOrd` / `Ord` | `<`, `>`, `sort()`, `BTreeMap` keys |
| `Hash` | `HashMap` / `HashSet` keys |

**Conversion**

| Trait | What it gives you |
|---|---|
| `From<T>` / `Into<T>` | Infallible conversion. Implement `From`, get `Into` free. |
| `TryFrom<T>` / `TryInto<T>` | Fallible conversion, returns `Result` |
| `FromStr` | `"42".parse::<T>()` |
| `AsRef<T>` / `AsMut<T>` | Cheap reference-to-reference conversion; why `fn open(p: impl AsRef<Path>)` accepts `&str`, `String`, and `PathBuf` alike |
| `Borrow<T>` | Like `AsRef` but promises `Eq`/`Hash` agree — why `map.get("k")` works on a `HashMap<String, V>` |
| `ToOwned` | The `&str → String` direction; the trait behind `Cow` |

**Formatting and errors**

| Trait | What it gives you |
|---|---|
| `Display` | `{}` formatting — the human-facing message. Never derivable. |
| `Error` | Marks a type as an error; enables `Box<dyn Error>` and `?` interop |

**Iteration**

| Trait | What it gives you |
|---|---|
| `Iterator` | `next()`, plus the ~70 adapters that come free with it |
| `IntoIterator` | What `for x in thing` desugars to |
| `FromIterator` | What `.collect::<T>()` requires of `T` |
| `Extend` | `.extend(iter)` on an existing collection |

**Ownership, pointers, lifecycle**

| Trait | What it gives you |
|---|---|
| `Drop` | A destructor. Runs at scope exit; mutually exclusive with `Copy`. |
| `Deref` / `DerefMut` | Smart-pointer transparency and deref coercion (below) |
| `Sized` | Implicit on every generic parameter; opt out with `?Sized` |

**Concurrency**

| Trait | What it gives you |
|---|---|
| `Send` | The type can move to another thread |
| `Sync` | `&T` can be shared across threads |

Both are auto-traits — the compiler implements them for you when all fields qualify. You almost never write these; you read them in error messages.

**Operators and callables**

| Trait | What it gives you |
|---|---|
| `Add`, `Sub`, `Mul`, `Neg`, ... (`std::ops`) | Operator overloading |
| `Index` / `IndexMut` | `x[i]` |
| `Fn` / `FnMut` / `FnOnce` | Closures, in decreasing order of restriction |

**Ecosystem traits you'll hit within a week**

`Serialize` / `Deserialize` (serde), `Read` / `Write` / `BufRead` (`std::io`), `Future` (async), `Any` (runtime downcasting).

Two rules of thumb. **Derive `Debug` on everything**, and `Clone`/`PartialEq`/`Eq`/`Hash` whenever they're free — derives cost nothing at runtime and unlock APIs you didn't anticipate needing. And **take the trait, not the type**, in signatures: `impl AsRef<Path>` over `&Path`, `impl IntoIterator<Item = T>` over `Vec<T>`, `impl Display` over `String`.

### `Default`

`Default` is the trait for types that know how to produce a sensible zero value — `0` for integers, `""` for `String`, `None` for `Option`, an empty `Vec`. You get it via `T::default()`.

A good way to see why the bound exists at all is `Cell::take()`.

**Why does `Cell::take()` require `Default`?**

Suppose you have:

```rust
use std::cell::Cell;

let c = Cell::new(10);
```

When you call:

```rust
let value = c.take();
```

Rust needs to do two things:

1. Return the current value (`10`).
2. Leave something inside the `Cell`, because a `Cell` can never be empty.

So it replaces the old value with `T::default()`. Conceptually, `take()` does this:

```rust
fn take(&self) -> T
where
    T: Default,
{
    self.replace(T::default())
}
```

So after:

```rust
let c = Cell::new(10);

let x = c.take();

println!("{}", x);       // 10
println!("{}", c.get()); // 0
```

The `10` is returned, and the cell now contains `0`, which is `i32::default()`.

For `String`:

```rust
let c = Cell::new(String::from("hello"));

let s = c.take();

println!("{s}");              // hello
println!("{:?}", c.take());   // ""
```

The cell is replaced with an empty `String`.

So whenever you see a bound like:

```rust
T: Default
```

read it as:

> "This function only works for types that know how to create a default value using `T::default()`."

### `PartialEq` and `Eq` — one method, two promises

`==` desugars to exactly one thing: `PartialEq::eq(&a, &b)`. That's the trait with the actual code in it. For a struct whose fields are all comparable, derive it and you get field-by-field comparison:

```rust
#[derive(Debug, PartialEq)]
struct User {
    id: u64,
    name: String,
}
```

`Eq`, by contrast, is this in full:

```rust
pub trait Eq: PartialEq<Self> {}
```

An empty marker trait. It defines no methods and changes nothing about what runs at the call site — `a == b` still calls `PartialEq::eq`, whether or not `Eq` is implemented. What `Eq` does is let *other* APIs demand a stronger promise as a bound. `HashMap`, `HashSet`, `BTreeMap` and `Ord` all require `Eq`, because their internals would misbehave if a key weren't equal to itself.

**The three axioms.** `PartialEq` asks for two:

- **Symmetry** — if `a == b` then `b == a`
- **Transitivity** — if `a == b` and `b == c` then `a == c`

`Eq` asks for those plus a third:

- **Reflexivity** — `a == a` holds for *every* value, no exceptions

That third one is the entire difference, and floats are the reason it's carved out. `f64::NAN == f64::NAN` is `false` by IEEE 754 design: `NaN` means "this result is meaningless," and two meaningless results aren't equal. Note precisely which axiom that breaks — symmetry is fine (`NaN == NaN` is consistently `false` in both directions) and transitivity is fine (no chain of equalities leads to a contradiction, since `NaN` is equal to nothing at all). Only reflexivity fails. That single broken guarantee is why `f32`/`f64` implement `PartialEq` but not `Eq`, and it propagates: any struct with a float field can derive `PartialEq` but not `Eq`.

**The one line that demonstrates it.** If you only remember one thing from this section, make it this:

```rust
let x = f64::NAN;

assert!(x != x);        // passes — the only value in Rust not equal to itself
assert_eq!(x == x, false);
```

That's the whole justification for splitting the trait in two. Every other numeric type is reflexive, which is why they're all `Eq`:

```rust
assert!(i32::MAX == i32::MAX);   // true, always
assert!(0u8 == 0u8);
```

**Now watch the derives track that distinction exactly.** This compiles:

```rust
#[derive(PartialEq)]
struct Reading {
    value: f64,
}
```

Add `Eq` and it doesn't:

```rust
#[derive(PartialEq, Eq)]
struct Reading {
    value: f64,
}
```

```
error[E0277]: the trait bound `f64: Eq` is not satisfied
   --> eq_fail.rs:3:5
    |
  1 | #[derive(PartialEq, Eq)]
    |                     -- in this derive macro expansion
  2 | struct Reading {
  3 |     value: f64,
    |     ^^^^^^^^^^ the trait `Eq` is not implemented for `f64`
    |
note: required by a bound in `std::cmp::AssertParamIsEq`
```

That `AssertParamIsEq` in the last line is the derive machinery showing its hand: `#[derive(Eq)]` generates no comparison code at all — it just emits a static assertion that every field is itself `Eq`. Which is the perfect illustration of what `Eq` *is*: not behaviour, just a checked claim.

Swap the field for a `u64` and both derives work:

```rust
#[derive(PartialEq, Eq)]      // fine — u64 and String are both Eq
struct User {
    id: u64,
    name: String,
}
```

So the rule to state in an interview: **derive `Eq` whenever every field is `Eq` — it's free and unlocks `HashMap` keys — and the one thing that will stop you is a float.**

Integers have no such value — every bit pattern of an `i32` is an ordinary number, `i32::MAX == i32::MAX` is `true` — so they implement both. And integer division by zero isn't a `NaN` analogue; there's no bit pattern to put there, so Rust panics instead. Among floats, only `0.0 / 0.0` (and friends like `(-1.0).sqrt()`, `inf - inf`) gives `NaN` — `1.0 / 0.0` is a well-defined `inf`.

**So should you derive both?** For `User` above, yes — all its fields are `Eq`, so it's free, costs nothing at runtime, and unlocks using `User` as a `HashSet` element or `HashMap` key. The only reason to derive `PartialEq` alone is a field that genuinely isn't reflexive, i.e. a float. Deriving `Eq` there would be a lie about your type's semantics, and the compiler stops you anyway.

### The contract is unenforced

Here's the part worth internalizing: symmetry, transitivity and reflexivity are promises *you* make, not properties the compiler checks. `#[derive(PartialEq)]` always produces a well-behaved impl. The moment you hand-write `impl PartialEq`, nothing stops you from breaking the rules — you just get code that misbehaves at a distance, in sorting or hashing or dedup logic that assumed the contract held.

**Case 1: `a == b` but `b != a`.** A derived impl can't do this; it's symmetric by construction. A buggy manual one can:

```rust
struct Fuzzy(i32);

impl PartialEq for Fuzzy {
    fn eq(&self, other: &Self) -> bool {
        // bug: the trailing clause makes this directional
        (self.0 - other.0).abs() <= 2 && self.0 > other.0
    }
}
```

The realistic version of this mistake involves cross-type comparison. `PartialEq` is generic over the right-hand side — `PartialEq<Rhs = Self>` — so `impl PartialEq<B> for A` is legal and gives you `a == b`. But `b == a` is then a *different* impl, resolved separately, and keeping the two consistent is entirely on you:

```rust
struct Celsius(f64);
struct Fahrenheit(f64);

impl PartialEq<Fahrenheit> for Celsius {
    fn eq(&self, other: &Fahrenheit) -> bool {
        self.0 == (other.0 - 32.0) / 1.8
    }
}

impl PartialEq<Celsius> for Fahrenheit {
    fn eq(&self, other: &Celsius) -> bool {
        self.0 * 1.8 + 32.0 == other.0   // different arithmetic, different rounding
    }
}
```

Both impls look right. They compute the conversion in opposite directions, so floating-point rounding can make `c == f` and `f == c` disagree for the same pair of values. If you write a cross-type `PartialEq`, write both directions and make them the *same* computation.

**Case 2: symmetric but not transitive.** This is the classic, and it's why "approximate equality" is a trap. Define equality as "within a tolerance":

```rust
struct Approx(f64);

impl PartialEq for Approx {
    fn eq(&self, other: &Self) -> bool {
        (self.0 - other.0).abs() < 1.0
    }
}

let a = Approx(1.0);
let b = Approx(1.9);
let c = Approx(2.8);

a == b   // true  (diff = 0.9)
b == c   // true  (diff = 0.9)
a == c   // false (diff = 1.8)  ← transitivity broken
```

Symmetry holds perfectly — `(x - y).abs()` doesn't care about argument order. But equality chains drift: `a` is close to `b`, `b` is close to `c`, and `a` is not close to `c`. Feed this type to `sort_by` or use it as a `HashMap` key and you get results that depend on comparison order.

This is exactly why `f64`'s own `PartialEq` uses exact bit comparison rather than a tolerance. Exact equality keeps symmetry and transitivity intact; it gives up only reflexivity, and only for `NaN`. If you need tolerance comparison, write it as a named method — `fn approx_eq(&self, other: &Self) -> bool` — not as `PartialEq`. Callers then know they're getting a fuzzy relation instead of assuming the axioms.

### `PartialOrd` and `Ord`

The same split, one level up. `PartialOrd::partial_cmp` returns `Option<Ordering>` — `None` means "these two aren't comparable." `Ord::cmp` returns a plain `Ordering` and promises a **total order**: every pair compares, and the ordering is transitive and antisymmetric.

Floats are the same culprit for the same reason. Here the `Option` in the return type stops being an abstraction and becomes something you can print:

```rust
assert_eq!(1.0_f64.partial_cmp(&2.0), Some(Ordering::Less));   // comparable
assert_eq!(f64::NAN.partial_cmp(&1.0), None);                  // not comparable
```

`None` is the whole reason `PartialOrd` exists. And it has a consequence people find genuinely surprising the first time — with `NaN` involved, a comparison and its opposite are **both false**:

```rust
let x = f64::NAN;

assert_eq!(x < 1.0, false);
assert_eq!(x > 1.0, false);
assert_eq!(x == 1.0, false);   // all three at once
```

In every other type, `!(a < b) && !(a == b)` implies `a > b`. That's trichotomy, and it's precisely what a *total* order guarantees and a partial one doesn't. So `f64` is `PartialOrd` but not `Ord` — which is the concrete cause of the error you hit the first time you sort floats:

```rust
let mut v = vec![3.0_f64, 1.0, 2.0];
v.sort();
```

```
error[E0277]: the trait bound `f64: Ord` is not satisfied
   --> sortfail.rs:3:7
    |
  3 |     v.sort();
    |       ^^^^ the trait `Ord` is not implemented for `f64`
```

`sort` needs `Ord` because a sorting algorithm has to be able to order *any* two elements it's handed — a `None` mid-sort would leave it with nowhere to go. Three ways out, in increasing order of how much I'd recommend them:

```rust
v.sort_by(|a, b| a.partial_cmp(b).unwrap());   // panics the moment a NaN appears
v.sort_by(|a, b| a.total_cmp(b));              // total order, NaN sorts to the end
```

```rust
let mut v = vec![3.0_f64, f64::NAN, 1.0, 2.0];
v.sort_by(|a, b| a.total_cmp(b));
// [1.0, 2.0, 3.0, NaN]
```

`total_cmp` is the right default. It implements IEEE 754's total ordering, so it never panics and gives `NaN` a defined position instead of pretending it can't occur.

When you derive `PartialOrd`/`Ord` on a struct, comparison is lexicographic in declaration order — first field, then second as a tiebreak, and so on. Reordering fields silently changes sort behaviour, which is a nice trap to know about before it bites you.

### `Copy` and `Clone` — why `String` isn't `Copy`

`Copy` means "duplicating this value is just a `memcpy` of its bytes, and both copies are independently valid."

A `String` is three words on the stack — pointer, length, capacity — pointing at a heap allocation. Bitwise-copying those three words gives you two `String`s pointing at the same buffer. Both would run their destructor at scope end → double free.

Rust enforces this structurally: **`Copy` and `Drop` are mutually exclusive.** If a type has a destructor, it can't be `Copy`, because `Copy` implies duplication is a no-op the compiler can do silently and the value has no cleanup obligation to duplicate.

```rust
struct Foo;
impl Copy for Foo {}
impl Drop for Foo { fn drop(&mut self) {} }
// error[E0184]: the trait `Copy` cannot be implemented for this type;
//               the type has a destructor
```

So anything owning a resource — `String`, `Vec`, `Box`, `File`, `Rc` (needs a refcount increment) — is `Clone` instead. `Clone` is the explicit, possibly-expensive version: you have to write `.clone()`, which makes the allocation visible in the source.

`Copy` is the "trivially duplicable" subset: integers, `char`, `bool`, `&T`, and aggregates of those.

### `Debug` vs. `Display`

Two formatting traits, and the split is about audience.

`Debug` is `{:?}` — for programmers. It's derivable, it's allowed to be ugly, and it should exist on essentially every public type you write. `{:#?}` is the pretty-printed multi-line version, which is what you want when inspecting nested structures.

`Display` is `{}` — for humans. It is deliberately **not derivable**, because there's no way for a macro to guess what a good user-facing message looks like. You write it by hand:

```rust
use std::fmt;

impl fmt::Display for User {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} (#{})", self.name, self.id)
    }
}
```

Implementing `Display` also gets you `.to_string()` for free, via a blanket `impl<T: Display> ToString for T` in the standard library. That's the same one-impl-many-uses pattern as `From`/`Into`.

The rule for error types: implement both. `Debug` for the developer reading a stack trace, `Display` for the message the user sees. `std::error::Error` requires both as supertraits precisely for that reason.

### `Hash` — and its contract with `Eq`

To use a type as a `HashMap` key or a `HashSet` element, you need **`Hash + Eq`** — and since `Eq: PartialEq`, that's three derives in practice:

```rust
#[derive(Hash, PartialEq, Eq)]
struct User {
    id: u64,
    name: String,
}
```

**Why both?** Because hashing alone can't identify a key. A hash narrows the search to one bucket; equality confirms you found the right key *inside* that bucket. Collisions aren't an edge case to engineer around — they're guaranteed by pigeonhole, since a `u64` hash has to represent infinitely many possible `User` values. So lookup is always two steps: hash to find the bucket, then `==` against the candidates in it. Drop `Eq` and the second step has nothing to call.

**The contract between them:**

> If `a == b`, then `hash(a)` must equal `hash(b)`.

Break it and `HashMap` silently loses entries — you insert a key, look it up with an equal key, and get `None`, because the two hashed into different buckets and the equality check never even runs. Deriving `Hash` alongside `PartialEq`/`Eq` keeps them in sync automatically. Hand-writing one but deriving the other is how this goes wrong: if your manual `PartialEq` ignores a field, your `Hash` must ignore it too.

Note the direction — the reverse isn't required. Two unequal values may hash the same; that's just a collision, and `==` sorts it out.

**So is `#[derive(Hash, PartialEq)]` enough?** It compiles fine on its own — but the type still won't work as a key. The bound lives on `HashMap`'s methods, not on the derive:

```rust
impl<K: Eq + Hash, V> HashMap<K, V> { ... }
```

so the error lands at the `insert`/`get` call site rather than on the type, and it's an E0599 ("method exists, but its trait bounds were not satisfied") instead of the E0277 you might expect:

```
error[E0599]: the method `insert` exists for struct `HashMap<K, &str>`,
              but its trait bounds were not satisfied
  |
5 |     struct K(u64, f64);
  |     -------- doesn't satisfy `K: Eq`
7 |     m.insert(K(1, f64::NAN), "data");
  |       ^^^^^^
  |
  = note: the following trait bounds were not satisfied:
          `K: Eq`
help: consider annotating `K` with `#[derive(Eq, PartialEq)]`
```

Worth recognising that shape — "method exists but trait bounds were not satisfied" almost always means a missing derive, not a missing method. Always the three-derive version.

**Why does `HashMap` insist on `Eq` rather than settling for `PartialEq`?** This is the question that makes the whole `Eq` marker trait earn its keep. `PartialEq` doesn't guarantee reflexivity, and a key that isn't equal to itself breaks the map at a basic level:

```rust
#[derive(Hash, PartialEq)]     // no Eq — id is f64
struct Reading { id: f64 }
```

The compiler stops you there, so to actually watch it break you have to lie — hand-write the impls and claim `Eq` anyway:

```rust
#[derive(Debug, Clone, Copy)]
struct Reading { value: f64 }

impl PartialEq for Reading {
    fn eq(&self, other: &Self) -> bool { self.value == other.value }  // NaN != NaN
}
impl Eq for Reading {}                       // the lie: this type is not reflexive
impl Hash for Reading {
    fn hash<H: Hasher>(&self, h: &mut H) { self.value.to_bits().hash(h); }
}
```

Note the `Hash` impl is impeccable — it hashes the raw bits, so two `NaN`s hash identically. The contract "`a == b` implies equal hashes" is upheld. Only reflexivity is broken. Now insert one key and try to use it:

```rust
let key = Reading { value: f64::NAN };
let mut m = HashMap::new();
m.insert(key, "sensor-7");
```

```
len            : 1
get(&key)      : None
contains_key   : false
remove(&key)   : None
```

The entry is in the map — `len` says so — and there is no way to reach it. The lookup hashes to the correct bucket, finds the byte-identical key sitting right there, runs `==` on it, gets `false`, and reports the key absent. It can't be read, can't be removed, and inserting the "same" key again doesn't replace it:

```rust
m.insert(key, "sensor-9");
// len after 2nd  : 2
// [(Reading { value: NaN }, "sensor-7"), (Reading { value: NaN }, "sensor-9")]
```

Two entries with visually identical keys, both unreachable, growing without bound. `Eq` is exactly the promise that this can't happen: **every key is findable by an equal key, including itself.** The bound isn't bureaucracy — it's the map refusing to accept keys it could lose.

`BTreeMap` and `BTreeSet` want `Ord` instead of `Hash + Eq`, for the same underlying reason one level up — they need a total order to navigate the tree, and `PartialOrd` returning `None` would leave a comparison with nowhere to go.

One last thing about that drill snippet, which is a borrow-checker trap rather than a trait one:

```rust
map.insert(user, "some data");
let value = map.get(&user);      // error: borrow of moved value
```

`insert` takes the key **by value**, so `user` is moved into the map and can't be used afterwards. Fix it by looking up a fresh equal key, deriving `Clone` and inserting `user.clone()`, or keying the map on something cheap like `user.id`. The last option is usually the right one — small `Copy` keys with the full struct as the *value* is the more common shape.

## Interior mutability

`Cell<T>`, `RefCell<T>` and `OnceCell<T>` all let you mutate through a `&T` instead of a `&mut T`. All three wrap `UnsafeCell` underneath, all three are `!Sync`. The difference is how they keep aliasing safe.

### `Cell`: move values in and out

`Cell<T>` never hands out a reference to its interior. No reference means nothing to alias, so no checking is needed. Zero runtime cost, can't panic.

```rust
let c = Cell::new(5);
c.set(10);              // no &mut needed
let v = c.get();        // requires T: Copy
let old = c.replace(7); // works for non-Copy too
let owned = c.take();   // requires T: Default
```

The catch is no in-place mutation. To modify a `Cell<Vec<i32>>` you take it out, push, and set it back.

### `RefCell`: real references, checked at runtime

`RefCell<T>` keeps a borrow counter. `borrow()` gives a `Ref<T>`, `borrow_mut()` gives a `RefMut<T>`, and the count is decremented when those guards drop.

```rust
let rc = RefCell::new(vec![1, 2, 3]);
rc.borrow_mut().push(4);
println!("{}", rc.borrow().len());

let _a = rc.borrow();
let _b = rc.borrow_mut();  // panics: already borrowed
```

Costs a word of storage plus a branch per borrow, and violations panic at runtime instead of failing to compile. `try_borrow` / `try_borrow_mut` return a `Result` if you'd rather handle it.

|  | `Cell` | `RefCell` | `OnceCell` |
|---|---|---|---|
| Access | get/set whole value | `&`/`&mut` to interior | `&` after first write |
| Cost | free | borrow flag + check | one `Option` check |
| Failure | can't fail | panics on bad borrow | second `set()` returns `Err` |
| Good for | small `Copy` types | large or non-`Copy` types | write-once / lazy init |

Rule of thumb: `Cell` first for `Copy` scalars, it's strictly cheaper and can't blow up. `RefCell` when you need to operate on the value in place, which is why `Rc<RefCell<T>>` is the standard shape for shared mutable graphs.

If you hold a `&mut Cell<T>` or `&mut RefCell<T>`, both have `get_mut()`, which is free and statically checked. The runtime machinery only exists on the shared path. Thread-safe analogues are `Mutex` / `RwLock`.

### `OnceCell`: write once, then it's frozen

`OnceCell<T>` is the third shape, and it trades generality for something the other two can't do: it hands out a `&T` that stays valid.

It starts empty and can be filled exactly once. After that the value never moves and never changes, so a plain reference to the interior is safe to give out — there's no possible mutation to alias against.

```rust
use std::cell::OnceCell;

let cell: OnceCell<String> = OnceCell::new();

assert!(cell.get().is_none());          // Option<&String>

cell.set(String::from("hello")).unwrap();   // Ok(()) the first time
assert!(cell.set(String::from("bye")).is_err());  // Err(value) — handed back

let s: &String = cell.get().unwrap();   // a real reference, no guard, no Copy bound
```

`set` returns `Result<(), T>` — on failure you get your value back rather than losing it. The method you'll actually use most is `get_or_init`, which does the check-and-fill in one step:

```rust
struct Parser {
    source: String,
    tokens: OnceCell<Vec<Token>>,
}

impl Parser {
    fn tokens(&self) -> &[Token] {          // &self, returns a borrow
        self.tokens.get_or_init(|| tokenize(&self.source))
    }
}
```

Compare that to the `Cell<Option<u64>>` memoization example further down. `Cell` forces the cached type to be `Copy` and makes you return a copy every call; `OnceCell` caches a `Vec` and lends it out. That's the reason to reach for it: **lazily initialized fields behind `&self`**, where the cached thing is expensive or non-`Copy`.

The catch is in the name — once. There's no `set` after the first, no invalidating the cache, no recomputation. If the value needs to change, you want `Cell` or `RefCell`.

A few relatives worth knowing:

- **`OnceLock<T>`** — the thread-safe version, in `std::sync`. Same API, blocks other threads racing to initialize. This is what you want for a global (`static CONFIG: OnceLock<Config> = OnceLock::new();`), since `OnceCell` is `!Sync` and can't be a `static`.
- **`LazyCell<T, F>` / `LazyLock<T, F>`** — the initializer is baked in at construction, so it fires on first deref instead of at an explicit `get_or_init` call. `LazyLock` is the modern replacement for the `lazy_static!` and `once_cell::sync::Lazy` you'll see in older code.
- The **`once_cell` crate** predates all of these. It's still common in the wild, but for new code the standard library versions are stable and there's no reason to take the dependency.

### Passing them around

The signature is just a shared reference:

```rust
fn solve(counter: &Cell<u64>) {
    counter.set(counter.get() + 1);
}
```

(`ref` is a keyword, so don't name the parameter that.)

There's no stable `update` method, so read-modify-write is manual: `c.set(c.get() * 2)`.

Two conversions worth knowing. `Cell::from_mut` turns a `&mut T` into a `&Cell<T>` for free, when you already have exclusive access but want to hand out several shared-mutable views. And `as_slice_of_cells` turns a `&Cell<[T]>` into a `&[Cell<T>]`, so you can mutate elements while several parts of the code hold the slice.

Don't reach for this too early. If a single caller owns the value, plain `&mut T` is better: compile-time checked, costs nothing. `Cell` earns its place when you need aliasing *and* mutation. The classic case is a memoized field on a struct whose methods take `&self`:

```rust
struct Grid {
    data: Vec<i32>,
    checksum: Cell<Option<u64>>,
}

impl Grid {
    fn checksum(&self) -> u64 {   // &self, not &mut self
        if let Some(v) = self.checksum.get() { return v; }
        let v = self.data.iter().map(|&x| x as u64).sum();
        self.checksum.set(Some(v));
        v
    }
}
```

Callers holding shared references can still call it. That's the whole payoff.

### `Cell` without `get()`

The `Copy` bound is only on `get()` — see the `Copy` and `Clone` section above for why `String` and friends can't have it. `Cell<T>` itself works for any `T`, and the move-out API covers plenty: `take()`, `replace()`, `set()`, `swap()`. The pattern is pull the value out, work on the owned value, put it back.

```rust
struct Collector {
    pending: Cell<Vec<Event>>,
}

impl Collector {
    fn push(&self, e: Event) {
        let mut v = self.pending.take();  // leaves Vec::new() behind
        v.push(e);
        self.pending.set(v);
    }

    fn drain(&self) -> Vec<Event> {
        self.pending.take()               // hand off, reset to empty
    }
}
```

The canonical one is single-threaded async:

```rust
struct Signal {
    waker: Cell<Option<Waker>>,
}

impl Signal {
    fn register(&self, w: Waker) { self.waker.set(Some(w)); }
    fn fire(&self) {
        if let Some(w) = self.waker.take() { w.wake(); }
    }
}
```

Also `Cell<Option<Box<Node>>>` for unlinking nodes in linked structures behind a shared reference, and `front.swap(&back)` for double-buffering — no `Copy`, no clone, no allocation.

One footgun with `take()`: while you hold the value, the cell contains `T::default()`. Anything that reaches back into that cell mid-operation sees an empty value instead of the real one. `RefCell` would panic loudly in the same situation, which is sometimes what you want.

For non-`Copy` types `RefCell` is usually nicer anyway — `self.pending.borrow_mut().push(e)` beats the take-push-set dance. `Cell<T>` for non-`Copy` shines specifically when the operation *is* a move: take it, swap it, hand it off.

### It's `UnsafeCell` all the way down

Every type in this section — `Cell`, `RefCell`, `OnceCell`, and their `sync` counterparts `Mutex`, `RwLock`, `OnceLock` — is a safe wrapper around the same primitive: `UnsafeCell<T>`.

That matters because mutating through a shared reference isn't something you can build yourself out of ordinary Rust. `&T` carries a hard guarantee to the optimizer that the pointee won't change, and the compiler emits `noalias` on that basis. `UnsafeCell<T>` is the *only* thing in the language that opts out of it — it's a compiler-recognized lang item, not a clever library trick.

So the whole hierarchy is one unsafe primitive plus different strategies for keeping the aliasing honest:

| Wrapper | Strategy |
|---|---|
| `Cell` | never hand out a reference at all |
| `RefCell` | count borrows at runtime, panic on conflict |
| `OnceCell` | allow one write, then it's immutable |
| `Mutex` / `RwLock` | block other threads |

Each one takes on the obligation of proving the aliasing rules hold, so your code doesn't have to. Writing a *correct* wrapper is genuinely hard — I'll do a full post on `UnsafeCell`, `noalias`, and what the compiler is actually promising soon.

## Deref coercion

Write enough Rust and you'll hit a moment where a function wants a `&str`, you have a `String`, and passing `&my_string` just... works. No conversion, no `.as_str()`. That's **deref coercion**, and it's worth understanding rather than treating as magic.

```rust
fn greet(name: &str) {
    println!("hello, {name}");
}

let owned = String::from("world");
greet(&owned);   // &String, but the function wants &str — this compiles
```

### A useful mental model

Think of deref coercion as Rust saying:

> "I expected a reference to type `B`, but you gave me a reference to type `A`. If `A` knows how to dereference into `B`, I'll do that automatically."

The common conversions:

```
&String   ──►  &str
&Vec<T>   ──►  &[T]
&Box<T>   ──►  &T
&Rc<T>    ──►  &T
&Arc<T>   ──►  &T
```

No heap allocation or copying happens — it's simply adjusting the view of the existing data through references.

### Why it matters in practice

The payoff is on the API side. If you write a function that takes `&str` instead of `&String`, callers can hand you a `String`, a `&str`, or a string literal and all three work. Take the narrower type and you only accept one of them:

```rust
fn takes_str(s: &str)     { /* accepts &String, &str, and literals */ }
fn takes_string(s: &String) { /* only accepts &String */ }
```

Same rule for slices: prefer `&[T]` over `&Vec<T>` in signatures, since `&Vec<T>` coerces to `&[T]` but not the reverse. This is why idiomatic Rust signatures are full of `&str` and `&[T]` — the borrowed view is strictly more general than the owned container.

The coercion also fires on method calls, which is why `Box<T>` and `Rc<T>` feel transparent:

```rust
let boxed = Box::new(String::from("hi"));
println!("{}", boxed.len());  // Box<String> → String, which has .len()
```

Rust keeps dereferencing until it finds a type that has the method. That chain is what makes smart pointers pleasant to use instead of a wall of `*` characters.

One limit to keep in mind: coercion only goes in the direction `Deref` defines. `&String → &str` is free; going the other way costs an allocation and you have to ask for it explicitly with `.to_string()` or `.to_owned()`.

## Error propagation and `?`

Rust has no exceptions. A function that can fail returns `Result<T, E>` — either `Ok(value)` or `Err(error)` — and the caller has to deal with both arms. Done by hand, that gets verbose fast:

```rust
fn read_config() -> Result<String, io::Error> {
    let contents = match fs::read_to_string("config.toml") {
        Ok(c) => c,
        Err(e) => return Err(e),
    };
    Ok(contents)
}
```

The `?` operator collapses that `match` into one character:

```rust
fn read_config() -> Result<String, io::Error> {
    let contents = fs::read_to_string("config.toml")?;
    Ok(contents)
}
```

### `?` and `Ok(...)` are inverses

This is the part that clicks late for a lot of people. `Ok(...)` converts a successful value into a `Result`. The `?` operator does the opposite: it extracts the value from a `Result`, or returns the error early if there is one.

A nice way to remember it:

```
?         :  Result<T, E>  →  T          (or early Err)
Ok(...)   :  T             →  Result<T, E>
```

So in the function above, `?` unwraps on the way in and `Ok` re-wraps on the way out. That's why almost every fallible function ends with `Ok(something)` — the return type demands a `Result`, and you're handing back a plain value.

Once you see the symmetry, the shape of everyday Rust makes sense:

```rust
fn parse_port() -> Result<u16, Box<dyn Error>> {
    let raw = env::var("PORT")?;    // Result<String, VarError> → String
    let port: u16 = raw.parse()?;   // Result<u16, ParseIntError> → u16
    Ok(port)                        // u16 → Result<u16, _>
}
```

Two different error types flow through that function, and neither is handled explicitly. `?` handles them by leaving.

### Where `?` can be used

`?` only works inside a function whose return type can absorb the early exit — a `Result`, an `Option`, or anything implementing `Try`. Put it in a function returning `()` and you get a compile error, which is the single most common first encounter with the operator:

```rust
fn main() {
    let contents = fs::read_to_string("config.toml")?;
}
```

```
error[E0277]: the `?` operator can only be used in a function that returns
              `Result` or `Option` (or another type that implements `FromResidual`)
 --> src/main.rs:2:52
  |
1 | fn main() {
  | --------- this function should return `Result` or `Option` to accept `?`
2 |     let contents = fs::read_to_string("config.toml")?;
  |                                                     ^ cannot use the `?` operator
  |                                                       in a function that returns `()`
```

Read the error literally and it tells you the fix: `?` needs somewhere to return the `Err` *to*, and `()` has no room for one. The mention of `FromResidual` is the general version — `Result` and `Option` are just the two types in the standard library that implement it.

So the fix is to widen `main`'s return type — `main` is allowed to return a `Result`:

```rust
fn main() -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string("config.toml")?;
    println!("{contents}");
    Ok(())
}
```

Note the `Ok(())` at the end — the unit value wrapped in `Ok`, the same `T → Result<T, E>` move as before, just with nothing interesting inside.

`?` works on `Option` too, with the same shape: it unwraps `Some(v)` to `v` and returns `None` early. What it can't do is mix the two — `?` on an `Option` inside a function returning `Result` won't compile. Convert explicitly with `.ok_or(...)` when you need to cross that boundary.

### Converting error types

The other thing `?` quietly does is call `From::from` on the error. If the function returns `Result<T, MyError>` and you `?` on something producing `io::Error`, it compiles as long as `MyError: From<io::Error>`:

```rust
impl From<io::Error> for MyError {
    fn from(e: io::Error) -> Self {
        MyError::Io(e)
    }
}
```

That single impl is what lets a function with one error type call into libraries with several. `Box<dyn Error>` is the low-ceremony version of the same trick — it accepts any error type, at the cost of losing the ability to match on which one you got. Fine for `main` and small tools; for a library, define a real error enum.

### `?` vs. `unwrap()`

People agonise over this one, but the rule is actually very simple:

- Use **`?`** when you want to let the caller handle the error.
- Use **`unwrap()`** when you're certain failure is impossible (or you deliberately want the program to crash).

```rust
// The caller decides what a missing file means.
fn load(path: &str) -> Result<String, io::Error> {
    let contents = fs::read_to_string(path)?;
    Ok(contents)
}

// This regex is a literal I wrote myself; if it doesn't compile that's a bug,
// not a runtime condition to recover from.
let re = Regex::new(r"^\d+$").unwrap();
```

The dividing line is who has enough context to make a decision. A library function usually doesn't — it can't know whether a missing config file is fatal or expected — so it propagates with `?` and lets the caller choose. A crash, by contrast, is a claim: *this cannot fail, and if it does the program's assumptions are broken and continuing is worse than stopping.*

Where `unwrap()` is genuinely fine:

- Tests — a failed assumption should fail the test loudly.
- Prototypes and one-off scripts, where error handling is noise.
- Invariants you can prove hold, like parsing a hardcoded literal.

Where it isn't: anything reading from the network, filesystem, or user. Those fail routinely and a panic just means the failure gets reported with a worse message.

When you do reach for it, prefer **`expect("...")`** over bare `unwrap()`. Same behaviour, but the panic message says what you assumed instead of leaving a stack trace to decode:

```rust
let port = env::var("PORT").expect("PORT must be set");
```

| Want | Use |
|---|---|
| Propagate the error to the caller | `?` |
| Handle both arms here | `match` |
| Substitute a default on error | `.unwrap_or(default)` |
| Crash on error (prototypes, tests) | `.unwrap()` / `.expect("msg")` |
| Turn `Option` into `Result` | `.ok_or(err)` / `.ok_or_else(...)` |

## Getting started with Serde

Serde splits serialization into two concerns, and understanding the split is most of the battle:

- The **`serde`** crate defines the generic `Serialize`/`Deserialize` traits, plus a `#[derive(...)]` macro (enabled via the `derive` feature) that auto-implements them for your structs.
- **Format-specific crates** like `serde_json` handle the actual encoding and decoding for one format.

So `serde` describes *what* your data looks like structurally, and `serde_json` decides *how* that gets written to bytes. Swapping JSON for YAML or MessagePack means changing the format crate, not your structs.

Once a type derives these traits, converting to and from JSON is two function calls — `serde_json::to_string` and `serde_json::from_str` — both of which return a `Result` that composes cleanly with `anyhow::Result` through the `?` operator described above.

### Basic derive

```rust
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
struct BlogPost {
    id: u32,
    title: String,
}
```

### Deserializing JSON into a struct

```rust
let data = r#"{"id": 1, "title": "Hello, Rust"}"#;
let post: BlogPost = serde_json::from_str(data)?;
println!("{:?}", post);
```

### Serializing a struct back to JSON

```rust
let json = serde_json::to_string(&post)?;
println!("{}", json);
// {"id":1,"title":"Hello, Rust"}
```

### Pretty-printed JSON

```rust
let pretty = serde_json::to_string_pretty(&post)?;
println!("{}", pretty);
```

### Renaming fields to match external JSON conventions

Rust wants `snake_case` fields; most JSON APIs hand you `camelCase`. Rather than compromising your struct's naming, annotate it:

```rust
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BlogPost {
    id: u32,
    post_title: String, // serializes as "postTitle"
}
```

### Skipping optional/empty fields

```rust
#[derive(Debug, Serialize, Deserialize)]
struct BlogPost {
    id: u32,
    title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    subtitle: Option<String>,
}
```

### Required `Cargo.toml` setup

```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
anyhow = "1"
```

### The gotcha: forgetting the `derive` feature

This one costs people an afternoon. Leave the `derive` feature off:

```toml
serde = "1"   # missing features = ["derive"]
```

and the derive macro simply doesn't exist. The confusing part is what the compiler tells you: it reports that your type doesn't implement `Serialize`/`Deserialize` — even though the `#[derive(Serialize, Deserialize)]` attribute is sitting right there in the code. The error points at the symptom, not the cause.

Whenever a derive that's plainly written in your source seems to have had no effect, check the crate's feature flags first.
