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
