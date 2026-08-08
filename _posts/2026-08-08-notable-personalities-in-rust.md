---
layout: post
title: "Notable personalities in Rust"
date: 2026-08-08 00:00:00 +0530
categories: rust
tags: [rust, rustc, open_source, compiler_performance]
author: "Seroze"
published: true
---

*A running list of people worth following in the Rust world — compiler, infrastructure,
tooling and governance — added as I come across their work.*

---

## [Jakub Beránek (Kobzol)](https://kobzol.github.io/)

Rust maintainer from the Czech Republic, working on Rust full time as a [Sovereign Tech
Fellow](https://www.sovereign.tech/programs/fellowship). He sits on the **Infrastructure
team**, was invited to the **compiler team** in 2025, and was elected to the **Leadership
Council** the same year. GitHub: [@Kobzol](https://github.com/Kobzol).

His beat is the unglamorous half of a language project: the build system, CI, the merge
queue, and compiler performance. Things he maintains or built:

- [**rustc-perf**](https://github.com/rust-lang/rustc-perf) — the Rust compiler benchmark
  suite, the thing that decides whether a compiler PR is a regression. Extended with ARM
  support (with James Barford at ARM).
- [**bors**](https://github.com/rust-lang/bors) — the new merge bot that replaced homu.
- [**bootstrap**](https://github.com/rust-lang/rust/tree/master/src/bootstrap) — the rustc
  build system, which he's been refactoring steadily; among other things he rewrote its
  `ci.py` in Rust.
- **triagebot**, **josh-sync** (making git subtree syncs less painful), plus his own
  [cargo-pgo](https://github.com/Kobzol/cargo-pgo) and
  [cargo-wizard](https://github.com/Kobzol/cargo-wizard) for squeezing performance out of
  Rust builds.

The post that got him on this list: [**1160 PRs to improve Rust in
2025**](https://kobzol.github.io/rust/rustc/2026/01/05/my-rust-contributions-in-2025.html) —
a year in review of what that maintenance actually consists of. Highlights: helping stabilize
**LLD as the default linker on Linux**, making **rustup ~3x faster** with a surprisingly small
change, plus ~20% off rust-analyzer and ~5% off Clippy; moving CI off the old
`rust-lang-ci/rust` repo; running Rust's **Google Summer of Code** program with 19 projects;
and helping design the Rust Foundation's Maintainer Fund. He's blunt that the PR count is a
bad proxy — "opening pull requests is just a fraction" of the job next to reviews, design
discussions and community work.

**Why I flagged it:** he writes the kind of post almost nobody writes — a concrete,
numbers-attached account of what keeping a major language healthy costs, from someone doing
it full time. His other posts ([why doesn't Rust care more about compiler
performance?](https://kobzol.github.io/rust/rustc/2025/06/09/why-doesnt-rust-care-more-about-compiler-performance.html),
[how memory-safety CVEs differ between Rust and
C/C++](https://kobzol.github.io/rust/2026/06/15/how-memory-safety-cves-differ-between-rust-and-c-cpp.html),
binary size vs. debuginfo) are the same: specific, measured, and about the parts of the
ecosystem that don't trend.

---

*More entries to come.*
