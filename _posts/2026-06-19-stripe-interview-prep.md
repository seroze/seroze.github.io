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

**Webhook delivery system**
Design an architecture for delivering webhook notifications to customers when a payment event occurs. The system must send HTTP requests with event payloads to all predefined merchant URLs. Requirements: payment events must never be lost, third-party endpoint failures must be retried, and merchants need a dashboard to view the history of all webhook attempts.

Core architecture:
- When a payment occurs, persist the event to a durable queue (e.g. a `webhook_events` DB table or message queue) *before* attempting delivery — this is what guarantees no event is lost.
- A worker pool picks up pending events and POSTs to each registered endpoint. On failure (non-2xx or timeout), write the attempt to a `webhook_attempts` log and re-enqueue with exponential backoff.
- Each attempt (timestamp, status code, response body, latency) is stored so the dashboard can show the full delivery history per event.

```
Payment Service → [webhook_events table] → Delivery Workers → Merchant URL
                                                ↓
                                       [webhook_attempts log] → Dashboard API
```

Retry policy: back off exponentially (1s, 2s, 4s, 8s…) up to a max (e.g. 72 hours), then mark the event as permanently failed and alert the merchant.

**Follow-up 1: How would you add rate limiting?**
Use a sliding window per merchant — cap outgoing webhook requests to N per minute. Before dispatching a delivery, check the counter. If the merchant is at the limit, delay the attempt (reschedule it rather than dropping it). See the rate limiter question below.

**Follow-up 2: Some merchants receive huge volumes while others receive very few. How do you ensure small merchants aren't starved?**
A single global queue lets a high-volume merchant monopolise the workers. Instead, use **per-merchant queues** with round-robin dispatch across merchants. Each worker iteration picks one event from merchant A, one from merchant B, one from merchant C — regardless of how full each queue is. High-volume merchants get proportionally more throughput as queue depth grows, but they can never block small merchants entirely.

**Real-time payment system with idempotency**
How would you design a real-time payment system that prevents duplicate charges? Key concept: idempotency keys. A client sends a unique key with each request; the server stores the result against that key and returns the cached result on retries rather than processing the charge again. Design the data model, the key storage, and the expiry policy.

```python
import hashlib
import time
from dataclasses import dataclass, field
from enum import Enum

class PaymentStatus(Enum):
    PENDING   = "pending"
    SUCCEEDED = "succeeded"
    FAILED    = "failed"

@dataclass
class PaymentResult:
    status: PaymentStatus
    charge_id: str
    amount: int
    currency: str
    created_at: float = field(default_factory=time.time)

class PaymentProcessor:
    def __init__(self, ttl_seconds: int = 86400):  # keys expire after 24h
        self._idempotency_store: dict[str, PaymentResult] = {}
        self._ttl = ttl_seconds

    def charge(self, idempotency_key: str, amount: int, currency: str) -> PaymentResult:
        # return cached result if this key was seen before
        if idempotency_key in self._idempotency_store:
            cached = self._idempotency_store[idempotency_key]
            if time.time() - cached.created_at < self._ttl:
                return cached
            # expired — remove and reprocess
            del self._idempotency_store[idempotency_key]

        result = self._process_charge(amount, currency)
        self._idempotency_store[idempotency_key] = result
        return result

    def _process_charge(self, amount: int, currency: str) -> PaymentResult:
        # in reality: call card network, write to DB, etc.
        charge_id = hashlib.sha256(f"{amount}{currency}{time.time()}".encode()).hexdigest()[:16]
        return PaymentResult(
            status=PaymentStatus.SUCCEEDED,
            charge_id=charge_id,
            amount=amount,
            currency=currency,
        )
```

Key points:
- Check the store *before* processing — return the cached `PaymentResult` immediately on a duplicate key. The charge logic never runs twice.
- The idempotency key is supplied by the *client* (e.g. a UUID they generate before the first attempt). The server never generates it.
- TTL prevents the store from growing unboundedly. 24 hours is Stripe's policy.
- In production, the store is a database table (not an in-process dict) so it survives restarts and works across multiple server instances. The key column has a `UNIQUE` constraint — a race between two simultaneous requests with the same key is resolved by the DB rejecting one insert.

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
        if not self.servers:
            raise RuntimeError("No servers available")
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
        # remove from rotation first so connect() won't pick it
        self.servers.remove(server_id)
        # migrate every existing client to a new server
        for client_id in list(self.connections[server_id]):
            self.disconnect(client_id)
            self.connect(client_id)
        del self.connections[server_id]

    def least_connections_connect(self, client_id):
        server = min(self.servers, key=lambda s: len(self.connections[s]))
        self.connections[server].add(client_id)
        self.client_map[client_id] = server
        return server
```

Key points for the interview:
- Remove the server from `self.servers` *before* migrating connections so that `connect()` during migration doesn't route back to the shutting-down server.
- `list(self.connections[server_id])` — copy the set before iterating because `disconnect` mutates it.
- Least-connections just needs `min(..., key=lambda s: len(self.connections[s]))` — one line once the data structure is in place.

**Invoice reminder email subjects**
Your invoicing system needs a configurable reminder schedule. Given an invoice and a schedule of day offsets relative to the due date, output the subject line of every email that would be sent, in sorted (chronological) order.

Example schedule: send an email 10 days before the due date, on the due date, 20 days after, and 30 days after.

```python
from datetime import date, timedelta

SCHEDULE = [
    (-10, "Reminder: Invoice #{id} is due in 10 days"),
    (0,   "Invoice #{id} is due today"),
    (20,  "Invoice #{id} is 20 days overdue — please pay"),
    (30,  "Final notice: Invoice #{id} is 30 days overdue"),
]

def email_subjects(invoice_id: str, due_date: date, schedule=SCHEDULE) -> list[str]:
    emails = []
    for offset, template in schedule:
        send_date = due_date + timedelta(days=offset)
        subject = template.format(id=invoice_id)
        emails.append((send_date, subject))

    emails.sort(key=lambda x: x[0])        # sort chronologically
    return [subject for _, subject in emails]

# Example
subjects = email_subjects("INV-001", date(2024, 3, 15))
for s in subjects:
    print(s)
# Reminder: Invoice #INV-001 is due in 10 days
# Invoice #INV-001 is due today
# Invoice #INV-001 is 20 days overdue — please pay
# Final notice: Invoice #INV-001 is 30 days overdue
```

The schedule is just a list of `(offset, template)` tuples — fully configurable, no special-casing. Sorting on `send_date` (a `date` object) is naturally chronological. The subject template uses `.format(id=...)` so the invoice ID is injected without hardcoding.

**Word Search (LeetCode)**
Given a 2D board of characters and a word, return true if the word exists in the grid following adjacent cells (horizontal/vertical, no reuse). Classic DFS with backtracking — mark a cell visited before recursing, unmark on the way back out.

```python
def exist(board: list[list[str]], word: str) -> bool:
    rows, cols = len(board), len(board[0])

    def dfs(r, c, i):
        if i == len(word):
            return True
        if r < 0 or r >= rows or c < 0 or c >= cols or board[r][c] != word[i]:
            return False
        tmp, board[r][c] = board[r][c], "#"    # mark visited in-place
        found = (dfs(r+1, c, i+1) or
                 dfs(r-1, c, i+1) or
                 dfs(r, c+1, i+1) or
                 dfs(r, c-1, i+1))
        board[r][c] = tmp                       # restore on the way back out
        return found

    return any(dfs(r, c, 0) for r in range(rows) for c in range(cols))
```

Key points:
- Temporarily overwrite the cell with `"#"` to mark it visited — no separate `visited` set needed.
- Restore the cell after the recursive call returns (backtracking). Without this, the mutation from one DFS path would corrupt subsequent paths.
- The base case `i == len(word)` fires when every character has been matched — return `True` immediately.
- Short-circuit with `or` — as soon as one direction succeeds, stop exploring.

**Rate limiter (100 requests per minute per user)**
Design a rate limiter that allows each unique user at most 100 requests per minute. The classic approach is a **sliding window** — track the timestamps of recent requests and evict ones outside the window.

```python
import time
from collections import deque

class RateLimiter:
    def __init__(self, max_requests: int = 100, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window = window_seconds
        self.user_windows: dict[str, deque] = {}

    def is_allowed(self, user_id: str) -> bool:
        now = time.time()
        if user_id not in self.user_windows:
            self.user_windows[user_id] = deque()

        window = self.user_windows[user_id]
        # evict timestamps that have fallen outside the window
        while window and window[0] <= now - self.window:
            window.popleft()

        if len(window) < self.max_requests:
            window.append(now)
            return True
        return False   # rate limited — caller should return 429
```

Key points:
- `deque` with `popleft()` is O(1) for eviction vs a list which is O(n).
- Evict *before* checking the count — otherwise stale timestamps inflate the count.
- At scale, replace the in-process dict with Redis (use a sorted set keyed by `user_id`, scored by timestamp). This makes it work across multiple server instances.
- Trade-off: sliding window is accurate but uses O(requests) memory per user. Fixed window (just a counter + reset time) uses O(1) but allows bursts at window boundaries.

---

**Document signing system (Docusign-like)**
Design the architecture for a system where a sender uploads a document, specifies signatories, and each signatory receives a link to sign. The document is considered complete when all parties have signed.

Core components:
- **Document store** — store the original PDF in object storage (S3). Never mutate the original; each signature creates a new version.
- **Signing workflow state machine** — track state per document: `draft → sent → partially_signed → completed | expired | voided`. Each signatory has their own `pending → signed | declined` state.
- **Audit trail** — every event (sent, viewed, signed, declined) is appended to an immutable log with timestamp and IP.
- **Notification service** — email each signatory when it's their turn. Email the sender when all parties have signed.
- **Signed document generation** — once all signatures are collected, render the final PDF with signature blocks embedded and store it separately.

Follow-up questions to be ready for: how do you prevent someone from signing twice? (idempotency token in the signing URL) How do you handle a signatory declining? (notify sender, allow resend or void) What if the document expires? (cron job scans for past-deadline `sent` documents and transitions them to `expired`).

```python
import uuid
import time
from dataclasses import dataclass, field
from enum import Enum

class DocStatus(Enum):
    DRAFT            = "draft"
    SENT             = "sent"
    PARTIALLY_SIGNED = "partially_signed"
    COMPLETED        = "completed"
    EXPIRED          = "expired"
    VOIDED           = "voided"

class SignatoryStatus(Enum):
    PENDING  = "pending"
    SIGNED   = "signed"
    DECLINED = "declined"

@dataclass
class Signatory:
    email: str
    token: str = field(default_factory=lambda: uuid.uuid4().hex)  # unique signing URL token
    status: SignatoryStatus = SignatoryStatus.PENDING
    signed_at: float | None = None

@dataclass
class Document:
    doc_id: str
    owner_email: str
    signatories: list[Signatory]
    status: DocStatus = DocStatus.DRAFT
    expires_at: float = field(default_factory=lambda: time.time() + 7 * 86400)  # 7 days
    audit_log: list[dict] = field(default_factory=list)

    def _log(self, event: str, actor: str, **kwargs):
        self.audit_log.append({"event": event, "actor": actor, "ts": time.time(), **kwargs})

    def send(self):
        self.status = DocStatus.SENT
        self._log("sent", self.owner_email)
        for s in self.signatories:
            self._notify(s.email, f"Please sign: /sign/{s.token}")

    def sign(self, token: str) -> str:
        if time.time() > self.expires_at:
            return "expired"

        signatory = next((s for s in self.signatories if s.token == token), None)
        if not signatory:
            return "invalid_token"
        if signatory.status == SignatoryStatus.SIGNED:
            return "already_signed"   # idempotent — no double processing

        signatory.status = SignatoryStatus.SIGNED
        signatory.signed_at = time.time()
        self._log("signed", signatory.email)

        if all(s.status == SignatoryStatus.SIGNED for s in self.signatories):
            self.status = DocStatus.COMPLETED
            self._log("completed", "system")
            self._notify(self.owner_email, "All parties have signed.")
        else:
            self.status = DocStatus.PARTIALLY_SIGNED

        return "ok"

    def decline(self, token: str) -> str:
        signatory = next((s for s in self.signatories if s.token == token), None)
        if not signatory:
            return "invalid_token"
        signatory.status = SignatoryStatus.DECLINED
        self._log("declined", signatory.email)
        self._notify(self.owner_email, f"{signatory.email} declined to sign.")
        return "ok"

    def void(self):
        self.status = DocStatus.VOIDED
        self._log("voided", self.owner_email)

    def _notify(self, recipient: str, message: str):
        print(f"[EMAIL] To: {recipient} | {message}")  # replace with real email service

def expire_documents(documents: list[Document]):
    now = time.time()
    for doc in documents:
        if doc.status == DocStatus.SENT and now > doc.expires_at:
            doc.status = DocStatus.EXPIRED
            doc._log("expired", "system")
```

Key points:
- Each signatory gets a unique `token` (UUID) embedded in their signing URL — this is the idempotency mechanism. The server looks up the token, not a session or login.
- `sign()` checks `already_signed` before doing any work — calling it twice with the same token is safe.
- The `audit_log` is append-only; nothing is ever removed from it.
- `expire_documents` is meant to run as a cron job — scan all `sent` documents and flip any that are past their deadline.

---

**Anti-fraud system — CSV aggregation**
Given a CSV file with columns `transaction_type`, `currency`, `date`, `amount`, sum all amounts grouped by `(date, transaction_type)`.

```python
import csv
from collections import defaultdict

def aggregate(filename: str) -> dict[tuple, float]:
    totals: dict[tuple, float] = defaultdict(float)

    with open(filename) as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = (row["date"], row["transaction_type"])
            totals[key] += float(row["amount"])

    return dict(totals)

# Example output:
# {("2024-03-01", "charge"): 15000.0, ("2024-03-01", "refund"): 450.0, ...}
```

For fraud detection, flag groups that exceed a threshold:

```python
def flag_suspicious(totals: dict[tuple, float], threshold: float = 10000.0):
    return {k: v for k, v in totals.items() if v > threshold}
```

Key points: `csv.DictReader` uses the header row as keys — no manual column indexing. `defaultdict(float)` starts every key at 0.0 so `+=` works without an existence check.

---

**Brace Expansion I (LeetCode 1087)**
Given a string like `"{a,b,c}d{e,f}"`, return all words it expands to, sorted. Each `{...}` block is a choice — pick exactly one character from it.

```python
def expand(s: str) -> list[str]:
    groups = []
    i = 0
    while i < len(s):
        if s[i] == '{':
            j = s.index('}', i)
            groups.append(sorted(s[i+1:j].split(',')))
            i = j + 1
        else:
            groups.append([s[i]])
            i += 1

    result = ['']
    for group in groups:
        result = [prefix + c for prefix in result for c in group]
    return sorted(result)

# expand("{a,b}c{d,e}") -> ["acd", "ace", "bcd", "bce"]
```

Build the result incrementally: start with `['']` and for each group, take the Cartesian product of current prefixes × current group choices.

---

**Brace Expansion II (LeetCode 1096)**
Harder variant — braces can be nested and concatenation happens implicitly. `"{a{b,c}}"` → `["ab","ac"]`, `"{a,b}{c,{d,e}}"` → `["ac","ad","ae","bc","bd","be"]`.

Approach: recursive parser. A comma at depth 0 separates alternatives; everything else is concatenation. Each level returns a sorted deduplicated list of strings.

```python
def braceExpansionII(expression: str) -> list[str]:
    def parse(expr: str) -> list[str]:
        groups = [['']]   # list of "alternatives"; each alternative is a list of prefixes
        depth = 0
        start = 0

        for i, c in enumerate(expr):
            if c == '{':
                if depth == 0:
                    start = i + 1
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    sub = parse(expr[start:i])
                    groups[-1] = [a + b for a in groups[-1] for b in sub]
            elif c == ',' and depth == 0:
                groups.append([''])
            elif depth == 0:
                groups[-1] = [a + c for a in groups[-1]]

        return sorted(set(w for g in groups for w in g))

    return parse(expression)
```

Key points:
- Track `depth` to know when you're inside a nested `{}` — only act on `,` and plain characters at depth 0.
- On closing `}` at depth 0: recursively parse the inner content and take the Cartesian product with the current group's prefixes.
- Deduplicate with `set` at each level since `{a,a}` should produce `["a"]` not `["a","a"]`.

---

**Sales data aggregation**
Given a list of sales records with varying input constraints (date range, region, product), calculate aggregate metrics. Focus on: grouping efficiently with dicts/defaultdict, handling missing keys gracefully, and clarifying the expected output format before writing any code.

---

## Resources

- [Stripe engineering blog](https://stripe.com/blog/engineering)
- LeetCode — filter by company tag: Stripe
- [RoundZ — Stripe interview experiences](https://roundz.ai/company/stripe?tab=interviews)
