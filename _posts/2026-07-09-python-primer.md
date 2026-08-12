---
layout: post
title: "A primer on Python"
date: 2026-07-09 00:00:00 +0530
categories: python
tags: [python, typing, protocols, descriptors, generators, concurrency, competitive_programming]
author: "Seroze"
published: true
---

*A running collection of Python concepts worth knowing cold.*

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Structural vs nominal subtyping (and why `Protocol` over ABC)

In **nominal subtyping**, type compatibility is decided by declared names: `Dog` is a subtype of `Animal` only if it explicitly inherits from `Animal`. This is how ABCs work — a class counts as implementing the interface only if it subclasses the ABC (or registers with it). In **structural subtyping**, compatibility is decided by shape: if a class has the right methods with the right signatures, it *is* the type, no inheritance required. This is duck typing — "if it quacks like a duck" — made checkable by static tools.

`Protocol` (from `typing`) lets you define an interface based on what an object *can do*, rather than what it inherits from. It's Python's way of formalizing duck typing — "if it walks like a duck and quacks like a duck" — but with static type-checker support.

### The problem it solves

Normally in Python, if you want to say "this function accepts anything with a `.read()` method," you have two bad options.

**Option A — no type hint at all:**

```python
def process(source):
    return source.read()
```

Works at runtime, but a type checker (mypy, pyright) can't verify callers are passing something valid. No safety net.

**Option B — force inheritance (nominal typing):**

```python
class Readable(ABC):
    @abstractmethod
    def read(self) -> str: ...

class MyFile(Readable):
    def read(self) -> str: ...
```

Now `process(source: Readable)` is type-checkable — but every class that wants to be "readable" must explicitly inherit from `Readable`. That's a real cost: you can't retrofit third-party classes you don't own, and you end up designing class hierarchies just to satisfy the type checker rather than to model anything meaningful.

### What Protocol does instead

```python
from typing import Protocol

class Readable(Protocol):
    def read(self) -> str: ...
```

Now any class with a matching `read() -> str` method satisfies `Readable` — automatically, with zero inheritance, zero registration. This is structural subtyping ("if it has the right shape, it counts") as opposed to nominal subtyping ("it counts only if it's declared as a subclass").

```python
class MyFile:          # doesn't inherit from Readable at all
    def read(self) -> str:
        return "contents"

def process(source: Readable) -> str:
    return source.read()

process(MyFile())      # ✅ type-checks fine, because MyFile has the right shape
```

### Are ABCs still useful?

Yes — ABC and Protocol solve different problems, and neither makes the other obsolete. They're often used together in the same codebase, even the same class hierarchy.

**1. You want to share actual implementation, not just a signature**

```python
class Tool(ABC):
    name: str

    @abstractmethod
    async def execute(self, **kwargs) -> ToolResult:
        ...

    def to_schema(self) -> dict:
        """Concrete, shared logic — every subclass gets this for free."""
        return {"name": self.name, "parameters": self._infer_params()}

    def _infer_params(self) -> dict:
        # shared helper logic, inherited by all tools
        ...
```

Protocol can't do this — it has no mechanism for shipping real, inherited method bodies. If your `Tool` base class needs to provide common utility logic (schema generation, logging, validation helpers) that every concrete tool reuses rather than reimplements, ABC (or a plain base class) is the only option.

**2. You want a hard runtime guarantee, not just a static-analysis hint**

```python
class Tool(ABC):
    @abstractmethod
    async def execute(self, **kwargs) -> ToolResult: ...

class BashTool(Tool):
    pass  # forgot to implement execute()

BashTool()  # TypeError: Can't instantiate abstract class BashTool with abstract method execute
```

This fails immediately at instantiation, even if nobody ever runs mypy/pyright. Protocol gives you zero runtime enforcement by default — a class that's missing a method just fails later, at the actual call site, with a plain `AttributeError`, possibly deep inside your agent loop mid-request. For something as central as "every tool the agent can invoke must actually be invocable," that fail-fast guarantee is valuable.

**3. You genuinely want an is-a relationship, not just a matching shape**

If `BashTool`, `FileReadTool`, `FileEditTool` really are conceptually kinds of `Tool` — sharing identity, meant to be used interchangeably in a registry, maybe with shared construction logic — ABC expresses that intent directly. Protocol is better suited to boundaries where you don't control, and shouldn't need to control, the other side (e.g. "any object with a `.stream()` method can be a provider," including ones from a third-party SDK you didn't write).

**Rule of thumb:** reach for `Protocol` at the edges of your system (plugin points, provider adapters, anything where "shape, not lineage" is the right mental model), and reach for ABC in the interior where you're deliberately building a family of related, shared-behavior classes and want the interpreter itself to catch incomplete implementations.

One last note: add `@runtime_checkable` to a protocol if you also want `isinstance()` checks against it — but it verifies method *presence* only, not signatures.

## Reading stdin fast (a competitive programming trick)

Mostly this matters in competitive programming, where input is huge and the time limit is tight — outside of CP you'll rarely notice. Three ways to read standard input, cheapest last:

```python
line = input()                              # per-call overhead
line = sys.stdin.readline()                 # ~2x faster, keeps the '\n'
data = sys.stdin.buffer.read().split()      # ~4x faster, one syscall
```

`input()` pays for a prompt check, a readline/tty check, newline stripping and text decoding **on every call**. `sys.stdin.readline` skips the first two (you strip yourself). `buffer.read().split()` skips all of it — one read, one C-level split — so per-line Python overhead disappears entirely.

The cost scales with **line count, not bytes**: on a 1000×1000 grid all three take ~2ms, but on 200k lines of two ints it's 0.31s vs 0.15s vs 0.08s. So use `input()` for a few thousand lines, `sys.stdin.buffer.read().split()` at 10⁵+ tokens, and `input = sys.stdin.readline` as the habit that's never wrong.

One trap: `.buffer` gives you `bytes`, and indexing bytes yields an **int**, so `row[j] == '#'` is silently always `False` — `.decode()` the rows, or compare against `b'#'[0]`.

## `is` vs `==`, small-int caching, and string interning

`==` asks *do these have the same value?* and calls `__eq__`. `is` asks *are these the same object?* and compares identities (`id()`, which in CPython is the memory address). Two structurally identical lists are equal but not identical:

```python
a = [1, 2, 3]
b = [1, 2, 3]

a == b   # True  — same contents
a is b   # False — two separate list objects
```

Where this gets interesting is when CPython *reuses* objects behind your back.

**Small integers.** CPython preallocates every `int` from −5 to 256 at startup and hands out the same object every time one is needed. So:

```python
a = 256
b = 256
a is b   # True  — both name the one cached 256 object

x = 257
y = 257
x is y   # ...it depends
```

In a script or a function body, `257` appears twice as a constant in the *same code object*, and the compiler deduplicates its constant table — so you get `True`. Typed as two separate statements in the REPL, each line is compiled separately, so you get `False`. Neither answer is part of the language; both are CPython implementation details that can change between versions.

**String interning.** The same thing happens with strings, through two separate mechanisms:

```python
s1 = "hello_world"
s2 = "hello_" + "world"

s1 is s2    # True
s1 == s2    # True
```

Two things conspire here. First, the peephole optimizer does **constant folding**: `"hello_" + "world"` is two literals, so the compiler evaluates the concatenation at compile time and stores a single constant. Second, compile-time string constants that look like identifiers — only ASCII letters, digits and underscores — are **interned** into a global table, so all occurrences share one object.

Change it so the concatenation happens at runtime and both mechanisms fall away:

```python
a = "hello"
b = "world"
s3 = a + "_" + b

s1 is s3    # False — s3 is a fresh string built at runtime
s1 == s3    # True
```

The equality answer is stable and meaningful. The identity answer is an artifact of how the string got built.

**Can you rely on any of this?** No. The takeaway isn't "memorize the ranges", it's:

> Use `is` only for singletons — `None`, `True`, `False`, sentinel objects you created yourself. Use `==` for values, always.

`if x is 5:` is a bug waiting for a version bump; modern CPython even emits a `SyntaxWarning` for it. The one place identity comparison genuinely matters is the sentinel pattern:

```python
_MISSING = object()          # a unique object, equal to nothing but itself

def get(key, default=_MISSING):
    ...
    if default is _MISSING:  # correct: distinguishes "not passed" from "passed None"
        raise KeyError(key)
```

## Default arguments are evaluated once

```python
def f(x=[]):
    x.append(1)
    return x

f()   # [1]
f()   # [1, 1]
f()   # [1, 1, 1]
```

The intuition that trips people up is imagining `x = []` running fresh on every call. It doesn't. **Default values are evaluated once, when the `def` statement executes**, and stored on the function object. Every call that omits the argument gets that same object:

```python
f.__defaults__      # ([1, 1, 1],) — you can watch it grow
```

So the code behaves as if it were written:

```python
_default_x = []

def f(x=_default_x):
    x.append(1)
    return x
```

This bites with any mutable default — `[]`, `{}`, `set()` — and also with anything whose value is *computed* at definition time, like `def log(msg, ts=datetime.now())`, which freezes a single timestamp for the lifetime of the process.

The fix is the `None` sentinel:

```python
def f(x=None):
    if x is None:
        x = []
    x.append(1)
    return x
```

For a dataclass, the same rule shows up as `field(default_factory=list)` — and dataclasses will actually raise `ValueError: mutable default` if you try to write it the broken way, because the problem is common enough to warrant a guard rail.

## Closures capture variables, not values

```python
funcs = []
for i in range(3):
    funcs.append(lambda: i)

[f() for f in funcs]    # [2, 2, 2]
```

Each lambda stores a reference to the *variable* `i`, not a snapshot of what `i` was at the time. The lambdas run after the loop is over, and at that point `i` is `2` — so all three see `2`. This is **late binding**: free variables are resolved when the function is *called*, not when it's defined.

This isn't a quirk of lambdas. The same happens with `def`, and with any function that closes over a loop variable — including the common bug of registering callbacks or building a list of partially-applied handlers in a loop.

The fix is to bind the value at definition time, and the idiomatic way is to (deliberately) exploit the rule from the previous section:

```python
funcs = [lambda i=i: i for i in range(3)]
[f() for f in funcs]    # [0, 1, 2]
```

Because default arguments *are* evaluated eagerly, `i=i` freezes the current value into each function. The same rule that causes the mutable-default bug is what rescues you here.

Two other ways, if the `i=i` idiom reads as too clever:

```python
from functools import partial
funcs = [partial(lambda i: i, i) for i in range(3)]

def make(i):            # a factory gives each closure its own scope
    return lambda: i
funcs = [make(i) for i in range(3)]
```

Note that Python 3 comprehensions already have their own scope, but that scope is shared across *iterations* — `[lambda: i for i in range(3)]` still gives `[2, 2, 2]`.

## Shallow vs deep copy

```python
import copy

a = [[1], [2]]
b = a.copy()             # shallow — same as list(a) or a[:]
c = copy.deepcopy(a)     # recursive

a[0].append(99)

a   # [[1, 99], [2]]
b   # [[1, 99], [2]]   ← surprised?
c   # [[1], [2]]
```

A shallow copy builds a new outer container and fills it with **the same references** the original held. `b` is genuinely a different list object from `a` — appending to `b` doesn't touch `a` — but `b[0]` and `a[0]` are the same inner list, so mutating *through* either name is visible from both.

```
a ──► [ • , • ]
        │   │
        ▼   ▼
      [1,99] [2]      ← shared
        ▲   ▲
        │   │
b ──► [ • , • ]

c ──► [ • , • ] ──► [1]  [2]   ← fresh copies all the way down
```

`copy.deepcopy` walks the whole object graph and rebuilds it, keeping a memo dict so shared references stay shared and cycles don't loop forever. It's correct but slow, and it will happily try to copy things you didn't intend — file handles, sockets, database connections. Classes can control it via `__copy__` / `__deepcopy__` / `__reduce__`.

For flat data, shallow is fine and cheap. For nested data you intend to mutate, either deep-copy it or — usually better — reach for immutable structures (tuples, frozen dataclasses) so the question never comes up.

## Generators: producing *and* consuming

`return` ends a function and hands back one value; the function's local state is destroyed. `yield` turns the function into a **generator function**: calling it doesn't run the body at all, it builds a generator object. Each `next()` runs the body up to the next `yield`, hands out the value, and **freezes the frame** — locals, instruction pointer and all — until the next `next()`.

That's why this prints an object, not a number:

```python
def accumulator():
    total = 0
    while True:
        n = yield total
        total += n

print(accumulator())     # <generator object accumulator at 0x...>
```

The line `n = yield total` is doing two jobs, and this is the part interviewers are usually fishing for:

1. **`yield total`** — emit `total` to whoever is driving the generator, and suspend.
2. **`n = ...`** — when the driver resumes us with `gen.send(value)`, that `value` becomes the result of the `yield` expression.

```python
g = accumulator()
next(g)        # 0   — must prime it: runs up to the first yield
g.send(5)      # 5
g.send(3)      # 8
g.send(10)     # 18
```

The priming `next(g)` (equivalently `g.send(None)`) is required — you can't send a value into a generator that hasn't reached a `yield` yet. Alongside `send`, generators also expose `throw` (raise an exception *at* the suspension point) and `close` (raise `GeneratorExit` there, which is how `try/finally` cleanup inside a generator gets to run).

**When to prefer a generator over returning a list:** when the sequence is large or unbounded (you hold one item in memory instead of all of them), when the consumer might stop early (you never compute the tail), or when you're building a pipeline where each stage transforms a stream. The cost is that a generator is single-pass and has no `len()` — if callers need to iterate twice or index, give them a list.

## `yield from`

```python
def flatten(nested):
    for sub in nested:
        yield from sub
```

Compared to the manual loop, `yield from sub` isn't just shorthand for `for x in sub: yield x`. It establishes a **transparent two-way channel** between the outermost caller and the innermost generator:

- Values yielded by the sub-generator pass straight through.
- `send()` from the caller is forwarded down to the sub-generator (the manual loop swallows it — the value lands in the loop's own `yield` expression and is thrown away).
- `throw()` and `close()` are likewise forwarded, so cleanup happens at the right level.
- The sub-generator's `return` value becomes the value of the `yield from` expression: `result = yield from sub()`. Under the hood that value rides on `StopIteration.value`.

It's also faster, since delegation happens in C rather than by running a Python-level loop per item. This delegation machinery is exactly what `await` was later built on — `yield from` was the stepping stone from generator-based coroutines to `async`/`await`.

## Context managers

```python
with open(path) as f:
    data = f.read()
```

desugars to roughly:

```python
mgr = open(path)
f = type(mgr).__enter__(mgr)        # note: looked up on the type, not the instance
try:
    data = f.read()
except BaseException as exc:
    if not type(mgr).__exit__(mgr, type(exc), exc, exc.__traceback__):
        raise
else:
    type(mgr).__exit__(mgr, None, None, None)
```

So the protocol is two methods:

- `__enter__(self)` — set up, and return whatever `as` should bind. (For a file, that's the file itself; it need not be `self`.)
- `__exit__(self, exc_type, exc_value, traceback)` — tear down. Called with three `None`s on the normal path, and with the exception details if the body blew up.

The detail worth knowing cold: **if `__exit__` returns a truthy value, the exception is swallowed.** That's how `contextlib.suppress` works. Returning `None` (the common case — just falling off the end of the method) lets the exception propagate, which is almost always what you want. Accidentally ending `__exit__` with something truthy is a great way to silently eat errors.

`__exit__` runs whether the block completes normally, raises, or exits via `return`/`break`/`continue` — that's the whole point, and it's why `with` is preferable to `try/finally` written by hand. (It does *not* survive `os._exit()` or a hard crash.)

Writing one is usually easiest with `contextlib`:

```python
from contextlib import contextmanager

@contextmanager
def timer(label):
    start = time.perf_counter()
    try:
        yield                       # everything before this is __enter__
    finally:                        # everything after is __exit__
        print(label, time.perf_counter() - start)
```

The `try/finally` matters: without it, an exception in the body propagates out of the `yield` and the teardown never runs. And note `contextlib.contextmanager` produces a *single-use* context manager — the generator is exhausted after one `with`.

## Decorators

```python
@timer
def foo():
    ...
```

is exactly:

```python
def foo():
    ...
foo = timer(foo)
```

That last line is the sentence to have ready: **after decoration, the name `foo` no longer refers to the original function.** It refers to whatever `timer` returned — usually a wrapper closure that holds the original and calls it in the middle of some before/after work.

```python
import functools, time

def timer(fn):
    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        try:
            return fn(*args, **kwargs)
        finally:
            print(fn.__name__, time.perf_counter() - start)
    return wrapper
```

`functools.wraps` copies `__name__`, `__doc__`, `__module__`, `__qualname__`, type annotations and `__dict__` from the original onto the wrapper, and sets `__wrapped__` so `inspect.signature` can see through it. Without it, your decorated functions all show up as `wrapper` in tracebacks, logs and docs — the classic sign of a decorator written in a hurry.

Two follow-ups that come up often:

**Decorators with arguments** need one more layer, because `@retry(3)` means `foo = retry(3)(foo)` — `retry(3)` is called first and must *return* a decorator.

**Stacking** applies bottom-up: with `@a` above `@b`, you get `foo = a(b(foo))`, so `b` is the inner wrapper and `a` sees `b`'s wrapper. That ordering matters a lot for things like `@staticmethod` and framework route decorators.

## `__slots__`

By default every instance carries a `__dict__` — a per-object dictionary holding its attributes. That's what makes Python objects freely extensible, and it costs memory: the dict itself, plus a pointer to it, per instance.

```python
class Point:
    __slots__ = ("x", "y")

    def __init__(self, x, y):
        self.x, self.y = x, y
```

`__slots__` tells the class to allocate fixed storage slots in the instance struct instead, and skip `__dict__` entirely.

**Advantages**

- **Memory.** Typically a large reduction per instance for small objects — the win scales with how many you create, and it's the entire reason to bother.
- **Slightly faster attribute access**, since it's a fixed offset rather than a dict lookup.
- **Typo protection.** `p.mispelled = 1` raises `AttributeError` instead of silently creating a new attribute.

**Disadvantages**

- You can't add attributes that weren't declared — sometimes the point, sometimes a real constraint (monkeypatching, caching a computed value on the instance, libraries that stash things on your objects).
- No `__weakref__` unless you list it explicitly in `__slots__`.
- Multiple inheritance gets awkward: two base classes with non-empty `__slots__` can't be combined (`TypeError: multiple bases have instance lay-out conflict`).
- A subclass that doesn't declare `__slots__` quietly gets a `__dict__` back, silently undoing the saving.
- You can't use a class attribute as a default for a slot name — the slot descriptor and the class attribute collide.

**When to use it:** exactly the case of millions of small, fixed-shape objects — AST nodes, graph vertices, geometry points, game entities, parsed records in a hot loop. For a config object you instantiate once, it's noise. Note that `@dataclass(slots=True)` gives you this without hand-writing the tuple, and `attrs` does it by default.

One thing worth noticing before the next section: each name in `__slots__` becomes a **descriptor** on the class. That's the mechanism that makes slot attributes work at all — which is a good excuse to look at descriptors properly.

## Descriptors — the protocol behind `property`, methods, and `classmethod`

This is the concept that ties together a surprising amount of Python's object model, and it's the one most people have never had to look at directly.

The starting point: `obj.x` is **not** a dictionary lookup. `object.__getattribute__` does something closer to this:

1. Walk `type(obj).__mro__` looking for `x`.
2. If it's found **and** it defines `__set__` or `__delete__` (a **data descriptor**), call its `__get__(obj, type(obj))` and stop.
3. Otherwise, if `x` is in `obj.__dict__`, return that.
4. Otherwise, if the class attribute found in step 1 defines `__get__` (a **non-data descriptor**), call it.
5. Otherwise return the plain class attribute.
6. If nothing was found, fall back to `__getattr__`.

A **descriptor** is any object implementing one or more of:

```python
__get__(self, obj, objtype=None)
__set__(self, obj, value)
__delete__(self, obj)
__set_name__(self, owner, name)     # called at class creation; tells you your own name
```

### Why `@property` works

`property` is simply a class implementing `__get__`, `__set__` and `__delete__`, which makes it a data descriptor — hence step 2, hence attribute *access* running your code. There's no special syntax involved; you could write your own:

```python
class Celsius:
    def __set_name__(self, owner, name):
        self.private = "_" + name

    def __get__(self, obj, objtype=None):
        if obj is None:              # accessed on the class, not an instance
            return self
        return getattr(obj, self.private)

    def __set__(self, obj, value):
        if value < -273.15:
            raise ValueError("below absolute zero")
        setattr(obj, self.private, value)


class Reading:
    temp = Celsius()                 # one descriptor object, shared by all instances

r = Reading()
r.temp = 20        # → Celsius.__set__(r, 20)
r.temp             # → Celsius.__get__(r, Reading)  → 20
r.temp = -300      # → ValueError
```

Note where the *data* lives: on the instance (`r._temp`), while the descriptor itself lives on the class. Storing state on `self` inside the descriptor would share it across every instance of `Reading` — a classic descriptor bug.

The data/non-data distinction is directly observable:

```python
class A:
    @property
    def x(self):
        return "from class"

a = A()
a.__dict__["x"] = "from instance"    # sneak past the property's __set__
a.x                                  # 'from class' — data descriptor wins
```

### Methods are descriptors too

Plain functions implement `__get__` (and *not* `__set__`), which makes them non-data descriptors. That's the entire mechanism behind bound methods:

```python
class A:
    def f(self): ...

A.f                             # <function A.f at 0x...>
a = A()
a.f                             # <bound method A.f of <A object ...>>
A.__dict__["f"].__get__(a, A)   # the same bound method — this is what a.f *is*
```

`__get__` returns a small object that remembers `a` and prepends it as the first argument. So "`self` is passed automatically" isn't a language rule bolted on for methods — it's the descriptor protocol.

Once you see that, the rest of the object model falls out of the same idea: `staticmethod` is a descriptor whose `__get__` returns the underlying function unchanged; `classmethod` is one that binds the *class* instead of the instance; `functools.cached_property` is a non-data descriptor that computes once and writes the result into `obj.__dict__`, so step 3 shadows it on every subsequent access; `__slots__` entries are data descriptors reading and writing fixed offsets in the instance struct. ORMs and validation libraries (`Model.name = CharField(...)`) are the same trick at application level.

## The GIL

The **Global Interpreter Lock** is a single mutex that a CPython thread must hold to execute Python bytecode. One thread runs bytecode at a time, per interpreter — so pure-Python CPU work does not scale across cores with threads, no matter how many you start.

It exists mainly because CPython manages memory with **reference counting**. Every object holds a refcount that changes constantly, and making every one of those increments atomic would slow single-threaded code down considerably. One coarse lock was the cheap answer, and it also makes C extension authors' lives much easier.

The GIL is released around blocking calls — file and socket I/O, `time.sleep`, most `select`/`epoll` waits — and by compute-heavy C extensions that know to drop it (NumPy does this for large array ops, as do zlib, hashlib, and many database drivers). It's also released periodically so threads can take turns; the interval is `sys.setswitchinterval()`, 5 ms by default.

**Does it prevent race conditions?** No — and this is the part worth getting precisely right. The usual explanation, "a thread can read a half-written value", isn't really what happens: the GIL does keep individual bytecode operations from interleaving, so you won't observe a torn object. The race is at the level of *operations composed of multiple bytecodes*:

```python
counter += 1
```

compiles to roughly:

```
LOAD_NAME    counter     # read
LOAD_CONST   1
BINARY_OP    +
STORE_NAME   counter     # write
```

A thread switch between the load and the store means two threads read the same old value, both add one, and both store the same new value — one increment is lost. Same story for `if key not in d: d[key] = ...`, and for read-modify-write on any shared structure. Anything beyond a single bytecode needs a `Lock`.

So: **the GIL protects the interpreter's internal state, not your program's invariants.**

Worth knowing that this is actively changing. Python 3.12 gave sub-interpreters their own GIL, and 3.13 shipped an experimental free-threaded build (PEP 703) that removes it entirely, using biased reference counting and finer-grained locking; 3.14 promoted that build to officially supported, though it's still not the default and C extensions need to opt in. The *race condition* half of this section stays true either way — arguably more so.

## `threading` vs `multiprocessing` vs `asyncio`

| | Best for | Concurrency unit | Cost |
|---|---|---|---|
| `threading` | blocking I/O, especially through libraries with no async version | OS thread | ~8 MB stack, preemptive switches |
| `multiprocessing` | CPU-bound Python work | OS process | full interpreter per process, IPC pickling |
| `asyncio` | very large numbers of concurrent I/O operations | coroutine | ~KB per task, cooperative switches |

**`threading`** — use it when you're waiting on something and the library you're waiting through is synchronous. The GIL is released during that wait, so threads genuinely overlap. It's not a prototyping-only tool: database connection pools, `logging`'s queue handlers, background workers, file uploads, GUI event loops and thread pools behind `concurrent.futures.ThreadPoolExecutor` are all real production uses. Concrete case: fetching 50 URLs with `requests`, which has no async mode — a `ThreadPoolExecutor(max_workers=16)` is the right and boring answer.

**`multiprocessing`** — use it when the work is CPU-bound *in Python*. Separate processes mean separate GILs and real parallelism, at the cost of process startup and having to pickle arguments and results across the boundary (so large data transfers can eat the win). Concrete case: rendering or OCR-ing a few thousand PDFs, or image resizing, across all cores. Note that if your CPU work is already inside a C extension that drops the GIL — big NumPy operations, `hashlib` — threads may be enough.

**`asyncio`** — use it when you have thousands of concurrent I/O operations and control over the whole stack. One thread, one event loop, coroutines that suspend at `await`. It's the cheapest per unit of concurrency by a wide margin, which is why it dominates for network servers, proxies, crawlers and anything fan-out-heavy. Concrete case: an API gateway holding 10k open connections, or a crawler issuing 5k concurrent requests with `httpx`/`aiohttp`. The catch is that it's *cooperative*: one blocking call — a synchronous DB driver, a `time.sleep`, a heavy CPU loop — stalls every task on the loop. Escape hatches are `loop.run_in_executor` / `asyncio.to_thread` for blocking calls, and a process pool for CPU work.

The one-line version: **blocking I/O through sync libraries → threads; CPU-bound Python → processes; massive concurrent I/O with an async stack → asyncio.** And they compose — an asyncio service with a `ProcessPoolExecutor` for its heavy computation is a perfectly normal shape.

## Method resolution order and C3

```python
class A:
    def f(self): print("A")

class B(A):
    def f(self): print("B")

class C(A):
    def f(self): print("C")

class D(B, C):
    pass

D().f()      # B
D.mro()      # [D, B, C, A, object]
```

`D().f()` prints `B` — attribute lookup walks `D.__mro__` in order and takes the first hit.

The MRO itself is *not* breadth-first, and not depth-first either. Python computes it with **C3 linearization**, which produces the unique ordering (when one exists) satisfying three constraints:

1. A class always precedes its parents.
2. **Local precedence order**: the order you wrote the bases in is preserved.
3. **Monotonicity**: the MRO of every class is a subsequence of the MRO of anything that inherits from it — a parent's ordering is never rearranged by a child.

Mechanically it's `L[D] = D + merge(L[B], L[C], [B, C])`, where `merge` repeatedly takes the head of the first list that doesn't appear in the *tail* of any other list. That "not in anyone's tail" rule is what stops a class from being placed before something that must come after it.

The diamond above doesn't distinguish the algorithms — depth-first is the one that clearly fails there, since `D, B, A, C` would find `A.f` before `C.f` and skip a more derived class entirely (this was real behaviour for old-style classes in Python 2). To see breadth-first fail, you need one more level:

```python
class O: pass
class A(O): pass
class B(O): pass
class C(A, B): pass
class D(B): pass
class E(C, D): pass

E.mro()   # [E, C, A, D, B, O, object]
```

Breadth-first would give `E, C, D, A, B, O`, putting `D` before `A`. C3 places `A` first because `C`'s own MRO says `A` comes before `B`, and `D` must come before `B` too — the merge resolves both without violating either.

When no consistent ordering exists, you get an error at class-creation time rather than a surprise at call time:

```python
class X: pass
class Y: pass
class A(X, Y): pass
class B(Y, X): pass
class C(A, B): pass    # TypeError: Cannot create a consistent MRO
```

For an interview, you don't need to run the merge by hand. Say: C3 linearization, it respects declaration order and is monotonic, and it's what makes cooperative `super()` work — `super()` doesn't mean "my parent", it means "the next class in the *instance's* MRO", which is why a `super().f()` chain in a diamond visits `C` before `A` even though `B` never mentions `C`.

## `except ... as e` deletes `e`

```python
try:
    raise ValueError("x")
except ValueError as e:
    pass

print(e)     # NameError: name 'e' is not defined
```

The `as e` name is **unbound at the end of the except block**, as if the block ended with `del e`. This is specified behaviour (PEP 3110), not an implementation detail.

The reason is reference cycles: the exception holds a traceback, the traceback holds the frame, and the frame holds the local `e` — so keeping `e` alive keeps the entire frame and everything in it alive until the cycle collector runs. Since this happens on error paths, which are often the memory-pressure paths, the language just clears the name.

The consequence catches people twice. The obvious one is that you can't use `e` after the block. The less obvious one is that it deletes the name even if you were already using it:

```python
e = "important"
try:
    raise ValueError
except ValueError as e:
    pass
print(e)      # NameError — your original 'e' is gone too
```

If you need the exception afterwards, rebind it:

```python
error = None
try:
    ...
except ValueError as e:
    error = e         # 'error' survives; 'e' does not
```

Related scoping trivia worth having: a comprehension's loop variable is confined to the comprehension (unlike a `for` loop, whose variable leaks into the enclosing scope and is still bound after the loop ends), and the `else` clause of a `try` runs only when no exception was raised — useful for keeping the `try` body down to the one line that can actually fail.

## Floats and floor division

```python
0.1 + 0.2 == 0.3      # False
0.1 + 0.2             # 0.30000000000000004
```

Floats are IEEE 754 binary64. A binary fraction can represent exactly those values with a denominator that's a power of two, and `0.1` isn't one — it's stored as the nearest representable double, which is slightly off. Two slightly-off values added give a result that isn't the nearest double to `0.3`. Nothing here is Python-specific; the same is true in C, Java and JavaScript.

The consequences: never compare floats with `==`, and never accumulate money in them.

```python
import math
math.isclose(0.1 + 0.2, 0.3)            # True — relative tolerance, sensible default

from decimal import Decimal
Decimal("0.1") + Decimal("0.2")         # Decimal('0.3') — exact base-10, for money

from fractions import Fraction          # exact rationals, when you need them
```

`math.isclose` uses a relative tolerance by default, so pass `abs_tol` explicitly when comparing against zero. And note `round()` uses banker's rounding — `round(0.5)` is `0`, `round(2.5)` is `2` — which is deliberate (it avoids upward bias over many values), not a bug.

**Floor division** rounds toward negative infinity, not toward zero:

```python
-3 // 2     # -2   (not -1)
 3 // -2    # -2
-3 %  2     #  1
 3 % -2     # -1
```

`//` floors, so `-1.5` becomes `-2`. The modulo result then follows from the invariant Python guarantees: `a == (a // b) * b + a % b`. That forces `a % b` to take the **sign of the divisor**, which is why `-3 % 2` is `1` — genuinely useful, since `arr[i % n]` and modular arithmetic just work for negative indices without a correction term. C and Java truncate toward zero instead, so their `%` takes the sign of the dividend and `-3 % 2` is `-1` there.

If you want truncation, be explicit: `int(-3 / 2)` is `-1`, `math.fmod(-3, 2)` is `-1.0`, and `math.trunc` truncates. `divmod(a, b)` gives you the floor-consistent pair in one call.

## 20 GB of CSV: pandas, NumPy, or Polars?

Not NumPy — it's a homogeneous n-dimensional array library, so a CSV with mixed dtypes and string columns isn't its shape. It's the layer underneath, not the tool for the job.

Not plain pandas either, at least not naively. `pd.read_csv` builds the whole frame in memory, and the in-memory footprint is typically well above the file size — object-dtype strings especially, plus transient copies during parsing. 20 GB of CSV can easily want 60–100 GB of RAM.

**Polars** is the default answer: a columnar Arrow-backed engine with a multi-threaded Rust core, a query optimizer, and — the part that actually matters here — a **lazy streaming** mode that processes larger-than-memory data in batches:

```python
import polars as pl

(pl.scan_csv("huge.csv")              # lazy: nothing read yet
   .filter(pl.col("status") == "ok")
   .group_by("user_id")
   .agg(pl.col("amount").sum())
   .collect(streaming=True))          # executes in batches
```

Because it's lazy, projection and predicate pushdown mean it only parses the columns and rows the query needs — often the single biggest win, independent of streaming.

The honest full answer names the alternatives too, since the interviewer usually wants to hear that you'd interrogate the problem:

- **DuckDB** — if the work is genuinely analytical SQL, it queries CSV/Parquet files directly, out of core, and is frequently the least-effort option.
- **Convert to Parquet once.** Columnar, compressed, typed. A 20 GB CSV often lands around 2–4 GB, after which everything downstream is cheap. If this data will be read more than once, this is the real fix — the CSV is the problem.
- **pandas in chunks** (`read_csv(chunksize=...)`, or `dtype=` with categoricals and `pyarrow` string dtype) — fine if the operation is embarrassingly row-wise and you don't want a new dependency.
- **Dask / Spark** — when it stops fitting on one machine, which 20 GB doesn't.

## When Cython helps

Cython compiles annotated Python to C. It helps when the bottleneck is **interpreter overhead in tight Python-level loops over scalars** — the case where each iteration does very little work but pays for bytecode dispatch, boxed integers and dynamic dispatch. Numeric inner loops, custom parsers, hand-rolled algorithms over arrays: adding `cdef int i` and typed memoryviews can be worth one to two orders of magnitude. Being able to release the GIL in a `nogil` block is a secondary win, since it lets threads parallelize the hot section for real.

It doesn't help when:

- **You're I/O bound.** The bottleneck is the network or the disk; compiling the waiting doesn't speed it up.
- **The work is already vectorized.** If the loop is `np.dot` or a pandas group-by, you're already in C — Cython just adds build complexity.
- **The time is inside a C library.** Compiling the Python that *calls* zlib or SQLite changes nothing.
- **You haven't profiled.** Cython on the wrong 5% of the code buys nothing and costs you a build step, wheels for every platform, and a harder debugging story.

Worth knowing the neighbours: `numba` gives you JIT compilation of numeric functions with a decorator and no build system; `mypyc` compiles typed Python ahead of time; and PyO3 lets you write the hot part in Rust with memory safety and good tooling — see [Calling Rust from Python with PyO3](/rust-python-interop-pyo3/) for a worked example.
