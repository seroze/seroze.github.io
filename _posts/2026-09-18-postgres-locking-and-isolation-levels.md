---
layout: post
title: "[Databases] Locking and isolation levels in Postgres"
date: 2026-09-18 00:00:00 +0530
categories: databases
tags: [databases, postgres, concurrency, isolation_levels, locking, transactions, system_design]
author: "Seroze"
published: true
---

This started as a refresher on the four SQL isolation levels and drifted, the way these
things do, into row locking and then into the one problem everybody uses to explain row
locking: how a movie ticket site avoids selling seat 42 twice.

The two halves are the same subject from opposite ends. Isolation levels are the
declarative knob — you tell Postgres how much interference you're willing to tolerate and
it decides what to do. Row locks are the imperative knob — you tell Postgres exactly which
rows nobody else may touch until you commit. Most real systems use a low isolation level
and a few carefully placed locks, and understanding why means understanding both.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The anomalies come first

Isolation levels are defined by what they forbid, so the anomalies are the actual
vocabulary. There are five worth knowing.

A **dirty read** is reading a row another transaction wrote but hasn't committed. If that
transaction rolls back, you've read a value that never really existed.

A **non-repeatable read** is reading the same row twice in one transaction and getting two
different values, because somebody updated and committed in between.

A **phantom read** is running the same query twice and getting a different *set* of rows,
because somebody inserted or deleted rows matching your predicate.

A **lost update** is two transactions reading the same row, each computing a new value from
what they read, and one write silently clobbering the other. Classic shape: read balance
500, compute 400, write 400 — twice, concurrently, and 200 of debits turn into 100.

**Write skew** is the subtle one. Two transactions read overlapping data, write to
*different* rows based on what they read, and the combination breaks an invariant that
neither transaction could see on its own. Nobody overwrote anybody. The database is still
wrong.

The first three are the anomalies the SQL standard uses to define isolation levels. The
last two are the ones that actually cause production incidents, which is most of the point
of this post.

## The four levels

### Read Uncommitted

Prevents nothing. Dirty reads, non-repeatable reads, phantoms are all allowed.

In Postgres this level does not exist in any meaningful sense — asking for it gets you Read
Committed. Postgres is MVCC all the way down and never exposes uncommitted row versions to
another snapshot, so there is simply no machinery to read dirty data with. You can set the
level and Postgres will accept it, but nothing changes.

### Read Committed

Prevents dirty reads. Allows non-repeatable reads and phantoms. This is the default in
Postgres, Oracle and SQL Server.

The mechanism is worth stating precisely because it explains a lot of surprising behaviour:
under Read Committed, **each statement takes a fresh snapshot**. So:

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 1;  -- 500
-- another transaction updates it to 400 and commits
SELECT balance FROM accounts WHERE id = 1;  -- 400
COMMIT;
```

Both reads are of committed data. Neither is wrong. But the transaction saw two different
truths, and any logic that assumed the first value still held is now running on a stale
premise.

### Repeatable Read

Prevents dirty reads and non-repeatable reads. The standard says phantoms are still
allowed.

Postgres implements this as **snapshot isolation**: one snapshot taken at the first
statement, held for the whole transaction. That happens to prevent phantoms too, which is
stronger than the standard demands. MySQL's InnoDB also blocks most phantoms here, via gap
locking. So "Repeatable Read" is one of those names that means genuinely different things
across engines — check the engine's docs, not the name.

The cost of a stable snapshot is that writes can now fail:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
-- ERROR:  could not serialize access due to concurrent update
```

If another transaction modified a row you're updating after your snapshot was taken,
Postgres aborts you rather than let you write on top of a version you never saw. Any code
running at Repeatable Read or above needs a retry loop. This is the part people forget when
they bump the level "for safety" and then get paged.

### Serializable

Prevents everything above, plus write skew. The guarantee is that the outcome is equivalent
to *some* serial, one-at-a-time execution of the concurrent transactions.

The example that makes write skew concrete: two doctors are on call, and the rule is that
at least one must remain on call. Doctor A's transaction reads the roster, sees B is on
call, and takes A off. Doctor B's transaction does exactly the same thing at the same
moment, seeing A on call. Both commit. Nobody is on call.

Each transaction read a valid state and made a locally consistent write, to a *different*
row. Repeatable Read does not catch this — snapshot isolation has nothing to complain
about, since no row was updated twice. Only Serializable does.

Postgres implements Serializable with **SSI**, Serializable Snapshot Isolation. Instead of
locking reads upfront the way textbook two-phase locking does, it tracks read/write
dependencies between concurrent transactions and aborts one when it spots a pattern that
couldn't have arisen from any serial order. You get serializability with concurrency close
to snapshot isolation, and you pay for it in occasional `40001` serialization failures that
your application has to retry. CockroachDB takes a similar approach.

One consequence that trips people up: because SSI reasons about what your transactions
*read*, Serializable is only correct if **every** transaction in the workload runs at
Serializable. One transaction at Read Committed writing behind SSI's back can break the
guarantee for everyone else.

## What isolation level do payment systems use?

The instinct is that anything touching money must run at Serializable. The real answer is
that it depends on the operation, and that mature systems mix levels rather than picking one
globally — with a strong bias toward designing the transaction so that correctness doesn't
*depend* on the database catching a race for them.

### Append-only ledger plus a row lock

The dominant pattern for straightforward debit and credit is to not have a mutable balance
at all. Instead of `UPDATE accounts SET balance = balance - 100`, you append immutable
postings to a ledger and derive the balance with a `sum()`:

```sql
BEGIN;

SELECT * FROM accounts WHERE id = 1 FOR UPDATE;   -- lock the debited account

-- application checks sufficient funds against the derived balance

INSERT INTO ledger_entries (account_id, amount, transfer_id) VALUES (1, -100, $t);
INSERT INTO ledger_entries (account_id, amount, transfer_id) VALUES (2, +100, $t);

COMMIT;
```

This is correct at Read Committed. The `FOR UPDATE` serialises access to the account being
debited by hand, so the read-then-write race is gone before the isolation level ever gets a
say. The invariants that matter — debits equal credits, balance never goes negative — are
enforced by the lock, the double-entry shape and a `CHECK` constraint, not by hoping
Serializable notices a write-skew case on your behalf. That's how real ledgers are built,
and it's why "what isolation level does your bank use" is usually the wrong question.

A materialised balance column can still exist as a cache, because with an append-only ledger
it's always rebuildable. Where it's the source of truth instead, the equivalent safe form is
a single atomic statement that does the check and the write together:

```sql
UPDATE accounts SET balance = balance - 100
WHERE id = 1 AND balance >= 100;
```

Zero rows updated means insufficient funds. There's no window between the check and the
write for anyone to slip into, at any isolation level.

### Serializable where the invariant spans rows

Row locks stop working as a strategy once the invariant isn't about one row. Fraud limits,
daily transfer caps, an overdraft rule across a customer's accounts — these read several
rows and the constraint holds over the combination. That's write skew, and Read Committed
plus `FOR UPDATE` only saves you if you remember to lock every row involved, which is
exactly the kind of discipline that decays as a codebase grows.

This is where Serializable earns its cost, and specifically SSI rather than 2PL-based
Serializable. SSI lets transactions proceed optimistically and aborts on a detected
dependency cycle, so you get the guarantee without the throughput collapse of locking every
row you read. CockroachDB goes furthest here and defaults to Serializable for everything,
on the argument that debugging an isolation anomaly in a distributed ledger is worse than
paying for retries.

### What actual systems do

Traditional RDBMS-backed banking cores — mainframe-era systems, including plenty of the
cores still running in Indian banks — lean hard on explicit locking at Read Committed.
Serializable's abort-and-retry behaviour was historically expensive, and a retry loop is not
a natural thing to express in a COBOL-era codebase.

Modern fintech and distributed-ledger stacks lean the other way: Serializable via SSI, with
idempotency keys at the API layer as a second line of defence. The retry cost is real but
tolerable, and the engineering argument is that an anomaly you find in production is more
expensive than a transaction you retry.

### Idempotency is not an isolation level

This is the part people conflate, and it's a common bug class. Isolation levels protect you
from *concurrent transactions* interfering with each other. They do nothing about the same
logical request being submitted twice by a client retrying after a network timeout — that's
one transaction, then later another identical one, and every isolation level in the standard
will happily run both.

The fix is an idempotency key with a unique index on it, so the second attempt collides with
a constraint instead of moving money again. Plenty of teams have tightened the isolation
level, declared the concurrency bug fixed, and gone on double-charging customers through
exactly this gap.

It generalises past retries, too: money moves between systems, not just between rows. A card
payment crosses an acquirer, a network and an issuer, and no database transaction spans
those. That correctness comes from idempotency keys, two-phase authorise-then-capture flows,
reconciliation against settlement files, and sagas with compensating entries. The isolation
level of one database is a small part of a much larger story.

### The one-line version

Serializable, via SSI where available, for anything whose invariant spans multiple rows.
Explicit row locking at Read Committed for straightforward transfers where you can lock
exactly the rows involved. Idempotency keys as an orthogonal and non-optional layer on top
of both.

## Row locking in Postgres

Now the imperative side. Row-level locks are automatic on writes: every `UPDATE` and
`DELETE` locks the rows it touches, and you can take the same locks explicitly with
`SELECT ... FOR ...`. Plain `SELECT` takes no row locks at all and is never blocked by them,
which is MVCC's headline feature — readers don't block writers and writers don't block
readers.

The four modes, strongest to weakest:

`FOR UPDATE` blocks any other transaction from updating, deleting, or locking that row until
you commit or roll back. This is the one you want when you're about to change a row based on
what you just read.

`FOR NO KEY UPDATE` is the same but allows concurrent foreign-key checks. Postgres takes
this automatically for `UPDATE`s that don't touch key columns.

`FOR SHARE` lets several transactions hold the row against modification at once. Everyone
can read, nobody can write.

`FOR KEY SHARE` is the weakest, taken automatically to keep a row alive for foreign-key
references. It blocks `DELETE` and key updates and nothing else.

### The race it exists to solve

Without a lock, two transactions can both read "available" before either writes:

```sql
BEGIN;
SELECT status FROM seats WHERE id = 42;  -- 'available'
-- the other transaction runs the same SELECT right here, also sees 'available'
UPDATE seats SET status = 'booked' WHERE id = 42;
COMMIT;
```

Both commit, both believe they booked it, one customer arrives at the cinema to find
somebody in their seat. That's a lost update.

`FOR UPDATE` closes it:

```sql
BEGIN;
SELECT status FROM seats WHERE id = 42 FOR UPDATE;  -- locks the row
UPDATE seats SET status = 'booked' WHERE id = 42;
COMMIT;                                             -- lock released here
```

The second transaction blocks on its `SELECT ... FOR UPDATE` until the first commits. It
doesn't error — it waits, and then, under Read Committed, re-reads the row at its *new*
version and correctly sees `'booked'`. That re-read is special: Read Committed normally
gives a statement a fixed snapshot, but a blocked locking statement re-evaluates the row
after the lock is granted, precisely so you don't act on the version you were waiting on.

### NOWAIT and SKIP LOCKED

Waiting is often the wrong behaviour, so there are two escape hatches:

```sql
SELECT ... FOR UPDATE NOWAIT;      -- error immediately if the row is locked
SELECT ... FOR UPDATE SKIP LOCKED; -- silently ignore locked rows
```

`NOWAIT` turns a queue into a fast failure, which is what you want when a user is staring at
a spinner and a retry is cheaper than a held connection.

`SKIP LOCKED` is the more interesting one. It changes "give me row 42" into "give me any row
that nobody else is working on", which is exactly the shape of a work queue or a
general-admission ticket pool:

```sql
SELECT id FROM seats
WHERE showing_id = 900 AND tier = 'premium' AND status = 'available'
ORDER BY row_label, seat_number
LIMIT 2
FOR UPDATE SKIP LOCKED;
```

Fifty concurrent requests asking for "two premium seats" each get a different pair instantly
instead of all fifty serialising on whichever row sorted first. This one clause is the
difference between a booking system that survives a Friday 6pm release and one that doesn't.

Note that `SKIP LOCKED` only makes sense when the rows are interchangeable. If the user
picked seat 42 specifically, skipping it and handing them seat 43 is a bug, not an
optimisation.

### Deadlocks

If A locks row 1 and then asks for row 2 while B locks row 2 and then asks for row 1,
neither can proceed. Postgres notices after `deadlock_timeout` (1s by default), picks a
victim and aborts it with `40P01`.

The fix is boring and works: **always acquire row locks in a consistent order**. For a
multi-seat booking, sort the seat ids before locking them.

```sql
SELECT id FROM seats WHERE id = ANY($1) ORDER BY id FOR UPDATE;
```

Every code path that locks the same family of rows has to agree on the order. This is the
kind of rule that belongs in a comment on the query, because the next person to add a
`FOR UPDATE` won't know it exists otherwise.

## Putting it together: seat booking

Seat inventory is the canonical hard concurrency problem — supply is fixed, demand arrives
in a spike the second a popular show opens, and double-booking is a visible business
failure rather than a log line.

The naive design is to open a transaction when the user clicks a seat, `FOR UPDATE` it, and
hold that until payment completes. It's correct and it's unusable: payment takes seconds at
best and minutes at worst, and for that whole window you're holding a database transaction
and a connection per in-flight customer. A few thousand concurrent checkouts and you're out
of connections, with a pile of long-running transactions blocking vacuum for good measure.

So real systems separate the *lock* from the *hold*. The lock lives for microseconds inside
a transaction. The hold is a row of data with an expiry.

```sql
CREATE TABLE seats (
    id           bigserial PRIMARY KEY,
    showing_id   bigint NOT NULL REFERENCES showings(id),
    row_label    text   NOT NULL,
    seat_number  int    NOT NULL,
    status       text   NOT NULL DEFAULT 'available',  -- available | held | booked
    held_by      uuid,
    held_until   timestamptz,
    booking_id   bigint REFERENCES bookings(id),
    UNIQUE (showing_id, row_label, seat_number)
);

CREATE INDEX ON seats (showing_id, status);
```

**Hold**, in one short transaction:

```sql
BEGIN;

SELECT id, status, held_until
FROM seats
WHERE id = ANY($seat_ids)
ORDER BY id
FOR UPDATE;

UPDATE seats
SET status = 'held', held_by = $session, held_until = now() + interval '8 minutes'
WHERE id = ANY($seat_ids)
  AND (status = 'available'
       OR (status = 'held' AND held_until < now()));

COMMIT;
```

The `UPDATE` returns a row count. If it's less than the number of seats requested, somebody
else got there first and you roll back and tell the user. The transaction runs in
milliseconds and the row locks are gone by the time the payment page renders.

That `held_until < now()` predicate is the whole trick: **an expired hold is treated as
available by the next writer**, so you don't strictly need a reaper job for correctness.
You still want one, so the seat map shows the seat as free before somebody tries to take it,
but the invariant doesn't depend on the job running.

**Confirm**, after the payment provider says yes:

```sql
BEGIN;

SELECT id FROM seats
WHERE id = ANY($seat_ids) ORDER BY id
FOR UPDATE;

UPDATE seats
SET status = 'booked', booking_id = $booking, held_by = NULL, held_until = NULL
WHERE id = ANY($seat_ids)
  AND status = 'held'
  AND held_by = $session
  AND held_until >= now();

COMMIT;
```

Notice that confirm re-checks the hold rather than trusting it. If the user sat on the
payment page past the expiry and somebody else took the seat, this `UPDATE` matches zero
rows and you refund instead of double-booking. The check belongs in the `WHERE` clause, not
in application code between two statements, because only then is it atomic with the write.

A few things that hang off this skeleton:

**Idempotency at the payment boundary.** Locking stops double-booking inside the database.
It does nothing about your payment webhook being delivered twice. A unique index on a
provider-supplied idempotency key in the `bookings` table turns the second delivery into a
constraint violation you can swallow, rather than a second booking.

**Advisory locks for coarser coordination.** `pg_advisory_xact_lock(showing_id)` gives you a
lock on a logical thing rather than a row, which is occasionally the right tool for
"serialise all seat-map mutations for this one showing". It's a blunt instrument — you've
just serialised an entire auditorium — but for something like a best-available allocator
that has to reason about the whole map, it's simpler than getting the row-lock ordering
right. Use the transaction-scoped variant so it releases on commit; the session-scoped one
leaks if your code path can return early.

**Replicas are for display only.** Row locks exist on the primary and nowhere else. Reading
the seat map from a replica is fine and is what you want for the browse path, but it's
eventually consistent and can't be trusted at the moment of booking. Every hold and confirm
goes to the primary.

**The queue in front of the database.** For a genuine spike — a blockbuster opening at
midnight — the real answer is often not a better lock but a virtual waiting room that admits
a bounded number of users into the checkout flow at all. `SKIP LOCKED` scales a long way,
but nothing scales like not letting 200,000 people hit the same auditorium's rows at once.

## What I'd remember

- Read Committed takes a snapshot per statement; Repeatable Read takes one per transaction.
  Almost every surprising behaviour follows from that one sentence.
- Postgres has no real Read Uncommitted, and its Repeatable Read prevents phantoms. Never
  trust a level's name across engines.
- Dirty reads are a solved problem. Lost updates and write skew are not, and they happen at
  Read Committed *and* Repeatable Read.
- Reach for an atomic `UPDATE ... WHERE` or a `SELECT ... FOR UPDATE` before reaching for a
  higher isolation level. Locking a row is cheap and local; raising the level changes the
  failure mode of every query in the transaction.
- Anything at Repeatable Read or above needs a retry loop for `40001`. If you don't have
  one, you haven't finished adopting the level.
- `SKIP LOCKED` when rows are interchangeable, `NOWAIT` when the user is waiting, plain
  `FOR UPDATE` when you need that specific row.
- Lock for microseconds, hold for minutes. Never span a payment call with a transaction.
- Sort before you lock, or you're writing a deadlock.
- Isolation levels stop concurrent transactions from interfering. They do nothing about a
  client retrying the same request. That's an idempotency key, and it isn't optional.
