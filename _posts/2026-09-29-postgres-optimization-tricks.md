---
layout: post
title: "[Databases] Database Optimization Tricks in Postgres"
date: 2026-09-29 00:00:00 +0530
categories: databases
tags: [databases, postgres, indexing, performance]
author: "Seroze"
published: true
---

A running collection of PostgreSQL optimization tricks, one section per trick.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Covering index

A covering index is an index that contains all the columns a query needs, so PostgreSQL
can answer the query from the index alone without looking up the full table row.

For example, if you often run:

```sql
SELECT name
FROM users
WHERE email = 'a@example.com';
```

An index on `email` can find the matching row, but PostgreSQL may still need to visit the
table to fetch `name`.

You could make the index cover both columns:

```sql
CREATE INDEX ON users (email) INCLUDE (name);
```

Now `email` helps PostgreSQL find the row, and `name` is stored in the index for this query.

PostgreSQL may then use an **index-only scan**. It still sometimes checks the table for
visibility information, so a covering index doesn't guarantee that every query avoids
table access.

Use covering indexes for queries you run often and keep them focused: extra index columns
use disk space and make inserts and updates a bit more expensive.

## Keyset pagination

Offset-based pagination gets slower the deeper you go:

```sql
SELECT *
FROM orders
ORDER BY created_at DESC
LIMIT 20 OFFSET 100000;
```

PostgreSQL generally has to find and step past the first 100,000 rows before returning 20,
so every later page does more wasted work. Keyset pagination avoids the skip entirely:
instead of saying "skip N rows", it asks for rows *after the last sort key* from the
previous page.

```sql
SELECT id, created_at, total
FROM orders
WHERE (created_at, id) < ('2026-09-01 10:00:00', 12345)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

With a matching index, PostgreSQL jumps straight to that position and reads the next 20
rows, so page 5,000 costs about the same as page 1:

```sql
CREATE INDEX ON orders (created_at DESC, id DESC);
```

The `id` tie-breaker matters when multiple rows share the same timestamp — without it, rows
can be skipped or repeated across pages. The trade-off is that you can't jump to an
arbitrary page number; you can only move forward (or backward) from a known row.

## Partitioning

Scenario: the table grows to 500 million rows, and 90% of queries only touch the last 30
days of data. Someone suggests partitioning. Would you? On which column, and what kind of
partitioning? And what happens to a query like
`SELECT * FROM users WHERE email = 'x@y.com'` after you partition?

### Decision

I'd consider partitioning if the table is large enough that managing and querying it is
becoming difficult. The fact that 90% of queries touch only the last 30 days is a strong
reason to consider it, but partitioning won't automatically make every query faster. I'd
check actual query plans and maintenance needs first.

### How

Partition by the date or timestamp column used to restrict queries — for example,
`created_at` — using **range partitioning**, with one partition per month or week. A query
such as:

```sql
SELECT *
FROM users
WHERE created_at >= now() - interval '30 days';
```

can then use **partition pruning** to avoid scanning older partitions.

#### What "range" means here

With range partitioning, each partition owns a non-overlapping interval of `created_at`
values:

```sql
CREATE TABLE users (
  id bigint,
  email text,
  created_at timestamptz
) PARTITION BY RANGE (created_at);

CREATE TABLE users_2026_09 PARTITION OF users
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
```

`users_2026_09` holds rows where `created_at` is at least September 1 and less than
October 1 (the upper bound is exclusive).

When a query filters on `created_at`, PostgreSQL compares that filter with the known
partition boundaries and skips partitions that cannot contain matching rows. It doesn't
"extract the month" from the timestamp — it reasons about the actual condition against the
bounds. A one-month condition can leave just one partition to scan; a rolling 30-day window
usually overlaps two monthly partitions, so both get scanned.

### Types of partitioning

PostgreSQL supports three kinds:

- **Range** — each partition holds an interval of values (dates, IDs). The natural fit when
  queries mostly filter by recent dates, and it makes retention easy: dropping an old month
  is `DROP TABLE`, not a huge `DELETE`.
- **List** — each partition holds an explicit set of values, such as one per country or
  status.
- **Hash** — PostgreSQL hashes a key and spreads rows across a fixed number of partitions.
  This evens out data and work, but a date-range query can't skip any partitions.

#### A real-world hash example

Take a high-volume `events` table where most queries look up one account's events:

```sql
SELECT *
FROM events
WHERE account_id = 42;
```

If there's no natural date-based retention requirement, hash-partition by `account_id`
into, say, 16 partitions:

```sql
CREATE TABLE events (
  account_id bigint,
  event_id bigint,
  payload jsonb
) PARTITION BY HASH (account_id);

CREATE TABLE events_p0 PARTITION OF events
  FOR VALUES WITH (MODULUS 16, REMAINDER 0);

CREATE TABLE events_p1 PARTITION OF events
  FOR VALUES WITH (MODULUS 16, REMAINDER 1);

-- Repeat for remainders 2 through 15
```

PostgreSQL hashes `account_id` to find its remainder, so a lookup for `account_id = 42`
prunes to a single partition. Rows are spread evenly, which keeps each table and its
indexes smaller and allows partition-level maintenance.

Hash partitioning fits when you want an even spread by a key that queries commonly specify,
but there's no useful range or list grouping. If queries instead ask for recent events
across all accounts, hashing by `account_id` won't let PostgreSQL skip anything for a date
range.

### Trade-offs

You'll need to manage partition creation and retention, and queries that don't filter on
the partition key may still need to consider many partitions.

**The email lookup gets worse, not just "slightly slower".** Take this query:

```sql
SELECT *
FROM users
WHERE email = 'x@y.com';
```

There's no `created_at` condition, so PostgreSQL can't prune anything. Say there are 40
monthly partitions. Postgres has **no global index**, so each partition gets its own index
on `email`, and the query probes all 40 of them — 40 index lookups instead of 1. That's fine
occasionally, but on a hot path like login it adds up.

**The bigger trap: unique constraints must include the partition key.** In PostgreSQL, every
`UNIQUE` (and `PRIMARY KEY`) constraint on a partitioned table has to contain the
partitioning column. Once `users` is partitioned by `created_at`, you can't enforce
`UNIQUE (email)` across the table — only `UNIQUE (email, created_at)`, which allows the same
email in two different months. For a users table, that's a serious problem: email
uniqueness now has to be enforced somewhere else (a separate lookup table, or the
application), and both options are weaker than a real constraint.

So partitioning `users` by `created_at` is likely the wrong call. It fits better on
append-heavy, time-oriented tables — events, logs, orders — where queries filter on the
date and nothing needs to be unique across all of time.
