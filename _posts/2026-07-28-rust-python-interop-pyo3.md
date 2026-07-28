---
layout: post
title: "Calling Rust from Python with PyO3"
date: 2026-07-28 00:00:00 +0530
categories: rust
tags: [rust, python, pyo3, maturin, packaging]
author: "Seroze"
published: true
---

*I set out to write a Rust hash map and call it from Python. Getting the Rust right took an afternoon; getting it installed into the right virtualenv took longer.*

This is a companion to [A primer on Rust](/primer-on-rust/) — that post covers the language, this one covers what happens when you try to ship it somewhere else.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The idea

The fastest way to find out whether you actually understand a systems language is to make it talk to something else. So: a key-value store, backed by a plain Rust `HashMap`, callable from Python as if it were a native class. Not because the world needs another key-value store, but because getting two languages to agree on a calling convention forces you to understand both of them a little better.

The tool for this is **PyO3** — a set of Rust macros that generate the CPython C-API glue for you — paired with **maturin**, the build tool that turns a PyO3 crate into something `pip` can install.

## The skeleton

Three macros do all the work:

- `#[pyclass]` turns a struct into a Python type.
- `#[pymethods]` makes the attributes inside an `impl` block — `#[new]`, dunder methods — mean something to Python.
- `#[pymodule]` is the entry point Python's import machinery calls when you write `import <name>`.

```toml
# Cargo.toml
[package]
name = "pickledb"
version = "0.1.0"
edition = "2024"

[lib]
name = "pickledb"
crate-type = ["cdylib"]

[dependencies]
pyo3 = { version = "0.22", features = ["extension-module"] }
```

`crate-type = ["cdylib"]` is the part easiest to forget — without it, cargo builds a normal Rust library that Python can't load at all.

## Two build commands, two purposes

`maturin develop` compiles the crate and drops the result straight into whatever venv is currently active — one command, fast loop, good for iterating inside a single project.

`maturin build --release` instead produces a `.whl` file on disk, meant to be installed into any venv, including ones in a completely different project.

I needed the second one: the plan was to consume this from a separate `pickledb-py-client` project.

## First wall: the system says no

Trying to `pip install` the freshly built wheel straight into a plain shell got refused outright:

```console
$ pip install ./target/wheels/pickledb-0.1.0-*.whl
error: externally-managed-environment
× This environment is externally managed
╰─> ... create a virtual environment using python3 -m venv path/to/venv
```

This is Debian/Ubuntu's [PEP 668](https://peps.python.org/pep-0668/) guard rail: it refuses to let pip write into the system Python's `site-packages`, on purpose. It's not a permissions bug to work around with a flag — it's telling you exactly what to do: use a venv.

## The macro that has to be there

One bug worth calling out, because it fails in a confusing way: the `impl` block was missing `#[pymethods]`. Without it, `#[new]` and the dunder methods are just inert attributes on a plain Rust `impl` — PyO3 never sees them, and depending on the edition, rustc won't even compile it.

```rust
// src/lib.rs
use pyo3::prelude::*;
use std::collections::HashMap;

#[pyclass]
struct PickleDB {
    map: HashMap<String, String>,
}

#[pymethods]
impl PickleDB {
    #[new]
    fn new() -> Self {
        PickleDB { map: HashMap::new() }
    }

    fn set(&mut self, key: String, value: String) {
        self.map.insert(key, value);
    }

    fn get(&self, key: String) -> Option<String> {
        self.map.get(&key).cloned()
    }

    fn remove(&mut self, key: String) -> Option<String> {
        self.map.remove(&key)
    }

    fn __len__(&self) -> usize {
        self.map.len()
    }

    fn __contains__(&self, key: String) -> bool {
        self.map.contains_key(&key)
    }
}

#[pymodule]
fn pickledb(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<PickleDB>()?;
    Ok(())
}
```

Worth noting how little ceremony the method bodies need: `Option<String>` becomes `None` on the Python side automatically, and `&mut self` maps onto ordinary mutating method calls. PyO3 handles the conversions at the boundary. The `.cloned()` in `get` is there because `String` isn't `Copy` and the map keeps owning its values — the primer's [`Copy` and `Clone`](/primer-on-rust/#copy-and-clone--why-string-isnt-copy) section covers why.

## It works

Rebuild, install into the venv, and:

```console
$ python -c "
import pickledb
db = pickledb.PickleDB()
db.set('a', '1')
print(db.get('a'))
print(len(db))
print('a' in db)
"
1
1
True
```

Six lines of Python driving a Rust `HashMap`, with `len()` and `in` behaving exactly as they would on a native dict.

## What actually mattered

- `#[pymethods]` is what makes `#[new]` and dunder methods real in PyO3. A plain `impl` block is just Rust — PyO3 never looks at it.
- `crate-type = ["cdylib"]` is non-negotiable. Without it you get a Rust library Python cannot load.
- `maturin develop` is for iterating inside one project's venv. `maturin build` + `pip install <wheel>` is how a Rust extension crosses into a different project entirely.

*pyo3 0.22 · maturin · rust edition 2024 — written while debugging a hash map that just wanted to say hello to Python.*
