---
layout: post
title: "Java Interview Revision — Data Structures Cheatsheet"
date: 2026-06-17 00:00:00 +0530
categories: java
tags: [java, interview, data-structures]
author: "Seroze"
published: true
---

*Quick reference for Java built-in data structures — the things that always trip you up mid-interview.*

---

## Arrays

Array length is an **instance variable**, not a method call.

```java
int[] arr = {3, 1, 4, 1, 5};
int n = arr.length;   // no parentheses
```

Sort an array in ascending order with `Arrays.sort()`:

```java
Arrays.sort(arr);  // [1, 1, 3, 4, 5]
```

Pass a custom comparator to sort in a different order. Comparators only work on object arrays (use `Integer[]`, not `int[]`):

```java
Integer[] arr = {3, 1, 4, 1, 5};

// Sort descending
Arrays.sort(arr, (a, b) -> b - a);  // [5, 4, 3, 1, 1]

// Sort by absolute value
Integer[] nums = {-3, 1, -4, 2};
Arrays.sort(nums, (a, b) -> Math.abs(a) - Math.abs(b));  // [1, 2, -3, -4]
```

---

## Priority Queue (Heap)

`PriorityQueue` is a **min-heap** by default — `poll()` returns the smallest element.

```java
PriorityQueue<Integer> minHeap = new PriorityQueue<>();
minHeap.add(5);
minHeap.add(1);
minHeap.add(3);

minHeap.peek();   // 1  — view top without removing
minHeap.poll();   // 1  — remove and return top
minHeap.isEmpty(); // false
```

Pass a comparator to the constructor to get a **max-heap** or custom ordering:

```java
// Max-heap
PriorityQueue<Integer> maxHeap = new PriorityQueue<>((a, b) -> b - a);

// Min-heap by string length
PriorityQueue<String> byLength = new PriorityQueue<>((a, b) -> a.length() - b.length());
```

---

## Strings

Length is a **method** on strings (unlike arrays where it's a field):

```java
String s = "hello";
int n = s.length();   // parentheses required
```

Strings are **immutable** — every operation returns a new string.

Use `.equals()` for value comparison, not `==`. The `==` operator only checks reference equality.

```java
String a = new String("hello");
String b = new String("hello");

a == b        // false — different objects in memory
a.equals(b)   // true  — same content
```

---

## Set

All collections in Java use `.size()` (not `.length`) to get their size.

```java
Set<Integer> s = new HashSet<>();

s.add(1);
s.add(2);
s.add(1);       // duplicate, ignored

s.size();        // 2
s.contains(1);   // true
s.contains(99);  // false
```

---

## HashMap

```java
Map<String, Integer> map = new HashMap<>();

map.put("apple", 1);
map.put("banana", 2);

map.get("apple");              // 1
map.get("missing");            // null
map.getOrDefault("missing", 0); // 0 — safe fallback
```

`getOrDefault` also accepts a lambda or expression as the default value:

```java
// Default to the result of some computation
map.getOrDefault(key, computeDefault());
```

Use `computeIfAbsent` when the default value is a new collection — it only computes and inserts when the key is absent, then returns the value. This lets you chain the update on the same line:

```java
Map<String, List<Integer>> groups = new HashMap<>();

// Without computeIfAbsent — verbose
groups.putIfAbsent("a", new ArrayList<>());
groups.get("a").add(1);

// With computeIfAbsent — idiomatic
groups.computeIfAbsent("a", k -> new ArrayList<>()).add(1);
```

The lambda `k -> new ArrayList<>()` receives the missing key `k` and returns the value to insert. The whole expression evaluates to the list, so `.add(1)` works directly on the returned list.

---

## ArrayList

`ArrayList` is a resizable array. Use it when you need indexed access and don't care about fast insertions at the front.

```java
List<Integer> list = new ArrayList<>();

list.add(10);       // append to end
list.add(20);
list.add(1, 99);    // insert 99 at index 1 — shifts elements right

list.get(0);        // 10  — O(1) random access
list.set(0, 55);    // replace element at index 0
list.remove(0);     // remove by index — shifts elements left
list.remove(Integer.valueOf(99)); // remove by value (need Integer, not int)

list.size();        // number of elements
list.contains(20);  // true
list.isEmpty();     // false
```

Iterate over elements:

```java
// Index-based
for (int i = 0; i < list.size(); i++) {
    System.out.println(list.get(i));
}

// Enhanced for-loop (preferred when index isn't needed)
for (int val : list) {
    System.out.println(val);
}
```

Sort an `ArrayList` with `Collections.sort()` or `list.sort()`:

```java
Collections.sort(list);                        // ascending
list.sort((a, b) -> b - a);                   // descending via comparator
```

---

## LinkedList

`LinkedList` is a doubly-linked list. It implements both `List` and `Deque`, so it's commonly used as a **queue** or **stack** in interviews.

```java
LinkedList<Integer> ll = new LinkedList<>();

// Add elements
ll.add(1);           // append to tail
ll.addFirst(0);      // prepend to head
ll.addLast(2);       // append to tail (same as add)

// Access elements
ll.get(0);           // O(n) — traverses from head, avoid in hot loops
ll.getFirst();       // O(1) — peek at head
ll.getLast();        // O(1) — peek at tail

// Remove elements
ll.removeFirst();    // remove and return head
ll.removeLast();     // remove and return tail
ll.remove(1);        // remove by index

ll.size();
ll.isEmpty();
```

Used as a **queue** (FIFO):

```java
Queue<Integer> queue = new LinkedList<>();

queue.offer(1);   // enqueue — add to tail (prefer over add(), won't throw on capacity)
queue.offer(2);
queue.offer(3);

queue.peek();     // 1 — view front without removing
queue.poll();     // 1 — remove and return front
```

Used as a **stack** (LIFO) — though `ArrayDeque` is faster in practice:

```java
Deque<Integer> stack = new LinkedList<>();

stack.push(1);    // push to front
stack.push(2);
stack.push(3);

stack.peek();     // 3 — view top
stack.pop();      // 3 — remove and return top
```

---

*More sections to come — Sorting patterns, String manipulation.*
