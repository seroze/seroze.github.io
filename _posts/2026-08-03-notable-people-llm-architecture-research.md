---
layout: post
title: "People to follow in LLM architecture research"
date: 2026-08-03 00:00:00 +0530
categories: llm
tags: [llm, llm_architecture_research, twitter, ai_research]
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

## [Yuchen Liu](https://x.com/YuchenL52766559)

Search/AI infrastructure engineer at DoorDash (Seattle, Aug 2025–present) working on streaming indexing and Lucene-native hybrid retrieval — and, on the side, a frequent collaborator of Muyu He (above): co-author on the ["Do Value Vectors in Deep Layers Need Context from the Residual Stream?"](https://github.com/RiddleHe/nanochat/blob/master/papers/bank_of_values.pdf) paper (EMNLP 2026, under review) and a contributor to the nanochat and llm-interp stacks. Also builds [nanoRL](https://github.com/Upcccccc), an open-source RL training framework with vLLM integration. Posts under the display name "Wuxxcc"; his site is [upcccccc.github.io](https://upcccccc.github.io).

The tweet that got him on this list: [a thread asking *when* a transformer actually reads faraway context](https://x.com/YuchenL52766559/status/2080162233275871656) — not whether it can, but at which layer the information gets pulled into the computation. Using hidden-state swap interventions on Qwen3-8B, they show nearby entities are read around layers 24–26 while entities 100+ tokens away aren't fully read until layers 31–34, with a neat sanity check: on a model with mostly sliding-window attention, the curves drop sharply at exactly the global-attention layers — the experiment recovered the architecture blind. They then trained models from scratch to confirm the corollary: moving global-attention layers earlier hurts at equal FLOPs.

**Why I flagged it:** the thread is a model example of interpretability done with the scientific loop closed — a clean intervention, a falsifiable architectural prediction, and a from-scratch training run to test it.

---

## [Elie Bakouch](https://x.com/eliebakouch)

Pretraining researcher at [Hugging Face](https://huggingface.co/eliebak) and one of the core people behind the SmolLM family — co-author of [SmolLM2](https://arxiv.org/abs/2502.02737) (data-centric training of small LMs) and [SmolLM3](https://huggingface.co/blog/smollm3) (a 3B multilingual long-context reasoner trained on 11T tokens). Co-authored [The Smol Training Playbook](https://huggingface.co/spaces/HuggingFaceTB/smol-training-playbook) (Oct 2025), Hugging Face's long-form writeup of the messy reality of training a state-of-the-art model end to end — ablations, bugs, and all. Has also contributed to open-training efforts like INTELLECT-1 and The Common Pile v0.1.

On X he's one of the best feeds for open-weight release breakdowns: when a new model drops, he reads the tech report and surfaces the architecture bets that actually matter. Example: [his thread on Motif's release](https://x.com/eliebakouch/status/2079364961353028078) — a Korean lab shipping a 314B-total / 13B-active MoE that performs on par with much bigger models like MiniMax M3 and DeepSeek v4 Pro, notable for baking the lab's own research bets into production (per-expert activation functions with PolyNorm, among others).

**Why I flagged it:** he sits at the intersection of doing pretraining (SmolLM) and explaining everyone else's — the release-day threads are a fast way to keep up with which architecture ideas are making it into real frontier-adjacent models.

---

## [Grigory Sapunov](https://x.com/che_shr_cat)

PhD in AI, CTO and co-founder of [Intento](https://inten.to/), Google Developer Expert in ML, and author of *Deep Learning with JAX* (Manning). Best known for his long-running paper-review writing: the [Gonzo ML](https://gonzoml.substack.com/) Substack (deep, readable walkthroughs of ML research) and [arXiviq](https://arxiviq.substack.com/) (daily AI paper reviews).

Two samples of why the feed is worth following:

- [The Transformer Zoo Revisited](https://gonzoml.substack.com/p/the-transformer-zoo-revisited) — a walkthrough of a paper pitting encoder-decoder ("RedLLM") against decoder-only ("DecLLM") transformers from 150M to 8B parameters. Decoder-only wins pretraining compute-efficiency (half the FLOPs for the same perplexity), but after instruction finetuning encoder-decoder catches up and edges ahead — and dominates the quality-per-compute Pareto front at inference, with better long-context extrapolation thanks to cross-attention. A good antidote to treating decoder-only as the architectural end of history.
- [A thread on emergence](https://x.com/che_shr_cat/status/2084239996790120638) — covering mechanistic research arguing that sudden capability jumps aren't a magic byproduct of scale or a metric illusion, but a high-variance optimization search for sparse attention routing circuits.

**Why I flagged it:** most paper-summary accounts skim abstracts; Sapunov actually reads the papers and explains the mechanism, and he covers the unfashionable corners of architecture research (encoder-decoder, non-transformer designs) that release-day hype skips.

---

*More entries to come.*
