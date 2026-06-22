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
