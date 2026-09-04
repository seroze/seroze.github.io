---
layout: post
title: "[Python] Exception Handling: The Parts I Got Wrong"
date: 2026-08-13 00:00:00 +0530
categories: python
tags: [python, exceptions]
author: "Seroze"
published: true
---

Notes from working through an exception-handling quiz. Everything below was verified
on CPython 3.12 rather than recalled — the sections marked **trap** are the ones I
actually got wrong, and they cluster around one theme: the *hierarchy* and the
*unwind*, not the syntax.

A companion to [A primer on Python](/python-primer/), which covers the object model —
descriptors, closures, copying, the GIL — in the same style.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

---

## 1. The exception tree

```
BaseException
├── SystemExit
├── KeyboardInterrupt
├── GeneratorExit
├── BaseExceptionGroup
└── Exception
    ├── ArithmeticError
    │   ├── ZeroDivisionError
    │   ├── OverflowError
    │   └── FloatingPointError
    │
    ├── LookupError
    │   ├── IndexError
    │   └── KeyError
    │
    ├── ValueError
    │   └── UnicodeError
    │       ├── UnicodeDecodeError
    │       └── UnicodeEncodeError
    │
    ├── NameError
    │   └── UnboundLocalError
    │
    ├── RuntimeError
    │   ├── RecursionError
    │   └── NotImplementedError
    │
    ├── ImportError
    │   └── ModuleNotFoundError
    │
    ├── SyntaxError
    │   └── IndentationError
    │       └── TabError
    │
    ├── TypeError
    ├── AttributeError
    ├── AssertionError
    ├── StopIteration
    ├── StopAsyncIteration
    ├── MemoryError
    ├── EOFError
    ├── ExceptionGroup        (BaseExceptionGroup + Exception)
    │
    └── OSError               (IOError, EnvironmentError are aliases)
        ├── FileNotFoundError
        ├── FileExistsError
        ├── PermissionError
        ├── IsADirectoryError
        ├── NotADirectoryError
        ├── TimeoutError      (socket.timeout is an alias of this)
        ├── BlockingIOError
        ├── InterruptedError
        ├── ProcessLookupError
        ├── ChildProcessError
        └── ConnectionError
            ├── ConnectionResetError
            ├── ConnectionRefusedError
            ├── ConnectionAbortedError
            └── BrokenPipeError
```

Three things worth memorising from this shape:

- **`KeyboardInterrupt`, `SystemExit`, and `GeneratorExit` are siblings of `Exception`, not children.** That is the entire reason `except Exception:` in a worker loop doesn't eat your Ctrl-C. They *are* in the `BaseException` tree — everything is — they're just outside the `Exception` subtree.
- **`TimeoutError` lives under `OSError`.** So `except OSError` catches network timeouts. Since 3.10, `socket.timeout` is literally the same object.
- **`IOError` is not a separate class.** `IOError is OSError` → `True`. Same for `EnvironmentError`. Both are 2.x compatibility aliases.

---

## 2. Handler order: first match wins **(trap)**

```python
try:
    raise KeyError("k")
except LookupError:
    print("lookup")      # ← this runs
except KeyError:
    print("key")         # ← unreachable, silently
```

Prints `lookup`. Handlers are tested **top to bottom, first match wins** — this is *not*
most-specific-wins like C++ overload resolution or Java's compile-checked catch ordering.
Python will not warn you that the second clause is dead.

`KeyError.__mro__` is `KeyError → LookupError → Exception → BaseException`, and
`except LookupError` matches anything in that chain.

**Rule: order handlers specific → general.**

---

## 3. `finally` runs on every exit edge **(trap)**

```python
for i in range(3):
    try:
        if i == 1:
            continue
        print("body", i)
    finally:
        print("finally", i)
```

```
body 0
finally 0
finally 1      ← continue still unwinds through finally
body 2
finally 2
```

`continue`, `break`, `return`, and a propagating exception all trigger the unwind.
That is the whole point of the clause: no exit path escapes it.

The corollary — and it's a real bug source:

```python
def f():
    try:
        return 1
    finally:
        return 2      # → 2. The pending return is discarded.
```

A `return`, `break`, or `continue` inside `finally` **discards whatever was in flight**,
including an in-flight exception, silently. Never transfer control out of a `finally`.

---

## 4. `except ... as e` deletes `e` at the end of the block **(trap)**

```python
try:
    raise ValueError("v")
except ValueError as e:
    pass
print(e)      # NameError: name 'e' is not defined
```

Python compiles `except X as e:` into an implicit `finally: del e`. The reason is a
reference cycle: the exception holds `__traceback__` → frame → locals → `e`, so keeping
the name bound would pin every local in that frame alive.

If you need it after the block, bind it out explicitly:

```python
err = None
try:
    ...
except ValueError as e:
    err = e
```

The nastier corollary — it deletes the name even if you were already using it for
something else — is in [the primer](/python-primer/#except--as-e-deletes-e).

---

## 5. `raise` vs `raise e`

Bare `raise` re-raises the exception being handled, untouched. `raise e` raises the same
object but records the current line as an extra traceback frame:

```
# bare raise                        # raise e
line 21, in <module>  fn()          line 21, in <module>  fn()
line  8, in bare      inner()       line 16, in explicit  raise e    ← extra frame
line  4, in inner     raise Value…  line 14, in explicit  inner()
                                    line  4, in inner     raise Value…
```

The traceback now claims the error surfaced at the re-raise site. **Use bare `raise`.**
(In Python 2, `raise e` discarded the original traceback outright; Python 3 keeps it on
`e.__traceback__`, so the damage is only noise — but it's still noise in a postmortem.)

---

## 6. Chaining: `__cause__` vs `__context__`

```python
try:
    cfg = json.loads(raw)
except json.JSONDecodeError as e:
    raise ConfigError(f"bad config at {path}") from e
```

- `raise X from Y` sets `__cause__` — an explicit *"this caused that"*.
- Raising inside an `except` block **without** `from` still sets `__context__` implicitly.
  The traceback reads *"During handling of the above exception, another exception occurred."*
- `from None` suppresses the chain, for when the inner exception is an implementation
  detail you don't want leaking to callers.

The failure mode this fixes:

```python
def load(path):
    try:
        return parse(open(path).read())
    except Exception:
        raise ConfigError("could not load config")   # ← cause destroyed
```

Everyone downstream sees `ConfigError: could not load config` with no idea whether the
file was missing, unreadable, or malformed. Two fixes, both needed: catch the specific
types (`FileNotFoundError`, `PermissionError`, `JSONDecodeError`) and use `from e`.

---

## 7. Custom exceptions: `args` must stay a valid argument list **(trap)**

This one is genuinely surprising. Start here:

```python
class ValidationError(Exception):
    def __init__(self, field, reason):
        self.field = field
        self.reason = reason
```

```python
e = ValidationError("age", "negative")
str(e)    # "('age', 'negative')"   ← the raw tuple repr, not a message
e.args    # ('age', 'negative')
```

`BaseException.__new__` populates `args` from the constructor arguments even though
`super().__init__()` was never called. So `str(e)` is ugly but pickling happens to work.

Now the *obvious* fix breaks it:

```python
def __init__(self, field, reason):
    super().__init__(f"{field}: {reason}")   # str(e) is nice now...
```

`args` is now a **one**-element tuple. `BaseException.__reduce__` reconstructs by
replaying `args` through `__init__`, so unpickling calls `ValidationError("age: negative")`:

```
TypeError: ValidationError.__init__() missing 1 required positional argument: 'reason'
```

Same breakage under `copy.copy()` and across a `multiprocessing` boundary.

**The invariant: `args` must remain a valid argument list for your own `__init__`.**

```python
class ValidationError(Exception):
    def __init__(self, field, reason):
        super().__init__(field, reason)       # args matches the signature
        self.field, self.reason = field, reason
    def __str__(self):
        return f"{self.field}: {self.reason}"
```

Carry structured data as attributes. Callers should never have to parse `str(e)`.

### Hierarchy design

One base class per subsystem, so callers can catch broadly or narrowly:

```python
class StorageError(Exception): pass
class KeyNotFound(StorageError): pass
class CorruptRecord(StorageError): pass
class ReadOnlyStore(StorageError): pass
```

```python
# caller that only cares that storage failed
try:
    value = store.get(k)
except StorageError as e:
    log.exception("storage failed")
    return INTERNAL_ERROR

# caller that treats a miss as normal, lets everything else propagate
try:
    value = store.get(k)
except KeyNotFound:
    value = DEFAULT
```

PEP 8 convention is the `Error` suffix, not `Exception` — matches the stdlib.
No trailing `except StorageError: raise`; unhandled exceptions propagate by default.

---

## 8. Keep the `try` block narrow, and use `else`

```python
try:
    data = fetch(url)
    parsed = json.loads(data)
    record = parsed["user"]["id"]
except Exception as e:
    log.error(f"fetch failed: {e}")
    return None
```

Three bugs in six lines:

1. **The `try` is too wide.** A `KeyError` from a missing `user` key gets logged as
   "fetch failed".
2. **`except Exception` swallows your own bugs** — `TypeError`, `NameError`,
   `AttributeError` all become a quiet `return None`.
3. **`log.error(f"...{e}")` throws away the traceback.** Use `log.exception(...)`,
   which attaches it automatically.

`else` exists to keep the guarded region minimal:

```python
try:
    conn = open_socket()
except TimeoutError:
    ...
else:
    notify_downstream(conn)   # its failures are NOT reported as connect failures
finally:
    cleanup()
```

Without `else`, a failure in `notify_downstream` gets attributed to the connect.

---

## 9. Cleanup belongs inside the unwind

```python
f = open("data.txt")
try:
    process(f)
except IOError:
    print("io error")
f.close()          # ← never runs if process() raises anything else
```

Any non-`IOError` propagates and the descriptor leaks. CPython's refcounting usually
papers over it; PyPy doesn't, and neither does the case where `f` is captured in a
traceback frame that outlives the function.

```python
with open("data.txt") as f:
    process(f)
```

`with` is just `try/finally` with the cleanup owned by the object instead of the caller.
The desugaring, and what `__exit__` returning truthy does, are in
[the primer](/python-primer/#context-managers).

---

## 10. EAFP, and why it's cheap now

*Easier to Ask Forgiveness than Permission* — attempt the operation, handle the failure,
rather than checking preconditions first.

The case where check-first (LBYL) is genuinely **wrong**, not just unidiomatic, is
TOCTOU:

```python
if os.path.exists(path):     # another process can unlink it right here
    f = open(path)           # → FileNotFoundError anyway
```

The check buys nothing; you still need the handler. Same class of bug as check-then-act
without a lock.

Since 3.11, CPython uses **zero-cost exceptions**: handler offsets live in a side table
rather than being pushed at `try` setup, so a `try` block that doesn't raise costs
essentially nothing. Raising is still expensive (traceback construction), so exceptions
remain a bad fit for hot-path control flow — but wrapping code defensively is free.

---

## 11. How a process dies, and what still runs

| How it's stopped | Can Python catch it? | Can the program continue? | Does `finally` run? |
|---|---|---|---|
| `Ctrl+C` (SIGINT) | Yes — `KeyboardInterrupt` | Yes | Yes |
| SIGTERM | Yes — via `signal.signal` handler | Yes, if you want | Yes, if the handler raises or returns |
| `sys.exit()` | Yes — it just raises `SystemExit` | Yes, if you catch `SystemExit` | **Yes** |
| `os._exit()` | No | No | **No** |
| `kill -9` (SIGKILL) | No | No | No |
| Power failure / OS crash | No | No | No |

**The one that catches people:** `sys.exit()` *does* run `finally`, because it is not a
special mechanism at all — it raises `SystemExit`, which unwinds the stack like any other
exception. Verified:

```
sys.exit(1)  ->  'finally ran'   rc=1
os._exit(1)  ->  ''              rc=1
```

So the correct answer to *"when does `finally` not run?"* is: `os._exit()`, `SIGKILL`,
a segfault in a C extension, a hard hang, or the machine going away. Not `sys.exit()`.

Note also that `SystemExit` derives from `BaseException`, not `Exception` — precisely so
that a blanket `except Exception` in a request loop can't accidentally cancel a shutdown.

---

## 12. A retry helper, as a worked example

```python
import time

def retry(fn, attempts=3, delay=0.5):
    for attempt in range(1, attempts + 1):
        try:
            return fn()
        except ConnectionError as e:
            if attempt == attempts:
                e.add_note(f"failed after {attempts} attempts")   # 3.11+
                raise                                            # bare — keep the traceback
            time.sleep(delay * 2 ** (attempt - 1))                # backoff
```

Points it exercises: retry only the specific exception; bare `raise` so the traceback
survives; `add_note` to attach context mid-stack without changing the exception type;
exponential backoff, because fixed-interval retries across many clients amplify the
outage you're retrying against.

`add_note` is the underrated one — it lets a middle frame contribute context the raiser
didn't have, without wrapping and without inventing a new exception class.

---

## Pre-interview checklist

- [ ] Handlers match **top to bottom, first match wins**. Order specific → general.
- [ ] `KeyboardInterrupt` / `SystemExit` / `GeneratorExit` are **siblings** of `Exception`.
- [ ] `finally` fires on `return`, `break`, `continue`, and exceptions. Never `return` from it.
- [ ] `except X as e:` implicitly `del e` at block exit.
- [ ] Bare `raise` to re-raise; `raise X from e` to wrap; `from None` to sever.
- [ ] `args` must stay a valid argument list for `__init__`, or pickling breaks.
- [ ] `log.exception`, not `log.error(f"{e}")`.
- [ ] `sys.exit()` runs `finally`; `os._exit()` does not.
- [ ] `TimeoutError` and `ConnectionError` are under `OSError`. `IOError is OSError`.

---

**Not covered here:** `ExceptionGroup` / `except*`. Context-manager semantics —
`__exit__` returning truthy to swallow an exception, `contextlib.suppress`, and
exceptions inside generators — are covered in
[A primer on Python](/python-primer/#context-managers).
