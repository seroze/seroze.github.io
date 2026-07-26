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
