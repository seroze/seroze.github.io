---
layout: post
title: "[System Design] Fan-out Reminder Messaging System"
date: 2026-09-03 00:00:00 +0530
categories: system-design
tags: [system_design, distributed_systems, kafka, notifications, interview_prep]
author: "Seroze"
published: true
---

I picked up a system design question that was floating around on Reddit and tried to
answer it properly instead of hand-waving: build a reminder service where a user
schedules a message for a future time, and when that time arrives the message goes out
to everyone it is addressed to. A single reminder might target one person or ten
thousand. The stated SLO is that the message lands within a second of the time it was
scheduled for.

I worked through it end to end and then had the design picked apart line by line. The
scheduler half held up reasonably well. The fan-out half — the part that actually turns
one row into ten thousand push notifications — did not. This post is that walk-through,
in the order the problems actually surfaced, with the places I got it wrong called out
as I go. The mistakes are the reason I'm writing it down.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The shape of the problem

Strip it down and there are two halves that look similar but are not.

The first half is a scheduler. Something has to hold "send this at 09:00" for hours or
days and then notice, promptly, that 09:00 has arrived. My first instinct here was a
Postgres table with a `dispatch_at` column and a poller. That works until it doesn't,
and I eventually moved to a durable log with an ownership model and a reconciliation
pass, which is the right direction.

The second half is fan-out. One scheduled message becomes N deliveries. This is where
the interesting failure modes live, and it is where I had drawn boxes without putting
any numbers in them.

The tell that you are in the second half: your unit of work has unbounded size. Every
problem below follows from that one fact.

Here is where the design ended up once all the corrections below had been applied. It's
worth having the finished shape in front of you while reading the mistakes, because
almost every one of them is a piece of this picture that I originally had on the wrong
side of the line:

```
  SCHEDULE TIME  ──  hours ahead, no latency pressure  ─────────────────

    client ──▶ schedule API ──▶ expand recipients ──▶ durable store
               msg + when        users → devices       dispatch_at,
                                 → provider tokens     device tokens,
                                                       pre-chunked

  ══════════════════════════════════════════════════════════════════════
      everything above this line is work you never do below it
  ══════════════════════════════════════════════════════════════════════

  DISPATCH TIME  ──  1 second budget  ──────────────────────────────────

    timer / owner ──▶  Kafka lanes  ──▶  fan-out consumers ──▶ providers
    dispatch_at        urgent  ─┐        poll batch            APNs
      <= now()         bulk    ─┘        ↓                     h2, warm
    lease + ack        (sized for        bounded pool          conns
                        peak, never       ↓                    FCM
                        resized)         circuit breaker       multicast
                             weighted     ↓                    batches
                             pulls       commit contiguous     WebPush
                                         offset prefix
```

The horizontal line is the important part of the diagram. Every arrow above it is work
done with hours of slack; every arrow below it is work competing for the same one
second. A large share of my mistakes were things sitting below the line that belonged
above it.

## The API contract

I skipped this in the interview and went straight to boxes, which was a mistake on its
own — writing the contract down forces several decisions that are otherwise easy to
leave vague. The version below is the one I'd write now, after the corrections. A few of
the fields exist purely because of a problem discussed later in the post, and I've said
which.

### Scheduling a message

```http
POST /v1/messages
Idempotency-Key: 8f14e45f-ea6b-4c2f-9d6c-3b1a7e05c2d9
Content-Type: application/json

{
  "dispatch_at": "2026-09-04T09:00:00+05:30",
  "expires_at":  "2026-09-04T09:05:00+05:30",
  "priority":    "bulk",
  "audience":    { "type": "segment", "id": "seg_morning_digest" },
  "payload": {
    "title": "Your daily digest",
    "body":  "12 new items since yesterday",
    "data":  { "deep_link": "app://digest/2026-09-04" }
  }
}
```

```http
202 Accepted
Location: /v1/messages/msg_01J9Z0R2

{
  "message_id":      "msg_01J9Z0R2",
  "state":           "scheduled",
  "dispatch_at":     "2026-09-04T03:30:00Z",
  "priority":        "bulk",
  "recipient_count": 9842,
  "device_count":    24317,
  "chunk_count":     49
}
```

Five things in there are load-bearing.

`dispatch_at` must carry an explicit UTC offset, and the response echoes it back
normalised to UTC. The client picks the instant; the server owns the frame it is
compared in. That is the clock-skew fix from later in the post, expressed as a schema
rule rather than a promise.

`expires_at` is what makes drop-on-expiry a contract rather than an implementation
detail. A reminder for 09:00 is worthless at 11:00, and saying so up front is what lets
the system shed a blocked message instead of dragging it through the pipeline.

`priority` names the lane. This is the OTP-versus-marketing-blast distinction, and it
belongs in the API because only the caller knows which one it is.

`audience` is a reference, not a list — a segment id or an explicit array of user ids.
Either way it is resolved *now*, at schedule time, which is why the response can tell you
`recipient_count` and `device_count` at all. If those numbers can be returned
synchronously, the expansion has already happened, and dispatch time has no lookup left
to do.

`chunk_count` leaks a little implementation, and I'd keep it anyway. It's the number the
caller needs to reason about their own blast radius, and it makes the unit of work
visible in the contract instead of hiding it.

The `Idempotency-Key` header is the usual story: a retried POST must not schedule the
message twice. Same key, same body returns the original `202` and the original
`message_id`; same key, different body is a `409`.

### Reading status

This endpoint is where the partial-failure problem from Mistake 6 shows up in the open,
and it is the reason the response is a set of counters rather than a single enum:

```http
GET /v1/messages/msg_01J9Z0R2

{
  "message_id":  "msg_01J9Z0R2",
  "state":       "dispatched",
  "dispatch_at": "2026-09-04T03:30:00Z",
  "started_at":  "2026-09-04T03:30:00.118Z",
  "settled_at":  "2026-09-04T03:30:00.834Z",
  "deliveries": {
    "total":     24317,
    "accepted":  24102,
    "failed":       97,
    "expired":     118,
    "pending":       0
  },
  "skew_ms": { "p50": 84, "p95": 402, "max": 716 }
}
```

The top-level `state` only ever describes the *message's* progress through the pipeline
— `scheduled`, `dispatching`, `dispatched`, `cancelled`, `expired`. It deliberately says
nothing about whether any particular person got the notification, because there is no
honest single value for "9,900 succeeded and 100 failed". Per-recipient truth lives in
`deliveries`, at device granularity, and the two never get collapsed into one field.

`accepted` is also carefully named. It means the provider took the send, not that a
phone displayed it. That is the handoff-versus-delivery gap, and the schema should not
paper over it.

`skew_ms` is measured against `dispatch_at`, not against `started_at` — elapsed pipeline
time is the wrong metric, for reasons the observability section gets into. `max` is there
because for a 10k-recipient message the SLO is a max, not a percentile.

For the actual failures you page through a separate collection, because at 24,000 rows
per message you do not want them inline:

```http
GET /v1/messages/msg_01J9Z0R2/deliveries?status=failed&limit=100&cursor=...

{
  "items": [
    { "user_id": "u_4471", "device_id": "d_91ab", "channel": "apns",
      "status": "failed", "reason": "unregistered", "attempted_at": "…" }
  ],
  "next_cursor": "eyJvIjoxMDB9"
}
```

`reason` matters more than it looks. `unregistered` is permanent and should evict the
token; `rate_limited` and `provider_unavailable` are transient and belong to the circuit
breaker, not to a retry loop. Collapsing them all into `failed` is how you end up
retrying into a dead provider forever.

### Cancelling

```http
DELETE /v1/messages/msg_01J9Z0R2
→ 204  cancelled
→ 409  already dispatching — partial delivery may have occurred
```

The `409` is the honest answer and worth stating explicitly. Once chunks are in flight
there is no clean stop, and an API that pretends otherwise is lying about a race it
cannot win.

### The internal contract

The record on the wire between the dispatcher and the fan-out consumers is the other
contract worth pinning down, since it's where the chunking decision actually lives:

```json
{
  "chunk_id":    "msg_01J9Z0R2/17",
  "message_id":  "msg_01J9Z0R2",
  "dispatch_at": "2026-09-04T03:30:00Z",
  "expires_at":  "2026-09-04T03:35:00Z",
  "attempt":     1,
  "targets": [
    { "user_id": "u_4471", "device_id": "d_91ab",
      "channel": "apns", "token": "…" }
  ],
  "payload_ref": "pay_01J9Z0R2"
}
```

Three deliberate choices. The chunk carries fully resolved device tokens, so a consumer
never touches a database on the hot path. It carries `expires_at`, so a consumer that
picks up a stale chunk can drop it without asking anyone. And the payload is a reference
rather than a copy, so the same body isn't duplicated across forty-nine records — the
targets are what differ between chunks, and only they should be paid for per chunk.

## Mistake 1: one Kafka record per message

My design put one record on a Kafka topic per scheduled message, and a consumer picked
it up and did the fan-out. It's a clean boundary and the instinct isn't wrong — but I
never asked what happens *inside* that consumer.

Say a push to the provider takes 20 ms and I run 200 of them concurrently. The time to
drain one message is roughly

$$T = \lceil N / C \rceil \times t_{\text{provider}}$$

With $$N = 10000$$, $$C = 200$$ and $$t = 20\,\text{ms}$$ that's 50 rounds at 20 ms —
exactly one second. The entire budget, consumed, assuming nothing anywhere is slow.
There is no margin for a retry, a slow TLS handshake, or a GC pause.

Worse, the unit of parallelism in that design is *one message*. One record means one
partition, which means one consumer, which means one thread pool. Nothing about the
architecture lets a big message spread out.

And then the thing I really missed: if two 10k-user messages land in the same Kafka
partition at the same second, the second one waits for the first to finish. That is
head-of-line blocking, and it is severe enough that partition count and fan-out
concurrency stop being independent choices — they are now both terms in the latency
budget. That relationship is something you should be able to write as a formula, and I
couldn't.

The fix is to stop treating "one message" as the unit. Expand a scheduled message into
chunks of a fixed size — a few hundred recipients each — and let the chunk be the thing
that flows through the system. Suddenly every unit of work costs about the same, and
adding capacity actually helps.

```
  BEFORE — one record per message, consumer processes serially

    partition 0:  [ msg A — 10,000 users ][ msg B — 1 user ]
                   └────────────────────┘
                     consumer pinned here for ~1s
                                                 B is late, and nothing
                                                 about B was slow        ✗

  AFTER — fixed-size chunks + completion decoupled from fetch order

    partition 0:  [A/1][B/1][A/2][A/3][A/4][A/5] …
                    │    │    │    │    │
                    ▼    ▼    ▼    ▼    ▼
                  ┌──────────────────────────┐   all in flight together;
                  │ bounded in-flight pool   │   B/1 returns first;
                  │ (sized to provider cap)  │   offsets commit as the
                  └──────────────────────────┘   contiguous prefix fills  ✓
```

Every unit is now roughly the same size, so a big message is spread across partitions
and consumers instead of monopolising one, and a small message never queues behind a
large one.

## Mistake 2: resolving recipients at dispatch time

I had the fan-out worker look up the target user IDs when the message fired. Redis, or
the main database if the cache was cold.

The problem is a scheduling problem, not a performance one. I know about this message
*hours in advance*. Doing a round trip for ten thousand IDs inside a one-second budget
means my SLO now depends on cache warmth at 09:00:00, which is exactly the moment I have
the least slack and the least control.

Anything that can be computed at schedule time should be computed at schedule time. The
useful question to keep asking is: what work am I doing at dispatch that I could have
done an hour ago?

## Mistake 3: treating fan-out as uniform

I kept saying "ten thousand users" as if that were the send count. It isn't.

A user is not an endpoint. A user has devices — call it one to five — spread across iOS,
Android and web. Ten thousand users is plausibly twenty-five thousand sends. Those sends
go to three different providers with three different APIs, three different batching
models and three separate rate limits.

So the fan-out is heterogeneous and I had modelled it as a flat loop. That matters
because the tail of the distribution is what blows the SLO, and the tail here is the user
with five devices on the slowest provider.

## Mistake 4: designing the send loop before reading the provider docs

This is the one that reframed the whole problem for me. The throughput ceiling is not in
my code. It is imposed by the provider.

FCM has multicast batching, so the right unit of work there is a batch, not a device.
APNs is HTTP/2, and the number of concurrent streams per connection is capped — so my
concurrency is bounded by how many connections I have already established. Establishing
a connection inside the one-second budget is fatal; those connections have to be warm and
pooled before the message fires.

The correct move is to design backward from the provider's limits and let that dictate
everything upstream: chunk size, worker count, in-flight concurrency, partition count.
I had been designing forward from my own code and hoping the provider would keep up.

## Mistake 5: retries that fight the clock

I had two inline retries and then a dead-letter queue. Two problems with that.

The first is definitional. If the promise is delivery within one second, a retried
delivery is late by construction. Retrying inside the budget doesn't save the SLO for
that recipient; it just spends time.

The second is worse. When APNs is genuinely down, per-message retries generate a
thundering herd against a dependency that is already on the floor. Every worker in the
fleet is now hammering a dead endpoint, which is how a provider outage becomes your
outage.

What you actually want at that layer is a circuit breaker plus backpressure: stop
calling, park or shed the work, probe periodically, resume when the probe succeeds. I had
also proposed writing a single "all failed" marker instead of ten thousand failure rows
to save bandwidth — a real optimisation, but I was tuning bytes while retry amplification
was the thing that would take the system down. Right idea, wrong order of concerns.

## Mistake 6: a per-message status for a per-user failure

My state machine had statuses on the message row: `scheduled`, `dispatched`,
`published`. Then the obvious question: 9,900 sends succeeded and 100 failed — what is
the status of that row?

There is no honest answer, because the state machine is per-message and the failures are
per-user. Those two granularities don't compose. Before anything else you have to decide
what `published` even means: handed off to the provider, or actually delivered to a
device? If there is a gap between those two — and there always is — something has to
track it at user granularity, and at these volumes that is a real storage cost worth
naming up front rather than discovering in production.

## Mistake 7: dismissing clock skew

Asked about clock skew I said it doesn't matter — precision is seconds, and the client
picks the time anyway.

That doesn't dismiss the problem, it moves it. The client chooses an absolute wall-clock
instant, but the comparison `dispatch_at <= now()` still executes on my servers, in their
frame. Typical NTP skew is tens to low hundreds of milliseconds, which is a meaningful
slice of a one-second budget.

The answer that costs nothing to say and is actually defensible: pick one authoritative
clock, never compare against a local host clock, and monitor skew with an alert
threshold. One sentence, and it closes the hole.

## Mistake 8: the observability plan, which was wrong three ways

I proposed having clients report delivery timings, aggregated in thirty-minute windows.
The instinct — measure end to end, from the device — is right. The instrument had three
independent defects.

**Survivorship bias.** Telemetry only comes back from deliveries that succeeded on
devices that later came online. The population I most need to see is exactly the
population that cannot report. So the p99 looks healthy in precisely the incidents where
it isn't.

**Percentiles don't average.** If every client reports its own p99, there is no
arithmetic that combines those into a system p99. You need mergeable structures —
t-digest, HDR histograms, or plain bucket counts — not pre-aggregated summaries.

**Thirty-minute windows mean thirty-minute detection.** For a one-second SLO that's a
very long time to be blind. Client telemetry is the ground truth, but you also need a
server-side signal that fires in seconds.

Then there was a subtler error in the metric itself. I was measuring elapsed time through
each pipeline stage. But the promise isn't "the pipeline is fast" — it's skew from
`dispatch_at`. A message can cross the whole system in 50 ms and still be four seconds
late because it was picked up late. Measure against the scheduled time, not against
ingestion.

And the one that matters most, which loops back to the SLO itself. If the promise is
"the ten-thousandth recipient gets it within a second," then the per-message number is a
**max**, not a p99 of individual deliveries. Those two diverge wildly: 99.9% of
deliveries landing in 200 ms is completely compatible with most *messages* blowing the
SLO on their slow tail. Decide which number you are graded on, and instrument that one.

## Head-of-line blocking, properly

This came up as a side question and turned out to be the most portable idea in the whole
exercise, so it gets its own section.

The general principle: head-of-line blocking is the price you pay for ordering. A queue
blocks because it promises to hand you items in sequence. So the first question is always
whether you actually need that promise — and here I don't. Two notification messages have
no ordering relationship whatsoever. I was paying for a guarantee my workload never
asked for.

There are five ways out, roughly in the order I'd reach for them.

**Decouple fetch order from completion order.** A Kafka consumer is serial by default:
poll a batch, process it, commit. But nothing forces serial *processing*. Poll into a
bounded worker pool, let records complete out of order, and commit only the contiguous
completed prefix of offsets. A 10k-user record and a 1-user record picked up together now
finish independently. You keep at-least-once semantics — the uncommitted prefix replays
after a crash — and you give up per-partition ordering, which costs nothing here. This is
what most high-throughput consumers actually do, and it's a bounded queue plus an offset
tracker, not a topology change.

**Make the units uniform.** The chunking from Mistake 1. This attacks the variance at its
source rather than tolerating it, and it's the only fix that also solves "a single 10k
message can't finish in one second no matter what." It composes cleanly with the previous
one.

**Bound the work per turn.** If a unit is genuinely indivisible, don't run it to
completion in one go — do a slice, yield, requeue the remainder. Cooperative
multitasking for queues. Useful when you can't split upfront; less relevant here, because
you can.

**Add lanes.** Separate topics or consumer groups per SLO class. Worth being clear that
this is *isolation*, not throughput: it stops class A being hurt by class B, and does
nothing about blocking within a class. The classes are real, though — an OTP or security
alert has a fan-out of one and is the most latency-critical thing in the system, while a
marketing blast is 10k and can tolerate seconds of slip. Those two should not share fate.

**Shed the blocker.** Time out and drop, or park to a side queue. Crude, but it's why the
drop-on-expiry decision matters: a message that is past its usefulness should never
occupy a slot.

For this system the answer is the first two together, with lanes on top if there's a
class like OTP that genuinely cannot share fate with bulk traffic.

## Kafka partitions: why the count only goes up

The lane discussion pulled me into Kafka's partition model, and it's worth writing down
because I had a wrong mental model of it.

Kafka lets you increase a topic's partition count and never decrease it. That is a
deliberate design decision, not an unimplemented feature.

Each partition is an independent, ordered log with its own offsets. Going from eight
partitions to four would mean merging logs — `P0 + P4 -> P0` and so on — and every
guarantee Kafka sells breaks in the process. There is no correct way to interleave two
independent ordered logs. Offsets are local to a partition, so merging invalidates every
committed consumer offset. Consumer groups assign work partition by partition, so
removing partitions changes assignment semantics and lets consumers reprocess or skip.
And keys map to partitions by hash, so after a reduction a large fraction of keys land
somewhere new and per-key ordering is gone.

Increasing is easy by comparison. Existing messages stay exactly where they are and only
new writes can be routed to the new partitions. The one caveat is that the partition for
a given key is computed as

```
partition = hash(key) % numPartitions
```

so changing `numPartitions` changes the modulo. Ordering is still preserved *within* each
partition, but messages for one key may now be split across the old and the new partition.
If strict per-key ordering across all of history matters, that's a real consideration.

If you truly need fewer partitions, the supported path is to create a new topic with the
smaller count, copy or reprocess data into it (MirrorMaker, Kafka Connect, or a plain
consumer/producer), cut producers and consumers over, and delete the old topic.

### The practical consequence: provision for peak on day one

The reason the missing feature stings so little in practice is that partitions are
*cheap*. An idle partition is a directory with a couple of segment files, a leader
assignment, and a small slice of the broker's memory for index and replication
bookkeeping. It costs you almost nothing to have partitions you aren't currently
saturating.

So the right move is to work out the maximum concurrency you'll ever need and create that
many partitions at the start. Don't plan to grow into it, and don't plan to shrink back
out of it afterwards — there is no increase-then-decrease cycle available to you, and you
don't want one. A topic sized for peak on day one never has to be resized, never
reshuffles its key-to-partition mapping mid-flight, and never forces a topic migration.

The only real cost of over-provisioning is that partition count is the ceiling on
*consumers* in a group, not on throughput — so a generous count buys you headroom to
scale consumers out later, which is exactly the option you want to keep open. The
asymmetry Kafka enforces (up, never down) is much less painful once you stop treating
partition count as a dial to tune and start treating it as a capacity decision you make
once.

### "Can't I just drain one partition and delete it?"

This was my follow-up, and I still think it's a reasonable question: if P4 is barely
getting traffic, why can't I wait for it to drain and then drop it? Feels much weaker
than a general reduction.

It isn't, for four reasons.

Producers still hash to P4. Some keys will always land there under `hash(key) % 5`. If
the partition is gone, what should happen — do those writes fail, silently go to P0, get
remapped? Any answer changes the partition assignment algorithm and therefore changes
semantics for those keys.

Consumer groups assume partition IDs are contiguous. Kafka numbers partitions 0 to N-1
and a great deal of metadata assumes exactly that. Delete P4 and you have a gap; delete
P1 and you have `0, 2, 3`. Now the controller, the group coordinator, the partition
assignors, leader election and the metadata APIs all have to support sparse numbering.
That's a large complexity increase for an uncommon operation.

Producers cache metadata. A client that fetched the partition list a minute ago still
believes P4 exists. Kafka would need extra protocol machinery to invalidate that, retry
sensibly, and handle the races.

Future expansion gets ambiguous. After deleting P4, does a later expansion recreate
partition 4, or create partition 5? Reusing the ID is confusing because that partition
existed before with its own offsets and state; skipping it leaves a permanent gap.

None of this is impossible to build — plenty of distributed systems do add and remove
shards dynamically. Kafka simply chose a different set of invariants: partitions are
permanent identities, IDs never change, the count only grows, metadata stays simple. And
note that the preconditions for a safe drain-and-delete (no producer will ever write
there again, every client has refreshed metadata, no consumer expects it, nothing depends
on its offsets) add up to roughly the same work as migrating to a new topic. Kafka just
makes you do the migration explicitly.

## Mistake 9: what I thought the fix for spiky load was

I filed the wrong lesson from the lane discussion. I wrote down "dynamically size
partitions based on time," which is not a thing you should do — partition counts can only
go up, and changing them mid-flight reshuffles key-to-partition mapping. That is not a
routine response to load.

The actual suggestion was a shared worker pool with weighted pulls across lanes. The
topics are fixed; the consumers draw from several of them with a priority bias, so idle
capacity in one lane is available to another rather than being stranded. Capacity is
dynamic, partitioning is static. Which is also the reason to over-provision partitions
up front: they're cheap when idle and painful to change later.

## Partitions do not cap your concurrency

One last correction, because I had two separate knobs collapsed into one.

The Kafka fact I had was right: within a consumer group, the partition count caps the
number of *consumers*. Forty partitions and fifty consumers means ten consumers sit idle.
That is real.

But it doesn't cap concurrency — it only would if each consumer processed records one at
a time. Once fetch order is decoupled from completion order, a consumer polls a batch and
hands it to an internal pool of, say, 200 in-flight sends. Forty consumers at 200
in-flight each is eight thousand concurrent sends. Partitions bound how many *processes*
can pull; the pool inside each bounds how much *work* is in flight. The second knob is
the one that actually tracks the provider's throughput ceiling.

So there are three separate dials, and they scale on different timescales:

- **Partitions** — provision for peak and leave them alone. Cheap when idle, painful to change later.
- **Consumers / pods** — scale by time of day. More at 09:00, fewer at 03:00. Capped at partition count for pulling, which is exactly why you over-provision partitions.
- **In-flight concurrency per consumer** — the dial that responds to load within a fixed process count, and the one to wire to a circuit breaker or rate limiter.

Stacked up, they multiply:

```
   partitions           consumers / pods        in-flight per consumer
   ──────────           ────────────────        ──────────────────────
   fixed at peak        scales by time          scales with load
   day one              of day                  (breaker + rate limit)

        40         ≥       40 pulling      ×          200
        │                  │                          │
        └── ceiling on ────┘                          │
            how many can pull                         │
                                                      ▼
                                        8,000 concurrent sends in flight

   the real ceiling is none of these — it is the provider's rate limit;
   these three exist only to reach it and not exceed it
```

One caveat on that internal pool: the failure mode is memory. A consumer that keeps
polling while its pool is saturated buffers records on the heap without bound. The pool
has to apply backpressure to the poll loop — which is the same `pause()` mechanism the
circuit breaker needs, now doing double duty for load as well as for outages.

## What I'm taking away

- Write the API contract before drawing the boxes. Half the decisions I got wrong — where recipients are resolved, what `published` means, whether a message can expire — are forced into the open the moment you have to name a field and give it a type.
- Partitions are cheap, so size the topic for peak load on day one. Kafka only lets the count go up, and you don't want an increase-then-decrease cycle anyway — it's a capacity decision you make once, not a dial you tune.
- The unit of work is the design decision. If it has unbounded size, every downstream number — partitions, workers, latency budget — is unbounded too. Chunk first, then everything else can be reasoned about.
- Design backward from the external limit. The provider's rate limit and connection model is the real ceiling; my code is just what fits underneath it.
- Move work from dispatch time to schedule time whenever the information is available early. A one-second budget is not the place to warm a cache.
- Head-of-line blocking is the price of an ordering guarantee. Check whether you actually need the guarantee before engineering around the symptom.
- Retries are not a resilience strategy on their own. Without a circuit breaker they're an amplifier pointed at a dependency that is already failing.
- Measure skew from the promised time, not elapsed time through the pipeline. And know whether your SLO is a percentile or a max, because those numbers can disagree completely.
- "It's fine, it's small" is not an answer to clock skew, partial failure, or survivorship bias. Each of those has a one-sentence correct answer that costs nothing to give.

The overall pattern in my own mistakes is consistent enough to be embarrassing: I drew
the right boxes and never put numbers in them. Every single problem above surfaced the
moment someone asked "how long does that take, and how many of them are there?"
