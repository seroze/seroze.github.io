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

## Takeaways

- Dynamic typing like Python, C-style syntax like Java.
- Always use `===` (and `!==`); ignore `==`.
- Use `const` by default, `let` when you must reassign.
- Learn the array basics and the common string methods — they cover most
  day-to-day work.
