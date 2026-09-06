---
layout: post
title: "[Databases] Primer on MongoDB"
date: 2026-09-06 00:00:00 +0530
categories: databases
tags: [databases, mongodb, distributed_systems, sharding, transactions, storage_engines, invariants]
author: "Seroze"
published: true
---

I spent an evening poking at a local sharded MongoDB cluster and the questions kept getting
bigger. It started with something small — chunk rebalancing looks genuinely hard to get right, so
how does anyone convince themselves it works? — and ended somewhere near "why hasn't everyone
migrated off Postgres, given how painful sharding is there?". These are my notes from that
session, kept to the parts I actually cared about rather than a full tour of the product.

## Navigation
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Nobody proves rebalancing is bug-free

This was my first question and I want to lead with the honest answer, because it's the one that
surprised me: they don't prove it. Not the implementation, anyway. What distributed databases
actually do is combine careful protocol design, strong invariants, an enormous amount of
automated testing, and years of production hardening. Even after all of that, distributed
databases still ship bugs occasionally.

It's worth being concrete about why moving one chunk from shard A to shard B is hard. While the
migration is running, a hundred clients may be reading, fifty may be writing, another migration
may be in flight, a shard may crash, the network may flake, and some `mongos` router may be
holding stale metadata that says the chunk still lives on A. All of that can happen at the same
time. The difficulty isn't copying bytes; it's that every one of those things is allowed to
happen mid-copy:

```
       readers (100)          writers (50)
              \                    /
               v                  v
        +---------------+  copy   +---------------+
        |    shard A    | ======> |    shard B    |
        | current owner |         |    target     |
        +---------------+         +---------------+
               ^                          ^
               |  may crash               |  may crash
               |                          |
        +--------------------------------------------+
        |  mongos routing cache: "chunk lives on A"   |  <- may be stale
        +--------------------------------------------+
                     ^
                     |  network may partition at any point
```

### Phases instead of one big move

So the operation isn't "move chunk". It's a sequence of phases, each with rules about what is
allowed to happen during it:

```
  phase                          invariant once the phase is done
  -----------------------------  ---------------------------------------
  acquire migration lock         only one migration touches this chunk
        |
        v
  copy the chunk                 source is authoritative,
        |                        destination may be stale
        v
  record concurrent writes       no write is lost, only deferred
        |
        v
  apply outstanding writes       destination == source
        |
        v
  verify consistency
        |
        v
  update config metadata         exactly one shard owns the chunk
        |
        v
  release ownership on A
        |
        v
  delete the source copy         the chunk exists in exactly one place
```

The right-hand column is the real content. During the copy, the destination may hold stale data
and the source is authoritative. After synchronisation, destination equals source. After the
metadata update, exactly one shard owns the chunk. Those three sentences are what makes the whole
thing reasonable to think about — you're never asking "is this correct?", you're asking "does this
transition preserve the invariant?".

The workflow itself is usually written as an explicit state machine rather than a thicket of
conditionals:

```
   START
     |
     v
   CLONING  ------------+
     |                  |
     v                  |  crash, timeout or
   SYNCING  ------------+  failed verification
     |                  |
     v                  v
   COMMITTING -----> ABORTED
     |                  |
     v                  v
   DONE               roll back; chunk stays on A,
   chunk owned by B,  destination copy is discarded
   source deleted
```

Transitions only happen between well-defined states, which is also what makes crash recovery
tractable: the process is assumed to be able to die at any point, so on restart the server reads
the persisted state and decides whether to resume, retry, or roll back. Every state has an answer
to "what if we die right here". Recoverability is designed in, not bolted on.

### The testing is the actual answer

The suites are much stranger than `insert()` and `find()`. A representative test is: move a
chunk, kill a shard, restart it, partition the network, keep writing throughout, then check the
invariants still hold. Then do it again with different timing. Then generate a random workload,
inject random failures, and compare the outcome against the invariants — sometimes for millions
of operations. That's where the edge cases nobody anticipated come from.

[Jepsen](https://jepsen.io) is the famous version of this idea. It partitions networks, kills
processes, delays and reorders messages, all while clients keep issuing reads and writes, and
then checks whether what was observed is consistent with the guarantees the database claims. A
lot of well-known distributed databases have found and fixed serious bugs this way.

A few places go further. Amazon uses TLA+, where you write a mathematical specification of the
protocol before the code — something as small as "the owner of a chunk is either Shard1 or
Shard2" plus the invariant "every chunk has exactly one owner" — and a model checker explores the
possible interleavings of client writes, balancer commits, shard crashes and router refreshes
looking for a sequence that violates it. When it finds one, it hands you the counterexample. This
proves things about the *specification*, for bounded models. It says nothing about whether the
C++ matches the spec.

FoundationDB is the gold standard: deterministic simulation where every packet, timeout, disk
write and crash is simulated, so a single run can explore tens of thousands of failure scenarios
that would be nearly impossible to reproduce on real hardware.

MongoDB itself leans on unit, integration, concurrency, replica-set, sharding, failover and
randomised tests, run across a large matrix of platforms and configurations by their internal CI
system (Evergreen) before anything merges.

The deeper pattern, which generalises well beyond databases: design a protocol with clear
invariants, keep the implementation faithful to the protocol, test the daylights out of it with
fault injection, and monitor real deployments for the bugs that get through anyway.

## Yes, it's C++

The server is primarily modern C++ — `mongod`, `mongos`, the storage engine integration,
replication, query execution and sharding logic. It's well over a million lines.

Roughly:

```
                    MongoDB server (C++)

                    +----------------+
                    | Query parser   |
                    +----------------+
                            |
                    +----------------+
                    | Query planner  |
                    +----------------+
                            |
                    +----------------+
                    | Execution      |
                    +----------------+
                            |
       -----------------------------------------
       |                |                      |
  Replication      Storage engine          Sharding
     (C++)          (WiredTiger)             (C++)
```

`mongod` is the database server: it stores documents, runs queries, handles replication,
transactions, indexes, the storage engine, and chunk migration if it happens to be a shard.
`mongos` is the router — query routing, shard targeting, metadata cache, scatter-gather queries,
forwarding writes — and stores no user data at all. `mongosh` is the odd one out: it's a
JavaScript application on Node.js, which is why you can write loops in the shell, and it talks to
the server over the wire protocol.

Why C++? The same reasons everyone else picked C or C++ for this job — predictable performance,
manual memory control where it matters, low latency, fine-grained concurrency, direct OS access:

| Database | Language |
|---|---|
| MongoDB | C++ |
| PostgreSQL | C |
| MySQL | C/C++ |
| SQLite | C |
| Redis | C |
| RocksDB | C++ |
| WiredTiger | C/C++ |
| DuckDB | C++ |
| ClickHouse | C++ |

If you go browsing, expect `std::unique_ptr`, `std::optional`, `std::variant`, async execution,
custom allocators and lock managers. Most of the difficulty isn't the C++ though — it's that
you're reading a distributed database. A sane reading order is BSON representation, then query
parsing, then indexes, then the execution engine, then replication, and only then sharding
(`mongos`, chunk manager, balancer), by which point the config servers and chunks you poked at in
a local cluster map straight onto the code.

## The storage engine, and why B-trees

The layering looks like this:

```
   db.users.insertOne({ userId: 10, name: "Sai" })
                    |
                    v
        +-------------------------+
        |      query parser       |   is this valid, what does it mean
        +-------------------------+
                    |
                    v
        +-------------------------+
        |     query executor      |   which documents, via which index
        +-------------------------+
                    |
                    v
        +-------------------------+
        | storage engine          |   pages, WAL, MVCC, compression,
        |     (WiredTiger)        |   caching, B-tree indexes
        +-------------------------+
                    |
                    v
        +-------------------------+
        |        disk (SSD)       |
        +-------------------------+
```

The storage engine is the piece that actually puts bytes on disk, and it owns all the questions MongoDB would otherwise
have to answer itself — how to save and update a document, how to recover after a crash, how to
compress, how to cache hot pages, how to implement indexes. MongoDB delegates all of it to
WiredTiger.

To see why that's a real division of labour, take a single `insertOne`. Somebody has to open the
file, find free space, write the bytes, flush, maintain the indexes, update metadata, and be able
to recover if the machine dies halfway. That list *is* the storage engine.

### Why a B-tree and not a BST

If you just append documents, a lookup by `userId` is a full scan, O(n). So you build an index.
The obvious tree is a binary search tree, and it's the wrong choice for two independent reasons.

The first is degeneracy: insert 1, 2, 3, 4, 5 in order into a plain BST and you get a linked
list. A B-tree stays balanced by construction.

```
   plain BST, keys inserted in order      the same keys in a B-tree

   1                                              [ 3 ]
    \                                            /     \
     2                                      [ 1 2 ]   [ 4 5 ]
      \
       3
        \
         4
          \
           5

   depth 5 -> five disk reads             depth 2 -> two disk reads
```

The second reason is the one that actually matters, and it's about disks rather than asymptotics.
A disk read costs on the order of a hundred microseconds, and it fetches a whole page regardless.
A binary tree node spends that entire read on *one key*. A B-tree node packs hundreds of keys
into the same page. One read buys you hundreds of times more information:

```
   binary tree node (one page)      B-tree node (one page)
   +-------------------+           +-------------------------------+
   |        300        |           | 100 200 300 400 500 ... 900   |
   +-------------------+           +-------------------------------+
   one key per read                hundreds of keys per read
```

So a single page splits the key space many ways instead of two:

```
              +---------------------------+
              |   ...  300   ...  700 ... |     one page, one read
              +---------------------------+
               /            |            \
          < 300         300..700         > 700
```

Same page, thousands of keys, very few disk accesses. That's why essentially every general-purpose
database index is a B-tree or a close relative like a B+ tree.

In MongoDB, creating an index on `email` builds a B-tree in WiredTiger whose keys are the email
values and whose payloads point at the document's location — the document itself lives elsewhere:

```
   B-tree on { email: 1 }                 collection storage

   +---------------------------+
   | alice@...   -> loc 0x1A2  | -------> { _id:.., email:"alice@..", .. }
   | bob@...     -> loc 0x9F0  | -------> { _id:.., email:"bob@..",   .. }
   | carol@...   -> loc 0x4C1  | -------> { _id:.., email:"carol@..", .. }
   +---------------------------+
      keys, kept sorted                    documents, wherever they fit
```

It's the index at the back of a book pointing you at a page number. An insert then validates the
document, serialises it to BSON, hands it to WiredTiger to store, updates the B-tree, and commits.

## Transactions: yes, including across shards

Before 4.0 the honest answer was "single-document atomicity and not much else". Today MongoDB has
real ACID transactions — multi-document, multi-collection, and even across shards:

```python
with client.start_session() as session:
    with session.start_transaction():
        accounts.update_one(...)
        accounts.update_one(...)
```

The motivating example is the one everybody uses: A transfers 100 to B. Without a transaction,
you deduct from A, crash, and the money is gone. With one, you either commit both sides or roll
back to where you started.

This is where WiredTiger earns its keep. It supplies MVCC, transactions, checkpoints,
write-ahead logging, crash recovery, compression, caching and the B-tree indexes. Without it,
MongoDB would be on the hook for all of that itself.

When a transaction spans shards — account A on shard 1, account B on shard 2 — MongoDB runs a
two-phase commit coordinated across the participating shards so that it either commits everywhere
or aborts everywhere:

```
                    transaction coordinator
                       |               |
              prepare  |               |  prepare
                       v               v
                +-------------+  +--------------+
                |   shard 1   |  |   shard 2    |
                |  debit A    |  |  credit B    |
                +-------------+  +--------------+
                   yes |               | yes
                       v               v
                    coordinator writes the commit decision
                       |               |
               commit  v               v  commit
                +-------------+  +--------------+
                |  committed  |  |  committed   |
                +-------------+  +--------------+

   a single "no", or a timeout, aborts everywhere and nothing is applied
```

That's meaningfully more complex, and more expensive, than a transaction that stays on one
server. MongoDB's own docs say as much.

## So can you build a bank on it?

This was the question I actually cared about. MongoDB today gives you ACID transactions,
multi-document and cross-shard transactions, majority write concern, snapshot isolation and
replica sets for HA. So "MongoDB can't do banking" is simply out of date — you *can* build it.

I still wouldn't reach for it first, and the reasons have almost nothing to do with the feature
checklist.

Start by killing the premise I came in with. "Postgres can't shard, so it doesn't scale" isn't
really true anymore: large deployments use Citus, YugabyteDB, CockroachDB, Aurora, partitioning,
read replicas, or application-level sharding. Sharding exists. It just isn't built into vanilla
Postgres the way MongoDB does it. Sharding is one dimension out of many — data model, query
language, consistency model, operational complexity, ecosystem, tooling, existing infrastructure —
and being better on that one axis doesn't settle the argument.

The bigger reason is the data model. Accounts, transactions, ledgers, loans, credit cards,
branches, customers, employees, audit trails, AML, fraud, compliance — everything references
everything else, and a single transfer touches account, ledger, transaction, audit and
notification. MongoDB can model that. SQL models it more naturally. Banking is also
query-heavy in exactly the way relational databases are good at: "every transaction involving
customer X over five years, joined with branch info, loan status, fraud investigations and KYC
records" is a query SQL was built for. And SQL lets you push rules like `FOREIGN KEY`, `CHECK`,
`UNIQUE`, `EXCLUDE` and `DEFERRABLE` into the database, where they stop invalid data from ever
being written. MongoDB has schema validation and unique indexes, but the integrity constraints
are less rich.

Then there's cost. If account A is on one shard and account B on another, every transfer becomes
a distributed transaction with coordination overhead. MongoDB's sweet spot is the opposite
shape — one request, one document, one shard. Banking often isn't that shape:

```
   MongoDB's sweet spot          a bank transfer
   --------------------          ---------------
      one request                   one request
           |                      /      |      \
           v                     v       v       v
      one document           account  ledger   audit
           |                    (A,B)  entry    log
           v                      |       |       |
       one shard                shard1  shard2  shard3
```


And finally, inertia, which is more legitimate than it sounds. Changing the database at a Visa or
a JPMorgan isn't changing a database; it's rewriting twenty years of stored procedures, SQL,
reporting tools, BI systems, auditors and compliance software. Meanwhile Postgres has had MVCC,
WAL, a sophisticated optimiser, rich indexing, extensions and replication for decades. That
history is worth a lot to an organisation that values stability over features.

### Where MongoDB does win

Anywhere the data is genuinely document-shaped. A repository with its issues, labels and settings
nested inside it. A chat with its participants and messages. An AI memory store with a
conversation, its messages, metadata and embeddings. In those cases the document *is* the unit of
work, and the impedance mismatch that makes an ORM necessary elsewhere just disappears.

The framing I ended up with is that the 2015 argument — SQL versus NoSQL — has mostly been
replaced by picking per workload:

```
                            application
        +-------------+-----------+---------+---------+
        |             |           |         |         |
        v             v           v         v         v
   PostgreSQL      MongoDB      Redis     Kafka   Elasticsearch
   orders          profiles     cache     events  search
   payments        content
   inventory       AI memory
```

Polyglot persistence, if you want the term for it.

For a social network, an event logging platform or a CMS, MongoDB is a strong candidate. For a
banking ledger I'd still lean relational — not because MongoDB can't, but because the model,
the constraints and the ecosystem line up so well with that particular workload.

## What to read next

Two threads I want to pull on. The first is MVCC, which is the foundation under all of this: how
two users read the same row while a third updates it, how transactions avoid blocking each other,
how rollback actually works. It ties transactions, storage engines and concurrency together.

The second is the correctness toolkit from the first section — Paxos and Raft, TLA+, Jepsen, and
FoundationDB's simulation testing. That's the mindset behind building systems like this, and once
you have it, MongoDB's sharding and replication stop looking like a pile of features and start
looking like carefully designed state machines preserving a small set of invariants under
failure.
