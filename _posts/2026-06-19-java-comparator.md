---
layout: post
title: "Comparator Interface in Java"
date: 2026-06-19 00:00:00 +0530
categories: java
tags: [java, comparator, sorting]
author: "Seroze"
published: true
---

*Comparator is one of those interfaces you'll use in almost every Java project. Getting fluent with it saves a lot of cognitive overhead.*

---

## Comparable vs Comparator

Java has two ways to define ordering:

**`Comparable<T>`** — the object defines its own natural ordering by implementing `compareTo`. One ordering per class, baked in.

```java
class Student implements Comparable<Student> {
    String name;
    int age;

    @Override
    public int compareTo(Student other) {
        return Integer.compare(this.age, other.age); // natural order: by age
    }
}

List<Student> list = ...;
Collections.sort(list); // uses compareTo
```

**`Comparator<T>`** — an external object defines an ordering. You can have as many as you want, and you don't need to touch the class.

```java
Comparator<Student> byName = (a, b) -> a.name.compareTo(b.name);
list.sort(byName);
```

Use `Comparable` for the one obvious natural ordering (e.g., integers by value, strings lexicographically). Use `Comparator` for everything else — alternate orderings, anonymous sorts, and when you don't own the class.

---

## The `compare` contract

`compare(a, b)` must return:
- **negative** — `a` should come before `b`
- **zero** — `a` and `b` are equal in ordering
- **positive** — `b` should come before `a`

The one rule to remember: **the first argument to `Integer.compare(x, y)` is what you want out first.**

```java
// ascending: small values first
(a, b) -> Integer.compare(a, b)

// descending: large values first
(a, b) -> Integer.compare(b, a)
```

Avoid `a - b` subtraction — it overflows when values are large or negative. Always use `Integer.compare` or `Double.compare`.

---

## The theory: why does `PriorityQueue` accept a comparator?

It's worth pausing on *why* you can pass `Comparator.comparingInt(Student::getAge)` into a `PriorityQueue` constructor and have it "just work." There's no magic here — it's a deliberate design contract.

### A comparator is just a strategy object

`Comparator<T>` is a **functional interface** — an interface with exactly one abstract method:

```java
@FunctionalInterface
public interface Comparator<T> {
    int compare(T a, T b);
}
```

That single method *is* the entire contract. Anything that, given two `T`s, returns an `int` with the right sign convention **is** a comparator. So `Comparator.comparingInt(Student::getAge)` isn't special syntax — it's a factory that builds an ordinary object equivalent to:

```java
new Comparator<Student>() {
    public int compare(Student a, Student b) {
        return Integer.compare(a.getAge(), b.getAge());
    }
};
```

It's an object you can store in a variable, pass around, and hand to anyone who asks for one.

### The sign convention is the agreed-upon construct

`PriorityQueue` knows nothing about `Student`, age, or your domain. It only knows the contract: *"if I call `compare(x, y)` and get a negative number, `x` is smaller and should come out first."* The comparator is the only thing that understands your data. That separation is the whole point.

There's a deeper mathematical requirement too: a comparator must define a **total order** — it has to be consistent (`compare(a,b)` and `compare(b,a)` have opposite signs) and transitive (if `a < b` and `b < c`, then `a < c`). Violate this — the classic `a - b` overflow bug, or a comparator returning inconsistent results — and the heap or sort can throw `IllegalArgumentException: Comparator violates its general contract`, because the algorithm *relies* on those guarantees to place elements.

### Why the constructor accepts it — the Strategy pattern

A heap needs *some* notion of "smallest" to know what `poll()` returns. It can get that two ways:

**Natural ordering** — if `Student implements Comparable<Student>`, the class defines its own `compareTo`, and the heap calls that. One ordering, baked into the type.

**Supplied ordering** — you inject the strategy through the constructor. This is the **Strategy design pattern**: the algorithm (heap maintenance) is fixed, but the *policy* (how to order) is a plug-in you provide. The constructor stores your comparator in a field and calls `comparator.compare(...)` every time it sifts an element up or down. No reflection, no annotations — just "hold a reference and call the method."

Supplied ordering matters because a type can have only **one** natural ordering, but you can have unlimited comparators — by age here, by GPA there — and because you may not even own the class you're sorting.

### The Python analogy

This clicks instantly if you've used Python's `sorted`:

```python
sorted(students, key=lambda s: s.age)
```

Python's `key` is the same plug-in strategy — you hand `sorted` a callable that derives the ordering, and `sorted` stays ignorant of your domain. `Comparator.comparingInt(Student::getAge)` is Java's equivalent of `key=lambda s: s.age`.

| Concept | Java | Python |
|---|---|---|
| Inject an ordering strategy | `Comparator` passed to constructor/`sort` | `key=` passed to `sorted`/`heapq` |
| Key-extractor form | `comparingInt(Student::getAge)` | `key=lambda s: s.age` |
| Raw two-arg form | `compare(a, b)` | `functools.cmp_to_key` |
| Natural ordering on the type | `implements Comparable` | `__lt__` / `__eq__` |

**Bottom line:** `PriorityQueue` accepts a comparator because it's built around the Strategy pattern — it owns the *how-to-heap* logic and delegates the *how-to-order* decision to an interchangeable object you supply. The `int compare(a, b)` sign convention is the contract that lets a generic, domain-blind data structure cooperate with your domain-specific ordering.

---

## Comparator factory methods

Since Java 8, `Comparator` has static factory methods that let you build comparators without writing the comparison logic manually.

### `Comparator.comparing`

```java
// Sort students by name
Comparator<Student> byName = Comparator.comparing(s -> s.name);

// With method reference (cleaner)
Comparator<Student> byName = Comparator.comparing(Student::getName);
```

### `comparingInt`, `comparingDouble`, `comparingLong`

Prefer these over `comparing` when the key is a primitive — they avoid boxing.

```java
Comparator<Student> byAge = Comparator.comparingInt(Student::getAge);
```

---

## Chaining with `thenComparing`

Sort by a primary key, break ties with a secondary key.

```java
// Sort by age ascending, then by name ascending for same age
Comparator<Student> cmp = Comparator
    .comparingInt(Student::getAge)
    .thenComparing(Student::getName);

list.sort(cmp);
```

You can chain as many levels as needed:

```java
Comparator<Employee> cmp = Comparator
    .comparingInt(Employee::getDepartment)
    .thenComparingInt(Employee::getSalary)
    .thenComparing(Employee::getName);
```

---

## Reversing order with `reversed()`

```java
// Descending by age
Comparator<Student> byAgeDesc = Comparator
    .comparingInt(Student::getAge)
    .reversed();

// Descending primary, ascending secondary
Comparator<Student> cmp = Comparator
    .comparingInt(Student::getAge).reversed()
    .thenComparing(Student::getName);       // name still ascending
```

Be careful about where you call `reversed()` — it reverses everything chained before it, not just the last key.

```java
// Reverses BOTH keys
Comparator<Student> cmp = Comparator
    .comparingInt(Student::getAge)
    .thenComparing(Student::getName)
    .reversed();

// Reverses ONLY age, name stays ascending
Comparator<Student> cmp = Comparator
    .comparingInt(Student::getAge).reversed()
    .thenComparing(Student::getName);
```

For mixed directions (ascending primary, descending secondary) without `reversed()`, write the secondary comparator manually:

```java
Comparator<Student> cmp = Comparator
    .comparingInt(Student::getAge)                              // age ascending
    .thenComparing((a, b) -> b.getName().compareTo(a.getName())); // name descending
```

---

## Handling nulls

`Comparator.nullsFirst` and `Comparator.nullsLast` wrap another comparator and push null values to the front or back.

```java
// Nulls sort to the front, non-nulls sort by name
Comparator<Student> cmp = Comparator.nullsFirst(
    Comparator.comparing(Student::getName)
);

// Nulls sort to the back
Comparator<Student> cmp = Comparator.nullsLast(
    Comparator.comparing(Student::getName)
);
```

---

## Where Comparator is used

**`List.sort` and `Collections.sort`:**
```java
list.sort(Comparator.comparingInt(Student::getAge));
Collections.sort(list, Comparator.comparing(Student::getName));
```

**`Arrays.sort`** (object arrays only — `int[]` doesn't accept a comparator):
```java
Student[] arr = ...;
Arrays.sort(arr, Comparator.comparingInt(Student::getAge));
```

**`PriorityQueue`** constructor:
```java
// Min by age
PriorityQueue<Student> pq = new PriorityQueue<>(
    Comparator.comparingInt(Student::getAge)
);

// Max by age
PriorityQueue<Student> pq = new PriorityQueue<>(
    Comparator.comparingInt(Student::getAge).reversed()
);
```

**`TreeMap` and `TreeSet`** constructor:
```java
// TreeSet ordered by name
TreeSet<Student> ts = new TreeSet<>(Comparator.comparing(Student::getName));

// TreeMap ordered by key length
TreeMap<String, Integer> tm = new TreeMap<>(
    Comparator.comparingInt(String::length).thenComparing(Comparator.naturalOrder())
);
```

---

## Storing and reusing comparators

Comparators are objects — you can store them in variables, pass them around, and compose them.

```java
class StudentComparators {
    static final Comparator<Student> BY_AGE = Comparator.comparingInt(Student::getAge);
    static final Comparator<Student> BY_NAME = Comparator.comparing(Student::getName);
    static final Comparator<Student> BY_AGE_THEN_NAME = BY_AGE.thenComparing(BY_NAME);
}

list.sort(StudentComparators.BY_AGE_THEN_NAME);
pq = new PriorityQueue<>(StudentComparators.BY_AGE);
```

---

## Quick reference

| Goal | Code |
|---|---|
| Sort ascending by int field | `Comparator.comparingInt(T::getField)` |
| Sort descending | `.reversed()` |
| Break ties | `.thenComparing(...)` or `.thenComparingInt(...)` |
| Null-safe | `Comparator.nullsFirst(inner)` / `nullsLast(inner)` |
| Natural order | `Comparator.naturalOrder()` |
| Reverse natural order | `Comparator.reverseOrder()` |
| Custom two-field compare | `(a, b) -> Integer.compare(a.x, b.x)` |

**The one rule:** `Integer.compare(X, Y)` means X comes before Y. Put the value you want out first as the first argument.
