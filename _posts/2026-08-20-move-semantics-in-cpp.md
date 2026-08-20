---
layout: post
title: "Move Semantics in C++"
date: 2026-08-20 00:00:00 +0530
categories: cpp
tags: [cpp, move_semantics, value_categories, rvalue_references]
author: "Seroze"
published: true
---

Move semantics is the thing that makes modern C++ fast without making you write
manual pointer-shuffling code. But you can't really understand it until you
understand what an lvalue and an rvalue actually are, and then the five value
categories that C++11 introduced on top of them.

These are notes from working through that whole chain in one sitting: lvalue and
rvalue first, then why those two names weren't enough, then the full hierarchy.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

---

## Where the names came from

The old explanation is positional. An lvalue is something that can sit on the
**left** of an `=`, an rvalue is something that shows up on the **right**.

```cpp
int x = 5;
```

Here `x` is the lvalue and `5` is the rvalue, and the test is that

```cpp
x = 10;   // fine
5 = x;    // nonsense
```

That story is a decent first approximation and it's how most people are
introduced to the terms. It's also wrong in enough cases that the standard
dropped it long ago.

## The definition that actually holds up

Think about memory instead of about the assignment operator.

An **lvalue has a persistent identity**. It occupies a location you can point at
and come back to later.

```cpp
int x = 5;
```

`x` lives somewhere in RAM:

```
Address 1000
+------+
|  5   |
+------+
```

Every time you write `x`, the compiler knows exactly which object you mean.
That's an lvalue.

Now consider `x + 2`. It evaluates to `7`, but that `7` has no permanent home —
it's a value the expression conjured up and will discard. That's an rvalue.

So the lvalues are the things with addresses you could name:

```cpp
x           // a variable
arr[3]      // an array element
*ptr        // what a pointer points at
obj.member  // a member of an existing object
```

and the rvalues are the things that are just *values*:

```cpp
5
x + 3
foo()                    // when foo returns by value
std::string("hello")
```

## Why the distinction earns its keep

Take a function that binds an lvalue reference:

```cpp
void f(int& x) { }
```

`int&` demands an object with identity, so this works:

```cpp
int x = 5;
f(x);
```

and this doesn't:

```cpp
f(5);   // error
```

There is nothing for the reference to refer to. `5` doesn't live anywhere the
function could write back to.

C++11 added the other kind of reference for exactly this case:

```cpp
void g(int&& x) { }   // rvalue reference

g(5);       // fine — 5 is an rvalue
int a = 10;
g(a);       // error — a is an lvalue
```

`int&&` reads as *"I want to bind to a temporary."*

Two more cases worth memorising, because they look inconsistent until you know
the rule:

```cpp
int x = 5;
int& r1 = x;        // fine
int& r2 = 5;        // error — can't bind a non-const lvalue ref to an rvalue
const int& r3 = 5;  // fine!
int&& r4 = 5;       // fine
```

The `const int&` case works because the compiler quietly materialises a
temporary and binds the reference to it, roughly as if you'd written

```cpp
const int temp = 5;
const int& r3 = temp;
```

That's the mechanism behind the old advice to take parameters by `const T&` —
it accepts both named objects and temporaries.

## The payoff: not copying a million integers

Here's the whole reason anyone cares.

```cpp
std::vector<int> a(1000000);
std::vector<int> b = a;
```

That copy allocates a fresh buffer and copies a million integers into it. Now:

```cpp
std::vector<int> b = std::move(a);
```

`std::move` turns `a` into an rvalue, which is a signal to the compiler:

> I'm done using this object. You can steal its resources.

The move constructor takes that permission and just transfers the internal
pointer.

Before:

```
a
 |
 +-----> heap buffer
```

After:

```
b
 |
 +-----> heap buffer

a
 |
 nullptr
```

No large copy happens at all. This optimisation is only possible because the
language can tell the difference between objects that should be preserved and
objects that are expendable.

## Why two categories weren't enough

Look closely at `std::move(x)` and ask the two questions.

Does it refer to an existing object? Yes — the object is still `x`, and `x` is
still alive afterwards.

Is it a temporary? Not really. Nothing new was created.

So it's neither cleanly an lvalue nor cleanly an rvalue. It refers to something
real, but we're treating it as disposable. That gap is what the extra
categories fill.

## The five names

Every expression in C++ belongs to exactly one value category, and the five
names are not five unrelated things — they're a small hierarchy with one node
shared between two branches.

```
                    Expression
                        |
          +-------------+-------------+
          |                           |
      glvalue                     rvalue
          |                           |
      +---+---+                   +---+---+
      |       |                   |       |
   lvalue   xvalue            xvalue   prvalue
```

`xvalue` appearing under both branches is the single fact that makes this
diagram confusing, and also the single fact worth remembering.

### prvalue

"Pure rvalue" — the classic brand-new temporary.

```cpp
5
x + y
std::string("hello")
foo()                  // returning by value
```

Nothing subtle here. These are values that didn't exist a moment ago and won't
exist a moment later.

### xvalue

"eXpiring value" — an existing object that has been marked as expendable.

```cpp
std::string s = "hello";
std::move(s);
```

`s` hasn't disappeared. You can still call `s.size()` afterwards, though its
contents are unspecified once something has actually moved from it. So
`std::move(s)` isn't a new temporary — it's the original object wearing a sign
that says *safe to steal from*.

### What std::move actually does

This is the part people get wrong: `std::move` does not move anything. It's
essentially

```cpp
static_cast<std::string&&>(s)
```

No memory is copied, nothing is freed, no constructor runs. It only changes the
value category of the expression:

```
s              ->  lvalue
std::move(s)   ->  xvalue
```

The actual work happens later, when an overload resolution picks the move
constructor because it saw an rvalue.

### glvalue

"Generalised lvalue" — an unfortunate name for a simple idea: *an expression
that identifies an object*.

```cpp
x              // identifies x
arr[3]         // identifies an array element
*ptr           // identifies whatever ptr points at
std::move(x)   // still identifies x
```

So `glvalue = lvalue + xvalue`.

### rvalue

An expression whose resources may be reused.

```cpp
5             // prvalue
x + y         // prvalue
foo()         // prvalue
std::move(x)  // xvalue
```

So `rvalue = prvalue + xvalue`. And since an xvalue is in both unions,

```
xvalue = glvalue + rvalue
```

which is the key fact of the entire hierarchy.

## Worked through

```cpp
int x = 5;
```

| Expression | Category | Also is |
|---|---|---|
| `x` | lvalue | glvalue |
| `5` | prvalue | rvalue |
| `x + 1` | prvalue | rvalue |
| `std::move(x)` | xvalue | glvalue *and* rvalue |

Said in one line each:

- **lvalue** — I have an object.
- **prvalue** — I have a brand-new temporary.
- **xvalue** — I have an existing object, but you may steal from it.
- **glvalue** — this expression identifies an object.
- **rvalue** — this expression can be treated as expendable.

## The correction worth making explicit

Early on I called an rvalue "a temporary value". That's a fine starting
intuition but it's not the real definition, and the difference matters once
xvalues are in the picture:

- Every prvalue is a temporary value.
- Every xvalue is *also* an rvalue, even though it refers to an existing,
  named object.

So the honest definition of an rvalue is **an expression whose resources may be
reused**, not simply a temporary.

## The mental model to keep

When you're staring at an expression and can't classify it, ask two questions
in order.

Does this expression refer to an existing object with a stable identity? If
yes, it's a glvalue — an lvalue normally, an xvalue if something has marked it
as movable.

If no, does it produce a temporary that's about to disappear? Then it's a
prvalue.

**`std::move` is a cast, not a move — the move happens in the constructor that
sees the rvalue.** And **the whole five-name hierarchy is just two overlapping
questions: does it identify an object, and can its resources be stolen.**

Everything downstream — move constructors, forwarding references (`T&&` in a
template, which is a different animal from a plain rvalue reference), and
perfect forwarding — is built directly on top of these categories.
