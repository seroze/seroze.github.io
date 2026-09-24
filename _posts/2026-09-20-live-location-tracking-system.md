---
layout: post
title: "[High level design] Designing a Live Location Tracking System"
date: 2026-09-20 00:00:00 +0530
categories: system-design
tags: [distributed_systems, system_design, redis, geohash, kafka, time_series]
author: "Seroze"
published: true
---

I took a shot at the live tracking problem — phones send their location every few
seconds, and the system has to answer "where is this person right now", "where were they
for the last day", and "who is near me". I got the broad shape right and then had it
picked apart, which is where the useful part started.

Roughly two thirds of the design survived. The third that didn't was not made of
architecture blunders so much as unasked questions: what queries does this thing serve,
what happens when a component is slow, and what happens when a client simply vanishes.
This post is that walk-through with my own mistakes called out as they come up, because
those are the reason I'm writing it down.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The shape of the problem

A client sends `(lat, lon, timestamp)` on a timer — call it every five seconds with some
jitter so a million phones don't align on the same second. That's the entire input. All
the design pressure comes from the read side, and the read side is not one query but
four:

- **Current location.** Where is driver X *now*? Single key, sub-millisecond, read constantly.
- **Nearby search.** Which drivers are within 2 km of this point? A spatial query, not a key lookup.
- **History.** Where was driver X between 09:00 and 17:00 yesterday? Append-heavy, read rarely, kept forever.
- **Analytics.** How many drivers were active in Bangalore at 10 a.m.? Aggregate over the same history.

Those four want genuinely different storage. The first wants a cache, the second wants a
spatial index, the last two want a time-series store. Once you've written them down the
architecture mostly falls out — which is exactly why *not* writing them down was my
biggest miss of the day.

Here's where the design landed after all the corrections below. Worth having in front of
you while reading the mistakes, since most of them are one arrow in this picture that I
originally had pointing the wrong way.

```
    client (phone)
      │  lat, lon, timestamp        every ~5s + jitter
      ▼
    ┌──────────────────────────────────────────────────────┐
    │              Location Service (stateless)            │
    │                                                      │
    │   1. read current user state from Redis              │
    │   2. if incoming.ts <= stored.last_seen → discard     │
    │   3. geohash = encode(lat, lon)                      │
    │   4. move user: old cell → new cell                  │
    │   5. update last_seen                                │
    └───────┬──────────────────────────────────┬───────────┘
            │  HOT PATH (synchronous)          │  COLD PATH (async)
            ▼                                  ▼
    ┌───────────────────────┐            ┌───────────┐
    │        Redis          │            │   Kafka   │  buffer, replay,
    │                       │            └─────┬─────┘  fan-out
    │  user:123 ──────────┐ │                  │
    │   lat, lon          │ │                  ▼
    │   geohash           │ │            ┌───────────┐
    │   last_seen         │ │            │   TSDB    │  location history
    │                     │ │            └───────────┘  + analytics
    │   geo index ◀───────┘ │
    │    abc125 → {123}     │      (Redis can also be rebuilt
    │    abc126 → {456,789} │       by replaying from Kafka)
    └───────────────────────┘

    ═══════════════════════════════════════════════════════════
    reads

    "where is X"      →  GET user:X                    → done
    "who is near P"   →  geo index: cell(P) + 8 neighbours
                         → candidate ids
                         → GET user:id for each
                         → exact distance + last_seen check
                         → fresh users within radius
    "where was X"     →  TSDB range scan on (user, time)
```

The dashed line matters. Everything on the hot path is in the request's latency budget;
everything on the cold path can lag by seconds without a user noticing. Several of my
mistakes were things sitting on the wrong side of it.

## What a geo-index actually is

First thing I had to get straight: a geo-index is not a separate database. It's an
indexing structure, exactly like any other index — the only difference is what it's
keyed by.

```
    normal index:    user_id          →  location record
    geo index:       geographic area  →  users in that area
```

Divide the world into cells and store the membership:

```
             ┌────────┬────────┐
             │  abc1  │  abc2  │       abc1 → {user123, user456, user789}
             │        │        │       abc2 → {user111, user222}
             ├────────┼────────┤       abc3 → {user555}
             │  abc3  │  abc4  │       abc4 → {}
             │        │        │
             └────────┴────────┘
```

When `user123` moves from `abc1` to `abc3`, you remove them from one set and add them to
the other. A nearby query turns into: hash the query point, pull the candidate sets, then
do real distance math on the handful of users you got back.

### Geohash is not the same thing as a geo-index

This distinction was worth the correction:

- **Geohash** is an *encoding* — it turns `(lat, lon)` into a string key by recursively splitting the world in half. Nearby points usually share a prefix.
- **Geo-index** is the *data structure* that uses those keys to make spatial search cheap.

```
    (lat, lon)  →  geohash  →  geo index  →  nearby users
     raw point     spatial     membership    the answer
                   key         structure
```

### Redis already does this

I didn't know Redis had this built in, which is the miss I care least about but should
still record. It's a sorted set under the hood, keyed by the interleaved geohash bits:

```
    GEOADD locations 77.5946 12.9716 user123
    GEOADD locations 77.6000 12.9750 user456
    GEOSEARCH locations FROMLONLAT 77.59 12.97 BYRADIUS 2 km ASC
```

So the architecture does not need a separate spatial database bolted on beside Redis.
Redis holds both the latest state and the index over it; the history lives elsewhere.

The honest framing for an interview is that knowing the command name is worth almost
nothing. Saying *"this needs a spatial nearest-neighbour query, so I'd want a geospatial
index — Redis has one"* is the whole insight. You can learn `GEOADD` in thirty seconds;
recognising that the problem contains a nearest-neighbour query is the part that takes
practice.

## Mistake 1: no buffer in front of the time-series store

My first version had the location service writing to the TSDB directly. That couples
ingestion availability to the slowest, least elastic component in the system. A TSDB
compaction pause, a hot shard, a rolling restart — any of those and phones start getting
errors for a write that nobody is waiting on.

Kafka belongs in between:

```
    Location API ──▶ Kafka ──┬──▶ TSDB consumer    (history)
                             ├──▶ Redis consumer   (hot state, rebuild)
                             └──▶ anything later   (analytics, ML, audit)
```

Three things this buys, none of which I said out loud:

- **Absorption.** Write spikes land in the log instead of on the database.
- **Replay.** Redis is a cache, not a source of truth. If it's lost you replay the tail of the log and rebuild it rather than waiting for every phone to check in.
- **Fan-out.** The next consumer of this stream costs nothing to add. Without the log, every new use case is another write from the API.

## Mistake 2: assuming messages arrive in the order they were sent

This is the one I actually argued about. If the client sends every five seconds, surely
reordering doesn't happen?

It does, and five seconds is not a long time.

```
    t=0    client sends A (ts=100)
           └── delayed 8s in a proxy / retried after timeout
    t=5    client sends B (ts=105)
    t=5.1  server receives B     ← applied
    t=8.0  server receives A     ← applied, user moves backwards
```

Ways this happens without anything being broken: the phone switches from Wi-Fi to 5G
mid-flight; a request is retried after a timeout and the original was not actually lost;
two requests land on two API servers and one of them takes 200 ms while the other takes
20 ms; a connection drops and the client retransmits.

That last one deserves its own picture, because it needs no network weirdness at all:

```
                 ┌── Server 1 ── 200 ms ──┐
    client ──────┤                        ├──▶ Redis
                 └── Server 2 ──  20 ms ──┘

    A goes to Server 1, B goes to Server 2.
    B wins the race and A overwrites it.
```

The fix is one comparison:

```
    if incoming.timestamp <= stored.last_seen:
        discard
    else:
        apply
```

The reasoning I want to keep: you don't add this because reordering is *frequent*. You
add it because correctness shouldn't depend on an ordering the system never promised, and
the check costs one branch.

## Mistake 3: letting the client tell me the old geohash

My proposal was for the update request to carry `old_geohash` so the server knew which
cell to remove the user from:

```
    { "user_id": 123, "old_geohash": "abc123", "new_geohash": "abc456" }
```

Cleaner than it looks, but wrong. The server already stores `user:123 → geohash`, so it
can derive the old cell itself — and a client-supplied value can be stale, wrong, or
hostile. Trusting it means a bad client can corrupt the index for a cell it doesn't
belong to.

The same server-side record is what makes Mistake 2's timestamp check possible. One
authoritative per-user record does both jobs:

```
    user:123 = { lat, lon, geohash, last_seen }   ← source of truth
                                  │
                                  │ referenced by
                                  ▼
    geo index: abc125 → { 123 }                   ← derived, disposable
```

Keeping the index derived rather than authoritative is what lets the next two fixes be
cheap.

## Mistake 4: spotting stale entries but not removing them

I did notice that the index would accumulate garbage — phone dies, nobody sends a
"remove me", the user sits in `abc125` forever. I stopped at noticing.

There are two mechanisms, and the point is that you need *both*:

- **Lazy validation on read** — a query filters candidates on `now - last_seen`. This is the correctness mechanism.
- **A background cleanup worker** — sweeps the index and evicts users whose `last_seen` is long past. This is the space and performance mechanism.

Why not just the worker? Because it's asynchronous:

```
    t=0   user goes offline
    t=1   query arrives            ← cleanup hasn't run yet
    t=2   cleanup worker runs
```

A query that blindly trusts the index returns an offline user in that window. And why not
just the read-time filter? Because the index grows without bound, every query pulls
candidates that will all be discarded, and cells slowly fill with ghosts.

The principle is worth stating on its own: **lazy validation for correctness,
asynchronous cleanup for efficiency.** They're not alternatives.

Redis TTLs help but don't finish the job — a TTL on `user:123` expires the record while
the id sits in the geo set, so the sweeper still has to reconcile the two.

## Mistake 5: no staleness lifecycle

"Stale" isn't a boolean, and I treated it as one. A location that's eight seconds old on
a five-second cadence is fine. One that's forty seconds old means something is wrong, and
the product needs to say so differently:

```
    age = now - last_seen

    0s ─────────── 10s ─────────── 30s ──────────▶
        LIVE           STALE          OFFLINE
        show the       show last      drop from
        marker         known + a      nearby results,
        moving         "last seen"    stop routing
                       label          work here
```

The thresholds are a product decision more than a technical one, but the fact that there
are three states and not two changes the API: a nearby query should probably return
`LIVE` only, while a "where is my driver" query wants `STALE` with the age attached so
the UI can grey the marker instead of showing nothing.

## Mistake 6: the cell boundary

I never mentioned it. A geohash cell has edges, and the user nearest to you is very often
on the other side of one:

```
        cell abc1   │   cell abc2
                    │
            you ────┼──▶ ● nearest driver
                    │      (different cell,
                    │       200 m away)
                    │
        ────────────┼────────────
        cell abc3   │   cell abc4
```

Querying only the user's own cell misses them entirely. Worse, the failure is silent and
position-dependent — it looks like the system just "sometimes" misses nearby drivers.

The fix is to query the cell plus its eight neighbours, then compute exact distances and
filter by the real radius:

```
    point  →  cell  →  cell + 8 neighbours  →  candidates
                                                   │
                                     exact haversine distance
                                                   │
                                            filter by radius
                                                   │
                                            sort, take K
```

The cell size has to be at least the search radius for nine cells to be sufficient;
otherwise you need a wider ring. Redis's `GEOSEARCH` handles this internally, which is a
fine reason to use it — but you should be able to say *why* the naive version is wrong.

## Mistake 7: not storing the geohash alongside lat/lon

I stored `(lat, lon)` in both Redis and the TSDB and computed the geohash on the fly.
Storing it explicitly in both places is nearly free and buys a lot:

- In Redis it's how the update path knows which cell to remove the user from without recomputing from possibly-rounded coordinates.
- In the TSDB it's a cheap, low-cardinality grouping key. "How many drivers were active in this area at 10 a.m." becomes a prefix filter instead of a full scan with per-row math.
- A truncated geohash prefix is a natural partition key — `abc` is a coarse region, `abc12` a fine one.

Derived fields are usually a smell, but this one is a coordinate transform that never
changes for a given point, and the query patterns want it.

## Mistake 8: no partitioning story for Redis

I said "Redis" as though it were a single box. At real scale it's a cluster and you have
to say what the shard key is. The two candidates pull in opposite directions:

```
    partition by user_id            partition by geohash prefix
    ────────────────────            ───────────────────────────
    ✓ even load                     ✓ nearby query hits one shard
    ✓ "where is X" is one hop       ✓ cell + neighbours are co-located
    ✗ nearby query fans out         ✗ hotspots — a city centre shard
      to every shard                  melts while an ocean shard idles
```

The usable answer is to do both, because they serve different structures: key the
per-user records by `user_id` (even distribution, point lookups), and key the geo-index
by a geohash prefix (spatial locality for the fan-out query). They're separate keyspaces;
nothing says they need the same shard function.

Hotspots remain the hard part, and a fixed prefix length guarantees them — a downtown
cell holds thousands of drivers and an ocean cell holds none. The real fix is adaptive
cell size, which is what quadtrees and S2 give you and flat geohashing does not.

## Mistake 9: not asking what the queries were

This is the big one, and the other eight are partly downstream of it.

I jumped straight to "store the latest location" without asking what anyone intended to
*do* with the location. The moment you ask, the design splits by itself:

```
                        Location
                            │
           ┌────────────┬───┴────────┬─────────────┐
           ▼            ▼            ▼             ▼
      current       nearby        history      analytics
      location      search
           │            │            │             │
        Redis      geo index       TSDB          TSDB
       key lookup   spatial      range scan    aggregation
```

Concretely, I never surfaced "find the nearest drivers" as a use case — and that one
query is the entire reason a geo-index exists in this design. Without it you can serve
everything with a key-value store and an append log; with it, spatial indexing,
neighbouring cells and staleness filtering all become mandatory. I designed the storage
before I knew the access pattern, and got lucky that most of it still fit.

## What I'm handwaving

Two things I know I skipped and am not pretending otherwise: how the TSDB partitions
(time-based chunks with a retention and downsampling policy, roughly), and how archival
to cold storage works (a CDC agent draining old chunks to object storage). Both are real
design surface. Neither was where my mistakes were today.

## The checklist I'd run next time

The point of writing these down is to have something to run through mentally before the
first box gets drawn:

```
     1. What does the client send?        →  lat/lon + timestamp
     2. How often?                        →  ~5s + jitter
     3. Ingestion path?                   →  LB → stateless service
     4. What is hot state?                →  Redis
     5. What queries exist?               →  current / nearby / history / analytics
     6. What index does each need?        →  key lookup / geo index / time range
     7. Where does durable history go?    →  Kafka → TSDB
     8. What if messages reorder?         →  timestamp check, discard older
     9. What if the client disappears?    →  last_seen + LIVE/STALE/OFFLINE
    10. What about cell boundaries?       →  neighbouring cells + exact distance
    11. What removes stale index entries? →  read filter + background sweeper
    12. What happens at scale?            →  partition Redis / Kafka / TSDB
    13. What happens during failure?      →  Kafka buffers and replays,
                                             Redis is rebuildable, writes idempotent
```

## What I'm taking away

- Ask what the queries are before choosing storage. Four different read patterns wanted four different structures here, and I picked the structures first.
- The server owns its own state. Anything the client tells you about prior state — an old geohash, a previous version — is an input to validate, not a fact.
- Correctness can't depend on ordering nobody guaranteed. A timestamp comparison is one branch; "it usually arrives in order" is not a design.
- Lazy validation for correctness, async cleanup for efficiency. Neither one substitutes for the other, and knowing which failure each prevents is the actual insight.
- "Stale" has more than two states. Live, stale and offline behave differently in the product, so they should behave differently in the API.
- Derived keys earn their storage when queries want them. Writing the geohash next to lat/lon costs bytes and saves scans, partition math and recomputation.
- Naming a technology isn't a partitioning strategy. "Redis" is a box; "sharded by user_id for records, by geohash prefix for the index, with hotspots as the known weakness" is a design.
- Not knowing `GEOADD` cost me nothing. Not asking "who queries this and how?" cost me most of the list above.
