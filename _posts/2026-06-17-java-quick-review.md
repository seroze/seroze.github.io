---
layout: post
title: "Java Quick Review"
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

## Comparator — how to tune ordering

> For a deeper dive, see the dedicated post: [Java Comparator]({% post_url 2026-06-19-java-comparator %}).

A comparator must return:
- **negative** → `a` comes before `b`
- **zero** → equal
- **positive** → `b` comes before `a`

Since `PriorityQueue` is a min-heap, the element the comparator considers "smallest" (most negative) pops first.

**Ascending (smallest first):**
```java
(a, b) -> Integer.compare(a, b)   // 2 pops before 5
```

**Descending (largest first — max-heap):**
```java
(a, b) -> Integer.compare(b, a)   // 5 pops before 2
```

**Custom objects — sort Tweets by timestamp:**
```java
// Oldest first
PriorityQueue<Tweet> pq = new PriorityQueue<>((a, b) -> Integer.compare(a.createdAt, b.createdAt));

// Newest first
PriorityQueue<Tweet> pq = new PriorityQueue<>((a, b) -> Integer.compare(b.createdAt, a.createdAt));
```

**Multi-level sort** — age ascending, salary descending:
```java
Comparator<Employee> cmp =
    Comparator.comparingInt((Employee e) -> e.age)
              .thenComparing((a, b) -> Integer.compare(b.salary, a.salary));
```

**The one rule to remember:**

> `Integer.compare(X, Y)` means *X pops before Y*.

So if you want the **largest** value out first, put the larger-valued expression first:
```java
Integer.compare(b.field, a.field)  // b (larger) comes before a (smaller)
```
If you want the **smallest** first:
```java
Integer.compare(a.field, b.field)  // a (smaller) comes before b (larger)
```

Avoid `a - b` style subtraction — it overflows on large integers. Always use `Integer.compare`.

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

**`hashCode()` and the contract with `equals()`**

By default, `hashCode()` returns a value derived from the object's memory address — so two `new` objects will have different hashcodes even if their contents are identical.

The contract Java requires:

- If `a.equals(b)` is `true` → `a.hashCode() == b.hashCode()` **must** be true.
- If `a.hashCode() == b.hashCode()` → `a.equals(b)` is **not necessarily** true (hash collision).

This matters because `HashMap` and `HashSet` use `hashCode()` first to find the bucket, then `equals()` to confirm the match. If you override `equals()` without overriding `hashCode()`, two logically equal objects will land in different buckets and the map/set will treat them as distinct keys.

```java
class Point {
    int x, y;

    @Override
    public boolean equals(Object o) {
        Point p = (Point) o;
        return x == p.x && y == p.y;
    }

    @Override
    public int hashCode() {
        return Objects.hash(x, y); // must include same fields as equals()
    }
}

Set<Point> set = new HashSet<>();
set.add(new Point(1, 2));
set.contains(new Point(1, 2)); // true — only works because both methods are overridden
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
s.remove(1);     // removes 1, returns true; returns false if not present
```

---

## HashMap

```java
Map<String, Integer> map = new HashMap<>();

map.put("apple", 1);
map.put("banana", 2);

map.get("apple");               // 1
map.get("missing");             // null
map.getOrDefault("missing", 0); // 0 — safe fallback
map.remove("apple");            // removes entry, returns the value (1) or null
map.containsKey("banana");      // true
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

## TreeSet

`TreeSet` stores elements in **sorted order** (natural ordering by default). All operations are O(log n). Use it when you need sorted membership and range queries — things `HashSet` can't do.

```java
TreeSet<Integer> ts = new TreeSet<>();
ts.add(10);
ts.add(30);
ts.add(20);
ts.add(50);
// internal order: [10, 20, 30, 50]

ts.first();   // 10 — smallest element
ts.last();    // 50 — largest element
ts.size();    // 4
ts.contains(20); // true
```

**Range queries** — the four key methods:

```java
ts.floor(25);    // 20 — largest element <= 25
ts.ceiling(25);  // 30 — smallest element >= 25
ts.lower(20);    // 10 — largest element strictly < 20
ts.higher(20);   // 30 — smallest element strictly > 20
```

All four return `null` if no such element exists, so null-check before using the result.

**Cross-language equivalents** — given a sorted list `a` and query value `x`:

| Java (TreeSet) | C++ | Python (`bisect`) |
|---|---|---|
| `ceiling(x)` — smallest ≥ x | `lower_bound(x)` | `a[bisect.bisect_left(a, x)]` |
| `higher(x)` — smallest > x | `upper_bound(x)` | `a[bisect.bisect_right(a, x)]` |
| `floor(x)` — largest ≤ x | `*prev(upper_bound(x))` | `a[bisect.bisect_right(a, x) - 1]` |
| `lower(x)` — largest < x | `*prev(lower_bound(x))` | `a[bisect.bisect_left(a, x) - 1]` |

Python's `bisect_left` and `bisect_right` return **indices**, not values — index into the list to get the element. Always bounds-check the index before using it (an index of `-1` or `>= len(a)` means no such element exists).

```python
import bisect

a = [10, 20, 30, 50]

# ceiling(25) — smallest >= 25
i = bisect.bisect_left(a, 25)   # i = 2
a[i]                             # 30

# higher(20) — smallest > 20
i = bisect.bisect_right(a, 20)  # i = 2
a[i]                             # 30

# floor(25) — largest <= 25
i = bisect.bisect_right(a, 25) - 1  # i = 1
a[i]                                 # 20

# lower(20) — largest < 20
i = bisect.bisect_left(a, 20) - 1   # i = 0
a[i]                                 # 10
```

---

## TreeMap

`TreeMap` is a sorted map — keys are kept in natural order (or a custom comparator). It gives you all the `HashMap` operations plus the same range query methods on keys.

```java
TreeMap<Integer, String> tm = new TreeMap<>();
tm.put(10, "ten");
tm.put(30, "thirty");
tm.put(20, "twenty");
tm.put(50, "fifty");
// key order: 10, 20, 30, 50

tm.firstKey();  // 10
tm.lastKey();   // 50
```

**Key-only range queries:**

```java
tm.floorKey(25);    // 20 — largest key <= 25
tm.ceilingKey(25);  // 30 — smallest key >= 25
tm.lowerKey(20);    // 10 — largest key strictly < 20
tm.higherKey(20);   // 30 — smallest key strictly > 20
```

**Entry range queries** — same methods but return the full key-value pair:

```java
Map.Entry<Integer, String> e = tm.floorEntry(25);
e.getKey();    // 20
e.getValue();  // "twenty"
```

**Example — find the closest appointment:**

```java
// Keys are timestamps, values are appointment names
TreeMap<Integer, String> calendar = new TreeMap<>();
calendar.put(900,  "standup");
calendar.put(1200, "lunch");
calendar.put(1500, "review");

int now = 1100;

// What's the next appointment from now?
Map.Entry<Integer, String> next = calendar.ceilingEntry(now);
// next.getKey() = 1200, next.getValue() = "lunch"

// What was the last appointment before now?
Map.Entry<Integer, String> prev = calendar.lowerEntry(now);
// prev.getKey() = 900, prev.getValue() = "standup"
```

**Submap — get all keys in a range:**

```java
// Keys from 1000 to 1400 (inclusive on both ends)
SortedMap<Integer, String> window = calendar.subMap(1000, true, 1400, true);
// {1200 -> "lunch"}
```

---

## EnumMap

`EnumMap` is a specialized `Map` whose keys **must** belong to a single enum type. When all your keys come from an enum, prefer it over `HashMap` — it's faster and uses less memory.

```java
enum Day { MON, TUE, WED, THU, FRI, SAT, SUN }

EnumMap<Day, String> plan = new EnumMap<>(Day.class); // pass the enum's Class

plan.put(Day.MON, "gym");
plan.put(Day.WED, "swim");
plan.put(Day.FRI, "rest");

plan.get(Day.MON);          // "gym"
plan.getOrDefault(Day.TUE, "free"); // "free"
plan.containsKey(Day.WED);  // true
```

**Why it's efficient:** internally an `EnumMap` is just an array indexed by each enum constant's `ordinal()` (its position in the declaration). There's no hashing, no buckets, and no collisions — a `get`/`put` is a direct array access. It also keeps keys in **enum declaration order** when iterated, which `HashMap` does not.

```java
// Iterates in MON, WED, FRI order — the order the constants are declared
for (Map.Entry<Day, String> e : plan.entrySet()) {
    System.out.println(e.getKey() + " -> " + e.getValue());
}
```

The one constraint: you must pass the enum's `Class` object to the constructor (`new EnumMap<>(Day.class)`), since the map needs to know the universe of possible keys up front. Keys cannot be `null`.

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

---

## Commonly Asked Questions

### Abstract Class vs Interface — what's the difference and which is preferred?

| | Abstract Class | Interface |
|---|---|---|
| Instantiation | Cannot be instantiated | Cannot be instantiated |
| Methods | Can have abstract and concrete methods | All methods abstract by default; `default` methods allowed since Java 8 |
| Fields | Can have instance variables (state) | Only `public static final` constants |
| Constructors | Yes | No |
| Inheritance | A class can extend only **one** abstract class | A class can implement **multiple** interfaces |
| Access modifiers | Methods can be any visibility | Methods are `public` by default |

**Which is preferred?**

Prefer **interfaces** in most cases. They let you:
- Implement multiple interfaces (avoiding the single-inheritance limit)
- Program to an abstraction without committing to a class hierarchy
- Add `default` method implementations without breaking existing code

Use an **abstract class** when:
- You need to share **state** (instance variables) across subclasses
- You need a **constructor** to enforce initialization
- Subclasses are tightly related and share a lot of common behavior that isn't just a contract

```java
// Interface — defines a contract
interface Flyable {
    void fly();
    default String describe() { return "I can fly"; }
}

// Abstract class — shares state and partial implementation
abstract class Animal {
    private String name;  // shared state

    Animal(String name) { this.name = name; }

    public String getName() { return name; }
    abstract void speak();  // subclasses must implement
}
```

**How Java avoids the diamond problem**

The diamond problem: if class `D` inherits from both `B` and `C`, and both `B` and `C` override a method from their common parent `A`, which version does `D` get?

Java sidesteps this entirely for classes — you can only `extend` one class, so the diamond can never form in the class hierarchy.

```java
class A { void hello() { System.out.println("A"); } }
class B extends A { void hello() { System.out.println("B"); } }
class C extends A { void hello() { System.out.println("C"); } }

// This is a compile error — Java doesn't allow it
class D extends B, C { }  // ERROR: cannot extend multiple classes
```

With interfaces it's trickier, because `default` methods (added in Java 8) can have implementations. If two interfaces both define a `default` method with the same signature, the implementing class **must override it** — the compiler forces you to resolve the ambiguity explicitly.

```java
interface B {
    default String hello() { return "Hello from B"; }
}

interface C {
    default String hello() { return "Hello from C"; }
}

// Compile error if you don't override hello()
class D implements B, C {
    @Override
    public String hello() {
        return B.super.hello(); // explicitly pick one, or write your own
    }
}
```

If only one of the interfaces provides a `default` implementation and the other declares the method as abstract, there's no conflict — the concrete default wins automatically.

```java
interface B {
    default String hello() { return "Hello from B"; }
}

interface C {
    String hello(); // abstract — no implementation
}

class D implements B, C {
    // No override needed — B's default satisfies C's contract too
}
```

---

### How do you make an object immutable?

An immutable object cannot be modified after construction. The pattern:

1. Make the class `final` so it can't be subclassed.
2. Make all fields `private final`.
3. Set all fields only in the constructor.
4. Provide no setters.
5. In getters for mutable fields (collections, arrays, other objects), return a **deep copy**, not the original reference.

```java
import java.util.ArrayList;
import java.util.List;

public final class Student {
    private final String name;
    private final List<String> courses;

    public Student(String name, List<String> courses) {
        this.name = name;
        this.courses = new ArrayList<>(courses); // defensive copy on the way in
    }

    public String getName() {
        return name; // String is already immutable, safe to return directly
    }

    public List<String> getCourses() {
        return new ArrayList<>(courses); // deep copy on the way out
    }
}
```

Why the deep copy in the getter matters:

```java
Student s = new Student("Alice", List.of("Math", "CS"));
List<String> c = s.getCourses();
c.add("Physics");           // modifies the copy, not the internal list
s.getCourses().size();      // still 2 — object is unaffected
```

If you returned `courses` directly, the caller could mutate the internal list and break immutability even without a setter.

---

### The `record` keyword — and why it's beneficial

A `record` (since Java 16) is a compact way to declare an immutable, data-carrying class. You write the components once, and the compiler generates the boilerplate for you.

```java
public record Point(int x, int y) {}
```

That single line gives you, for free:

- A `private final` field for each component (`x`, `y`)
- A canonical constructor `Point(int x, int y)`
- An accessor for each component — `x()` and `y()` (note: no `get` prefix)
- `equals()` and `hashCode()` based on **all** components
- A readable `toString()` — `Point[x=1, y=2]`

Compare this to the hand-written equivalent from the immutability section above — a record collapses ~40 lines of fields, constructor, getters, `equals`, and `hashCode` into one line.

**Why it's beneficial:**

1. **Eliminates boilerplate.** No more manually writing and maintaining `equals`/`hashCode`/`toString` that drift out of sync when you add a field.
2. **Immutable by default.** All fields are `final` and there are no setters, so records are inherently thread-safe and safe to use as `HashMap`/`HashSet` keys — the generated `equals`/`hashCode` honor the contract automatically (see the [hashCode section](#strings) above).
3. **Correct `equals`/`hashCode` for free.** The compiler includes every component, so two records with equal contents are always equal — exactly the behavior you want for value objects and DTOs.
4. **Intent is explicit.** `record` signals "this is just data," making code easier to read than a class full of generated-looking methods.

You can still add validation or custom logic via a **compact constructor**:

```java
public record Point(int x, int y) {
    public Point {                       // compact canonical constructor
        if (x < 0 || y < 0) {
            throw new IllegalArgumentException("coordinates must be non-negative");
        }
    }
}
```

```java
Point a = new Point(1, 2);
Point b = new Point(1, 2);

a.equals(b);   // true  — value equality, generated automatically
a.x();         // 1     — accessor, no "get" prefix
a.toString();  // Point[x=1, y=2]

Set<Point> seen = new HashSet<>();
seen.add(new Point(1, 2));
seen.contains(new Point(1, 2)); // true — works out of the box
```

**Limitations to know:** a record can't extend another class (it implicitly extends `java.lang.Record`), and its components are always final — so it's the right tool for immutable value carriers, not for mutable entities.

---

### Optional — handling "maybe absent" values

`Optional<T>` (since Java 8) is a container that holds either a value or nothing. It exists to make the absence of a value explicit in the type signature, so callers are forced to deal with it instead of being surprised by a `NullPointerException`.

```java
Optional<String> present = Optional.of("hello");   // value must be non-null
Optional<String> empty   = Optional.empty();        // no value
Optional<String> maybe   = Optional.ofNullable(x);  // empty if x is null, else holds x
```

Use `Optional` as a **return type** for methods that might not have an answer — not for fields or method parameters.

```java
public Optional<User> findByEmail(String email) {
    // returns Optional.empty() instead of null when not found
}
```

**Commonly used APIs:**

```java
Optional<User> result = findByEmail("a@b.com");

// 1. Check presence
result.isPresent();   // true if a value is held
result.isEmpty();     // true if empty (Java 11+)

// 2. Provide a fallback
result.orElse(defaultUser);            // returns the value, or defaultUser if empty
result.orElseGet(() -> buildUser());   // lazy — supplier only runs when empty
result.orElseThrow();                  // throws NoSuchElementException if empty (Java 10+)
result.orElseThrow(() -> new UserNotFoundException()); // custom exception

// 3. Run code only when present
result.ifPresent(user -> System.out.println(user.name));
result.ifPresentOrElse(                // Java 9+
    user -> System.out.println(user.name),
    ()   -> System.out.println("not found")
);

// 4. Transform / chain without unwrapping
result.map(user -> user.email);        // Optional<String> — empty stays empty
result.filter(user -> user.isActive()); // empties out if predicate fails
result.flatMap(user -> user.getManager()); // when the mapper itself returns an Optional
```

**`map` vs `flatMap`:** use `map` when your function returns a plain value (`User -> String`); use `flatMap` when your function already returns an `Optional` (`User -> Optional<Manager>`) — otherwise you'd get a nested `Optional<Optional<Manager>>`.

**`orElse` vs `orElseGet`:** `orElse(buildUser())` **always** evaluates `buildUser()`, even when the value is present. `orElseGet(() -> buildUser())` only calls it when empty — prefer `orElseGet` when the fallback is expensive.

A typical fluent chain ties it together:

```java
String managerEmail = findByEmail("a@b.com")
    .filter(User::isActive)
    .flatMap(User::getManager)
    .map(User::getEmail)
    .orElse("no-manager@company.com");
```

**Anti-patterns to avoid:**

- Don't call `.get()` without checking presence first — it throws on empty. Prefer `orElse`, `orElseThrow`, or `ifPresent`.
- Don't use `Optional` for fields or collection elements — it adds overhead and was never designed for that. Use it for return values.
- Don't wrap a collection in `Optional` — return an empty list/map instead.

---

### Composition vs Inheritance

This is one of my favorite interview questions.

Suppose you're building a payment system.

**Inheritance:**

```java
class PaymentProcessor {}

class StripeProcessor extends PaymentProcessor {}

class RazorpayProcessor extends PaymentProcessor {}
```

Fine. But now you want:

- logging
- retries
- metrics
- authentication
- rate limiting

Inheritance quickly becomes:

```java
LoggingStripeProcessor
RetryStripeProcessor
RetryLoggingStripeProcessor
AuthenticatedRetryLoggingStripeProcessor
```

It explodes combinatorially — every new behavior multiplies the number of subclasses you'd need to cover all combinations.

**Composition:**

```java
class PaymentProcessor {
    private Logger logger;
    private RetryPolicy retry;
    private Metrics metrics;
}
```

Each behavior is independent:

- Need retries? Swap `RetryPolicy`.
- Need a different logger? Swap `Logger`.
- Need exponential backoff? Inject another implementation.

Much cleaner.

**Interview answer**

Use **inheritance** when there is a genuine *is-a* relationship and subclasses should be substitutable for the base class (the idea behind the Liskov substitution principle).

Use **composition** when you want to assemble behavior from interchangeable parts, or when behaviors may change independently.

**Composition and unit testing**

This is one of the biggest practical advantages.

```java
class OrderService {
    private PaymentGateway gateway;
}
```

Unit test:

```java
PaymentGateway gateway = mock(PaymentGateway.class);
OrderService service = new OrderService(gateway);
```

Easy.

With inheritance:

```java
class OrderService extends StripeGateway { }
```

How do you replace `StripeGateway`? You usually can't without awkward subclassing or specialized mocking tools.

Composition naturally supports **dependency injection**, making code easier to isolate in tests.
