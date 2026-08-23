---
layout: post
title: "People to follow in LLM architecture research"
date: 2026-08-03 00:00:00 +0530
categories: llm
tags: [llm, llm_architecture_research, twitter, ai_research]
author: "Seroze"
published: true
---

*A running list of people to follow for LLM architecture, pretraining, and post-training research — added as I come across their work. I've split it three ways: **creators** who propose the ideas, **implementors** who make them run fast enough to matter, and **explainers** who actually read the papers and write up the mechanism.*

---

## Creators

### [Muyu He](https://x.com/HeMuyu0327)

Research Scientist at [Zyphra](https://www.zyphra.com/) (June 2026–present), previously at [Collinear AI](https://www.collinear.ai/) (Jul 2025–Jun 2026). MS in CS from UPenn (2023–2025), previously a researcher across PennNLP, Penn Medicine, and Drexel. Was lead author on the TraitBasis paper ["Impatient Users Confuse AI Agents"](https://blog.collinear.ai/p/trait-basis) (ACL 2026 Oral), which builds high-fidelity simulations of human traits for testing AI agents, and first author on ["Do Value Vectors in Deep Layers Need Context from the Residual Stream?"](https://github.com/RiddleHe/nanochat/blob/master/papers/bank_of_values.pdf) (EMNLP 2026, under review) — proposes "Bank of Values," an attention variant that replaces value vectors in the last third of layers with a learned per-layer table, eliminating the V cache entirely and beating standard attention on validation loss and 21 benchmarks across two model sizes.

On X he posts hands-on architecture experiments — e.g. training a load-balanced "Attention Residual" variant end-to-end from pretraining through SFT (broke the nanochat validation-loss record, but turned out "amusingly bad" downstream) — and interpretability work on *when* and *at which layer* transformers actually pull in far-away context, plus jailbreak/alignment probing on `gpt-oss-20b`. Open-source work backs this up: [nanochat](https://github.com/RiddleHe/nanochat) (hackable pretraining stack with FLOP-controlled ablations), [llm-interp](https://github.com/RiddleHe/llm-interp) (reproducible interpretability scripts, including findings on attention sinks in Qwen3), and [gpt-oss-alignment](https://github.com/RiddleHe/gpt-oss-alignment) (the chat-template jailbreak plus a sparse-autoencoder training framework).

**Why I flagged it:** the account is a good feed for people who actually run the pretrain → SFT loop on novel architecture ideas and report the failures honestly, not just the wins.

---

### [Yuchen Liu](https://x.com/YuchenL52766559)

Search/AI infrastructure engineer at DoorDash (Seattle, Aug 2025–present) working on streaming indexing and Lucene-native hybrid retrieval — and, on the side, a frequent collaborator of Muyu He (above): co-author on the ["Do Value Vectors in Deep Layers Need Context from the Residual Stream?"](https://github.com/RiddleHe/nanochat/blob/master/papers/bank_of_values.pdf) paper (EMNLP 2026, under review) and a contributor to the nanochat and llm-interp stacks. Also builds [nanoRL](https://github.com/Upcccccc), an open-source RL training framework with vLLM integration. Posts under the display name "Wuxxcc"; his site is [upcccccc.github.io](https://upcccccc.github.io).

The tweet that got him on this list: [a thread asking *when* a transformer actually reads faraway context](https://x.com/YuchenL52766559/status/2080162233275871656) — not whether it can, but at which layer the information gets pulled into the computation. Using hidden-state swap interventions on Qwen3-8B, they show nearby entities are read around layers 24–26 while entities 100+ tokens away aren't fully read until layers 31–34, with a neat sanity check: on a model with mostly sliding-window attention, the curves drop sharply at exactly the global-attention layers — the experiment recovered the architecture blind. They then trained models from scratch to confirm the corollary: moving global-attention layers earlier hurts at equal FLOPs.

**Why I flagged it:** the thread is a model example of interpretability done with the scientific loop closed — a clean intervention, a falsifiable architectural prediction, and a from-scratch training run to test it.

---

### [Elie Bakouch](https://x.com/eliebakouch)

Pretraining researcher at [Hugging Face](https://huggingface.co/eliebak) and one of the core people behind the SmolLM family — co-author of [SmolLM2](https://arxiv.org/abs/2502.02737) (data-centric training of small LMs) and [SmolLM3](https://huggingface.co/blog/smollm3) (a 3B multilingual long-context reasoner trained on 11T tokens). Co-authored [The Smol Training Playbook](https://huggingface.co/spaces/HuggingFaceTB/smol-training-playbook) (Oct 2025), Hugging Face's long-form writeup of the messy reality of training a state-of-the-art model end to end — ablations, bugs, and all. Has also contributed to open-training efforts like INTELLECT-1 and The Common Pile v0.1.

On X he's one of the best feeds for open-weight release breakdowns: when a new model drops, he reads the tech report and surfaces the architecture bets that actually matter. Example: [his thread on Motif's release](https://x.com/eliebakouch/status/2079364961353028078) — a Korean lab shipping a 314B-total / 13B-active MoE that performs on par with much bigger models like MiniMax M3 and DeepSeek v4 Pro, notable for baking the lab's own research bets into production (per-expert activation functions with PolyNorm, among others).

**Why I flagged it:** he sits at the intersection of doing pretraining (SmolLM) and explaining everyone else's — the release-day threads are a fast way to keep up with which architecture ideas are making it into real frontier-adjacent models.

---

### [Kaiyue Wen](https://github.com/WhenWen)

Second-year PhD student at Stanford, advised by Tengyu Ma and Percy Liang (below); before that, Tsinghua's Yao class. Site at [whenwen.github.io](https://whenwen.github.io/). He's the one person on this list who doesn't really post on X — you follow him through arXiv and GitHub instead — but the work is too directly about *"which architecture and optimizer choices actually hold up"* to leave out.

His best-known paper is ["Fantastic Pretraining Optimizers and Where to Find Them"](https://arxiv.org/abs/2509.02046) (ICLR 2025, with David Hall, Tengyu Ma and Percy Liang), which takes the standing claim that new optimizers give 1.4–2× speedups over AdamW and shows most of it evaporates under fair comparison. Two methodological sins do the damage: tuning hyperparameters for the baseline and reusing them for the challenger, and reading off the winner mid-run instead of at the end. Once you fix both, matrix-based optimizers like Muon and Soap are still the fastest — but the edge decays from roughly 1.4× at 0.1B parameters to about 1.1× at 1.2B, which is exactly the direction you don't want if you're planning to scale.

The follow-up, ["Fantastic Pretraining Optimizers and Where to Find Them II: Hyperball Optimization"](https://arxiv.org/abs/2606.16899) (June 2026), goes after the cause rather than just reporting it, arguing that standard constant decoupled weight decay is what makes the gains shrink, because of how it controls the *angular* learning rate of a weight matrix. Hyperball instead pins the Frobenius norms of the weight matrices and their updates to fixed constants; Muon plus Hyperball buys 20–30% token-equivalent speedup over the weight-decay baseline on Qwen3-style models up to 1.2B, with cleaner hyperparameter transfer as a bonus. Earlier work in the same spirit: ["Understanding Warmup-Stable-Decay Learning Rates: A River Valley Loss Landscape Perspective"](https://whenwen.github.io/publications/) (ICLR 2024) and "Gated Attention for Large Language Models" (NeurIPS 2025 Best Paper). He also contributes to [marin](https://github.com/marin-community/marin) and [levanter](https://github.com/stanford-crfm/levanter).

**Why I flagged it:** almost everyone publishing an optimizer or an attention variant claims a speedup. Kaiyue Wen is one of the few people spending his time on whether those numbers survive being tuned properly and measured at the end of training — and that's the paper you want to have read before you burn a training run on someone's plot.

---

### [Percy Liang](https://x.com/percyliang)

Professor of CS at Stanford, director of the [Center for Research on Foundation Models](https://crfm.stanford.edu/), co-founder of Together AI, and — as far as this list is concerned — the person behind [Marin](https://marin.community/). His fingerprints are on a lot of the field's furniture already: SQuAD, HELM, prefix tuning, generative agents, and the term "foundation models" itself.

Marin is the interesting part. It's an attempt at what he calls *open development*: not just dropping weights at the end, but running the whole lab in public. Experiments are preregistered, every run is visible while it's training, and anyone can propose an idea, review someone else's, or send a PR that actually gets executed — model development structured like an open-source project instead of a paper with an artifact attached. It's a real answer to the reproducibility complaint rather than a gesture at one, and it's backed by [Open Athena](https://openathena.ai/), a nonprofit that supplies academic labs with the engineering and compute they otherwise can't get.

It also produces models. [Marin 32B Base ("mantis")](https://x.com/percyliang/status/1983561556127567911) beat OLMo 2 32B Base on 14 of 19 benchmarks in October 2025, landing within reach of Gemma 3 27B PT and Qwen 2.5 32B Base, all Apache 2.0.

**Why I flagged it:** his X feed is essentially a live commentary track on a frontier-ish training run — what's being tried, what broke, what the ablation said — which is the thing tech reports systematically leave out. And once you notice that Kaiyue Wen and Larry Dial both work on Marin, a good chunk of this list turns out to be the same project seen from three different seats.

---

## Implementors

### [Larry Dial](https://x.com/classiclarryd)

Engineer at [Open Athena](https://openathena.ai/) working on Marin. MS in CS (ML specialization) from Georgia Tech, undergrad in chemical engineering at Texas A&M, and a previous life at AWS Infrastructure Science, Amazon Games and ExxonMobil. Also, and this is relevant rather than trivia, a serious competitive gamer — $5k in StarCraft II tournament winnings and a rank-1 2v2 ladder finish across NA and EU. The same instinct shows up in his ML work: he holds multiple world records in the [modded-nanogpt](https://github.com/KellerJordan/modded-nanogpt) speedrun, where the whole task is training a 124M-parameter model to 3.28 validation loss on FineWeb in as little wall-clock time as possible on an 8×H100 box.

That competition is why he belongs in this section rather than the previous one. A speedrun record is architecture research with the escape hatches removed — no "we leave scaling to future work," just a number in seconds that either went down or didn't. Two of his:

- [Paired Head Attention](https://github.com/KellerJordan/modded-nanogpt/pull/191) (−3.5s, 112.3s → 109.2s) interleaves the key, query and value tensors from *pairs* of heads into longer sequences, so a query sees multiple representations of every position and puts multiple logits for the same position into one softmax.
- [Bigram Hash Embedding](https://github.com/KellerJordan/modded-nanogpt/pull/201) (−5.6s, 104.9s → 99.3s, 165 fewer steps) hashes each adjacent token pair — `(r1 * cur) XOR (r2 * prev)` mod vocab size — into a supplementary embedding table and adds it straight into the residual stream with a learnable per-layer lambda. It's an old idea (Svenstrup et al.'s 2017 hash embeddings) crossed with a new one (DeepSeek's Engram). He tried trigrams and fancier hash functions and several ways of mixing it in; plain addition to the residual stream won by a decent margin, and collisions turn out to be rare enough not to matter because real token distributions are so skewed.

He writes too. ["The Curious Case of the bos_token"](https://www.lesswrong.com/posts/tr3DrQiuyxkDpPqx2/the-curious-case-of-the-bos-token) argues that attention has no clean way to express a contextual no-op, so the BOS token gets quietly conscripted into that job — forced to serve as an attention sink using the same weights the model uses for ordinary language. His proposed fix is a learnable `bos_override` parameter per block that simply replaces the residual stream at the BOS position after the MLP, giving the sink its own machinery instead of making it share.

**Why I flagged it:** this is the implementor's view of architecture research, and it's a useful corrective. The literature is full of variants that win on a loss curve; the speedrun asks whether the idea survives contact with a kernel, a memory bus, and a stopwatch. Reading his PRs is a fast way to learn which clever ideas are actually cheap.

---

## Explainers

### [Grigory Sapunov](https://x.com/che_shr_cat)

PhD in AI, CTO and co-founder of [Intento](https://inten.to/), Google Developer Expert in ML, and author of *Deep Learning with JAX* (Manning). Best known for his long-running paper-review writing: the [Gonzo ML](https://gonzoml.substack.com/) Substack (deep, readable walkthroughs of ML research) and [arXiviq](https://arxiviq.substack.com/) (daily AI paper reviews).

Two samples of why the feed is worth following:

- [The Transformer Zoo Revisited](https://gonzoml.substack.com/p/the-transformer-zoo-revisited) — a walkthrough of a paper pitting encoder-decoder ("RedLLM") against decoder-only ("DecLLM") transformers from 150M to 8B parameters. Decoder-only wins pretraining compute-efficiency (half the FLOPs for the same perplexity), but after instruction finetuning encoder-decoder catches up and edges ahead — and dominates the quality-per-compute Pareto front at inference, with better long-context extrapolation thanks to cross-attention. A good antidote to treating decoder-only as the architectural end of history.
- [A thread on emergence](https://x.com/che_shr_cat/status/2084239996790120638) — covering mechanistic research arguing that sudden capability jumps aren't a magic byproduct of scale or a metric illusion, but a high-variance optimization search for sparse attention routing circuits.

**Why I flagged it:** most paper-summary accounts skim abstracts; Sapunov actually reads the papers and explains the mechanism, and he covers the unfashionable corners of architecture research (encoder-decoder, non-transformer designs) that release-day hype skips.

---

*More entries to come.*
