---
layout: post
title: "The Saga Pattern"
date: 2026-07-05 00:00:00 +0530
categories: distributed-systems
tags: [distributed_systems, saga, distributed_writes]
author: "Seroze"
published: true
---

*I've been meaning to write this up for a while. It's a refresher on the saga pattern plus a summary of an article that stuck with me: ["Everyone Recommends Saga. Almost Nobody Mentions How Hard It Is to Get Right."](https://www.linkedin.com/pulse/everyone-recommends-saga-almost-nobody-mentions-how-hard-yamada-ziuuc/) by Hiroyuki Yamada (CTO at Scalar). The whiteboard version of a saga is a tidy row of boxes with a dotted rollback arrow — this post is about everything that drawing hides.*

---

Before diving in, here's where sagas sit in the broader distributed systems landscape:

```
Distributed Systems
│
├── Consensus
│   ├── Raft
│   ├── Paxos
│   └── Zab
│
├── Replication
│   ├── Primary-Replica
│   ├── Multi-Leader
│   └── Leaderless
│
├── Messaging
│   ├── Kafka
│   ├── RabbitMQ
│   └── Pulsar
│
└── Distributed Transactions
    │
    ├── ACID (single database)
    │
    ├── 2PC (Two Phase Commit)
    │
    ├── 3PC
    │
    ├── Saga Pattern
    │   ├── Orchestration
    │   └── Choreography
    │
    ├── TCC (Try Confirm Cancel)
    │
    ├── Event Sourcing (used in conjunction with CQRS)
    │
    └── Outbox Pattern
```

## Refresher: what a saga is

In a monolith, "place an order" is one ACID transaction. Split it across microservices — each with its own database — and no single transaction can span them. A **saga** is the standard answer: run the operation as a **sequence of local transactions**, each committed independently in its own service. If step N fails, you can't roll back the earlier steps (they already committed), so you run **compensating transactions** in reverse order to semantically undo them: refund the payment, restock the inventory, cancel the order.

Two coordination styles:

- **Orchestration** — a central coordinator (a saga class, or an engine like Temporal / AWS Step Functions / Camunda) drives each step and tracks state. The flow is explicit and readable in one place; the cost is coupling to every participant.
- **Choreography** — no coordinator; each service reacts to the others' events, usually through a broker like Kafka. Decoupled and simple for short flows, but the workflow exists nowhere explicitly — debugging a 6-step flow becomes archaeology. This failure mode is sometimes called **"pinball architecture"**: requests bounce between services like a pinball, and nobody can say where the ball is or why it went there. [This talk](https://www.youtube.com/watch?v=ysFP6X7rJhA) is a good presentation on the problems with advanced messaging patterns and how pinball architectures go wrong.

Typical uses: e-commerce checkout (order → payment → inventory → shipping), travel booking (flight + hotel + car), food delivery, banking and ledger flows — any business process spanning services with independent stores.

### The alternatives, briefly

- **Two-phase commit (2PC/XA)**: real atomicity and isolation, but blocking (participants hold locks), coordinator is a single point of failure, and most modern stacks (HTTP services, Kafka, NoSQL) don't speak XA. Effectively unusable across microservice boundaries.
- **TCC (Try-Confirm-Cancel)**: a saga variant where each step first *reserves* (hold ₹500, reserve stock), then confirms or cancels. The reservation acts as a business-level lock, recovering some isolation — at the cost of every participant implementing three endpoints plus timeout-based auto-cancel.
- **Don't distribute the transaction**: redraw service boundaries so the data that must change atomically lives in one service. When possible, this is the best answer.
- **Outbox + eventual consistency**: solves the "DB commit + message publish" atomicity problem, but has no compensation story — it's the transport layer under a choreographed saga, not an alternative.

So: sagas are often the only viable option. Which is exactly why Yamada's article matters — everyone recommends them, and almost nobody mentions how hard they are to get right.

## What each participating service has to get right

**1. Idempotency — in both directions.** Every step must be safe to run twice, *and so must its compensation*. This isn't theoretical: a participant may commit its work and then crash before sending the response. From the coordinator's side, "it succeeded" and "it failed" look identical, so it must retry without knowing whether the previous attempt got through. The only safe assumption is that any action — forward or backward — might arrive twice.

**2. Once you've gone backward, you can't go forward.** Messages get delayed and reordered. A participant can receive the *compensation* for step X **before** the forward action for X ever arrives — the coordinator sent the forward action, heard nothing, gave up, and sent the compensation, while the forward message was still in flight. The correct behavior: compensating a step you never performed is a no-op, *and* the late-arriving forward action must then be ignored. Every participant has to implement this, and it's fiddly and easy to get subtly wrong. (This out-of-order compensation was the production failure that taught the author the lesson.)

**3. Classify failures: retryable vs. permanent.** When a step fails, the participant must tell the coordination which kind of failure it was. Report a retryable failure as permanent, and the saga abandons work that would have succeeded and triggers an unnecessary rollback. Report a permanent failure as retryable, and the coordination retries forever, burning resources on something that will never succeed.

## What the coordination has to get right

**4. Making safe progress under ambiguity.** Did the participant's write fail, or did it succeed and the response got lost? Those cases are indistinguishable from where the coordination sits, and it must roll back correctly in both.

**5. Durable, highly available, scalable state tracking.** It's not enough to track saga state correctly — it must survive crashes so the coordination can resume or roll back exactly where it left off, without losing or double-counting anything. Coordination sits at the center of every saga, so it can't be a single point of failure. And with thousands of sagas in flight, the state reads/writes and timeout scanning become a scalability problem of their own. Tracking progress is a logic problem; tracking it durably, available, and at scale is a serious infrastructure problem.

## The two sides have to agree

A saga is a **protocol spread across many independently built pieces**. The retryable-vs-permanent contract only helps if participants classify failures the way the coordination reads them; the ordering rules only hold if every participant implements the same backward-blocks-forward behavior the coordination assumes. The protocol is only as correct as its least careful participant.

## And the part no mechanism fixes

Even with a perfect framework, three problems remain — they're about the nature of the work, not the machinery:

**6. Some actions can't truly be undone.** A compensation is a *semantic* reversal, not a real one. You can refund a charge, but you can't un-send the email, un-ship the package, or un-call the external API. Part of designing a saga is deciding what's even safely compensable — and pushing the irreversible steps as late in the sequence as possible.

**7. Intermediate state is visible the whole time.** Sagas give up isolation: half-finished results are readable by everyone while the saga runs, including values about to be compensated away. There's no free fix — you add semantic locks or `pending`/`confirmed` status flags and teach every reader to respect them. Real complexity, layered on top, to recover a fraction of what a single database gave you for nothing.

**8. Compensation can fail too.** There is no compensation for the compensation. When a rollback can't complete, your options are: keep retrying, escalate to a human, or accept persistent inconsistency. The mechanism you reached for to guarantee correctness has a failure mode of its own.

## What to actually do

The article's advice, which I fully buy:

- **Don't build the machinery yourself.** A good saga framework handles the mechanical half — idempotency scaffolding, ordering, durable state, HA and scaling. If it ships a participant-side SDK, the per-service obligations arrive as a shape to fill in rather than something each team reinvents and gets wrong.
- **Know what the framework can't do.** It can't decide which of your operations are safely compensable, can't un-send your emails, can't tell you how much isolation your business needs or design your semantic locks. The framework handles the half that's the same for everyone; the design judgment about *your* operations stays with you.

The uncomfortable lesson underneath: the parts of consistency that infrastructure *can* handle are exactly the parts you shouldn't be hand-writing, service by service.

## My takeaway

The whiteboard saga is three boxes and a dotted arrow. The production saga is: two-way idempotency in every participant, a compensated-before-performed edge case in every participant, a failure-classification contract everyone must honor, a coordinator that must make safe progress when success and failure are indistinguishable, durable HA state at scale, semantic locks to fake back some isolation, an ordering discipline for irreversible steps, and an escalation path for when the rollback itself fails. "Simple" is the wrong word — reach for a framework for the mechanical half, and spend your own effort on the half only you can do.
