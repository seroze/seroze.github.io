---
layout: post
title: "[Rust] 0-1 Rust-CUDA contribution roadmap"
date: 2026-09-13 00:00:00 +0530
categories: compilers
tags: [rust, cuda, gpu, compilers, llvm, ptx, rustc]
author: "Seroze"
published: true
---

I plan to contribute to [Rust-CUDA](https://github.com/Rust-GPU/rust-cuda), and this is the
roadmap I plan to follow.

The goal of this project is to make Rust a first-class citizen for CUDA GPU computing.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The thing I'm deliberately not doing

The obvious plan is to study compilers properly first:

```text
Dragon Book
    ↓
compiler course
    ↓
LLVM documentation
    ↓
MLIR documentation
    ↓
CUDA documentation
    ↓
finally Rust-CUDA
```

Six months of that and I'd have a lot of vocabulary and zero commits. It's a trap, and it's the
comfortable kind of trap because it feels like progress the whole way down.

The loop I want instead is small and repeats:

```text
          ┌──────────────┐
          │  Rust-CUDA   │
          └──────┬───────┘
                 │
           "why does this work?"
                 │
     ┌───────────┼───────────┐
     ▼           ▼           ▼
   CUDA        LLVM        rustc
     │           │           │
     └───────────┼───────────┘
                 ▼
            learn theory
                 │
                 ▼
          modify something
                 │
                 ▼
              observe
                 │
                 └──────► repeat
```

## The stack I'm learning

Everything below is a layer in one pipeline:

```text
              YOUR RUST CODE
                    │
                    ▼
              Rust compiler
                    │
                   MIR
                    │
                    ▼
             code generation
                    │
              LLVM IR / LLVM
                    │
                    ▼
              NVIDIA PTX
                    │
                    ▼
              NVIDIA driver
                    │
                    ▼
                   GPU
```

Rust-CUDA lives across several of those layers at once, which is exactly why it looks
intimidating from outside. But the layers can be learned one at a time, and roughly in this
order:

```text
Rust
 │
 ├── CUDA programming
 │
 ├── PTX
 │
 ├── LLVM IR
 │
 ├── compiler fundamentals
 │
 └── rustc internals
          │
          ▼
      Rust-CUDA
          │
          ▼
   meaningful contributions
```

## Phase 0 — Rust, the compiler-facing dialect

**About 1–2 weeks.** I'm not trying to become a language lawyer. What I need is fluency in the
parts of Rust that GPU crates actually use, which is a different subset from application Rust:
ownership and borrowing, lifetimes at a basic level, traits and generics, both flavours of
macros, `unsafe`, `no_std`, the crate and module system, build scripts, and Cargo.

`no_std` and `unsafe` matter more here than anywhere else, because a GPU kernel has no
allocator, no OS, and no standard library to lean on. The real skill being trained is reading
unfamiliar Rust comfortably — Rust-CUDA is a codebase I'll be reading far more than writing.

## Phase 1 — CUDA itself ✅

**About 2–3 weeks,** and I'm prioritising this above compiler theory. You cannot write a
compiler backend for a target you don't understand, and right now the GPU is the part of the
pipeline I know least about.

So: write actual CUDA kernels. Start where everyone starts:

```c
__global__
void add(float* a, float* b, float* c) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    c[i] = a[i] + b[i];
}
```

Then build the mental model of the execution hierarchy:

```text
GPU
 │
 ├── Grid
 │    │
 │    ├── Block
 │    │    ├── Thread
 │    │    ├── Thread
 │    │    └── Thread
 │    │
 │    └── Block
 │
 └── Block
```

Threads, warps, blocks, grids, SMs. The memory hierarchy — registers, shared, global — plus
coalescing, occupancy, synchronisation and atomics.

I don't need to be a CUDA performance expert at this stage. The bar is narrower than that: when
I read `let tid = thread::index();` in Rust, I should know exactly which piece of physical GPU
machinery that corresponds to.

## Phase 2 — PTX

PTX is NVIDIA's assembly-like intermediate language, and it's the thing Rust-CUDA is ultimately
producing. Roughly, a kernel looks like:

```text
.visible .entry add(
    .param .u64 a,
    .param .u64 b,
    .param .u64 c
)
{
    ...
    ld.global.f32 ...
    add.f32 ...
    st.global.f32 ...
}
```

The moment this phase becomes interesting is when I can hold up `let c = a + b;` next to the PTX
it produced and ask how one became the other. That question is the doorway into compiler
engineering, and it's the habit I most want to build: stop only running programs, start reading
what the compiler emitted.

```text
Rust
 ↓
LLVM IR
 ↓
PTX
```

## Phase 3 — LLVM IR

**About 2–4 weeks.** This is the bridge from normal programming to compiler work. rustc uses
LLVM for code generation, and its own guide describes the pipeline as Rust → HIR → MIR → LLVM
IR → LLVM → machine code.

The goal is being able to read something like this without effort:

```llvm
define float @add(float %a, float %b) {
entry:
    %x = fadd float %a, %b
    ret float %x
}
```

Concepts to actually understand rather than recognise: SSA form, basic blocks, PHI nodes,
control flow, loads and stores, pointer types, calls, intrinsics, metadata and attributes.

And the important part — don't learn this by reading LLVM's documentation. Build something.
LLVM's [Kaleidoscope tutorial](https://llvm.org/docs/tutorial/) walks you through a tiny
language all the way to emitting IR, and I plan to implement it rather than skim it.

## Phase 4 — Compiler fundamentals

**3–6 weeks, running alongside the other phases.** Not a PhD-level course. A mental model, in
three pieces.

The frontend turns text into a tree:

```text
source
 ↓
lexer
 ↓
parser
 ↓
AST
```

The middle-end rewrites an IR into a better IR:

```text
AST
 ↓
IR
 ↓
optimization
 ↓
IR
```

The backend turns IR into instructions:

```text
IR
 ↓
instruction selection
 ↓
register allocation
 ↓
machine code
```

Underneath those: control-flow graphs, SSA, dataflow analysis, dominance, liveness, constant
propagation, dead-code elimination, loop optimisation, instruction selection, register
allocation. I don't need to implement every algorithm. I need to look at a chain like

```text
basic block
      │
      ▼
  SSA value
      │
      ▼
 optimization
      │
      ▼
machine instruction
```

and know what's happening at each arrow.

## Phase 5 — rustc

Now it gets serious. The Rust compiler's pipeline:

```text
Rust source
    │
    ▼
   AST
    │
    ▼
   HIR
    │
    ▼
  THIR
    │
    ▼
   MIR
    │
    ▼
 LLVM IR
    │
    ▼
   LLVM
    │
    ▼
machine code
```

The [rustc dev guide](https://rustc-dev-guide.rust-lang.org/) is the canonical reference for
this architecture, and its codegen chapters are the relevant ones: `rustc_codegen_ssa` holds the
backend-agnostic machinery, `rustc_codegen_llvm` the LLVM-specific parts. A GPU backend is
another consumer of that same split, which is what makes those two crates worth reading
carefully.

MIR is the layer that matters most. And the question I want to be able to answer by the end of
this phase is: why can't Rust-CUDA just compile ordinary Rust to PTX?

The answer is that GPUs impose constraints CPU Rust never has to think about — no allocator, a
different memory model, restricted control flow, a completely different execution environment.
So the real pipeline has a filter in the middle:

```text
Rust language semantics
        ↓
       MIR
        ↓
GPU-specific restrictions
        ↓
     LLVM IR
        ↓
       PTX
```

Understanding that filter *is* the compiler engineering.

## Phase 6 — Read Rust-CUDA

Not "when I'm ready". Clone it now and re-read it after every phase.

The question to hold while reading: what are all the pieces required to make a single Rust CUDA
kernel work? That pulls in `cuda_std`, `cuda_builder`, the proc macros, PTX generation, the CUDA
runtime, device functions, and the host/device boundary. The getting-started docs sketch the
basic shape — a GPU crate built on `cuda_std`, compiled by `cuda_builder`, with CUDA and LLVM
tooling doing the work underneath.

## Phase 7 — Write tiny Rust-CUDA programs

This is where it should click, and it comes before contributing anything. Five kernels, in
increasing order of interest:

1. Vector addition — `C[i] = A[i] + B[i]`
2. Elementwise multiply — `C[i] = A[i] * B[i]`
3. SAXPY — `C[i] = a*A[i] + B[i]`
4. Reduction — `sum(A)`
5. Matrix multiply — `C = A × B`

For every single one, the same routine:

```text
Rust source
     ↓
  build
     ↓
   PTX
     ↓
inspect PTX
     ↓
   run
     ↓
benchmark
```

The inspect and benchmark steps are the ones that teach me something. Running it only proves it
compiles.

## Phase 8 — Get obsessed with generated code

This is the transition from "I know Rust and CUDA" to "I'm becoming a compiler engineer", and
it's mostly a matter of curiosity applied repeatedly to trivial functions.

```rust
fn foo(x: f32) -> f32 {
    x * 2.0 + 1.0
}
```

What MIR does that produce? What LLVM IR? What PTX? What actually executes? Then perturb it —
add explicit parentheses, or split it:

```rust
let y = x * 2.0;
y + 1.0
```

and diff the output at every level. Sometimes nothing changes, and knowing *why* nothing changed
is the lesson. This is worth more than another 500 pages of theory.

## Phase 9 — Start with boring PRs

My first contribution is not going to be a redesign of the codegen architecture. It's going to
be boring, and boring is the point — a boring PR teaches me the review process, the CI, and the
maintainers' taste, at a point where I can't do much damage.

Roughly in order of ambition:

**Documentation.** Wrong instructions, stale dependency versions, broken examples, missing
explanations. A rebooting project always has a backlog of these, and fixing them requires
actually following the instructions, which is useful to me anyway.

**Tests.** Rust input plus expected PTX, or runtime tests that check a kernel's output. Writing
these forces me to learn how the project pins down correctness.

**Small bugs.** Incorrect generated PTX, a missing intrinsic, mishandled types, bad error
messages, build failures, CUDA version compatibility.

**Codegen work.** Once the above is comfortable, this is the actually interesting stuff.

## Phase 10 — Pick a direction

Four specialisations branch off from here, and eventually I'll have to choose.

**A. rustc and LLVM** (`rustc → MIR → LLVM IR → LLVM`) if it turns out I love compiler
internals for their own sake.

**B. GPU compiler** (`Rust → MIR → LLVM IR → PTX → GPU`) — the one most directly relevant to
Rust-CUDA, and my current guess for where I'll land.

**C. GPU runtime and systems** — the host side: memory, kernels, streams, events. More systems
programming than compiler work.

**D. GPU libraries** — cuBLAS, cuDNN, cuFFT bindings and their Rust-native equivalents. More
HPC and library engineering.

I don't need to decide now. I do need to notice which of the earlier phases I enjoyed, because
that's the actual signal.

## A concrete 12-week plan

At roughly 10–15 hours a week:

| Week | Focus | Deliverable |
|------|-------|-------------|
| 1 | Rust internals | a small `no_std` project |
| 2 | CUDA basics | 3 CUDA kernels |
| 3 | GPU architecture | vector and reduction kernels |
| 4 | PTX | read and hand-write tiny PTX |
| 5 | LLVM IR | Kaleidoscope |
| 6 | LLVM optimization | inspect and modify LLVM passes |
| 7 | Compiler fundamentals | CFG and SSA exercises |
| 8 | Rust compiler | understand HIR → MIR |
| 9 | rustc codegen | MIR → LLVM IR experiments |
| 10 | Rust-CUDA | build several kernels |
| 11 | Rust-CUDA internals | trace one kernel's compilation end to end |
| 12 | Contribution | first PR |

Week 12 is not "become a compiler expert". The honest arc is narrower and still worth it:

```text
Week 1   "I don't understand compilers."
            ↓
Week 4   "I understand what PTX is."
            ↓
Week 6   "I can read LLVM IR."
            ↓
Week 8   "I roughly understand MIR."
            ↓
Week 10  "I understand how Rust becomes GPU code."
            ↓
Week 12  "I can find a bug and open a PR."
```

## The one project I want to come out of this

If only one artifact survives these twelve weeks, I want it to be a **Rust → MIR → LLVM IR →
PTX explorer**: a small tool where I write

```rust
fn kernel(x: f32) -> f32 {
    x * x + 2.0
}
```

and see every intermediate form side by side, each transformation annotated with what happened
and why.

```text
Rust:   x * x + 2.0

          ↓

LLVM:   %1 = fmul float %x, %x
        %2 = fadd float %1, 2.0

          ↓

PTX:    mul.f32 ...
        add.f32 ...
```

Two reasons it's the right centerpiece. Building it requires understanding every layer, so it
can't be faked. And it collapses LLVM, MLIR, Triton, PTX, rustc and MIR from a pile of
disconnected words into one pipeline I can point at.

MLIR deliberately doesn't appear anywhere in the plan above. It's not a prerequisite — it's
easier after LLVM IR, because its dialects, transformations, lowering and GPU dialect all assume
you already think in IRs.

## Next action

Nothing on this list, actually. Clone Rust-CUDA, get one kernel running on real hardware, and
trace that single kernel from Rust through MIR and LLVM IR down to PTX. Everything above is
theory until that works once.
