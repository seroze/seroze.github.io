---
layout: post
title: "Interesting Startups"
date: 2026-06-30 00:00:00 +0530
categories: startups
tags: [startups, ai, tech]
author: "Seroze"
published: true
---

*A running list of startups I find interesting — updated as I come across new ones.*

---

## [AfterQuery](https://afterquery.com/)

AfterQuery builds expert-grade evaluation data and benchmarks for frontier AI labs — measuring what models can actually do in real professional workflows rather than toy tasks. They recently helped build **SpreadsheetBench 2**, a benchmark that seeds realistic financial models (LBOs, DCFs, merger and credit models) with deliberate bugs — sign errors, unit/timing mismatches, hardcodes, broken cross-sheet references — and asks AI agents to audit and fix them, exactly what a first-year analyst would do. Frontier models still miss roughly half the required fixes (Claude Opus 4.6 corrects 50% of target cells, Gemini 3.1 Pro 42%, GPT-5.2 39%), and the scary part is they fail *quietly*, returning polished workbooks that hide errors a junior analyst would catch.

**Use case:** an investment bank or private equity firm evaluating AI copilots for its analysts can use benchmarks like SpreadsheetBench 2 to know exactly how much of a model's output still needs human review before trusting it with live deal models.

---

## [Archil](https://archil.com/)

Archil builds a distributed filesystem for AI agents — infinite storage that mounts like a local disk, with share, snapshot, and fork capabilities. Sachin Raja's article ["The 2026 AI Infra Startup Template"](https://x.com/s4chinraja/status/2076747836818104457) argues that most agent-focused infra startups (agent browsers, agent databases, orchestration layers) reduce to exactly this primitive: networked Linux applications running in sandboxes on top of a shared, forkable filesystem. He demonstrates the template with an [agent browser built on Archil](https://github.com/sachinraja/archil-browser).

**Use case:** anyone building agent infrastructure — instead of a bespoke "browser for agents" or "database for agents" product, compose a sandboxed Linux app with a distributed filesystem and get sharing, snapshotting, and forking for free.

---

## [Beluga](https://www.trybeluga.ai/team)

Beluga is building creator marketing tooling that aims to make influencer campaigns "as measurable and easy to run as paid ads" — combining campaign management with AI-driven creator matching and optimization to cut the guesswork out of picking who to work with. The founding team spent six years at Dare Drop selling, managing, and scaling creator campaigns across thousands of creators and millions in ad spend before building Beluga to systematize what they learned. Backed by Y Combinator.

**Use case:** brands and agencies running influencer campaigns who currently pick creators on gut feel — Beluga's matching and optimization layer gives them the same kind of measurability paid ads already have.

---

## [Bottlecap](https://www.bottlecapai.com/)

Bottlecap makes existing AI models more efficient rather than building new ones — fine-tuning them to cut out wasted internal reasoning while preserving capability. Their [ThinkingCap Qwen3.6-27B](https://www.bottlecapai.com/thinkingcap-qwen3-6-27b) is a fine-tune of Qwen's 27B model that uses roughly half the thinking tokens of the base version: across 12 out-of-domain benchmarks it cuts tokens by 45.8% with only a 0.7-point accuracy drop, and on in-domain knowledge tasks it cuts 57.7% of tokens while actually *gaining* 1.0 point of accuracy. Fewer tokens means lower latency, lower cost, and less reasoning stuck in loops. The model is open under Apache 2.0 on HuggingFace.

**Use case:** anyone running reasoning models at scale under a token budget — inference providers or product teams who want the same answers with half the compute bill.

---

## [Core Automation](https://www.coreauto.com/)

Core Automation is betting that the transformer architecture itself is the bottleneck to smarter, continuously-learning AI — so they're building new learning algorithms and architectures meant to outperform large-scale pretraining as we know it, starting by automating the research process itself. Co-founded by **Rohan Anil**, who led pretraining on Gemini at Google DeepMind (leaving as a Distinguished Engineer for his contributions there) before a stint at Anthropic, alongside Jerry Tworek (former OpenAI VP who led the reasoning/Strawberry and RL teams) and Joanne Jang.

**Use case:** worth watching for anyone tracking whether post-transformer architectures actually ship, given the team has firsthand experience scaling the thing they're now betting against.

---

## [exe.dev](https://exe.dev/) ([blog](https://blog.exe.dev/))

exe.dev (from Bold Software) provisions Linux micro-VMs over SSH — Sandbox (disposable, for AI agents), VPS (persistent), and Devbox (cloud dev environments), each reachable at `<vm>.exe.xyz` with automatic TLS. Using Kata Containers + Cloud Hypervisor gets them sub-second container-like start times while keeping real kernel isolation and a persistent disk — root access, `apt`, `systemd`, the works. $35M Series A backed by Amplify Partners, CRV, and HeavyBit.

Their engineering blog is what makes them worth flagging: real systems-level problems written up in public — sharing IPs across VMs without breaking SSH ("SSH Has No Host Header"), shipping features without dropping live network connections, proxying secrets for third-party integrations safely, and the economics of LLM agent inference cost at scale.

**Use case:** worth watching for the infra work alone — and a promising place to work if you like virtualization, networking, and distributed-systems problems that show up the moment "give an AI agent its own computer" has to work at scale.

---

## [Flapping Airplanes](https://flappingairplanes.com/)

*(description coming soon)*

---

## [General Intuition](https://www.generalintuition.com/)

General Intuition is a frontier AI lab building models that can perceive, predict, and act in virtual and physical environments — moving AI beyond language toward genuine spatial and temporal reasoning. Their models train on billions of action-labeled gameplay clips sourced from Medal, the gaming platform they spun out of, giving the AI a rich diet of intent, action, and consequence across countless 3D environments. The long-term bet: world models general enough to transfer from games into robotics, drones, and autonomous systems.

---

## [Standard Intelligence](https://si.inc/)

Standard Intelligence is building general-purpose AI models focused on autonomous action and perception — systems that explore and learn like humans do. Their work spans computer vision capable of navigating websites and physical environments, as well as conversational AI for natural speech. They're targeting enterprises and developers who need AI that can handle complex, multi-step tasks rather than narrow single-purpose models.

---

# Startups I think won't work

*And why — I could be wrong, but noting my reasoning so I can check back later.*

## [TalentPluto](https://talentpluto.com/companies?selected-company=hdixqO0v9)

TalentPluto is an AI recruiter that makes "warm intros" between companies and candidates. The catch: candidates onboard by describing themselves to an AI voice agent that "learns your story in 10 minutes."

**Why I'm skeptical:** making candidates narrate their own background over voice adds a lot of friction — everyone already has a resume that captures this. The better flow would be the inverse: upload your resume first, then converse with the voice agent for suggestions and to fill in the gaps.
