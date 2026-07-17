---
layout: post
title: "[System Design] WhatsApp architecture"
date: 2026-07-17 00:00:00 +0530
categories: system-design
tags: [system_design]
author: "Seroze"
published: true
---

*How WhatsApp delivers messages to offline users — it's not "just a database".*

Ask most engineers how WhatsApp handles messages sent to someone whose phone is off, and you'll get some version of:

> "The server stores the message in a database until the user comes online."

That's technically true — and almost entirely useless as a system design answer. It skips everything that makes message delivery *reliable*: durable storage, delivery acknowledgments, retries, duplicate protection, and what happens when someone comes back to a mountain of pending messages.

Let's build the real answer in four layers, then dig into two follow-up questions that separate a good answer from a great one.

## Layer 1: Store the message before saying "sent"

When you press send, your message travels to a WhatsApp server. The server assigns it a unique message ID and writes the encrypted payload to durable storage.

Only after that write succeeds does the sender see the first tick.

This ordering is not an implementation detail — it's the core reliability guarantee. If the server acknowledged "sent" while the message existed only in memory, a server crash would silently vaporize it. The sender would believe the message was on its way; the recipient would never receive it; nobody would know.

**Rule: never acknowledge what you haven't durably stored.**

## Layer 2: A pending inbox for every offline user

Next, the server checks whether the recipient has an active connection.

- **Online?** Deliver immediately.
- **Offline?** Place the message in that user's *pending inbox* — a per-user queue of messages waiting for them to return.

Each entry in the queue carries:

- the unique message ID
- the encrypted message content
- sender and recipient IDs
- creation timestamp
- delivery status

The message waits there until the recipient reconnects — or until the retention window expires (more on that below).

## Layer 3: Deliver, confirm, *then* delete

When the recipient's phone comes back online, it opens a connection and the server begins sending the pending messages.

But here's the crucial part: **the server does not delete a message when it sends it. It deletes the message when the phone confirms it.**

The sequence is:

1. Server sends message 123.
2. Phone receives it, decrypts it, persists it locally.
3. Phone acks: "I have message 123."
4. Server marks it delivered, removes it from the queue.
5. Sender sees the second tick.

If the connection drops between steps 1 and 3, the server still has the message and simply sends it again on the next connection. Delivery is *at-least-once* by design.

## Layer 4: Retries create duplicates — unique IDs kill them

At-least-once delivery has an obvious side effect: the same message can arrive twice. If the phone received message 123 but the ack got lost, the server will resend it.

This is why every message has a unique ID. The phone keeps track of IDs it has already processed; when a duplicate arrives, it's recognized and silently dropped. The sender-facing behavior becomes *effectively exactly-once*, built from at-least-once delivery plus idempotent receipt.

Messages also carry ordering information, so when a batch of stored messages arrives together, the conversation renders in the right sequence rather than shuffled.

**The complete answer in one sentence:** the server durably stores the message before confirming it, queues it per-recipient, retries delivery until the device acknowledges receipt, and relies on unique IDs so retries never become duplicates.

---

## Follow-up #1: Does WhatsApp keep your conversation history?

No — and this surprises people. **WhatsApp's servers are a relay, not an archive.**

Once a message is delivered and acknowledged, the server deletes it. If the recipient never comes online, the message sits in the pending queue for up to about 30 days, after which it's discarded entirely. That's why a message sent to a phone that's dead for a month simply never arrives.

Your actual conversation history lives in exactly two places:

1. **On-device databases.** Each phone maintains its own local message store. This is the source of truth.
2. **Backups.** Google Drive or iCloud backups are snapshots of that local database — not something WhatsApp's servers maintain.

This design is tightly coupled to end-to-end encryption: the server only ever handles ciphertext it cannot read, and even that ciphertext is transient.

It's also why WhatsApp's multi-device support was genuinely hard to build. A newly linked device can't "pull the conversation from the cloud" — there is no cloud copy. History has to be transferred from the primary phone to the new device, with the server acting as a blind pipe.

Compare the spectrum:

| System | Server-side history | Multi-device sync |
|---|---|---|
| WhatsApp | None (ephemeral queue only) | History transfer from primary device |
| Telegram (cloud chats) | Indefinite | Trivial — fetch from server |
| Slack / Discord | Fully server-authoritative | Trivial — server is the truth |

Neither end of the spectrum is "correct." WhatsApp trades sync convenience for a minimal server trust surface; Telegram and Slack trade the reverse.

## Follow-up #2: The backpressure problem hiding in "send all pending messages"

Here's the trap question: *what happens when a user reconnects after weeks away and has 50,000 pending messages?*

(WhatsApp's 30-day TTL bounds the worst case, but a heavy group-chat user can still rack up tens of thousands of messages in a few weeks. The problem is real.)

The server cannot firehose 50,000 messages at a phone. The phone would choke — and the interesting part is *why* it would choke, and what the fix looks like.

### Invert control: let the client drain the queue

The clean solution is pull-based draining. Instead of the server pushing at its own pace, the reconnecting phone requests messages at *its* pace: "give me the next batch" → process → persist → ack → repeat.

The consumer sets the rate. That is backpressure done properly.

(In practice, many systems keep server push but add a **bounded in-flight window**: the server may only have N unacknowledged messages outstanding, and the window advances only as acks return. Behaviorally, it's the same thing.)

### Batch with cursors, so the drain is resumable

The queue is drained in pages — a few hundred messages at a time, ordered by sequence number. Each request carries a cursor: "I've processed everything up to sequence 48,200."

If the phone loses connectivity halfway through the backlog, it reconnects and resumes from the cursor instead of starting over. The ack-then-delete rule from Layer 3 now applies per *batch* rather than per message, which also amortizes round trips.

### The phone is the real bottleneck

The network isn't the slow part. The phone is doing:

- **Per-message decryption**, which for the Signal protocol must happen *in order* per sender (the ratchet advances with each message)
- **Local database writes** — and writing each batch in one transaction instead of hundreds of individual inserts matters enormously
- **UI work** for conversations that just gained thousands of messages

So the client deliberately paces itself: decrypt a batch, persist it, sync to disk, ack, ask for more.

### Not all pending data is equal

A sensible drain order:

1. **Delivery receipts and control messages first** — tiny, and they unblock the sender's ticks immediately
2. **Recent 1:1 messages**
3. **Bulk group backlog last**

Some systems go further and deliver newest-first for visible conversations so the app becomes usable right away, backfilling older history lazily. That complicates per-sender ordering, so it's done per-conversation rather than globally.

### The server protects itself too

- Per-device rate limits on drain requests
- A cap on in-flight *bytes*, not just message count — one message with a 60MB video is very different from a text
- **Media offloaded to blob storage.** The queue holds only the small encrypted envelope plus a pointer; the actual media downloads lazily when the user opens the chat. The drain path only ever moves lightweight envelopes.

### The escape hatch

Past some backlog size, replaying everything stops making sense — which is one more argument for the TTL: it bounds the worst case. Systems with server-side history handle the extreme differently: they don't replay at all. The client fetches recent history on demand and pages backward, which is effectively infinite backpressure tolerance.

---

## The patterns underneath

Strip away the WhatsApp branding and you're left with a handful of patterns that show up all over distributed systems:

- **Durable write before acknowledgment** — the same rule behind write-ahead logs and Kafka's `acks=all`
- **At-least-once delivery + idempotent consumers = effectively exactly-once** — the same trick as idempotency keys in payment APIs
- **Ack-then-delete queues with TTLs** — the same lifecycle as SQS visibility timeouts and dead-letter policies
- **Bounded in-flight windows + cursor-based resumable batches + consumer-paced acks** — the same trio as TCP flow control, Kafka consumer groups, and gRPC streaming

A messaging system doesn't move text from one phone to another. It runs a delivery protocol designed to survive offline users, broken networks, retries, and server crashes — without ever asking anyone to press "send" again.
