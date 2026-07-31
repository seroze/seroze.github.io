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

## [Sarvam AI](https://www.sarvam.ai) — Applied AI Engineer, Sarvam Agents (Bengaluru, on-site)

Full-stack sovereign AI platform for India — research, models, infrastructure, applications. Backed by Lightspeed, Peak XV, Khosla. Deployed with Tata Capital, SBI Life, CRED, IDFC, LIC.

**The product** — agents that plug into an org's actual tools (email, docs, calendars, internal systems, the long tail of SaaS), take multi-step action on a user's behalf, run on a schedule when nobody is watching, and are shared across the org with scoped permissions and admin observability.

**The role** — build the agents end-to-end and own them in production:

- Flow design, prompting, tool definitions, memory, evaluation, deployment
- Agent runtime: state management, retries, scheduled triggers, long-running execution
- Connector framework: OAuth, third-party SaaS APIs
- MCP server infrastructure at scale
- Memory and context engineering — working memory vs. long-term vs. retrieval
- Multi-tenancy: permissions, audit trails, admin surfaces
- Evals — the test infra that says whether a change helped, before it reaches a user
- Tool design discipline: schemas, error messages, idempotency, retry semantics
- Streaming, cost, and latency engineering; observability for agent runs
- Prompt iteration workflows: versioning, A/B testing, safe rollback
- On the hook for incident response when it breaks

**Who they want** — 3–5 years total, 2+ in backend Python. LLM API fluency (structured outputs, function calling). Agentic frameworks (LangGraph, ADK). Production MCP servers at scale. RAG patterns — chunking, embeddings, hybrid search, reranking, vector DBs. Evals for AI systems. Cost/latency optimization. Observability (Signoz, Datadog). OAuth + SaaS integrations. Postgres/MySQL, Redis.

*Bonus:* open-source work in the agent/LLM ecosystem, eval frameworks (LangSmith, Braintrust), human-in-the-loop approval flow design.

**Why I flagged it:** this is the other half of the Emergent role. Emergent is *measure and advance the agent's capability*; this is *make agents survive contact with a real organization* — permissions, audit trails, OAuth plumbing, retries, incident response. Less glamorous, arguably the harder engineering problem, and the skill set is more transferable. Note that evals show up as a first-class requirement in both listings.

---

## [Google DeepMind](https://deepmind.google) — Research Engineer, AGI Safety and Alignment (London)

The AGI Safety and Alignment Team (ASAT) works to reduce existential and catastrophic risk from AGI and eventually ASI — researching novel techniques, applying them across GDM and Google, and advising executive leadership on safety.

**What the sub-teams do:**

- Align future Geminis — find and fix sources of misalignment, alignment techniques with better generalization
- Simulate future AGI risks today; interpretability for model forensics and eval awareness
- Agent control as defense-in-depth against misaligned internal deployments
- Training techniques like debate for aligning superhuman AI; measuring and improving monitorability
- Adversarially robust control systems, shipped to production
- AI assistance that accelerates safety research itself
- The frontier safety framework — threat models and evals feeding executive risk advice

Currently prioritising **deep alignment, alignment stress testing, language model interpretability, agent control, amplified oversight.** Hiring both Research Scientists and Software Engineers depending on background.

**Bar** — CS degree or equivalent practical experience; 3 years in software development, ML engineering, or ML research. Preferred: applied safety/alignment research on frontier systems, experience training large models (SFT, RLHF).

**Why I flagged it:** the requirements bar is startlingly low for the problem — 3 years and a bachelor's. Compare that to Emergent's 5–8. Alignment is young enough that there's no deep bench of credentialed people, so the entry point is unusually open relative to how much the work matters.

The overlap with the other two roles is also worth noting: "study the failure modes, build the evals, feed them back into training" is the same loop in all three. Here the stakes attached to that loop are just considerably higher.

---

*More entries to come.*
