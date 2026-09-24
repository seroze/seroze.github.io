---
layout: post
title: "[Distributed Systems] NATS vs Kafka: Messaging vs the Log"
date: 2026-09-24 00:00:00 +0530
categories: distributed-systems
tags: [distributed_systems, nats, kafka, messaging, pub_sub, event_sourcing]
author: "Seroze"
published: true
---

While working through the [Flink alerting post]({% post_url 2026-09-22-apache-flink-for-alerting %}),
I kept seeing NATS mentioned next to Kafka as if they were interchangeable. They aren't.
The comparison only clicked for me once I stopped thinking "RPC vs pub/sub" and started
asking a different question: *does this message need to exist after it's delivered?*

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## The one-sentence version {#one-sentence}

**NATS is messaging first. Kafka is a durable log first.**

NATS asks "who is listening right now?" Kafka asks "what has happened, and how far along
is each consumer in that history?"

## NATS request/reply {#request-reply}

NATS supports a direct request → response pattern over a subject:

```
Client ──request("user.get", 42)──> NATS ──> UserService
Client <──────────── reply(user) ─── NATS <──┘
```

```python
response = await nc.request("user.get", b"42")
```

The honest take: **this is just RPC.** It's one way to implement "I need an answer from
another service." If all you need is typed, synchronous service-to-service calls, gRPC is
usually the more obvious choice — protobuf schemas, generated clients, deadlines, streaming.

So why would anyone use NATS request/reply? Because you already want a messaging fabric:

- **No service discovery.** The caller addresses a subject (`payment.authorize`), not a
  host. Whoever is subscribed answers.
- **Built-in load balancing.** Several instances join a *queue group* and NATS delivers
  each request to one of them.
- **One transport for everything.** The same connection does request/reply, pub/sub and
  (with JetStream) durable streams.

If none of those matter to you, don't reach for NATS just to do RPC.

### Why request/reply is awkward on Kafka {#kafka-rpc}

Kafka *can* do it, but you build it yourself:

```
OrderService ──PaymentRequest──> [payment.requests]  ──> PaymentService
OrderService <──PaymentResponse─ [payment.responses] <──┘
```

Now you own request and response topics, correlation IDs, a consumer that matches replies
to in-flight requests, and timeouts. Every request also gets written to disk and
replicated — overhead you're paying for durability you probably don't want on a
"calculate shipping cost" call.

## NATS pub/sub {#pub-sub}

```
                           ┌──> Email
payment.completed ──> NATS ├──> Ledger
                           └──> Analytics
```

This is where messaging genuinely differs from RPC. The publisher doesn't call three
services and wait; it announces that something happened and moves on.

The catch with **core NATS**: delivery is at-most-once to *currently connected*
subscribers. If Analytics is offline when the message is published, it never sees it.
There's no history to come back to.

## Kafka: append, persist, consume, track offset, replay {#kafka}

Kafka's core abstraction is a partitioned, append-only log:

```
topic: payments
  partition 0:  [A][B][C][D][E][F][G][H][I][J]
                          ^                  ^
                    Analytics offset    Fraud offset
```

Messages stay in the log (for the retention period) regardless of who has read them. Each
consumer group tracks its own offset.

Say Analytics goes down for six hours. Fraud keeps consuming through `J`. When Analytics
comes back, it resumes from `D` and catches up. It can even rewind and reprocess from `B`
if you shipped a bug.

Fan-out works through **consumer groups**: every group gets every message, but *within*
a group Kafka assigns partitions across consumers, so each message is processed by one
member. One mechanism gives you both broadcast (across groups) and competing consumers
(within a group).

## JetStream muddies the water {#jetstream}

"NATS is ephemeral, Kafka is durable" is too simple, because NATS has **JetStream**:
persisted streams, durable consumers, acks, replay. With JetStream, NATS can absolutely
back a durable event stream.

So the real question isn't "does it persist?" but which model you want. Kafka's
partitioned log has a deep ecosystem around it (Connect, Flink, Kafka Streams, CDC via
Debezium). JetStream is lighter to run and sits alongside NATS's messaging patterns.

## Side by side {#comparison}

|                               | Core NATS              | NATS JetStream        | Kafka                         |
|-------------------------------|------------------------|-----------------------|-------------------------------|
| Primary abstraction           | Message bus            | Persisted stream      | Distributed log               |
| Persistence                   | No                     | Yes                   | Yes                           |
| Offline consumer catches up   | No                     | Yes                   | Yes                           |
| Replay                        | No                     | Yes                   | Yes                           |
| Request/reply                 | Native                 | Native (via NATS)     | Build it yourself             |
| Load-balanced consumers       | Queue groups           | Pull consumers        | Consumer groups + partitions  |
| Latency                       | Very low               | Low                   | Low, tuned for throughput     |
| Stream processing ecosystem   | Minimal                | Small                 | Huge                          |

## What event sourcing actually means {#event-sourcing}

This gets conflated with "using Kafka" constantly, so it's worth separating.

A normal database stores current state:

```
accounts
id   balance
42   700
```

**Event sourcing** stores the events that *produced* that state, and treats them as the
source of truth:

```
Account 42
  Deposited  1000   → balance 1000
  Withdrew    200   → balance  800
  Withdrew    100   → balance  700
```

Current state is a *projection* you get by replaying events. Two things fall out of that:

- **You keep the "why."** A row saying `status = CANCELLED` tells you nothing six months
  later. `OrderCreated → PaymentAuthorized → CancellationRequested → PaymentRefunded →
  OrderCancelled` does.
- **You can build new views later.** Need customer lifetime value next quarter? Replay
  history into a new projection.

### Kafka ≠ event sourcing {#not-event-sourcing}

You can run Kafka everywhere and do no event sourcing at all:

```
Postgres ──CDC──> Kafka ──┬──> Search index
                          ├──> Analytics
                          └──> Notifications
```

Kafka holds events here, but Postgres is still the source of truth. Same for the Flink
alerting pipeline: `Ledger → Kafka → Flink → Alert Service` uses Kafka as durable
transport so Flink can consume at its own pace, checkpoint offsets, and recover. That's a
log, not event sourcing.

## The mental model {#mental-model}

Stop framing it as NATS vs Kafka and start from what the communication needs:

1. **I need an answer** → RPC: gRPC, or NATS request/reply if you already run NATS.
2. **Something happened; tell whoever cares** → pub/sub: NATS, or Kafka.
3. **I need a durable history consumers can process at their own pace** → Kafka, or
   NATS JetStream.
4. **That history *is* my source of truth** → event sourcing, which you can build on
   top of #3 — but #3 alone doesn't make it event sourcing.

For the alerting pipeline, Kafka wins because of #3: history, independent consumers,
replay, partitioning, and a stream processor that expects all of that. For "what does
shipping cost?", nobody needs that message to exist a second after it's answered.
