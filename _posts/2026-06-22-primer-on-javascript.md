---
layout: post
title: "A Primer on JavaScript"
date: 2026-06-22 00:00:00 +0530
categories: programming
tags: [javascript, web, basics]
author: "Seroze"
published: true
---

If you already know Python and Java, JavaScript is easy to pick up. It sits
somewhere between the two:

- **Like Python**, it is *dynamically typed* — you don't declare types, and a
  variable can hold a string now and a number later.
- **Like Java**, the *syntax* is C-style — curly braces for blocks, semicolons
  at the end of statements, `for` loops with the classic three-part header.

This post collects the handful of things worth knowing up front.

## Primitive types

Unlike some languages, JavaScript doesn't split numbers into `int`, `float`,
`double`, etc. — there is just one `number` type that covers integers and
floating-point alike. In total JavaScript has **7 primitive types**:

| Type        | Example              |
|-------------|----------------------|
| `number`    | `42`, `3.14`, `NaN`, `Infinity` |
| `string`    | `"hello"`, `'world'` |
| `boolean`   | `true`, `false`      |
| `undefined` | `let x;`             |
| `null`      | `let x = null;`      |
| `bigint`    | `123n`               |
| `symbol`    | `Symbol("id")`       |

A couple of things worth noting:

- `number` includes special values `NaN` (not-a-number) and `Infinity`.
- `bigint` is for integers larger than `number` can safely hold — note the `n`
  suffix.

You check a value's type with the `typeof` operator. A few worth remembering:

```javascript
typeof 42           // "number"
typeof "hello"      // "string"
typeof true         // "boolean"
typeof undefined    // "undefined"
typeof null         // "object"   <-- historical bug
typeof {}           // "object"
typeof []           // "object"
typeof function(){} // "function"
```

Two gotchas to note: `typeof null` returns `"object"` (a long-standing bug in
the language), and arrays also report `"object"`.

For arrays specifically, use `Array.isArray(obj)`. Your instinct might be to
reach for `typeof`, but there's a gotcha — both arrays and plain objects report
`"object"`, so `typeof` can't tell them apart:

```javascript
typeof []   // "object"
typeof {}   // "object"

Array.isArray([])   // true
Array.isArray({})   // false
```

## Math utilities

The built-in `Math` object has the usual helpers. `Math.min` and `Math.max`
return the smallest/largest of their arguments, and `Infinity` is handy as a
starting "very large" value (for example when finding a minimum):

```javascript
Math.min(3, 1, 2);   // 1
Math.max(3, 1, 2);   // 3

let smallest = Infinity;
for (const x of [5, 2, 8]) {
    smallest = Math.min(smallest, x);
}
// smallest === 2
```

## Always use `===`, never `==`

This is the single most important habit to build. The honest answer is that
most modern JavaScript developers rarely use `==`.

Historically, `==` was added to make JavaScript more forgiving in the early days
of the web. It does *type coercion* before comparing, so it converts the
operands to a common type first:

```javascript
"5" == 5      // true
1 == true     // true
0 == false    // true
```

The idea was that developers wouldn't have to manually convert types all the
time. For example, a value coming from an HTML form is always a string:

```javascript
let age = "25"; // from an HTML form

if (age == 25) {
    console.log("same");   // this prints
}
```

The problem is that these coercion rules are surprising and error-prone. `===`
(strict equality) compares **value and type** with no coercion:

```javascript
"5" === 5     // false
1 === true    // false
0 === false   // false
```

**Rule of thumb:** always use `===` and `!==`. Forget `==` exists.

## Declaring variables: `const` and `let`

Prefer `const` for anything that won't be reassigned (think `final` in Java),
and `let` when you genuinely need to reassign. Avoid the old `var`.

```javascript
const name = "Seroze";   // cannot be reassigned
let count = 0;           // can be reassigned
count = count + 1;
```

<span style="color:red">Watch out: if you assign to a variable *without*
declaring it with `let`/`const`/`var`, JavaScript silently creates a **global
variable** instead of erroring. This is a historical quirk and a real source of
bugs.</span>

I got bitten by this in a binary search — I used `lo` and `hi` without declaring
them, so they leaked into the global scope and the code did all sorts of garbage:

```javascript
function search(arr, target) {
    lo = 0;              // ❌ no let/const — becomes a global!
    hi = arr.length - 1;
    while (lo <= hi) {
        // ...
    }
}
```

The fix is just to declare them: `let lo = 0, hi = arr.length - 1;`. (Running in
*strict mode* — `"use strict";` — turns this silent footgun into an actual
error, which is why modules and classes enable it by default.)

## For loops

The classic C-style loop is exactly what you'd expect:

```javascript
for (let i = 0; i < 10; i++) {
    console.log(i);
}
```

## Arrays

Arrays are JavaScript's lists. Use `.length` to get the number of elements:

```javascript
const arr = [10, 20, 30];
console.log(arr.length);   // 3

for (let i = 0; i < arr.length; i++) {
    console.log(arr[i]);
}
```

A few array basics worth learning early: `push()` / `pop()` (add/remove at the
end), `shift()` / `unshift()` (front), `slice()`, `indexOf()`, and the
higher-order ones like `map()`, `filter()`, and `forEach()`.

### Creating an array of size n

Use the `Array(n)` constructor together with `.fill()` to get an array of a
fixed size with a default value:

```javascript
const zeros = new Array(5).fill(0);     // [0, 0, 0, 0, 0]
const ones  = new Array(3).fill(1);     // [1, 1, 1]
```

If you need each element computed from its index, use `Array.from()`:

```javascript
// [0, 1, 2, 3, 4]
const seq = Array.from({ length: 5 }, (_, i) => i);

// 2D array (3x3 grid of zeros) — note: build each row separately
const grid = Array.from({ length: 3 }, () => new Array(3).fill(0));
```

> **Heads up:** don't write `new Array(3).fill(new Array(3).fill(0))` for a 2D
> grid — every row would be the *same* array reference, so changing one row
> changes all of them. Use `Array.from` as shown above.

### Checking if an element is in an array

Use `includes()` — it returns a boolean and is the cleanest way to check
membership:

```javascript
const arr = [10, 20, 30];

arr.includes(20);   // true
arr.includes(99);   // false
```

If you also need the *position* of the element, use `indexOf()`. It returns the
index, or `-1` if the element isn't present:

```javascript
arr.indexOf(20);    // 1
arr.indexOf(99);    // -1

if (arr.indexOf(20) !== -1) {
    console.log("found it");
}
```

<span style="color:red">Note: `indexOf()` returns only the **first** matching
index, even if the value appears multiple times in the array.</span>

```javascript
[5, 7, 5, 9].indexOf(5);   // 0, not 2 — only the first match
```

(If you need the last one, use `lastIndexOf()`.)

### Sorting: always pass a comparator

By default `sort()` converts elements to **strings** and sorts
lexicographically. This produces nonsense for numbers:

```javascript
const nums = [1, 2, 10, 5];

nums.sort();

console.log(nums);   // [1, 10, 2, 5]  ❌
```

`10` comes before `2` because the string `"10"` is less than `"2"`.

<span style="color:red">Always pass a custom comparator (a lambda) when sorting
numbers. The comparator returns a negative number if `a` should come first, zero
if equal, positive if `b` should come first.</span>

```javascript
const nums = [1, 2, 10, 5];

nums.sort((a, b) => a - b);   // ascending
console.log(nums);            // [1, 2, 5, 10]  ✅

nums.sort((a, b) => b - a);   // descending
console.log(nums);            // [10, 5, 2, 1]
```

Yes, the string-by-default behaviour is garbage — but this is how JavaScript
works, so just build the habit of always passing a comparator.

#### Comparator vs key functions (vs Python)

There's a subtle difference here if you're coming from Python. **JavaScript
follows the Java convention** — `sort()` takes a *comparator* `(a, b)` that
answers *"which of these two comes first?"*. **Python takes a *key* function**
that answers *"what value should I sort this element by?"*.

```python
# Python — key style
arr.sort(key=lambda obj: obj.x)
```

```javascript
// JavaScript — comparator style
arr.sort((a, b) => a.x - b.x);
```

A common mistake is to pass a Python-style key to JS: `arr.sort(o => o.x)`. That
silently breaks, because JS calls it as `fn(a, b)`, not `fn(a)`. To sort by a
key `fn`, wrap it in a comparator: `arr.sort((a, b) => fn(a) - fn(b))`.

## String utility methods

Strings come with a bunch of built-in helpers. Get familiar with them — you'll
reach for these constantly:

```javascript
const s = "hello world";

s.charAt(0);       // "h"
s.slice(0, 5);     // "hello"
s.toUpperCase();   // "HELLO WORLD"
s.toLowerCase();   // "hello world"
s.indexOf("world") // 6
s.includes("lo")   // true
s.split(" ");      // ["hello", "world"]
s.trim();          // removes leading/trailing whitespace
```

Note that `.length` works on strings too (`s.length` is `11`).

Strings in JavaScript are **immutable** — you can't change a character in place.
Assigning to an index simply does nothing:

```javascript
let s = "hello";
s[0] = "H";
console.log(s);   // "hello" — unchanged
```

If you need to edit a string, convert it to a character array first, mutate the
array, then join it back:

```javascript
let s = "hello";
const chars = s.split("");   // ["h", "e", "l", "l", "o"]
chars[0] = "H";
s = chars.join("");          // "Hello"
console.log(s);              // "Hello"
```

The key trick is `const chars = s.split("")` — since strings are immutable, this
is the standard way to get a mutable char array you can index into and edit. It
comes up constantly in string problems, so keep it handy.

And to go back the other way, join the array into a string:

```javascript
return chars.join("");   // convert char array back to a String
```

## Sets

A `Set` stores unique values. Use `add()` to insert, `has()` to check
membership, `delete()` to remove, and `.size` for the count:

```javascript
const seen = new Set();
seen.add(1); seen.add(1); seen.add(2);
console.log(seen.has(1), seen.size);   // true 2
```

## The `...` spread / rest operator

`...` is one of the most useful pieces of modern JS syntax. It does two
opposite-looking things depending on where it appears. (It's roughly analogous
to Python's `*args` / `*list` unpacking.)

### Spread — "unpack" into individual items

It expands an array (or any iterable) into its individual elements. This is
exactly what `fn(...args)` does in the `cancellable` example above:

```javascript
fn(...args);   // if args = [2, 3], this calls fn(2, 3)
```

Other common uses:

```javascript
const a = [1, 2, 3];
const b = [...a, 4, 5];        // [1, 2, 3, 4, 5]  — copy + extend
Math.max(...a);                // 3                — array -> arguments

const o1 = { x: 1 };
const o2 = { ...o1, y: 2 };    // { x: 1, y: 2 }   — works on objects too
```

It's also the idiomatic way to make a **shallow copy**: `const copy = [...arr]`.

Note that spread is only a *shallow* copy — nested objects/arrays are still
shared by reference. For a true **deep copy**, use the built-in
`structuredClone()`:

```javascript
const original = { a: 1, nested: { b: 2 } };

const shallow = { ...original };
shallow.nested.b = 99;
console.log(original.nested.b);   // 99  — nested object was shared ❌

const deep = structuredClone(original);
deep.nested.b = 42;
console.log(original.nested.b);   // 99  — original untouched ✅
```

This is the JS equivalent of Python's `copy.deepcopy()` (versus the shallow
`copy.copy()`).

### Rest — "collect" the leftovers into one array

In a function's parameter list (or in destructuring), `...` does the reverse —
it gathers multiple values into a single array:

```javascript
function sum(...nums) {         // nums is a real array
    return nums.reduce((acc, x) => acc + x, 0);
}
sum(1, 2, 3);                   // 6

const [first, ...others] = [10, 20, 30];
// first = 10, others = [20, 30]
```

**Rule of thumb:** `...` in a *call or literal* spreads (unpacks); `...` in a
*parameter list or destructuring target* collects (rest).

## Generators

A generator is a function that can pause and resume, producing a sequence of
values lazily — much like Python's generators. You declare one with `function*`
and emit values with `yield`. Calling the generator returns an iterator, and
each `.next()` runs until the next `yield`.

Here's an infinite Fibonacci generator:

```javascript
function* fibonacci() {
    let [a, b] = [0, 1];
    while (true) {
        yield a;
        [a, b] = [b, a + b];
    }
}

const gen = fibonacci();
console.log(gen.next().value);   // 0
console.log(gen.next().value);   // 1
console.log(gen.next().value);   // 1
console.log(gen.next().value);   // 2
console.log(gen.next().value);   // 3
```

Because it's lazy, an infinite generator is fine — you just take as many values
as you need. For example, the first 10 Fibonacci numbers:

```javascript
function firstN(gen, n) {
    const out = [];
    for (const x of gen) {
        out.push(x);
        if (out.length === n) break;
    }
    return out;
}

console.log(firstN(fibonacci(), 10));
// [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
```

## Extending built-ins with `.prototype`

In JavaScript you can add new methods to a built-in class (like `Array`) by
attaching them to its `prototype`. Every array then has access to your method:

```javascript
Array.prototype.second = function () {
    return this[1];
};

const arr = [10, 20, 30];
console.log(arr.second());   // 20
```

This is real **monkey-patching** — you're modifying the built-in type itself.

> **Note:** you *cannot* do this directly in Python. Python forbids patching
> built-in types like `list` (`list.second = ...` raises a `TypeError`). To get
> similar behaviour there you'd have to **subclass** `list`:
>
> ```python
> class MyList(list):
>     def second(self):
>         return self[1]
> ```

A word of caution: monkey-patching built-ins is powerful but considered risky —
it affects *every* array in your program and can clash with future language
features or other libraries. Use it sparingly.

## `setTimeout` and `clearTimeout`

`setTimeout(fn, t)` schedules `fn` to run once after `t` milliseconds. It
returns a **timer id** that you can pass to `clearTimeout(id)` to cancel the
call *before* it fires.

A classic LeetCode problem (*Cancellable Function*) makes this concrete: schedule
a function, but hand back a `cancel()` that stops it if called in time.

```javascript
var cancellable = function (fn, args, t) {
    const timerId = setTimeout(() => { fn(...args); }, t);

    // calling this before `t` ms have passed cancels the scheduled fn
    return function () {
        clearTimeout(timerId);
    };
};
```

How it plays out: if the returned `cancel()` runs before `t`, `clearTimeout`
removes the pending call and `fn` never executes. If `t` elapses first, `fn`
runs and the later `clearTimeout` is a harmless no-op.

```javascript
const fn = (x) => x * 5;
const args = [2], t = 20, cancelTimeMs = 50;

const cancel = cancellable(fn, args, t);   // fn fires at t = 20ms
setTimeout(cancel, cancelTimeMs);          // cancel at 50ms — too late, fn already ran
// fn(2) returns 10
```

Here `cancelTimeMs` (50) is greater than `t` (20), so `fn` fires first and the
cancel does nothing. If `cancelTimeMs` were less than `t`, the call would be
cancelled and `fn` would never run.

If the calling and execution flow is still confusing, here's another way to
frame it:

- You're supposed to execute `fn` after a delay of `t`, and *also* return a
  `cancel` function.
- If `cancel` is called, it should stop the pending timeout for `fn`.
- So if `cancel` is called *after* `fn` has already executed, nothing happens.
  But if it's called *before*, we clear the timeout so `fn` never runs at all.

The implementation recipe is simple: put a `setTimeout` (which will resolve into
executing `fn`) just before returning the `cancel` function, and put a
`clearTimeout` inside `cancel`.

### `setInterval` and `clearInterval`

Where `setTimeout` fires once, `setInterval(fn, t)` calls `fn` **repeatedly**
every `t` milliseconds. It also returns a timer id, which you cancel with
`clearInterval(id)` to stop the repeats:

```javascript
let count = 0;
const id = setInterval(() => {
    count++;
    console.log(count);
}, 1000);          // logs 1, 2, 3, ... every second

// later, to stop it:
clearInterval(id);
```

## The event loop: microtasks vs macrotasks

JavaScript is single-threaded, and async callbacks are scheduled onto two
different queues:

- **Microtask queue** — Promise callbacks (`.then`, `await`), `queueMicrotask`.
- **Macrotask queue** — `setTimeout`, `setInterval`, I/O events.

The event loop's rule is simple but easy to get wrong:

1. Run **all** microtasks (draining the queue completely).
2. Run **one** macrotask.
3. Repeat.

Crucially, the entire microtask queue is emptied before the *next* macrotask
runs — so a `setTimeout(fn, 0)` still waits behind every pending Promise
callback. Consider:

```javascript
console.log(1);

setTimeout(() => {
    console.log(2);
}, 0);

Promise.resolve()
    .then(() => { console.log(3); })
    .then(() => { console.log(4); });

console.log(5);
```

This prints **`1, 5, 3, 4, 2`**:

- `1` and `5` are synchronous — they run first, top to bottom.
- `3` and `4` are microtasks (Promise callbacks) — they drain next, in order.
- `2` is a macrotask (`setTimeout`) — even with a `0`ms delay, it runs *last*,
  after the microtask queue is empty.

(Python's `asyncio` has a comparable distinction between ready callbacks and
scheduled-later ones, though the exact ordering rules differ.)

## `valueOf()` and `toString()` — custom conversion

JavaScript objects can control how they behave when converted to a number or a
string. This is something I ran into while solving LeetCode.

- **`valueOf()`** is called when JavaScript needs a *numeric* value from an
  object (for example, with the `+` operator).
- **`toString()`** is called when it needs a *string* representation (for
  example, inside `String(...)`).

```javascript
class Box {
    constructor(x) {
        this.x = x;
    }
    valueOf()  { return this.x; }
    toString() { return `Box(${this.x})`; }
}

const a = new Box(3);
const b = new Box(7);

console.log(a + b);        // 10   -> a.valueOf() + b.valueOf()
console.log(String(a));    // "Box(3)" -> a.toString()
```

The LeetCode **Array Wrapper** problem uses both at once:

```javascript
var ArrayWrapper = function (nums) {
    this.nums = nums;
};

ArrayWrapper.prototype.valueOf = function () {
    return this.nums.reduce((sum, x) => sum + x, 0);
};

ArrayWrapper.prototype.toString = function () {
    return `[${this.nums.join(',')}]`;
};

const obj1 = new ArrayWrapper([1, 2]);
const obj2 = new ArrayWrapper([3, 4]);

obj1 + obj2;     // 10        -> obj1.valueOf() + obj2.valueOf()
String(obj1);    // "[1,2]"   -> obj1.toString()
```

This lets operators like `+` and functions like `String()` work naturally with
your own classes — a feature without a direct equivalent in Python, Java, or Go.

## Takeaways

- Dynamic typing like Python, C-style syntax like Java.
- Always use `===` (and `!==`); ignore `==`.
- Use `const` by default, `let` when you must reassign.
- Learn the array basics and the common string methods — they cover most
  day-to-day work.
- Always pass a comparator to `sort()` for numbers — the default sorts as
  strings.
- Generators (`function*` / `yield`) give you lazy sequences.
- You can monkey-patch built-ins via `.prototype`, but do it sparingly.
- Custom classes can hook into `+` and `String()` via `valueOf()` and
  `toString()`.
- `...` spreads in calls/literals and collects (rest) in parameter lists.
