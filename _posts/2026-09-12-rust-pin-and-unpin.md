---
layout: post
title: "Pin and Unpin in Rust"
date: 2026-09-12 00:00:00 +0530
categories: rust
tags: [rust, pin, async, futures, memory_safety]
author: "Seroze"
published: true
---

`Pin` has a reputation for being the part of Rust where people quietly give up. I don't
think it's actually hard — I think it's badly named, and the name does most of the damage.
Three things sound true about `Pin` and are not: that it makes memory immovable, that
`Unpin` means "cannot be pinned", and that you need it whenever a struct holds a pointer
into itself. Once those three are gone, what's left is a fairly small idea.

This is my attempt to write down that small idea properly, in the order I wish someone had
explained it to me.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## What a move actually is

Before anything about pinning makes sense, it's worth being precise about what a move is in
Rust, because the word carries more drama than the operation deserves.

A move is a `memcpy` of a value's bytes from one address to another, after which the
original location is treated as dead. That's it. No destructor runs, no allocation happens,
nothing gets fixed up. When you write `let b = a;` for a `struct` that isn't `Copy`, the
compiler copies the bytes to `b`'s stack slot and stops letting you touch `a`.

The crucial consequence is that a move changes the *address* of the value. Everything
`Pin` exists for follows from that one sentence.

### Where moves come from

"Move" shows up in more syntactic shapes than people expect, and `Pin` is easier to reason
about once you can spot all of them. Take a deliberately non-`Copy` type:

```rust
struct Foo {
    x: i32,
}

let a = Foo { x: 10 };
```

**1. Assignment.** The plainest case:

```rust
let b = a;
```

```text
before:                     after:

a ──► Foo { x: 10 }         b ──► Foo { x: 10 }
                            a     ✗ unusable
```

Worth dwelling on: `b` is a *different storage location*. Semantically the bytes are copied
into a new stack slot and `a`'s slot is dead — the value's address changed even though
nothing dramatic-looking happened. LLVM often coalesces the two slots so no instruction is
actually emitted, but that's an optimization you can never rely on. As far as the language
is concerned, an assignment relocates the value.

**2. Passing by value.**

```rust
fn consume(foo: Foo) {}

consume(a);
```

```text
a
│
│ move
▼
foo: Foo
```

`a` is moved into the parameter and can't be used afterwards.

**3. Returning by value.**

```rust
fn make_foo() -> Foo {
    let a = Foo { x: 10 };
    a
}
```

`a` is moved out of the frame that's about to be destroyed and into the caller's slot.

**4. Moving out through a dereference.** This is the interesting one:

```rust
fn move_it(x: &mut Foo) {
    let y = *x;   // error[E0507]: cannot move out of `*x`
}
```

`*x` means "the `Foo` stored at the location `x` points to", and `let y = *x;` means "take
that `Foo` and move it into `y`":

```text
x ──────► Foo
          │
          │ move
          ▼
          y
```

The compiler rejects it, because it would leave the location `x` points at uninitialized
while `x` is still alive and usable. (Had `Foo` been `Copy`, the same line would compile —
as a copy, leaving the original intact. `Copy` types simply don't have this problem.)

Which is exactly why `mem::replace` exists:

```rust
let y = std::mem::replace(x, Foo { x: 0 });
```

```text
before:                     after:

x ──► Foo { x: 10 }         x ──► Foo { x: 0 }
                            y ──► Foo { x: 10 }
```

The old value moves out and a fresh one moves in, so the location never becomes
uninitialized. `mem::swap` and `mem::take` are the same trick with a different shape.

This is the single most important fact for understanding `Pin`, so it's worth saying
flatly: **an unrestricted `&mut T` is a license to relocate the `T`.** Not because
dereferencing moves anything on its own, but because `&mut T` is the key that
`mem::replace` and friends require.

**5. Moving a field out of a struct.**

```rust
struct Pair {
    a: Foo,
    b: Foo,
}

let p = Pair { a: Foo { x: 1 }, b: Foo { x: 2 } };
let a = p.a;
```

```text
p
├── a ──► moved ❌
└── b ──► still there ✅
```

This is a *partial move*: `p.a` is gone, `p.b` is still usable on its own, and `p` as a
whole no longer is. Note that this only works because you own `p` — you can't partially
move out of a borrow.

**6. Moving out of a tuple.** Same thing, different syntax:

```rust
let p = (Foo { x: 1 }, Foo { x: 2 });
let a = p.0;
```

**7. Moving out of an enum, via pattern matching.**

```rust
enum MyEnum {
    A(Foo),
    B,
}

let e = MyEnum::A(Foo { x: 10 });

if let MyEnum::A(foo) = e {
    // the Foo was moved out of `e` and into `foo`
}
```

Patterns bind by value when they can, so matching on an owned value moves its contents out.

**8. Moving an element out of a collection.** This one surprises people:

```rust
let v = vec![Foo { x: 1 }];
let x = v[0];   // error[E0507]: cannot move out of index
```

Indexing goes through the `Index` trait, which hands back a `&Foo` — and the compiler won't
let you tear a hole in the middle of a `Vec`. You need an operation designed to fix the
hole up:

```rust
let mut v = vec![Foo { x: 1 }];
let x = v.remove(0);
```

```text
before:                after:

Vec                    x ──► Foo
┌───────┐
│ Foo   │              Vec
└───────┘              ┌───────┐
                       │       │
                       └───────┘
```

`pop`, `drain`, `swap_remove` and `into_iter` are the same idea: each either takes
`&mut self` and repairs the container, or consumes it outright.

### Reading versus taking

The whole list collapses into one distinction:

```text
READING a value                TAKING ownership
      ↓                               ↓
    &Foo                             Foo
      ↓                               ↓
 does NOT move            DOES move (unless Foo: Copy)
```

So `let y = &*x;` reborrows and moves nothing, while `let y = *x;` tries to take ownership
of what's there. One character apart, completely different operations.

### The two ways in, and why Pin cares

Every entry on that list is one of two things: either you **owned** the value (assignment,
passing, returning, field and tuple extraction, pattern matching), or you held a **`&mut`**
to it and used an API that swaps something in behind you (`mem::replace`, `mem::swap`,
`mem::take`, `Vec::remove`).

```rust
let mut a = String::from("hello");
let mut b = String::from("world");

std::mem::swap(&mut a, &mut b);                      // a and b exchange bytes
let old = std::mem::replace(&mut a, String::new());  // a's bytes move out
let taken = std::mem::take(&mut a);                  // same, using Default
```

There is no third way. If you have neither ownership nor a `&mut`, you cannot relocate the
value, full stop. Hold onto that, because it *is* the mechanism behind `Pin` — there's no
deeper magic underneath, and it's the entire reason the API distinguishes `Pin<&mut T>`
from a plain `&mut T`.

## The problem: values that point at themselves

A value that stores a pointer into its own bytes breaks the moment it's moved. The bytes
get copied to a new address, the internal pointer still holds the old one, and now it
dangles. The compiler can't fix this up for you; it doesn't know which of your fields are
pointers into yourself, and Rust's move semantics are deliberately dumb-and-fast.

Here's the shape of the problem:

```rust
struct SelfRef {
    data: [u8; 16],
    slice: *const u8,   // points into `data` above
}
```

Move a `SelfRef` and `slice` points into the husk of the old stack slot. Nothing in the
type system stops you.

### The non-example that trips everyone up

This is the part I got wrong for a long time, so it deserves its own paragraph. Consider:

```rust
struct Parsed {
    buf: Vec<u8>,
    first_word: &'??? str,   // wants to borrow from buf's contents
}
```

Does moving `Parsed` invalidate `first_word`? **No.** `Vec` stores its elements on the
heap; the struct itself holds only a pointer, a length and a capacity. Moving the struct
copies that three-word triple to a new address, and the heap buffer it describes doesn't
budge. The address `first_word` holds stays perfectly valid.

The reason you can't write that struct has nothing to do with moves. It's that Rust has no
way to spell a `'self` lifetime — a borrow of a sibling field. That's a type-system
limitation, and the fixes are type-system fixes: store an index range instead of a
reference, or reach for `self_cell`, `ouroboros` or `yoke` if you really want the
reference. `Pin` will not help you here, and reaching for it is a sign you've
misdiagnosed the problem.

`Pin` is for the other case — when the pointee lives *inline in the struct*, like the
`[u8; 16]` above. Heap-backed indirection is already move-stable. Inline data is not.

### Where this actually happens in practice

Almost nobody writes a `SelfRef` by hand. The reason `Pin` is in the standard library at
all is that the compiler writes them for you, every time you write an `async` block.

```rust
async fn read_twice(f: &mut File) -> io::Result<()> {
    let mut buf = [0u8; 1024];
    f.read_exact(&mut buf).await?;
    process(&buf);
    f.read_exact(&mut buf).await?;
    Ok(())
}
```

`buf` is a local that stays alive across an `.await`, so it becomes a field of the
generated state machine — stored inline, all 1024 bytes of it. The in-flight
`read_exact` future is *also* a field of that state machine, and it holds a `&mut [u8]`
pointing at `buf`. One struct, one field pointing into another field of the same struct.
Self-referential, generated automatically, from code that looks entirely innocent.

That's the whole motivation. `async` made self-referential structs an everyday occurrence
in ordinary Rust, so the language needed a way to say "this value must not move again".

## Pin is a promise, not a mechanism

Here's the sentence that unlocked it for me: `Pin` does not make anything immovable. It is
a wrapper around a pointer, and its only power is refusing to give you a `&mut` to what
that pointer points at.

```rust
pub struct Pin<Ptr> {
    pointer: Ptr,   // roughly; the field is private
}
```

### What "pointer type" means here

`Pin<&mut T>`, `Pin<Box<T>>`, `Pin<Rc<T>>` — the parameter is the *pointer* type, not the
pointee, and that trips people up often enough to be worth spelling out.

In the context of `Pin`, "pointer-like type" has a specific meaning: a type that gives
access to some value through **indirection**. You hold a handle to a `T` rather than owning
the `T` inline. The ones that matter are:

- `&T` and `&mut T`
- `Box<T>`
- `Rc<T>` and `Arc<T>`
- `Pin<Box<T>>` itself — it derefs too, so pinned pointers nest

The struct definition carries no bound, but essentially every useful method on `Pin<Ptr>`
requires `Ptr: Deref` or `Ptr: DerefMut`. That's the operational definition of pointer-like
here: it implements `Deref`, so there's a `Ptr::Target` sitting at the other end of it.

Why is it built this way? Look at where the bytes actually are. Start with an ordinary box:

```text
let x = Box::new(MyStruct);

  stack                         heap

  x ──────────────────────►     MyStruct
  (Box<MyStruct>)
```

`x` is a pointer-like value living in the stack frame. The `MyStruct` it describes lives
somewhere else entirely. Now pin it:

```text
let x = Box::pin(MyStruct);

  stack                         heap

  x ──────────────────────►     MyStruct
  (Pin<Box<MyStruct>>)          ^^^^^^^^ pinned
```

`Pin<Box<MyStruct>>` reads as: *through this pointer, I guarantee the `MyStruct` being
pointed at will not move.* The guarantee is attached to the far end of the arrow, not to
`x`:

```text
Pin<Box<T>>
    ^   ^
    |   the actual value — this is what must not move
    the pointer — this moves around freely
```

And it genuinely does move freely. `x` itself is a normal local you can pass to a function,
return, or store in a struct. `Pin<&mut T>` is even `Unpin`, because `&mut T` is. The
pointer moves; the thing at the far end of it does not.

This is also why there's no such thing as a pinned *value* in Rust — no `Pin<T>` holding a
`T` by value. Pinning is a statement about an address staying stable, and you can only make
that statement from behind a level of indirection. If you had the value directly, you would
by definition be able to move it.

### The mechanism, finally

So how does `Pin` stop moves? Go back to the two ways to move something. `Pin` hides the
owned value behind a pointer, so you can't move it by owning it. And for a `!Unpin` `T`, it
simply refuses to hand out a `&mut T`:

```rust
impl<Ptr: DerefMut> Pin<Ptr> {
    // only when the pointee doesn't care about pinning
    pub fn get_mut(self) -> &mut Ptr::Target
    where Ptr::Target: Unpin { ... }

    // otherwise you're in unsafe territory
    pub unsafe fn get_unchecked_mut(self) -> &mut Ptr::Target { ... }
}
```

No `&mut T` means no `mem::swap`, no `mem::replace`, no `ptr::read`. The grip you'd need
to relocate the value simply isn't available. Nothing about the memory changed — no
allocator flag, no runtime check, no compiler-enforced `!Move` marker. It's an API-level
refusal, and that's genuinely all it is.

What you *can* get is `Pin<&mut T>` for deeper access, and `&T` (shared references can't
move anything, so those are always safe). Once you accept that `Pin` is a promise enforced
by absence — by the things it declines to give you — the rest of the API stops looking
arbitrary.

### Pinned means fixed in place, not frozen

The other half of the guarantee is the half people assume is there and isn't: `Pin` says
nothing whatsoever about mutation. It constrains *where* the value lives, not *what* it
contains.

```text
                PINNED VALUE
                     │
          ┌──────────┴──────────┐
          ↓                     ↓
       mutate                  move
          │                     │
          ✅                    ❌
    same address            different address
```

Mutating a pinned value is completely fine, and in fact it's the normal case. A pinned
future is mutated on every single poll — advancing the state machine is exactly what `poll`
does. What must never happen is relocation, because that's what invalidates the internal
pointers.

```rust
let mut fut = Box::pin(async { /* ... */ });

// mutates the state machine in place, over and over — fine
fut.as_mut().poll(cx);

// there is no operation available here that changes its address
```

So the invariant is *address stability*, not immutability. The bytes at that address change
all the time; the address itself doesn't, from the moment the value is pinned until it is
dropped. `&mut T` is withheld not because mutation is dangerous, but because `&mut T` is
the handle that `mem::swap` and friends need — it's collateral damage, and it's why
in-place mutation of a `!Unpin` value has to be routed through `Pin<&mut T>` (or
`pin-project`, for fields that aren't structurally pinned) instead.

## Unpin is the worst-named trait in the standard library

`Unpin` is an auto-trait, implemented for essentially every type, and it means:

> I do not care about being pinned. Pin me if you like, it changes nothing.

It does **not** mean "cannot be pinned", and it does not mean "can be un-pinned". If the
trait had been called `MoveAnyTime` or `DontCareAboutPinning`, half the confusion around
`Pin` would never have existed.

For `T: Unpin`, `Pin<&mut T>` will happily hand back a plain `&mut T` via `get_mut`, and
the whole wrapper collapses into a no-op. `i32`, `String`, `Vec<u8>`, your ordinary structs
— all `Unpin`, all completely unaffected by pinning.

The types that actually feel the restriction are the `!Unpin` ones, and there are basically
two sources:

- compiler-generated `async` state machines that hold a borrow across an `await`
- anything containing `std::marker::PhantomPinned`, the opt-out marker

```rust
use std::marker::PhantomPinned;

struct SelfRef {
    data: [u8; 16],
    slice: *const u8,
    _pin: PhantomPinned,   // makes the whole struct !Unpin
}
```

Auto-traits propagate structurally, so one `PhantomPinned` field poisons the containing
type, which is exactly what you want.

## Getting a Pin

Every way of obtaining a pinned pointer is answering the same question: who guarantees that
the value never moves again? The answers split cleanly by where the value lives.

### Pinning on the heap

`Box::pin` is the one you'll reach for most, but it isn't the only one — `Rc` and `Arc`
have the same constructor, and an existing `Box` can be converted:

```rust
use std::pin::Pin;
use std::rc::Rc;
use std::sync::Arc;

let fut:    Pin<Box<_>> = Box::pin(async { /* ... */ });
let shared: Pin<Arc<_>> = Arc::pin(SelfRef::new());
let local:  Pin<Rc<_>>  = Rc::pin(SelfRef::new());

let already_boxed: Box<SelfRef> = Box::new(SelfRef::new());
let pinned: Pin<Box<SelfRef>> = Box::into_pin(already_boxed);
```

All of these are safe, for the same structural reason. The value is moved into the
allocation exactly once, at construction, and the only handle that escapes is the pinned
pointer. Nothing else can ever name that allocation, so there is no route by which the
value could be moved out of it. For `Arc` and `Rc` there's a second lock on the door: the
only way to get a `&mut` out of them is `Arc::get_mut`, which needs the `Arc` itself — and
that `Arc` is sealed inside the `Pin`.

Heap pinning costs you one allocation, and buys you a pinned pointer that is an ordinary
owned value. You can return it from a function, store it in a struct, put it in a `Vec`.
That's why `Pin<Box<dyn Future + Send>>` — spelled `BoxFuture` in the `futures` crate, and
produced by `.boxed()` — is the standard way to hold a future whose concrete type you'd
rather not name.

### Pinning on the stack

If the value can live and die inside the current stack frame, you don't need the
allocation. Stack pinning gives you a `Pin<&mut T>` pointing at a local, and its safety
comes from shadowing: after the macro runs there is no usable binding left through which
you could move the value, and the borrow holds until the end of the scope.

Three macros do this, and they're all the same idea:

```rust
// std — an expression macro, returns the Pin<&mut T>
use std::pin::pin;
let mut fut = pin!(async { /* ... */ });

// tokio — a statement macro, rebinds an existing variable in place
let fut = async { /* ... */ };
tokio::pin!(fut);          // `fut` is now Pin<&mut impl Future>

// futures — same shape, predates the std macro
use futures::pin_mut;
let fut = async { /* ... */ };
pin_mut!(fut);
```

The difference is ergonomic rather than semantic. `tokio::pin!` and `futures::pin_mut!`
take identifiers and rebind them (both accept several at once), which reads well when the
value is already sitting in a local — typically a future you're about to poll repeatedly
inside a `select!` loop. `std::pin::pin!` is an expression macro that hands back the
`Pin<&mut T>`, so it composes inline wherever a pinned pointer is wanted.

One stability note, since a lot of writing on this topic is out of date: `std::pin::pin!`
spent a long stretch as a nightly-only API behind tracking issue
[#93178](https://github.com/rust-lang/rust/issues/93178), and plenty of articles still say
so. It **stabilized in Rust 1.68** (March 2023). On any modern toolchain, reach for it
first; keep `tokio::pin!` and `pin_mut!` for older MSRVs or when you prefer the rebinding
form.

The catch with stack pinning is the obvious one: the pin is tied to the stack frame. You
can't return it, and you can't store it anywhere that outlives the frame. The moment you
need either, pay for `Box::pin`.

### Pin::new_unchecked, and why it's the unsafe one

`Pin::new_unchecked(ptr)` is worth understanding properly, because it's the clearest
statement of what `Pin` actually means.

The promise `Pin` makes is that the value will never move again *until it is dropped*, and
the compiler cannot verify that. `new_unchecked` lets you wrap a pointer to a value you may
still hold other access to:

```rust
let mut value = SelfRef::new();
let pinned = unsafe { Pin::new_unchecked(&mut value) };
// ... use `pinned` ...
drop(pinned);
let moved = value;   // plain safe Rust, moves the value, breaks the promise
```

That last line is ordinary safe code, and it invalidates everything the pinned code
assumed. So `new_unchecked` makes *you* assert, by hand, that no other handle survives that
could move the value later. The heap constructors and the stack macros are safe precisely
because each has a structural reason no such handle exists — the allocation for one,
shadowing for the other.

By contrast, `Pin::new` is safe, but only exists for `T: Unpin`, where the promise is
vacuous anyway.

One more clause that's easy to miss: pinning also carries a **drop guarantee**. Once a
`!Unpin` value has been pinned, its memory must stay valid and must not be repurposed until
its destructor runs. That's what makes intrusive linked lists possible, and it's why
`mem::forget`-style leaks of a pinned value are a hazard the API has to think about.

## Why `poll` takes `Pin<&mut Self>`

This is the design question I found most illuminating, so it gets its own section.

```rust
pub trait Future {
    type Output;
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}
```

The obvious alternative would be to require a pin at construction — make futures pinned
from birth, so `poll` could take a plain `&mut self`. Why not?

Because a freshly constructed, never-polled future holds no internal pointers yet. In its
initial state the state machine contains only the arguments it was created with; nothing
borrows anything. It is a perfectly ordinary, freely movable value. The self-reference is
created by the *first poll*, which advances the machine into a state that stores an
in-flight sub-future borrowing an inline buffer. From that instant the address must stay
fixed — but not one moment earlier.

Pinning at poll time is what keeps all the pre-poll ergonomics intact. You can return
futures by value from functions, collect them into a `Vec`, pass them to combinators like
`join!` and `select!`, box them or not box them — all of which would be miserable if the
type demanded a stable address from the moment it existed. The executor pins the future
exactly once, right before it starts driving it, and the cost lands in one place instead of
being smeared across every line of async code you write.

It's a nice piece of design: the restriction is attached to the operation that actually
needs it.

## Pin projection, briefly

If you're writing your own `Future` by hand, you'll immediately hit the question of how to
get at fields of a pinned struct. Given `Pin<&mut MyFuture>`, is a field `Pin<&mut Field>`
or plain `&mut Field`?

Both are legitimate, and it's a per-field decision. A field is **structurally pinned** if
pinning the outer struct pins that field too — you'd choose this for a nested future you
need to poll. Otherwise the field is not structurally pinned and you can hand out a normal
`&mut` to it, which is what you want for something like a counter or a flag.

Doing this by hand requires `unsafe` and a list of conditions that are easy to get subtly
wrong (among them: you must not implement `Drop` in a way that moves the pinned fields, and
you must not offer any safe API that could move them). In practice, use
[`pin-project`](https://docs.rs/pin-project) or `pin-project-lite` and let the macro
enforce the rules:

```rust
use pin_project::pin_project;

#[pin_project]
struct Timeout<F> {
    #[pin]
    inner: F,        // structurally pinned — we poll it
    deadline: Instant,   // not pinned — just data
}
```

Then `self.project()` gives you a struct with `inner: Pin<&mut F>` and
`deadline: &mut Instant`, which is exactly the split you wanted.

## So when do you actually need Pin?

Most of the time, you don't. The honest summary:

- **Writing application-level async code**: you never touch `Pin` directly. `.await`
  handles it, and `tokio::spawn` pins for you.
- **Holding a reference to heap data you also own**: `Pin` is the wrong tool. The heap
  buffer doesn't move; your problem is expressing a `'self` lifetime. Use indices, or
  `self_cell` / `ouroboros` / `yoke`.
- **Storing a future in a struct, or writing a `Future`/`Stream` by hand**: this is where
  `Pin` shows up for real. Use `Box::pin` (or `Arc::pin`) when the value must outlive the
  current frame, `std::pin::pin!` / `tokio::pin!` when it doesn't, and `pin-project` for
  the field access.
- **Building genuinely self-referential or intrusive data structures**: `PhantomPinned`,
  `new_unchecked`, and a careful reading of the pin module docs. Rare, and you'll know.

## Takeaways

- A move is a `memcpy` that changes a value's address. Everything about `Pin` follows from
  that.
- In safe Rust you can only move a value by owning it or by holding a `&mut` to it.
  `Pin` hides the first and refuses the second — that's the entire mechanism.
- `Pin` changes nothing about memory. The `Pin` and the pointer inside it move around
  freely; only the pointee is held still.
- `Unpin` means "I don't care about being pinned", not "cannot be pinned". Nearly every
  type implements it, and for those types `Pin` is a no-op wrapper.
- Heap-backed data is already move-stable. `Pin` is for pointees stored *inline*, which is
  why generated `async` state machines are the canonical case.
- Heap pinning (`Box::pin`, `Arc::pin`, `Rc::pin`) and stack pinning (`std::pin::pin!`,
  `tokio::pin!`, `futures::pin_mut!`) are both safe, because in each case no other handle to
  the value survives — the allocation seals it in one case, shadowing in the other.
  `Pin::new_unchecked` is unsafe because it makes you promise that by hand.
- Stack pinning is allocation-free but frame-bound; the moment the value has to outlive the
  frame, pay for `Box::pin`.
- `poll` takes `Pin<&mut Self>` rather than pinning at construction because an unpolled
  future has no self-reference yet — the first poll is what creates it.
