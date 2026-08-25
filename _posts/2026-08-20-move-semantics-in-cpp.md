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

## A reference is not an object

Worth pinning down before going further, because it comes back when we get to
value categories: a reference is not a separate object that stores something.
It's an **alias** — another name for an object that already exists.

The contrast with pointers makes it concrete:

```cpp
int x = 10;

int* p = &x;
int& r = x;
```

```
x
┌──────┐
│  10  │
└──────┘
  ↑
  │
  └──── r          r is another name for x

p
┌──────┐
│  &x  │────────→ x
└──────┘
```

`p` is a real object. It has its own storage and its own address, `&p`, and you
can point it somewhere else whenever you like:

```cpp
p = nullptr;
p = &some_other_object;
```

`r` is not a second object sitting somewhere holding "the address of `x`".
`&r` gives you the address of `x`, because `r` *is* `x` under a different name.
So

```cpp
r = 20;
```

is just `x = 20`. And there is no way to say "make `r` refer to `y` instead" —
writing `r = y;` means `x = y;`. Once bound, a reference stays bound.

This is also why you can't have an array of references:

```cpp
int& arr[3] = {a, b, c};   // not allowed
```

If it worked, `arr[0]` would simply be another name for `a`, `arr[1]` for `b`,
and so on. But an array is defined as a run of *objects* laid out in memory.
With pointers there really are three objects to lay out:

```
arr
 ↓
┌────────┬────────┬────────┐
│ ptr 0  │ ptr 1  │ ptr 2  │
└────────┴────────┴────────┘
```

each with its own value, each independently changeable. References have no
corresponding "reference object" to occupy an element slot, so there's nothing
for the array to be made of.

None of this means the compiler can't implement `int& r = x;` using a machine
address under the hood. It usually does. But that's an implementation detail,
and the language semantics are the thing to reason with:

> A reference is not an object containing an address. It is an alias to an
> object.

Keep that in mind for the next part — value categories are precisely a
classification of how expressions identify objects, and references are the
mechanism that binds to them.

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

## The same idea in a knapsack loop

Competitive programming has a standard shape for 0/1 knapsack that carries two
DP arrays, and it's a good place to watch this play out on something other than
a toy vector.

```cpp
vector<long long> ndp = dp;

for (...) {
    // update ndp using values from dp
}

dp.swap(ndp);
```

At a glance `ndp` looks like it might just be another name for `dp`, the way a
reference would be. It isn't. That first line is copy-initialisation: it
allocates a fresh buffer and copies every element, so it costs O(X) for X DP
states. Two independent arrays now exist, which is the entire point. Every
transition reads from the old `dp` and writes into `ndp`, so nothing written
during a pass can be read back during the same pass, and each item gets used at
most once.

Then the last line:

```cpp
dp.swap(ndp);
```

`swap` copies nothing. A vector is really a handful of pointers into the heap —
begin, end, capacity — and swapping two vectors exchanges those pointers. O(1),
whatever X is. Write `dp = ndp;` instead and you get copy assignment: another
full O(X) pass, possibly with an allocation, to produce a copy of something you
were about to discard anyway. `dp = std::move(ndp);` is also O(1) and says the
same thing in the vocabulary of this post; `swap` is the older idiom and has the
small advantage of leaving `ndp` holding the previous buffer, whose capacity gets
reused on the next iteration's copy.

So one iteration costs O(X) to copy, O(X) for the transitions, and O(1) to swap.
The copy is the real price, and it's the price of keeping the two layers
separate. The swap at the end is free — which is exactly why the pattern shows
up all over 0/1 knapsack and its relatives.

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
