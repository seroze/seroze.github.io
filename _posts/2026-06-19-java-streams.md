---
layout: post
title: "Streams in Java"
date: 2026-06-19 00:00:00 +0530
categories: java
tags: [java, streams, functional-programming]
author: "Seroze"
published: true
---

*A Stream is not a data structure — it's a pipeline. You describe what you want, and the stream figures out how to compute it lazily.*

---

## What is a Stream?

A `Stream<T>` is a sequence of elements that supports a pipeline of operations. The key properties:

- **Not a data structure** — it doesn't store elements. It pulls them from a source (collection, array, generator).
- **Lazy** — intermediate operations are not executed until a terminal operation is called.
- **Single-use** — once consumed, a stream cannot be reused.

A pipeline has three parts:

```
source → intermediate operations (lazy) → terminal operation (triggers execution)
```

---

## Creating streams

```java
// From a collection
List<String> names = List.of("Alice", "Bob", "Charlie");
Stream<String> s = names.stream();

// From an array
int[] arr = {1, 2, 3};
IntStream s = Arrays.stream(arr);

// From values directly
Stream<String> s = Stream.of("a", "b", "c");

// Infinite stream — generate
Stream<Double> randoms = Stream.generate(Math::random);

// Infinite stream — iterate (like a for loop)
Stream<Integer> naturals = Stream.iterate(0, n -> n + 1); // 0, 1, 2, 3, ...

// Finite iterate (Java 9+)
Stream<Integer> first10 = Stream.iterate(0, n -> n < 10, n -> n + 1);
```

---

## Intermediate operations

These are lazy — they return a new stream and don't execute until a terminal operation is called.

### `filter` — keep elements matching a predicate

```java
List<Integer> evens = numbers.stream()
    .filter(n -> n % 2 == 0)
    .collect(Collectors.toList());
```

### `map` — transform each element

```java
List<String> upperNames = names.stream()
    .map(String::toUpperCase)
    .collect(Collectors.toList());

// Map to a different type
List<Integer> lengths = names.stream()
    .map(String::length)
    .collect(Collectors.toList());
```

### `flatMap` — flatten a stream of streams

Use when each element maps to multiple elements. `map` would give you a `Stream<List<T>>`; `flatMap` flattens it to `Stream<T>`.

```java
List<List<Integer>> nested = List.of(List.of(1, 2), List.of(3, 4), List.of(5));

// map gives Stream<List<Integer>> — not what we want
// flatMap gives Stream<Integer>
List<Integer> flat = nested.stream()
    .flatMap(Collection::stream)
    .collect(Collectors.toList());
// [1, 2, 3, 4, 5]
```

Another common use — splitting strings into words:

```java
List<String> sentences = List.of("hello world", "foo bar");
List<String> words = sentences.stream()
    .flatMap(s -> Arrays.stream(s.split(" ")))
    .collect(Collectors.toList());
// ["hello", "world", "foo", "bar"]
```

### `sorted` — sort elements

```java
// Natural order
list.stream().sorted()

// Custom comparator
list.stream().sorted(Comparator.comparingInt(Student::getAge))

// Descending
list.stream().sorted(Comparator.comparingInt(Student::getAge).reversed())
```

### `distinct` — remove duplicates

```java
List<Integer> unique = List.of(1, 2, 2, 3, 3, 3).stream()
    .distinct()
    .collect(Collectors.toList());
// [1, 2, 3]
```

### `limit` and `skip`

```java
// First 5 elements
stream.limit(5)

// Skip first 5, take the rest
stream.skip(5)

// Pagination: page 2, size 10
stream.skip(10).limit(10)
```

### `peek` — inspect elements without consuming the stream

Useful for debugging. Does not alter the stream.

```java
list.stream()
    .filter(n -> n > 0)
    .peek(n -> System.out.println("after filter: " + n))
    .map(n -> n * 2)
    .collect(Collectors.toList());
```

---

## Terminal operations

These trigger the pipeline to execute and produce a result. After calling one, the stream is consumed.

### `collect` — gather results into a collection

The most common terminal operation. Takes a `Collector` — covered in the next section.

```java
List<String> list = stream.collect(Collectors.toList());
Set<String> set = stream.collect(Collectors.toSet());
```

### `forEach` — consume each element

```java
names.stream().forEach(System.out::println);
```

Note: `forEach` does not guarantee order on parallel streams. Use `forEachOrdered` if order matters.

### `count`

```java
long count = names.stream().filter(n -> n.startsWith("A")).count();
```

### `findFirst` and `findAny`

Both return an `Optional<T>`. `findFirst` returns the first element in encounter order; `findAny` may return any element (faster on parallel streams).

```java
Optional<String> first = names.stream()
    .filter(n -> n.length() > 3)
    .findFirst();

first.ifPresent(System.out::println);
String val = first.orElse("none");
```

### `anyMatch`, `allMatch`, `noneMatch`

Short-circuit — stop as soon as the answer is known.

```java
boolean hasAdult = students.stream().anyMatch(s -> s.getAge() >= 18);
boolean allAdults = students.stream().allMatch(s -> s.getAge() >= 18);
boolean noneMinor = students.stream().noneMatch(s -> s.getAge() < 18);
```

### `min` and `max`

Return `Optional<T>`.

```java
Optional<Student> youngest = students.stream()
    .min(Comparator.comparingInt(Student::getAge));

Optional<Integer> maxVal = numbers.stream().max(Integer::compare);
```

### `reduce` — fold elements into a single value

```java
// Sum
int sum = numbers.stream().reduce(0, Integer::sum);

// Product
int product = numbers.stream().reduce(1, (a, b) -> a * b);

// Without identity — returns Optional
Optional<Integer> max = numbers.stream().reduce(Integer::max);
```

---

## Collectors

`Collectors` is a utility class with factory methods for common collection strategies.

### `toList`, `toSet`, `toUnmodifiableList`

```java
List<String> list = stream.collect(Collectors.toList());
Set<String> set  = stream.collect(Collectors.toSet());
List<String> immutable = stream.collect(Collectors.toUnmodifiableList());
```

### `toMap`

```java
// Map from name to age
Map<String, Integer> nameToAge = students.stream()
    .collect(Collectors.toMap(Student::getName, Student::getAge));

// Handle duplicate keys with a merge function
Map<String, Integer> nameToAge = students.stream()
    .collect(Collectors.toMap(
        Student::getName,
        Student::getAge,
        (existing, newVal) -> existing  // keep existing on collision
    ));
```

### `groupingBy` — group elements by a classifier

```java
// Group students by department
Map<String, List<Student>> byDept = students.stream()
    .collect(Collectors.groupingBy(Student::getDepartment));

// Group and count
Map<String, Long> countByDept = students.stream()
    .collect(Collectors.groupingBy(
        Student::getDepartment,
        Collectors.counting()
    ));

// Group and collect only names
Map<String, List<String>> namesByDept = students.stream()
    .collect(Collectors.groupingBy(
        Student::getDepartment,
        Collectors.mapping(Student::getName, Collectors.toList())
    ));
```

### `partitioningBy` — split into two groups (true/false)

```java
Map<Boolean, List<Student>> partition = students.stream()
    .collect(Collectors.partitioningBy(s -> s.getAge() >= 18));

List<Student> adults = partition.get(true);
List<Student> minors = partition.get(false);
```

### `joining` — concatenate strings

```java
String result = names.stream().collect(Collectors.joining());
// "AliceBobCharlie"

String result = names.stream().collect(Collectors.joining(", "));
// "Alice, Bob, Charlie"

String result = names.stream().collect(Collectors.joining(", ", "[", "]"));
// "[Alice, Bob, Charlie]"
```

### `counting`, `summingInt`, `averagingInt`

```java
long count = stream.collect(Collectors.counting());
int total  = stream.collect(Collectors.summingInt(Student::getAge));
double avg = stream.collect(Collectors.averagingInt(Student::getAge));
```

---

## Primitive streams

For `int`, `long`, and `double`, use `IntStream`, `LongStream`, `DoubleStream` to avoid boxing overhead. They have extra methods like `sum()`, `average()`, `range()`.

```java
// Sum of 1 to 100
int sum = IntStream.rangeClosed(1, 100).sum();

// Average age
OptionalDouble avg = students.stream()
    .mapToInt(Student::getAge)
    .average();

// Box back to Stream<Integer> if needed
Stream<Integer> boxed = IntStream.range(0, 10).boxed();
```

---

## Common patterns

**Filter then transform:**
```java
List<String> result = students.stream()
    .filter(s -> s.getAge() > 20)
    .map(Student::getName)
    .sorted()
    .collect(Collectors.toList());
```

**Frequency map (word count):**
```java
Map<String, Long> freq = words.stream()
    .collect(Collectors.groupingBy(w -> w, Collectors.counting()));
```

**Flatten and deduplicate:**
```java
Set<String> allTags = posts.stream()
    .flatMap(p -> p.getTags().stream())
    .collect(Collectors.toSet());
```

**Top N elements:**
```java
List<Student> top3 = students.stream()
    .sorted(Comparator.comparingInt(Student::getScore).reversed())
    .limit(3)
    .collect(Collectors.toList());
```

**Check if a value exists and get it:**
```java
students.stream()
    .filter(s -> s.getName().equals("Alice"))
    .findFirst()
    .ifPresent(s -> System.out.println(s.getAge()));
```

---

## Parallel streams

Call `.parallelStream()` instead of `.stream()` to split work across threads. Useful for CPU-bound operations on large collections.

```java
long count = bigList.parallelStream()
    .filter(expensiveOperation)
    .count();
```

Caveats:
- Not always faster — parallelism has overhead. Benchmark before using.
- Order is not guaranteed unless you use `forEachOrdered` or `sorted`.
- Avoid stateful lambdas (e.g., modifying a shared variable) — they cause race conditions.

---

## Quick reference

| Operation | Type | What it does |
|---|---|---|
| `filter(pred)` | Intermediate | Keep matching elements |
| `map(fn)` | Intermediate | Transform each element |
| `flatMap(fn)` | Intermediate | Transform and flatten |
| `sorted(cmp)` | Intermediate | Sort elements |
| `distinct()` | Intermediate | Remove duplicates |
| `limit(n)` | Intermediate | Take first n |
| `skip(n)` | Intermediate | Skip first n |
| `peek(fn)` | Intermediate | Inspect without consuming |
| `collect(c)` | Terminal | Gather into collection |
| `forEach(fn)` | Terminal | Consume each element |
| `count()` | Terminal | Count elements |
| `findFirst()` | Terminal | First element as Optional |
| `anyMatch(pred)` | Terminal | Short-circuit OR |
| `allMatch(pred)` | Terminal | Short-circuit AND |
| `reduce(id, fn)` | Terminal | Fold into single value |
| `min(cmp)` / `max(cmp)` | Terminal | Minimum / maximum as Optional |
