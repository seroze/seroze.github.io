---
layout: post
title: "[Distributed Systems] Apache Flink for Aggregation-Based Alerting"
date: 2026-09-22 00:00:00 +0530
categories: distributed-systems
tags: [distributed_systems, apache_flink, stream_processing, kafka, alerting, monitoring]
author: "Seroze"
published: true
---

I keep running into Flink from the side door — not because I wanted to learn a stream
processor, but because every alerting system I've sketched out eventually needs the same
thing: count something per key, over a time window, and fire when the count crosses a
line. That's the whole job. Flink happens to be the thing people reach for when that job
outgrows a cron loop.

This is the explanation I wish someone had given me first, written around the alerting
use case and nothing else. No cluster tuning, no SQL API tour, no exactly-once theology.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The one-sentence version {#one-sentence}

Flink is a program that continuously reads an infinite stream of events, keeps some state
about those events, and produces results whenever that state changes.

Everything else — windows, watermarks, checkpoints — exists to make that sentence work
when the stream is a million events a second and the machine running it might die.

## Start with the alert you actually want {#the-alert}

Say your services emit logs like this:

```
18:00:01  service=payments  status=500
18:00:02  service=payments  status=200
18:00:03  service=payments  status=500
18:00:04  service=users     status=500
```

And the rule you want is:

> Alert me if a service returns more than 100 HTTP 500s in one minute.

The version without a stream processor is a cron job hitting a database:

```sql
-- every minute
SELECT service, count(*)
FROM logs
WHERE status = 500
  AND timestamp > now() - interval '1 minute'
GROUP BY service;
```

This works right up until it doesn't. You're storing every log line just to count a
subset of them, the query gets slower as the table grows, you poll on a fixed minute
boundary whether or not anything happened, and a late-arriving log silently lands in the
wrong bucket or gets missed entirely.

Flink flips it around. Instead of storing everything and asking questions later, you
declare the question once and let events flow through it:

```
events
  ↓
Kafka
  ↓
Flink
  ↓
aggregate
  ↓
alert
```

## The mental model {#mental-model}

```
         infinite stream
              ↓
       ┌──────────────┐
       │     Flink    │
       │              │
       │  process     │
       │  filter      │
       │  aggregate   │
       │  state       │
       └──────────────┘
              ↓
           alerts
```

A database thinks *"run this query once."* Flink thinks *"events are continuously
arriving, what should I do with each one?"* That difference is the whole thing. Once you
internalise it, the API stops looking like a weird dialect of SQL and starts looking
like a description of a pipeline.

## Filtering {#filtering}

The simplest operator. Events come in looking like:

```json
{ "service": "payments", "status": 500, "timestamp": "18:00:03" }
```

and you say: keep only the ones where `status == 500`.

```
200
500  ────────┐
200          │
500  ────────┤
500          │
200          │
             ↓
          Flink
             ↓
          500
          500
          500
```

Nothing surprising. It's `filter`, it's stateless, and it's the cheapest way to cut your
volume before the expensive operators downstream.

## Aggregation, and the word "stateful" {#aggregation}

Now count errors per service. Events:

```
payments 500
payments 500
users    500
payments 500
users    500
```

Group by service and you get:

```
payments → 3
users    → 2
```

Conceptually Flink is doing `counts[service] += 1`, and the interesting part is *who owns
that map*. It's Flink. It holds it, it partitions it across workers so each key lives on
exactly one worker, and it checkpoints it to durable storage so a crash doesn't reset your
counters to zero.

That's what people mean when they say Flink is **stateful**: it remembers things about
events it has already processed, and that memory survives failures.

## Add a window {#windows}

`payments has had 1,000 errors since the process started` is a useless alert. What you
want is `payments had 100 errors in the last minute`. So you bound the aggregation with a
window:

```
18:00:00 ───────────────── 18:01:00
              1 minute
```

Flink collects the events that belong to that window:

```
18:00:03 payments 500
18:00:04 payments 500
18:00:11 payments 500
...
18:00:59 payments 500
```

closes it at 18:01:00, and emits:

```
payments → 103 errors
```

Then your rule is just `if errors > 100: ALERT`. The full pipeline:

```
Kafka
  │
  │ events
  ↓
Flink
  │
  ├── filter status == 500
  │
  ├── group by service
  │
  ├── 1 minute window
  │
  ├── count
  │
  └── if count > 100
          ↓
        ALERT
```

If you only take one diagram from this post, take that one. Most aggregation alerts are
that shape with different words in the boxes.

### Tumbling windows {#tumbling}

The simplest kind. Fixed size, no overlap:

```
18:00:00 ───── 18:01:00
18:01:00 ───── 18:02:00
18:02:00 ───── 18:03:00
```

Each event lands in exactly one window, and each window produces exactly one result:

```
18:00-18:01 → 103 errors   → ALERT
18:01-18:02 →  57 errors   → nothing
18:02-18:03 → 121 errors   → ALERT
```

### Sliding windows {#sliding}

Tumbling windows have an annoying failure mode for alerting: 60 errors at 18:00:45 and 60
more at 18:01:15 is 120 errors in thirty seconds, and neither window sees more than 60.
The burst is real and you missed it because it straddled a boundary.

A sliding window fixes that by evaluating a one-minute window more often than once a
minute:

```
window = 1 minute
slide  = 10 seconds
```

```
18:00:00 → 18:01:00
18:00:10 → 18:01:10
18:00:20 → 18:01:20
18:00:30 → 18:01:30
...
```

Every event now belongs to six windows instead of one, which is exactly the cost: six
times the state and six times the aggregation work, in exchange for catching bursts
wherever they land. For alerting that trade is usually worth making, but pick the slide
deliberately — a one-second slide on a one-hour window is sixty times the work of the
tumbling version.

## Grouping by more than one thing {#multiple-dimensions}

This is where it starts paying for itself. Suppose events carry `service`, `region`,
`status`, and `latency`, and the rule is *alert if a service in a particular region gets
more than 100 errors a minute*. Group by the pair:

```
group by (service, region)
```

and the state becomes:

```
(payments, us-east) → 103
(payments, eu-west) →  12
(users,    us-east) →   3
(users,    eu-west) → 107
```

Two alerts fire, `payments/us-east` and `users/eu-west`, and crucially the `payments`
outage in one region doesn't get averaged away by the other region being healthy. The
number of keys is the product of the cardinalities, so this is also the knob that blows
up your state if you key on something unbounded like user ID or request ID.

## Count isn't the only aggregation {#beyond-count}

Once the pipeline exists, swapping the aggregate function gives you a family of alerts for
free.

**Average latency:**

```
payments → 1 minute window → avg(latency) = 850ms → 850 > 500 → ALERT
```

**Max latency:** `max(latency) > 5s`.

**Error rate**, which in practice is the one you want most often, because a raw count
alerts on traffic spikes as much as on outages. Keep two counters per key instead of one:

```
             ┌─ total requests
events ──────┤
             └─ error requests
                    ↓
               error rate
                    ↓
               threshold
                    ↓
                  ALERT
```

With 10,000 requests and 600 errors, that's 6%, and `error_rate > 5%` fires. The same
600 errors against 10 million requests is 0.006% and shouldn't wake anyone.

## The alert that needs real state: consecutive violations {#consecutive}

Here's the rule that separates Flink from a SQL query on a timer:

> Alert if the error rate is above 5% for five consecutive minutes.

Now you're keeping state *about previous window results*, not just about events.

```
minute    error rate

18:00       6%   ✓
18:01       7%   ✓
18:02       8%   ✓
18:03       6%   ✓
18:04       9%   ✓
                     → ALERT
```

But this sequence stays quiet:

```
18:00  6% ✓
18:01  7% ✓
18:02  3% ✗     ← streak resets
18:03  8% ✓
18:04  9% ✓
```

You'd implement it with a keyed state value holding the current streak length per key:
increment on a violating window, reset to zero otherwise, fire at five. That's a handful
of lines on top of the existing pipeline, and it's the thing that turns a noisy threshold
alert into one people don't mute.

## What Flink actually stores {#what-is-stored}

A fair worry when you first see "one million events per second": where does all that go?

It doesn't. For `count errors per service per minute`, the state for the open window is
roughly:

```
payments → 53
users    → 17
search   → 81
```

A few numbers per key. The events themselves are discarded as soon as they've been folded
into the aggregate — that's why you want an incremental aggregate function rather than one
that buffers the window's events and reduces at the end.

Flink periodically checkpoints that state to durable storage, so if a worker dies the job
restarts from the last checkpoint and replays Kafka from the matching offset instead of
losing your counters.

## Kafka's role {#kafka}

People sometimes ask whether Flink replaces Kafka. It doesn't; they sit next to each
other and solve different problems.

```
                    ┌─────────────┐
applications ──────→│    Kafka    │
                    └──────┬──────┘
                           │
                           ↓
                    ┌─────────────┐
                    │    Flink    │
                    │             │
                    │ filter      │
                    │ group       │
                    │ window      │
                    │ aggregate   │
                    │ alert rules │
                    └──────┬──────┘
                           │
                           ↓
                    Alert service
                           │
                 ┌─────────┼─────────┐
                 ↓         ↓         ↓
               Slack     Email     PagerDuty
```

Kafka is the durable, replayable event log. Flink is the computation engine that consumes
it. The replay part matters more than it looks: it's what makes Flink's recovery story
work at all, because restarting from a checkpoint means rewinding the Kafka offset too.

## Why not just write the alerting service yourself {#why-not-diy}

This was my honest first reaction. `Kafka → my own service` is not a hard program to
start writing. It's a hard program to finish. You'd end up owning:

- consuming and partitioning the stream
- aggregation and window management
- state, and state recovery after a crash
- checkpointing
- event ordering and late events
- timers
- parallel workers and rebalancing when one dies
- backpressure
- scaling up and down
- something resembling exactly-once semantics

None of that is the alerting logic. It's the machinery underneath it. Flink's pitch is
that you write:

```
events
  → filter
  → groupBy(service)
  → window(1 minute)
  → aggregate
  → alert
```

and it owns the list above. Whether that trade is worth it depends on how much of the
list you'd actually need — for a single low-volume rule it clearly isn't, and for a
platform where teams define their own alert rules over a firehose it clearly is.

## Event time, briefly {#event-time}

One concept you can't skip for monitoring. Your app logs an error at 10:00:01, network
congestion delays it, and Flink receives it at 10:00:08. Which minute does it count
toward?

- **Processing time** — 10:00:08, when Flink saw it. Simple, fast, and wrong whenever the
  pipeline hiccups: a thirty-second consumer lag shifts every event into later windows and
  your alert history stops matching your logs.
- **Event time** — 10:00:01, when it happened. Results are reproducible; replaying the same
  Kafka topic gives identical windows.

For alerting you almost always want event time. The cost is that Flink now has to decide
when a window is *done*, given that a late event might still show up. That's what
**watermarks** are: a running claim that "I've probably seen everything up to time T", which
lets windows close and fire.

You don't need to go deep on watermarks to build the first version, but you do need to
know the knob exists, because "my alert fires two minutes late" and "my alert missed half
the errors" are both watermark-configuration answers.

## The layers, in one picture {#layers}

```
                  EVENTS
                    │
                    ↓
             ┌─────────────┐
             │   FILTER    │
             └──────┬──────┘
                    ↓
             ┌─────────────┐
             │   GROUP BY  │
             └──────┬──────┘
                    ↓
             ┌─────────────┐
             │    WINDOW   │
             └──────┬──────┘
                    ↓
             ┌─────────────┐
             │  AGGREGATE  │
             └──────┬──────┘
                    ↓
             ┌─────────────┐
             │ ALERT RULE  │
             └──────┬──────┘
                    ↓
                  ALERT
```

Filled in for the running example:

```
logs → status == 500 → group by service → 1 minute window → count → count > 100 → alert
```

Every rule below is that skeleton with different contents:

| Rule | Aggregate | Condition |
|---|---|---|
| Traffic spike | `count` | `requests/sec > 10,000` |
| Error rate | `errors / requests` | `> 5%` |
| Slow service | `avg(latency)` | `> 500ms` |
| Tail latency | `p99(latency)` | `> 2s` |
| Per-region errors | `errors / requests` keyed by `(service, region)` | `> 5%` |
| Sustained degradation | error rate + streak counter | `> 5%` for 5 consecutive minutes |
| Anomaly-ish | current rate vs rolling baseline | `> 2 × baseline` |
| Composite | error rate AND request rate | `> 5%` AND `> 1000/sec` |

All of them run continuously over the same stream.

## If you're learning this for an alerting system {#learning-path}

Don't start with the ecosystem. Six concepts, in this order:

```
1. DataStream
      ↓
2. map / filter
      ↓
3. keyBy
      ↓
4. windows
      ↓
5. state
      ↓
6. event time + watermarks
```

Then build exactly one tiny thing:

> Kafka → Flink → alert when HTTP 500 count > 100 in 1 minute

and once it works, extend it sideways rather than deeper:

```
                    ┌→ count errors
Kafka → Flink ──────┼→ error rate
                    ├→ avg latency
                    └→ p99 latency
                              ↓
                         Alert rules
```

That project teaches you more about what Flink is for than reading the API surface ever
will. It's also, conveniently, the smallest useful version of the system you'd actually
ship.
