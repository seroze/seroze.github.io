---
layout: post
title: "[Rust] Lifetimes in Rust"
date: 2026-09-17 00:00:00 +0530
categories: rust
tags: [rust, lifetimes, borrow_checker, serialization]
author: "Seroze"
published: true
---

*Notes from writing a small binary event encoder, where every lifetime question I'd been
hand-waving past finally had to be answered.*

This is a companion to [A primer on Rust](/primer-on-rust/) — that post is the running
reference, this one is the part of it I kept getting wrong in practice.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Why `impl<'a> Reader<'a>` says `'a` twice

The code that started this was a byte reader over a borrowed buffer:

```rust
pub struct Reader<'a> {
    buf: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    #[inline]
    pub fn new(buf: &'a [u8]) -> Reader<'a> {
        Reader { buf, pos: 0 }
    }
}
```

The `impl<'a> Reader<'a>` line looks like a stutter. It isn't — the two `'a`s are doing
completely different jobs, and it's the same split you already accept without thinking for
type parameters:

```rust
impl<T> Foo<T> {
    fn new(x: T) -> Foo<T> {
        Foo(x)
    }
}
```

`impl<T>` *introduces* `T`. `Foo<T>` *uses* it. You can't use a parameter you haven't
introduced, so the name has to appear twice. Lifetimes are parameters too, so they play by
the same rule: `impl<'a>` brings `'a` into scope for the whole block, and `Reader<'a>` is
the thing being implemented for that particular `'a`.

Read out loud, `impl<'a> Reader<'a>` is "for every possible lifetime `'a`, here are the
methods on a `Reader` that borrows for `'a`."

## What `new` is actually promising

The signature inside the block is where the interesting constraint lives:

```rust
pub fn new(buf: &'a [u8]) -> Reader<'a>
```

Both sides mention `'a`, which welds them together: give me a slice that's valid for `'a`,
and you get back a `Reader` that's valid for exactly that long and no longer. The `Reader`
cannot outlive the buffer it points into, and the compiler now knows it without being told
anything else.

```
buf: &'a [u8]
       ↓
   Reader<'a>
       │
       └── holds &'a [u8]
```

That's the whole point of the lifetime parameter on the struct. `Reader` isn't a self-
contained value; it's a cursor into somebody else's memory, and `'a` is the label on the
leash.

## `&'static str` doesn't need a parameter

Elsewhere in the same file I had this, and it surprised me that it compiled with no
lifetime parameter at all:

```rust
#[derive(Clone, Copy, Debug)]
pub struct Field {
    pub name: &'static str,
    pub ty: FieldType,
}
```

`Field` holds a reference, same as `Reader` does. So why does one need `<'a>` and the other
doesn't?

Because `'a` and `'static` are different kinds of thing. `'a` is a *variable* — a
placeholder for some lifetime the caller picks, which is exactly why it has to be declared
as a parameter. `'static` is a *constant*: one specific, already-known lifetime meaning
"valid for the entire run of the program". There's nothing for the caller to choose, so
there's nothing to parameterise over.

Had I written it the other way,

```rust
pub struct Field<'a> {
    pub name: &'a str,
    pub ty: FieldType,
}
```

then every `Field` would be tethered to whatever string it borrowed from, and every
function handing one back would have to thread that lifetime through:

```rust
fn make_field<'a>(name: &'a str) -> Field<'a> {
    Field { name, ty: FieldType::U64 }
}
```

With `&'static str`, the names are string literals baked into the binary, so a `Field` is
just a plain value that happens to contain a pointer. That's what makes this work:

```rust
const FIELDS: &[Field] = &[
    Field::new("price", FieldType::U64),
    Field::new("quantity", FieldType::U32),
];
```

and it's what lets the schema hang off the trait as static metadata rather than being
rebuilt per event:

```rust
pub trait Event {
    const TYPE_ID: u16;
    const NAME: &'static str;

    fn schema() -> &'static [Field];
    fn encoded_len(&self) -> usize;
    fn encode(&self, w: &mut Writer<'_>);
}
```

The schema outlives every individual event; the events come and go.

So the rule I landed on: a struct needs a lifetime parameter when the lifetime of what it
borrows is *variable*. If you've pinned it to `'static`, there's nothing left to vary.

## `Writer<'_>`: naming a lifetime you don't care about

That last trait method is worth a second look:

```rust
fn encode(&self, w: &mut Writer<'_>);
```

`Writer` has a lifetime parameter, so it has to appear somewhere — but `encode` genuinely
doesn't care what it is. It writes some bytes and returns. `'_` says "there's a lifetime
here, infer it, I have no opinion."

Compare what happens if you name it out of habit:

```rust
fn encode<'a>(&self, w: &'a mut Writer<'a>);
```

This is a much stronger claim: the borrow of the `Writer` must last as long as the buffer
the `Writer` points into. In practice that tends to mean the caller lends out the `Writer`
for the rest of the buffer's life and can't touch it again afterwards — which is the
opposite of what you want from a method you call once per field. Naming a lifetime is a
constraint, so don't name one unless you mean it.

## How this worked before NLL

Everything above assumes the borrow checker Rust has today. It's worth knowing that it
used to be noticeably dumber, because a lot of older Rust code — and a lot of the advice
you'll find while searching — is shaped around the old rules.

The old borrow checker tied a borrow to the *lexical scope* it was created in. A `&x`
stayed live until the closing brace of the block containing it, whether or not you ever
touched the reference again. Non-lexical lifetimes (NLL) replaced that with something
closer to what you'd guess by reading the code: a borrow lasts until its **last use**.

The canonical example is three lines long:

```rust
fn main() {
    let mut x = 10;

    let r = &x;
    println!("{}", r);

    let m = &mut x;
    *m += 1;
}
```

This compiles today. `r` is dead after the `println!`, so the shared borrow is over by the
time `&mut x` happens and the two never overlap. Pre-NLL, the compiler saw `r` declared in
`main`'s body, extended its borrow to the end of `main`, and rejected the program:

```
error[E0502]: cannot borrow `x` as mutable because it is also borrowed as immutable
```

Which is a confusing error to get, because the immutable borrow it's complaining about is
plainly finished.

Here's the difference, with the borrow drawn as a bar:

```
                      pre-NLL              NLL
let r = &x;             ┃                   ┃
println!("{}", r);      ┃                   ┗━ borrow ends
let m = &mut x;         ┃  ← error          ok
*m += 1;                ┃
}                       ┗━ borrow ends
```

### The block trick

This is why older Rust is sprinkled with blocks that seem to exist for no reason:

```rust
fn main() {
    let mut x = 10;

    {
        let r = &x;
        println!("{}", r);
    } // borrow ends here, because the scope does

    let m = &mut x;
    *m += 1;
}
```

The block isn't doing anything at runtime. It's there to hand the borrow checker a lexical
boundary it could actually see, since that was the only vocabulary it had. If you find
yourself writing one of these today, you almost certainly don't need it — the cases where
an explicit scope still helps are ones where a value has a `Drop` impl, because dropping
counts as a use and the compiler won't move it earlier for you.

### The one that actually hurt

The three-line example is a toy. This is the shape that made NLL worth doing:

```rust
let mut data = vec![1, 2, 3];

let first = &data[0];
println!("{}", first);

data.push(4);
```

Perfectly safe — `first` is done being read before anything mutates the vector — and
perfectly rejected by the old checker. You'd hit this constantly in real code: grab a
reference into a collection, use it, then want to mutate the collection. The workaround
was either an artificial block or copying the value out, and neither one is what you
meant.

Conditionals made it worse, because the borrow got extended past branches that couldn't
possibly use it:

```rust
let mut map: HashMap<String, Vec<u32>> = HashMap::new();

match map.get_mut("key") {
    Some(v) => v.push(1),
    None => {
        map.insert("key".to_string(), vec![1]); // pre-NLL: still borrowed
    }
}
```

In the `None` arm the mutable borrow from `get_mut` obviously isn't live — there's no `v`
in scope to use it. The old checker didn't care; the borrow belonged to the enclosing
scope, so the `insert` was an error. This particular one is famous enough to have a name,
and NLL only *partially* fixed it: the version above compiles now, but the closely related
one where you return the reference out of the match still doesn't. That remaining hole is
what Polonius, the next iteration of the borrow checker, is meant to close.

### What NLL did not change

Two things are easy to over-read here.

It didn't touch the aliasing rules. You still get many shared references *or* one mutable
reference, never both. NLL only changed the compiler's answer to "is this borrow still
live?", not what it does with the answer.

And it didn't remove explicit lifetime annotations. A signature like

```rust
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str
```

means exactly what it always meant: the returned reference is tied to the inputs. That
`'a` describes a relationship across a function boundary, which is caller-visible API, and
no amount of cleverness inside the function body can infer it. NLL is about reasoning
*within* a function body. Everything earlier in this post about `Reader<'a>` and
`impl<'a>` is unaffected by it.

### Why the switch was a big deal internally

The old checker walked the AST and asked "which lexical scope does this borrow belong to?"
NLL threw that out and works on the control-flow graph instead: a lifetime becomes a set
of program points where the reference might still be used, computed by a liveness analysis
and solved as a constraint problem. That's why it handles branches and loops sensibly —
"last use" is a genuinely path-dependent question, and an AST walk can't ask it.

If that "a lifetime is a set of program points" line still reads like a slogan rather than
a definition, leddoo's [but what is `'a` lifetime?](https://www.youtube.com/watch?v=gRAVZv7V91Q)
is twelve minutes on exactly that framing. It's built on Niko Matsakis's
[alias-based formulation of the borrow checker](https://smallcultfollowing.com/babysteps/blog/2018/04/27/an-alias-based-formulation-of-the-borrow-checker/),
which is the longer written version if you'd rather read than watch.

NLL shipped in Rust 1.31 for the 2018 edition and reached the 2015 edition in 1.36, so
anything you compile today has it. The practical takeaway is smaller than the machinery:
if you're reading Rust from before 2018 and wondering why it's full of tiny bare blocks,
now you know, and you can delete most of them.

## Three bugs that weren't lifetime bugs at all

While staring at lifetimes I nearly missed the actual compile errors, which were dumber:

**A second `struct` where an `impl` belonged.** I'd written `pub struct Writer<'a> { ... }`
twice, the second one meant to be `impl<'a> Writer<'a> { ... }`. The error message points at
a duplicate definition, not at anything to do with borrowing.

**A method outside its `impl` block.** `FieldType::code` had drifted below the closing brace,
which makes it a free function that takes `self` — and `self` outside an `impl` means
nothing. Easy to miss when the block is long enough to scroll.

**Slicing that panics on short input.** Every read looks like this:

```rust
pub fn u64(&mut self) -> u64 {
    let v = u64::from_le_bytes(self.buf[self.pos..self.pos + 8].try_into().unwrap());
    self.pos += 8;
    v
}
```

If fewer than eight bytes remain, the *slice* panics before `try_into` ever runs. The same
goes for `Writer` if the caller hands it a buffer that's too small. For an internal format
where the encoder sizes the buffer with `encoded_len()`, that's a defensible bounds check —
it's a bug in my code, not in the input. The moment those bytes arrive from a file or a
socket, it becomes a denial of service, and the reads need to return
`Result<u64, DecodeError>` instead. Worth deciding on purpose rather than by default.

## The skeleton, cleaned up

For reference, here's the shape the whole thing settled into:

```rust
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FieldType {
    U8,
    U16,
    U32,
    U64,
    I64,
    /// A `u32` index into the segment's string table.
    StrId,
}

impl FieldType {
    pub const fn size(self) -> usize {
        match self {
            FieldType::U8 => 1,
            FieldType::U16 => 2,
            FieldType::U32 | FieldType::StrId => 4,
            FieldType::U64 | FieldType::I64 => 8,
        }
    }

    pub const fn code(self) -> u8 {
        match self {
            FieldType::U8 => 1,
            FieldType::U16 => 2,
            FieldType::U32 => 3,
            FieldType::U64 => 4,
            FieldType::I64 => 5,
            FieldType::StrId => 6,
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct Field {
    pub name: &'static str,
    pub ty: FieldType,
}

impl Field {
    pub const fn new(name: &'static str, ty: FieldType) -> Field {
        Field { name, ty }
    }
}

pub fn schema_len(fields: &[Field]) -> usize {
    fields.iter().map(|f| f.ty.size()).sum()
}

pub struct Writer<'a> {
    buf: &'a mut [u8],
    pos: usize,
}

impl<'a> Writer<'a> {
    #[inline(always)]
    pub fn new(buf: &'a mut [u8]) -> Writer<'a> {
        Writer { buf, pos: 0 }
    }

    #[inline(always)]
    pub fn u8(&mut self, v: u8) {
        self.buf[self.pos] = v;
        self.pos += 1;
    }

    #[inline(always)]
    pub fn u32(&mut self, v: u32) {
        self.buf[self.pos..self.pos + 4].copy_from_slice(&v.to_le_bytes());
        self.pos += 4;
    }

    #[inline(always)]
    pub fn u64(&mut self, v: u64) {
        self.buf[self.pos..self.pos + 8].copy_from_slice(&v.to_le_bytes());
        self.pos += 8;
    }

    #[inline(always)]
    pub fn i64(&mut self, v: i64) {
        self.u64(v as u64)
    }

    #[inline(always)]
    pub fn written(&self) -> usize {
        self.pos
    }
}

pub struct Reader<'a> {
    buf: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    #[inline]
    pub fn new(buf: &'a [u8]) -> Reader<'a> {
        Reader { buf, pos: 0 }
    }

    #[inline]
    pub fn u8(&mut self) -> u8 {
        let v = self.buf[self.pos];
        self.pos += 1;
        v
    }

    #[inline]
    pub fn u32(&mut self) -> u32 {
        let v = u32::from_le_bytes(self.buf[self.pos..self.pos + 4].try_into().unwrap());
        self.pos += 4;
        v
    }

    #[inline]
    pub fn u64(&mut self) -> u64 {
        let v = u64::from_le_bytes(self.buf[self.pos..self.pos + 8].try_into().unwrap());
        self.pos += 8;
        v
    }

    #[inline]
    pub fn i64(&mut self) -> i64 {
        self.u64() as i64
    }

    #[inline]
    pub fn remaining(&self) -> usize {
        self.buf.len() - self.pos
    }
}
```

The `i64` round trip through `u64` is fine, incidentally — `as` between same-width integers
keeps the two's-complement bits untouched, so `-1` goes out as `FFFFFFFFFFFFFFFF` and comes
back as `-1`.

One assumption worth writing down: `schema_len` sums only the *value* widths, so for a
`U64` plus a `U32` it returns 12. That's correct for a bare `[value][value][value]` wire
format. The day the format grows per-field type tags, this function has to grow with it.

## What I'd tell myself a week ago

- `impl<'a> Type<'a>` — the first `'a` declares, the second uses. Same as `impl<T> Foo<T>`.
- Repeating a lifetime across a signature is how you say "these two things must live
  together". Don't repeat it by accident.
- `'static` is a lifetime, not a lifetime *parameter*. A struct that only holds `&'static`
  references doesn't need `<'a>`.
- `'_` is the honest thing to write when a lifetime exists but you have no constraint on it.
- A borrow ends at its last use, not at the closing brace. That's NLL; before 2018 it
  really did end at the brace, which is why old code is full of blocks that do nothing.
