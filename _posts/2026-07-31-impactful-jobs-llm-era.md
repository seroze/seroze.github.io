---
layout: post
title: "Impactful Jobs in the LLM Era"
date: 2026-07-31 00:00:00 +0530
categories: careers
tags: [careers, llm, ai_research, evaluations, jobs]
author: "Seroze"
published: true
---

*A running list of roles that look genuinely high-leverage right now — jobs where the work itself moves what the models can do, not just jobs that call an LLM API. Bookmarking these to revisit.*

---

## [Emergent](https://emergent.sh) — AI Research Engineer (Bangalore)

Autonomous coding agents that generate, test, and deploy production apps from plain-language intent. $100M ARR, 10M+ users across 190+ countries since public launch. Backed by Khosla, SoftBank, Google, Lightspeed, Prosus, Together, YC.

The problem they name is the honest one: **correctness, reliability, security, and scale** in real production systems.

**The role** — turn ambiguous notions of "agent quality" into defensible metrics, then use those metrics to drive improvements.

- Architect the next version of the agent — how it thinks, learns, and improves over time
- Design and ship evaluations across reasoning, planning, tool use, code correctness, long-horizon execution, security, reliability
- Climb public benchmarks — SWE-bench Pro, Terminal-Bench
- Run post-training experiments — SFT, RLHF/RLAIF, DPO, distillation, reward modeling, prompt optimization, judge-model calibration
- Own end-to-end: hypothesis → experiment → analysis → rollout → post-launch measurement
- Make hard calls in subjective systems — is the regression real, is the win noise, is the benchmark overfit

**Who they want** — 5–8 years AI experience, in *either* training/fine-tuning *or* evaluation design (explicitly equal paths). Python. Transformers, RLHF/DPO, eval frameworks (Inspect, lm-eval-harness), judge models, agent frameworks. Comfortable reasoning about noise floors, confounds, distribution shift, judge bias, selection effects.

**Why I flagged it:** the phrase *"treat models as objects of study rather than black boxes"* is the actual skill gap right now. Almost everyone can wire up an agent loop; very few can say with statistical honesty whether their change made it better. And treating the eval path as equal to the training path is unusual — most posts treat eval as the consolation prize, when it's currently the binding constraint on agent progress.

---

*More entries to come.*
