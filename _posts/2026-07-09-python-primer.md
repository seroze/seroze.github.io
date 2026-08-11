---
layout: post
title: "A primer on Python"
date: 2026-07-09 00:00:00 +0530
categories: python
tags: [python, typing, protocols, competitive_programming]
author: "Seroze"
published: true
---

*A running collection of Python concepts worth knowing cold.*

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
