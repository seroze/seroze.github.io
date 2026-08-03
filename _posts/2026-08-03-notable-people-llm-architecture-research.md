---
layout: post
title: "Notable People in LLM Architecture Research"
date: 2026-08-03 00:00:00 +0530
categories: llm
tags: [llm, architecture_research, twitter, ai_research]
author: "Seroze"
published: true
---

*A running list of people to follow on X for LLM architecture, pretraining, and post-training research — added as I come across their work.*

---

## [Muyu He](https://x.com/HeMuyu0327)

Research Scientist at [Zyphra](https://www.zyphra.com/) (June 2026–present), previously at [Collinear AI](https://www.collinear.ai/) (Jul 2025–Jun 2026). MS in CS from UPenn (2023–2025), previously a researcher across PennNLP, Penn Medicine, and Drexel. Was lead author on the TraitBasis paper ["Impatient Users Confuse AI Agents"](https://blog.collinear.ai/p/trait-basis) (ACL 2026 Oral), which builds high-fidelity simulations of human traits for testing AI agents, and first author on ["Do Value Vectors in Deep Layers Need Context from the Residual Stream?"](https://github.com/RiddleHe/nanochat/blob/master/papers/bank_of_values.pdf) (EMNLP 2026, under review) — proposes "Bank of Values," an attention variant that replaces value vectors in the last third of layers with a learned per-layer table, eliminating the V cache entirely and beating standard attention on validation loss and 21 benchmarks across two model sizes.

On X he posts hands-on architecture experiments — e.g. training a load-balanced "Attention Residual" variant end-to-end from pretraining through SFT (broke the nanochat validation-loss record, but turned out "amusingly bad" downstream) — and interpretability work on *when* and *at which layer* transformers actually pull in far-away context, plus jailbreak/alignment probing on `gpt-oss-20b`. Open-source work backs this up: [nanochat](https://github.com/RiddleHe/nanochat) (hackable pretraining stack with FLOP-controlled ablations), [llm-interp](https://github.com/RiddleHe/llm-interp) (reproducible interpretability scripts, including findings on attention sinks in Qwen3), and [gpt-oss-alignment](https://github.com/RiddleHe/gpt-oss-alignment) (the chat-template jailbreak plus a sparse-autoencoder training framework).

**Why I flagged it:** the account is a good feed for people who actually run the pretrain → SFT loop on novel architecture ideas and report the failures honestly, not just the wins.

---

*More entries to come.*
