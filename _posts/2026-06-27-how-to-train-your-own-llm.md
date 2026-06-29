---
layout: post
title: "How to Train Your Own LLM — A 20-Session Curriculum"
date: 2026-06-27 00:00:00 +0530
categories: machine-learning
tags: [llm, transformers, training, distributed-training, deep-learning]
author: "Seroze"
published: true
---

*Training a large language model end-to-end touches almost every part of the ML stack — from the math of attention to multi-GPU communication patterns to the operations of keeping a long run alive. This is a 20-session roadmap that walks through the full lifecycle: architecture, data, training, scaling, alignment, and shipping.*

---

## Phase 1 — Architecture Foundations

### Session 1: Transformer Foundations
Attention, multi-head attention (MHA), positional encodings; build a minimal transformer block from scratch.

### Session 2: Tokenization & Vocabulary Design
BPE / WordPiece / SentencePiece; vocab size, merges, frequency sorting; handling Indic and multilingual text.

---

## Phase 2 — Data

### Session 3: Data Collection & Sourcing
Sourcing across the full lifecycle: pre-training, SFT, preference, safety, and evaluation data.

### Session 4: Data Cleaning & Deduplication
Quality filters, MinHash/LSH dedup, toxicity/PII removal, contamination scans; reproducible at scale.

### Session 5: Data Mixtures & Curriculum
Domain weighting, upsampling, and mixture-shift effects on loss.

### Session 6: Building the Training Dataset
Sharding, packing, streaming dataloaders; resumable data ordering.

---

## Phase 3 — Model Internals

### Session 7: Embeddings & Model Internals
Token, positional, and factorized (Kronecker) embeddings; weight tying.

### Session 8: Modern Attention Variants
RoPE, ALiBi, GQA/MQA, sliding-window, linear-attention; long-context extension.

### Session 9: Loss Functions & Output Heads
Cross-entropy, adaptive softmax, fused linear CE kernels, multi-token prediction.

---

## Phase 4 — Training

### Session 10: Training Loop Fundamentals
Forward/backward, gradient accumulation, mixed precision, gradient clipping.

### Session 11: Optimizers & Learning-Rate Schedules
AdamW, weight decay, warmup, cosine vs WSD, EMA; the linear scaling rule.

### Session 12: Distributed Training I
Data Parallel & ZeRO 1/2/3; memory math for multi-GPU.

### Session 13: Distributed Training II
Tensor, pipeline, and sequence parallelism; communication overhead.

### Session 14: Mixture-of-Experts
Routing, load balancing, expert sharding, active-vs-total params.

### Session 15: Stability, Debugging & Live Monitoring
Divergence detection, frozen-layer constraints, dashboards.

### Session 16: Scaling Laws & Compute Planning
Chinchilla-style trade-offs, compute budgeting, run sizing.

---

## Phase 5 — Alignment & Serving

### Session 17: Supervised Fine-Tuning
Current best SFT recipes; LoRA/QLoRA; instruction-following benchmarks.

### Session 18: Preference Alignment & Inference Serving
Current SOTA preference learning (GRPO/DPO family); vLLM serving.

---

## Phase 6 — Infrastructure & Launch

### Session 19: Infrastructure, Checkpointing & Quantization
Cloud provisioning, fault tolerance, QAT; the actual cluster the run launches on.

### Session 20: Training Run Kickoff & Ongoing Lab Operations
Launching the lab's flagship training run; ongoing roles continue past the formal calendar.

---

## Closing Thoughts

The path from a minimal transformer block to a launched flagship run is long, but each session builds on the last. The first half is about *understanding* — architecture, data, and the training loop. The second half is about *scale and operations* — distributing the compute, aligning the model, and keeping a multi-week run alive. Master both halves and you can train your own LLM.
