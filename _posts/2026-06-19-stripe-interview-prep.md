---
layout: post
title: "Stripe Interview Preparation Guide"
date: 2026-06-19 00:00:00 +0530
categories: interview-prep
tags: [stripe, interview, python]
author: "Seroze"
published: true
---

*My preparation notes for the Stripe interview process. Using Python throughout and Zed as the editor.*

> **Disclaimer:** The views and opinions expressed in this post are entirely my own and based on publicly available information. The problem statements included here were sourced from various online communities and discussion forums — they are not confirmed to be actual Stripe interview questions. This is a personal study guide, not an official representation of Stripe's hiring process.

---

## The process

Stripe's interview loop typically has five stages:

1. **Online Assessment** — timed coding problems on an external platform. Usually algorithmic, with a focus on correctness and edge cases.
2. **Problem Solving** — one or two technical interviews where you solve coding problems live with an engineer.
3. **Bug Bash** — you're given a broken codebase and asked to find and fix bugs. Tests the ability to read unfamiliar code quickly.
4. **Integration Round** — design or extend a system, often involving APIs or working with existing abstractions. Less about algorithms, more about how you think about interfaces.
5. **Hiring Manager Round** — behavioural and motivation questions. Why Stripe, how you've worked in the past, how you handle ambiguity.

---

## Setup

**Language:** Python 3  
**Editor:** Zed ([setup guide](/zed-editor/))

Disable auto-completion before every technical round — it won't be available in most assessment environments and you don't want to depend on it:

```json
// Zed settings (Ctrl+,)
{
  "show_completions_on_input": false
}
```

---

## Online Assessment

*Problem statements and solutions to be added.*

---

## Problem Solving

*Problem statements and solutions to be added.*

---

## Bug Bash

This round tests the scientific method in an unfamiliar codebase — not your ability to memorize APIs.

**What you're given:** a clone of a slightly modified internal project, a description of a reported failure, and a test suite where some tests are failing. Your job is to find and fix the bug.

### What the bugs look like

They're rarely algorithmic. Expect logic or configuration errors:

- **Validation too strict** — regex rejecting valid emails containing `+`, or a parser rejecting edge-case input it should accept
- **Platform assumptions** — code that writes to a path without checking the directory exists first; works on the developer's Mac, fails elsewhere
- **Logic gaps** — a condition that misses a specific case, e.g. an `if` that handles `status == "active"` and `status == "inactive"` but silently drops `"pending"`
- **Wrong library usage** — passing arguments in the wrong order, using the wrong method variant, off-by-one in a range

### Debugging methodology

Randomly changing lines until tests pass will fail you. Follow a disciplined five-step process:

**1. Reproduction — confirm the failure first**

Run the failing tests immediately. Do not look at the code yet. Do not touch the code yet. You need a stable, confirmed failure before you can tell whether any change you make actually fixed anything. If you change code before reproducing, you lose your baseline.

```bash
pytest tests/ -v
# note exactly which tests fail and what the error message says
```

**2. Isolation — read the stack trace, not the whole codebase**

Don't start reading files top to bottom. Go straight to the stack trace. Find the exact line where the exception is raised or where the assertion fails. That's your entry point into the code. Everything above it in the trace is call context — read upward only as needed.

**3. Hypothesis generation — say it out loud**

Form a specific, falsifiable statement before touching anything:

> "I suspect the user ID is `None` here because the lookup is returning early"

> "I think this regex doesn't account for `+` in the local part of the email"

Vague suspicions ("something seems off here") lead to random edits. A named hypothesis leads to a targeted test.

**4. Verification — add a print, confirm, then fix**

Add a `print` or `breakpoint()` just before the suspect line to confirm your hypothesis:

```python
print(f"DEBUG user_id={user_id!r}")   # is it None?
print(f"DEBUG pattern match: {re.match(pattern, email)!r}")
breakpoint()   # drop into pdb at runtime
```

Run only the failing test — not the whole suite — to iterate fast. Once confirmed, make the minimal fix.

**5. Cleanup — leave it cleaner than you found it**

Remove every `print` and `breakpoint()`. Run the full test suite. All previously passing tests must still pass. Commit with a clear message describing what was wrong and why.

### How to prepare

The best practice is working with real bugs in real codebases:

1. Go to the [requests](https://github.com/psf/requests) or [httpx](https://github.com/encode/httpx) GitHub repo. Filter issues by the `bug` label. Pick a closed one. Read the issue description, find the code that was broken, then read the PR that fixed it. Notice how small the fix usually is relative to the diagnosis work.

2. Clone pandas or any library you know. Find a function, introduce a subtle break — change `<` to `<=`, swap two arguments, remove a `.strip()`. Then write a test that catches it and use the methodology above to find it. This builds the muscle memory of going from a failing test to a root cause without flailing.

---

## API Fundamentals

Stripe is a REST API company. The integration round and system design questions will expect you to be fluent in these basics.

### HTTP Methods

| Method | Meaning | Example |
|--------|---------|---------|
| `GET` | Read a resource, no side effects | `GET /customers/cus_123` |
| `POST` | Create a new resource | `POST /charges` |
| `PUT` | Replace a resource entirely | `PUT /customers/cus_123` (send all fields) |
| `PATCH` | Partially update a resource | `PATCH /customers/cus_123` (send only changed fields) |
| `DELETE` | Remove a resource | `DELETE /customers/cus_123` |

The distinction between `PUT` and `PATCH` matters: if you're only updating a user's status, use `PATCH` — `PUT` implies you're replacing the whole object and anything you omit gets cleared.

---

### HTTP Status Codes

**2xx — Success**

| Code | Meaning |
|------|---------|
| `200 OK` | Standard success response |
| `201 Created` | Resource was created (successful `POST`) |
| `202 Accepted` | Request accepted but processing continues in the background (async jobs) |

**4xx — Client errors (you messed up)**

| Code | Meaning |
|------|---------|
| `400 Bad Request` | Validation error, missing required field |
| `401 Unauthorized` | Not authenticated — no API key or invalid key |
| `403 Forbidden` | Authenticated but insufficient permissions |
| `404 Not Found` | Resource doesn't exist |
| `429 Too Many Requests` | Rate limited — critical for Stripe integrations |

For `429`, you must know how to handle it: **exponential backoff**. Retry after 1s, then 2s, 4s, 8s — with jitter to avoid thundering herd. Don't hammer the API on a tight loop.

**5xx — Server errors (Stripe messed up)**

| Code | Meaning |
|------|---------|
| `500 Internal Server Error` | Unexpected error on the server |
| `502 Bad Gateway` | Upstream service returned an invalid response |
| `503 Service Unavailable` | Server down for maintenance or overloaded |

5xx errors are safe to retry (unlike 4xx which will keep failing). Same exponential backoff applies.

---

### Pagination: Cursor vs Offset

**Offset pagination** (`?page=2&limit=10`) is what most people reach for first. It's inefficient and unstable:

- **Inefficient:** the database has to count and skip rows on every request — expensive at scale.
- **Unstable:** if items are added or deleted while you're paging, you'll see duplicates or miss records.

**Cursor pagination** (`?starting_after=obj_id`) is what Stripe uses. The cursor points to a specific record in the database, and the query fetches the next N records after it. No counting, no skipping.

```python
# Stripe API example
page = stripe.Customer.list(limit=10)

while True:
    process(page.data)
    if not page.has_more:
        break
    page = stripe.Customer.list(limit=10, starting_after=page.data[-1].id)
```

The response includes `has_more: true` if there are more records beyond the current page, `false` otherwise — clean and unambiguous. Cursor pagination is both efficient (index seek, no full scan) and stable (the cursor anchors to a fixed position in the dataset regardless of concurrent writes).

---

### JSON Serialization and Deserialization

REST APIs speak JSON. You need to be comfortable converting between Python objects and JSON without reaching for documentation.

**Serialization — Python → JSON**

```python
import json

customer = {
    "id": "cus_123",
    "name": "Alice",
    "email": "alice@example.com",
    "balance": 0,
    "metadata": {"plan": "pro"}
}

# Python dict → JSON string
json_string = json.dumps(customer)
print(json_string)
# '{"id": "cus_123", "name": "Alice", "email": "alice@example.com", ...}'

# Pretty-print (useful for debugging)
print(json.dumps(customer, indent=2))

# Python dict → JSON file
with open("customer.json", "w") as f:
    json.dump(customer, f, indent=2)
```

**Deserialization — JSON → Python**

```python
import json

# JSON string → Python dict
json_string = '{"id": "cus_123", "name": "Alice", "balance": 0}'
customer = json.loads(json_string)
print(customer["name"])   # Alice
print(type(customer))     # <class 'dict'>

# JSON file → Python dict
with open("customer.json", "r") as f:
    customer = json.load(f)
```

**Serializing custom objects**

`json.dumps` only handles built-in types (dict, list, str, int, float, bool, None). For custom classes you need a custom encoder or convert to dict first:

```python
import json
from dataclasses import dataclass, asdict

@dataclass
class Charge:
    id: str
    amount: int
    currency: str

charge = Charge(id="ch_123", amount=2000, currency="usd")

# Option 1: convert to dict manually
json.dumps({"id": charge.id, "amount": charge.amount, "currency": charge.currency})

# Option 2: use asdict for dataclasses
json.dumps(asdict(charge))

# Option 3: custom encoder
class ChargeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Charge):
            return asdict(obj)
        return super().default(obj)

json.dumps(charge, cls=ChargeEncoder)
```

**Key distinction to remember:**

| | String | File |
|--|--------|------|
| Serialize | `json.dumps(obj)` | `json.dump(obj, f)` |
| Deserialize | `json.loads(s)` | `json.load(f)` |

`dumps`/`loads` — the `s` stands for string. `dump`/`load` — no `s`, takes a file handle.

---

### Reading and Parsing Files Line by Line

Say you have a file with 100 lines, each containing a transaction: an integer ID, a float amount, and a float fee separated by commas:

```
1001,49.99,1.50
1002,120.00,3.60
1003,9.99,0.30
...
```

**Reading and parsing:**

```python
transactions = []

with open("transactions.txt", "r") as f:
    for line in f:
        line = line.strip()          # remove trailing newline and whitespace
        if not line:                 # skip empty lines
            continue
        parts = line.split(",")
        txn_id = int(parts[0])
        amount = float(parts[1])
        fee = float(parts[2])
        transactions.append((txn_id, amount, fee))

# or more concisely with unpacking
with open("transactions.txt", "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        txn_id, amount, fee = line.split(",")
        transactions.append((int(txn_id), float(amount), float(fee)))
```

**Processing — total revenue, total fees:**

```python
total_amount = sum(t[1] for t in transactions)
total_fees   = sum(t[2] for t in transactions)
net          = total_amount - total_fees

print(f"Transactions: {len(transactions)}")
print(f"Total amount: {total_amount:.2f}")
print(f"Total fees:   {total_fees:.2f}")
print(f"Net revenue:  {net:.2f}")
```

**Things to always do:**
- `strip()` every line — trailing `\n` will break `int()`/`float()` silently turning into a `ValueError`
- Guard against empty lines — files often have a trailing newline that produces a blank last line
- Use `with open(...)` — it closes the file automatically even if an exception is raised

**Does `for line in f` load the whole file into memory?**

No — iterating over a file object in Python is lazy. It reads one line at a time using the OS's buffered I/O (typically 8KB chunks internally), but exposes it to you one line at a time. The whole file is never in memory at once. This is safe and efficient even for multi-GB files.

The things that *do* load the whole file into memory: `f.read()` (one giant string) and `f.readlines()` (list of all lines). Avoid these for large files — use the `for line in f` loop instead.

**Writing to a file:**

```python
transactions = [
    (1001, 49.99, 1.50),
    (1002, 120.00, 3.60),
    (1003, 9.99, 0.30),
]

# Write (overwrites if file exists)
with open("output.txt", "w") as f:
    for txn_id, amount, fee in transactions:
        f.write(f"{txn_id},{amount},{fee}\n")

# Append (adds to end of file without overwriting)
with open("output.txt", "a") as f:
    f.write(f"{1004},{75.00},{2.25}\n")
```

File modes:

| Mode | Behaviour |
|------|-----------|
| `"r"` | Read (default) — error if file doesn't exist |
| `"w"` | Write — creates file if missing, **truncates if it exists** |
| `"a"` | Append — creates file if missing, preserves existing content |
| `"r+"` | Read and write — file must exist |

---

## Integration Round

This round is less about algorithms and more about how you think through interfaces, data structures, and system design at the code level. You'll be asked to build something real — not pseudocode.

**Language note:** Prefer Python over Java here. Less boilerplate means more time thinking about the actual problem. That said, Python's dynamic typing is a double-edged sword — a typo in a variable name won't be caught at compile time and will silently blow up at runtime. Be deliberate: name variables clearly, re-read your code before running, and test incrementally.

---

### Question bank

**Notification delivery system**
Design the architecture for delivering notifications to customers. Think about: delivery channels (email, SMS, webhook), retry logic for failed deliveries, deduplication so a customer doesn't receive the same notification twice, and ordering guarantees.

**Real-time payment system with idempotency**
How would you design a real-time payment system that prevents duplicate charges? Key concept: idempotency keys. A client sends a unique key with each request; the server stores the result against that key and returns the cached result on retries rather than processing the charge again. Design the data model, the key storage, and the expiry policy.

**Currency exchange algorithm**
Design an algorithm that converts an amount from one currency to another given a table of exchange rates. Extension: what if a direct rate doesn't exist and you need to chain conversions (USD → EUR → GBP)?

**Parse currency/shipping rate string**
Parse a string in this format:
```
USD:CAD:DHL:5, USD:GBP:FedEx:3, EUR:USD:UPS:8
```
Each entry represents: `source_currency:target_currency:carrier:rate`. Write a method that takes a source currency, target currency, and amount, and returns the converted amount and the carrier to use.

```python
def parse_rates(rate_string):
    rates = {}
    for entry in rate_string.split(", "):
        src, tgt, carrier, rate = entry.split(":")
        rates[(src, tgt)] = (carrier, float(rate))
    return rates

def convert(rates, src, tgt, amount):
    if (src, tgt) not in rates:
        raise ValueError(f"No rate for {src} -> {tgt}")
    carrier, rate = rates[(src, tgt)]
    return amount * rate, carrier
```

**Invoice scheduler**
Design a system for scheduling invoices to be sent at a future time. Think about: the data model for a scheduled job, how you'd persist and poll pending invoices, handling clock skew, and what happens if the scheduler crashes mid-send.

**CSV processing and validation**
Given a CSV file of transactions, parse and validate the data. Common validation rules: required fields present, numeric fields are valid numbers, dates are in the expected format, no duplicate IDs. Return a list of valid rows and a list of errors with line numbers.

**Shipping cost calculator**
Given a list of orders each with an associated country, calculate the shipping cost for each order. The rate table maps country → cost. Handle missing countries, bulk discounts, and free shipping thresholds.

**Server load balancer**
Build the data structures and logic to manage a pool of servers and distribute client connections across them. Operations to implement:

- `connect(client_id)` — assign a client to a server using the balancing strategy
- `disconnect(client_id)` — release a client's connection
- `shutdown(server_id)` — graceful shutdown: migrate all existing connections from this server to others, then remove it from the pool

Balancing strategies to know:
- **Round robin** — cycle through servers in order; simple, assumes homogeneous servers
- **Least connections** — assign to the server with the fewest active connections; better for variable-length sessions
- **Consistent hashing** — hash the client ID to a point on a ring; each server owns a range; adding/removing a server only remaps a fraction of clients — important for stateful sessions

```python
from collections import defaultdict

class LoadBalancer:
    def __init__(self, servers):
        self.servers = list(servers)        # available server IDs
        self.connections = defaultdict(set) # server_id -> set of client_ids
        self.client_map = {}                # client_id -> server_id
        self._rr_index = 0

    def connect(self, client_id):
        server = self.servers[self._rr_index % len(self.servers)]
        self._rr_index += 1
        self.connections[server].add(client_id)
        self.client_map[client_id] = server
        return server

    def disconnect(self, client_id):
        server = self.client_map.pop(client_id, None)
        if server:
            self.connections[server].discard(client_id)

    def shutdown(self, server_id):
        self.servers.remove(server_id)
        for client_id in list(self.connections[server_id]):
            self.disconnect(client_id)
            self.connect(client_id)          # reassign to remaining servers
        del self.connections[server_id]
```

**Word Search (LeetCode)**
Given a 2D board of characters and a word, return true if the word exists in the grid following adjacent cells (horizontal/vertical, no reuse). Classic DFS with backtracking — mark a cell visited before recursing, unmark on the way back out.

**Sales data aggregation**
Given a list of sales records with varying input constraints (date range, region, product), calculate aggregate metrics. Focus on: grouping efficiently with dicts/defaultdict, handling missing keys gracefully, and clarifying the expected output format before writing any code.

---

## Resources

- [Stripe engineering blog](https://stripe.com/blog/engineering)
- LeetCode — filter by company tag: Stripe
