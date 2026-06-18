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
