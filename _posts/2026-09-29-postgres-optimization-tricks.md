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

But the first move should be to **question the premise**. This is a users table. Users
don't expire, so "retention" would mean deleting customers. And do 90% of queries really
only touch users who signed up in the last 30 days? That pattern fits an events, orders or
logs table much better. A stronger answer:

> Time-based partitioning makes sense if this is really an append-heavy table like events
> or orders. For a users table, I'd push back: lookups are by `user_id` or `email`, not by
> signup date, so pruning rarely kicks in and I'd lose global uniqueness on email. I'd
> rather keep good indexes and maybe hash-partition by `user_id` if the table size itself
> becomes a problem.

The rest of this section assumes the time-oriented case.

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

### What you actually gain

Pruning is only one of the wins, and often not the biggest:

- **Cheap retention.** Dropping (or detaching) an old partition is a near-instant metadata
  operation. The unpartitioned alternative is a huge `DELETE` that bloats the table and
  leaves `VACUUM` a mess to clean up.
- **Smaller indexes.** Each partition has its own, smaller indexes. The ones for hot, recent
  partitions are more likely to fit entirely in memory.
- **Per-partition maintenance.** `VACUUM`, `ANALYZE` and reindexing run on one partition at
  a time, so each run is faster, and old partitions that no longer change rarely need it.

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

The same rule hits the **primary key**: it has to become `PRIMARY KEY (id, created_at)`
rather than just `id`. That ripples out to **foreign keys** — any table referencing `users`
must now reference the full `(id, created_at)` key, so every child table has to carry
`created_at` as well.

So partitioning `users` by `created_at` is likely the wrong call. It fits better on
append-heavy, time-oriented tables — events, logs, orders — where queries filter on the
date and nothing needs to be unique across all of time.

## Partitioning vs sharding

These two get used interchangeably, but they solve different problems.

Scenario: the app is now global with 2 billion users, and a single Postgres instance can't
handle the write load anymore, even with partitioning. You need to shard. What's the actual
difference, would you shard by `user_id` or by region, and what happens when one shard gets
too hot or you need more shards?

### The difference

**Partitioning** breaks one big table into smaller tables **on the same host**. Indexes get
smaller and maintenance gets cheaper, but the total rows, CPU, memory and disk all still
belong to one machine. It's also transparent to the application: you still query `users`,
and Postgres routes to the right partition.

**Sharding** splits the data across **multiple physical hosts**, each its own database.
That's what actually adds write capacity. It's usually *not* transparent: routing logic
lives in the application or in a proxy/extension (Citus, Vitess) that knows which shard
owns which key.

| | Partitioning | Sharding |
|---|---|---|
| Where the data lives | One host | Many hosts |
| Fixes | Big-table pain: index size, vacuum, retention | Single-host limits: write load, total size |
| Application sees | One table | Usually needs routing logic |
| Unique constraints | Must include partition key | Only enforceable per shard |
| Transactions | Normal | Cross-shard ones are expensive |

### Shard by `user_id` or by region?

**By `user_id`**, as the default. Sharding by region suffers from skew: if 90% of users are
in the US, the US shard is nearly the whole dataset and you've gained little.

There's one legitimate reason to shard by region: **data residency**. GDPR may require EU
users' data to stay in the EU. The real-world answer is often *region first, then hash by
`user_id` within each region*.

Within `user_id`, use **hash** sharding rather than range. `user_id` is usually a numeric,
auto-incrementing value, so with range sharding every new user gets the highest ID and
every insert lands on the last shard. Hashing spreads new users evenly.

### What sharding costs you

- **Scatter-gather queries.** Any query without a `user_id` filter has to be broadcast to
  every shard and the results merged.
- **No global unique constraints.** Uniqueness is only enforced per shard, so constraints
  across shards need other tricks.
- **Login by email needs a lookup table.** After sharding by `user_id`, a lookup by email
  would be a scatter-gather. The fix is a separate `email → user_id` table, itself sharded
  by `email`, which routes the query to the right user shard. This is a global secondary
  index built by hand — and it's also where global email uniqueness gets enforced.
- **Cross-shard transactions are possible but expensive.** Two-phase commit, or systems like
  Spanner, CockroachDB, Citus and Vitess, can do them, but they're slow, complex and hurt
  availability. Design the schema so a user's data lives on one shard and most transactions
  stay single-shard.
- **Moving data between shards is hard** and takes real engineering time.

### Adding shards

With naive `hash(user_id) % N`, going from 4 to 5 shards remaps about **80%** of keys: a key
stays put only if `hash % 4 == hash % 5`, which holds for 4 out of every 20 hash values. That
means a massive data migration. Two standard fixes:

- **Consistent hashing.** Keys and nodes sit on a hash ring; adding a node moves only about
  1/N of the keys.
- **Many logical shards.** Create, say, 4,096 virtual shards up front and map them onto 8
  physical hosts. To scale out, move whole virtual shards to new hosts — the
  key-to-virtual-shard mapping never changes, only the virtual-to-physical map does. Vitess,
  Citus and Instagram's setup work roughly like this.

### When one shard gets too hot

First diagnose why. On a users table the usual cause is **uneven key distribution**, or
several heavy tenants landing on the same shard — not a single row being hammered. With
logical shards the fix is the same as scaling out: move some of the hot host's virtual
shards somewhere else.

**Key salting** solves a different problem: one key getting hammered, like a celebrity's
likes counter or a viral post. You split the key into `post-1`, `post-2`, … spread across
shards, and reads have to gather and combine all the salts. It works, but it adds separate
read logic for hot keys, and a single user row is rarely that hot.

## Replication

Scenario: your shards handle writes fine, but reads are 20x the writes, so you've added
read replicas. A user updates their profile picture, refreshes, and sees the old picture.
They refresh again and see the new one. What's happening? How do you fix it without sending
all reads to the primary? Should replication be sync or async, and what do you give up
with each?

### What's happening

**Replication lag.** The write went to the primary; the first refresh was served by a
replica that hadn't applied it yet; the second refresh hit a replica (or the same one,
later) that had caught up. The guarantee being violated is called **read-your-writes**
consistency.

### Vocabulary that's easy to get wrong

Most of the mistakes I made on this question came from blending terms that belong to
different systems.

**Leader-based vs leaderless replication.** These are different architectures, and the
reasoning for one doesn't carry over to the other.

| | Leader-based (single-leader) | Leaderless (Dynamo-style) |
|---|---|---|
| Who accepts writes | One primary (leader) | Any node |
| How writes spread | Leader ships its log to followers | Client/coordinator writes to W of N nodes |
| Read guarantee comes from | Reading the leader, or a replica known to be caught up | Quorum overlap: `R + W > N` |
| Examples | Postgres, MySQL, Raft-based systems | Cassandra, DynamoDB, Riak |

- **Quorums and the pigeonhole argument** (`R + W > N` means every read set overlaps every
  write set) belong to **leaderless** systems. They're correct there.
- **Postgres and MySQL are single-leader.** With async replication the primary waits for
  *nobody* — not a majority, not one replica. So reading from 3 of 4 replicas guarantees
  nothing: all 4 could be behind.
- **Raft is leader-based too**, even though it uses majorities. The leader commits an entry
  once a majority has it in their logs, but reads still go through the leader (via a lease
  or a ReadIndex check) to be linearizable — you don't get fresh reads by polling a
  majority of followers. Postgres streaming replication isn't Raft either way.

Other terms worth having straight:

- **WAL** (write-ahead log): the log Postgres writes changes to and ships to replicas.
- **LSN** (log sequence number): a position in the WAL. `pg_current_wal_lsn()` on the
  primary, `pg_last_wal_replay_lsn()` on a replica for how far it has *applied*.
- **Written vs flushed vs applied**: a replica can have received the WAL, flushed it to
  disk, and still not have replayed it — so a query on that replica won't see it yet.
- **Failover**: promoting a replica to primary when the primary dies.

### Fixing read-your-writes without routing everything to the primary

From simplest to most involved:

1. **Show the change on the client.** The frontend already has the new picture, so it can
   display it immediately. The problem disappears without touching the database.
2. **Read from the primary for a short window after a write.** Route that user's reads to
   the primary for ~5–10 seconds, tracked in their session or a cookie. Simple and very
   common.
3. **LSN-based routing.** The write returns its LSN (`pg_current_wal_lsn()` after commit),
   stored in the user's session. On the next read, pick any replica and check that its
   `pg_last_wal_replay_lsn()` is at least the stored LSN. If not, wait briefly or fall back
   to the primary. No broadcast and no extra primary query needed.

It's still worth asking whether the complexity is worth it — for most reads, brief
staleness is fine.

### Sync vs async

| | Async | Sync | Semi-sync / quorum commit |
|---|---|---|---|
| Primary waits for | Nobody | All (or named) replicas | At least 1 or k replicas |
| Write latency | Lowest | Highest | Middle |
| On primary crash | Can lose recent committed writes | No loss | No loss if an acked replica survives |
| If a replica dies | Nothing happens | Writes block | Fine while k replicas are up |

- **The real cost of async is data loss on failover**, not just stale reads. If the
  primary dies before shipping its latest writes, those writes are gone — even though the
  user was told they succeeded.
- **The real cost of sync is availability**: one slow or dead replica stalls every write.

**Sync replication doesn't give you read-your-writes by default. Postgres's
`synchronous_commit = on` only guarantees the replica has written the WAL to disk, not
applied it. You need `remote_apply` for replica reads to see the write.**
{: .note-red}

A strong answer:

> Async for replicas that serve reads, because the latency matters and brief staleness is
> fine for most reads. I'd handle read-your-writes at the application layer. For
> durability, I'd keep one semi-sync standby in another availability zone, so a failover
> doesn't lose acknowledged writes, without every write waiting on every replica.

## When should you shard?

Scenario: back to the start. The table is 1.2 million rows, one Postgres instance, and the
query is slow. A junior engineer says: *"We should shard it now so we don't have problems
later."* How do you respond? And at what point would you actually consider partitioning,
replicas or sharding? Concrete signals, not just "when it gets big".

### Diagnose before you architect

1.2 million rows is tiny — it likely fits entirely in RAM on a laptop. A slow query at that
size means a missing index or a bad query, not a scaling problem:

> Sharding won't fix a missing index. It'll give us the same slow query on 8 machines, plus
> cross-shard problems. Let's run `EXPLAIN ANALYZE` first. At 1.2M rows, this is a tuning
> problem, not a scaling problem.

### The ladder

Sharding goes last because its engineering cost is very high. Climb the cheaper rungs
first, and don't skip them unless you're genuinely sure the load will outgrow them within
months:

1. **Tune queries and indexes.** `EXPLAIN ANALYZE`, add or fix indexes, rewrite bad queries.
2. **Connection pooling** (PgBouncer).
3. **Caching** (Redis) for hot, read-heavy data.
4. **Read replicas** — for reads only. Replicas don't help a write bottleneck at all, and
   writes are usually the harder problem.
5. **Vertical scaling.** Buy a bigger machine; large instances go a long way, and most
   companies never need to shard.
6. **Shrink the hot table.** Move rarely used or static columns into a separate table so
   the hot rows are narrower.
7. **Partitioning + archiving** — for time-series or archival data. It isn't free (see
   above: it changes your primary key, breaks global unique constraints and complicates
   foreign keys), so don't do it "early just because".
8. **Sharding.**

### Signals that you actually need to shard

Row count alone is a weak signal — a 1B-row table with good indexes can be perfectly fine.
Look at load and operational signals instead:

| Signal | What it tells you |
|---|---|
| Primary CPU consistently above ~70% after tuning | You've run out of compute on one box |
| Buffer cache hit ratio falling below ~99% | The hot data no longer fits in RAM |
| Write IOPS or WAL throughput near the instance's limit | The write ceiling that replicas can't fix |
| Replication lag growing under normal load | Replicas can't keep up with the write volume |
| `VACUUM` can't keep up, bloat keeps growing | The table is too large to maintain |
| Backup or restore takes longer than your RTO | Often the real forcing function |
| Already on the largest instance type | No vertical headroom left |

The backup/restore signal is the catch in "just get a host with a 16 TB disk". A 16 TB
database is possible, but restoring it after a failure can take many hours — sometimes a
day.

### The NoSQL off-ramp

If your access patterns fit, DynamoDB, Cassandra or MongoDB can scale elastically. But
they get there by dropping joins, ad hoc queries and often strong consistency. That only
works when you know your access patterns up front.
