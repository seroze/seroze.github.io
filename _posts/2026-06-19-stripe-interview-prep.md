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

*Examples and approach to be added.*

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

---

## Integration Round

*Examples and approach to be added.*

---

## Resources

- [Stripe engineering blog](https://stripe.com/blog/engineering)
- LeetCode — filter by company tag: Stripe
