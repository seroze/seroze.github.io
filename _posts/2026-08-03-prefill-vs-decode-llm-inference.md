---
layout: post
title: "Prefill vs Decode: The Two Phases of LLM Inference Explained"
date: 2026-08-03 00:00:00 +0530
categories: llm
tags: [llm, inference, kv_cache, transformers, attention]
author: "Seroze"
published: true
---

When people talk about LLM inference, you'll often hear terms like **prefill**, **decode**, and **KV cache**. Understanding these three concepts makes it much easier to understand optimizations such as FlashAttention, Continuous Batching, Speculative Decoding, and PagedAttention.

Let's break them down.

---

## A Simple Example

Suppose the user asks:

> **"What is the capital of France?"**

After tokenization, the prompt might look like:

```
[What] [is] [the] [capital] [of] [France] [?]
```

Let's say this results in **7 tokens**.

The model will eventually generate:

```
Paris is the capital of France.
```

Inference happens in two distinct phases.

---

## Phase 1: Prefill

The **prefill phase** processes the **entire prompt** in a single forward pass.

```
Input Prompt
────────────────────────────
What  is  the  capital  of  France  ?

          ↓

Transformer
```

For every transformer layer, every token computes:

$$
Q = XW_q \qquad K = XW_k \qquad V = XW_v
$$

Since the whole prompt is already known, all tokens can be processed **in parallel**.

The attention matrix looks like:

$$
7 \times 7
$$

Each token attends only to previous tokens using a causal mask, but all of those computations happen simultaneously on the GPU.

At the end of every transformer layer, the model stores:

```
K1 K2 K3 ... K7
V1 V2 V3 ... V7
```

This is called the **KV Cache**.

The purpose of prefill is simple:

> **Read the entire prompt and build the KV cache.**

---

## Why Is Prefill Expensive?

Suppose the prompt contains **4000 tokens**.

The attention matrix now becomes:

$$
4000 \times 4000
$$

That's a huge amount of computation.

However, GPUs excel at large matrix multiplications, so utilization is typically very high.

Prefill is therefore **compute-bound**.

---

## Phase 2: Decode

Once prefill finishes, the model starts generating new tokens.

Suppose the first generated token is:

```
Paris
```

A common misconception is that the model processes all 8 tokens again.

It doesn't.

Instead, only the **new token** is passed through the transformer.

For that new token, each layer computes:

$$
Q_{new} \qquad K_{new} \qquad V_{new}
$$

Then attention becomes:

```
Q_new

    ↓

[K1 K2 K3 ... K7 K_new]
[V1 V2 V3 ... V7 V_new]
```

Notice what happened:

- Previous Keys and Values are reused from the cache.
- Only one new Key and one new Value are computed.
- The cache simply grows by one entry.

```
Before

K1 K2 K3 ... K7

After

K1 K2 K3 ... K7 K8
```

The same process repeats for every generated token.

---

## Why Don't We Cache Queries?

During decoding, the Query is only needed once.

For example:

$$
Q_{100}
$$

is used only to generate token 100.

The next step computes:

$$
Q_{101}
$$

instead.

Queries are never reused, so caching them provides no benefit.

Keys and Values, on the other hand, are reused by every future token.

---

## Why Don't We Cache Hidden States?

Another common question is:

> Why not cache the hidden state instead of Keys and Values?

Suppose we cache:

$$
h_{100}
$$

During the next decoding step, we'd still have to compute:

$$
K_{100} = h_{100} W_k \qquad V_{100} = h_{100} W_v
$$

for every previous token.

For long contexts, that means recomputing thousands of Keys and Values every decoding step.

By caching **K** and **V** directly, we avoid all of that work.

The attention mechanism operates on **Keys and Values**, not on raw hidden states.

---

## Why Don't We Cache Attention Outputs?

Attention output depends on the **current Query**.

Suppose token C has already been processed.

Its attention output was computed using:

$$
Q_C
$$

When a new token D arrives, attention becomes:

$$
Q_D \times [K_1\ K_2\ \ldots\ K_D]
$$

The Query has changed.

Therefore, the previous attention output cannot be reused.

Only Keys and Values remain valid for future tokens.

---

## Compute vs Memory

The two phases stress different hardware resources.

### Prefill

- Entire prompt processed together
- Large matrix multiplications
- High GPU utilization
- Compute-bound

Think:

> **Read and understand the prompt.**

### Decode

- One token at a time
- Sequential generation
- Reuses KV cache
- Memory-bandwidth-bound

Think:

> **Generate the next token using everything learned so far.**

---

## Which Phase Is More Expensive?

It depends on the workload.

### Long Prompt, Short Answer

```
Prompt: 16K tokens
Output: 5 tokens
```

Prefill dominates.

### Short Prompt, Long Answer

```
Prompt: 20 tokens
Output: 4000 tokens
```

Decode dominates because thousands of sequential forward passes are required.

---

## Why Do Datacenters Separate Prefill and Decode?

Large inference systems often use separate GPU clusters.

```
Client Request

        │

        ▼

+----------------------+
|   Prefill Cluster    |
|  Compute Optimized   |
+----------------------+

        │
   KV Cache Transfer

        ▼

+----------------------+
|   Decode Cluster     |
|  Memory Optimized    |
+----------------------+
```

This allows each cluster to be optimized for its own workload:

- Prefill GPUs maximize FLOPs.
- Decode GPUs maximize throughput and memory bandwidth.

---

## Key Takeaways

| Prefill | Decode |
|----------|---------|
| Processes the entire prompt | Processes one new token at a time |
| Computes Q, K, and V for every prompt token | Computes Q, K, and V only for the new token |
| Builds the KV cache | Reuses and extends the KV cache |
| Compute-bound | Memory-bandwidth-bound |
| High GPU utilization | Lower GPU utilization, sequential execution |

## Mental Model

Think of inference as two distinct stages:

- **Prefill:** *"Read and understand everything the user has written."*
- **Decode:** *"Generate one word at a time while reusing everything already understood."*

Once this distinction clicks, many modern LLM inference optimizations — FlashAttention, Continuous Batching, PagedAttention, Speculative Decoding, and Disaggregated Prefill/Decode — become much easier to understand.
