---
layout: post
title: "[Careers] Attributes of an Agentic AI Engineer"
date: 2026-09-14 00:00:00 +0530
categories: careers
tags: [agents, ai_engineering, career, open_source, distributed_systems, mcp, vector_databases]
author: "Seroze"
published: true
---

I read an "Agentic AI Engineer" posting recently and it stuck with me, because the list of
requirements looked like three different jobs stapled together. Agent frameworks and LLM
APIs on one line, Kubernetes and CI/CD on the next, distributed systems and idempotent
webhooks after that, and somewhere at the bottom, a customer-facing widget. The obvious
reaction is that they want too much. The more useful reaction is to notice that this is
what an agent product actually consists of, and the posting is just being honest about it.

This post is my attempt to write down what that role really demands, and what I'd build
toward if I were aiming at it.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## What the posting is actually asking for

Strip the buzzwords and the requirements collapse into four groups.

An **agent layer**: tool calling, state machines, checkpointing, streaming,
human-in-the-loop, multi-agent coordination, and the Model Context Protocol as the wiring
between them. A **retrieval layer**: a vector database with real schema design and hybrid
retrieval, plus knowledge graphs for the relationships that embeddings are bad at. A
**platform layer**: REST APIs, async processing, queues, Docker, Kubernetes, CI/CD,
observability. And a **product layer**: the surface a customer actually touches.

Then there's the mindset section, which is the part worth reading twice. It asks for
someone who reads code faster than docs, designs for failure — idempotent webhooks,
retried queue jobs, circuit breakers, guardrails on every prompt — and owns the thing when
it breaks. None of that is AI-specific. That's a description of a good backend engineer who
happens to be pointing their skills at agents.

That's the whole insight, really. The scarce thing isn't LangGraph knowledge. It's
engineers who can make a non-deterministic, network-bound, partially-failing system behave
well enough to put in front of paying customers.

```
                    AGENTIC AI ENGINEER
                           │
          ┌────────────────┼────────────────┐
          │                │                │
      AI / LLMs      Systems / Backend     Infra
          │                │                │
     Tool calling      Async systems      Docker
     RAG               Queues             Kubernetes
     Agents            APIs               CI/CD
     MCP               State machines     Observability
     Evals             Reliability        Distributed systems
```

## Start with backend systems, not with LangChain

The instinct is to open the agent framework docs first. I think that's backwards, and it's
the single most common way these portfolios go wrong.

An agent is a program that calls slow, unreliable, expensive remote services in a loop,
sometimes for minutes at a time, and occasionally crashes halfway through. Every hard
problem in that sentence is a backend problem. If you don't already have good instincts for
queues, retries and idempotency, the framework will hide the problem from you right up
until it appears in production.

So the first thing to be able to build, without help, is this:

```
                 HTTP
                  │
                  ▼
             API Server
                  │
           ┌──────┴──────┐
           │             │
        Postgres       Redis
           │             │
           └──────┬──────┘
                  │
              Job Queue
                  │
          ┌───────┴────────┐
          │                │
       Worker 1         Worker 2
          │                │
       External APIs / LLM providers
```

Not read about — build, deploy, and then break on purpose.

The backend vocabulary that matters here is HTTP and REST, authentication, async
programming, WebSockets and SSE for streaming, database transactions, Postgres, Redis,
queues, retries, idempotency, rate limiting, caching and connection pooling. On the
distributed systems side you don't need to become a researcher, but you do need working
intuitions about at-least-once delivery, why exactly-once is mostly a myth, backpressure,
timeouts, exponential backoff, circuit breakers, eventual consistency, race conditions and
failure domains.

Of that list, idempotency and retry semantics are disproportionately important for agent
work, because agents retry constantly and every retry is a chance to do something twice.

Here's the kind of thing I mean. Look at this webhook handler:

```python
def process_webhook(event):
    if already_processed(event.id):
        return

    db.begin()
    store_event(event)
    enqueue_job(event)
    db.commit()
```

The question you should be asking before you finish reading it is: what happens if the
process dies between `enqueue_job()` and `commit()`? The job is now in the queue, the event
isn't in the database, and a worker is about to pick up something that officially never
happened. Whether you reach for a transactional outbox, or make the job handler tolerate a
missing event, matters less than the fact that the question occurred to you at all.

That reflex is exactly what the "designs for failure" line in the posting is fishing for.

## Learn the LLM primitives before the frameworks

Once the backend instincts are there, go one level below the agent libraries.

Don't start at `create_react_agent(...)`. Start by writing the provider integrations
yourself — OpenAI, Anthropic, Gemini — and handling streaming, structured output, tool
calling, token limits, rate limits, model fallbacks, context management and prompt
versioning by hand. It's a few weekends of unglamorous work and it permanently demystifies
everything built on top.

The mental model you're after is small:

```
                  LLM
                   │
            ┌──────┴───────┐
            │              │
          Input          Output
            │              │
            ▼              ▼
        Messages       Tool calls
                           │
                           ▼
                       Tool router
                           │
                  ┌────────┼────────┐
                  ▼        ▼        ▼
                 DB       API      Search
```

Then build the thinnest possible abstraction over the providers, and on top of that, an
agent that is nothing but state, messages, tools, a model, memory and an execution loop.
When you've written that loop once, the frameworks stop being magic and become a set of
design decisions you can evaluate — which is the position you want to be in during an
interview.

## Understand agent runtimes from the inside

Now learn LangGraph, or whichever runtime the target company uses — but learn it as an
architecture, not as an API surface.

The core of it is a graph over a state object, where each node can call tools, the state is
checkpointed between steps, and execution can pause for a human and resume later.

```
             ┌──────────────┐
             │    State     │
             └──────┬───────┘
                    │
                    ▼
             ┌──────────────┐
             │    Agent     │
             └──────┬───────┘
                    │
              ┌─────┴─────┐
              │           │
           Tool?        Answer?
              │
              ▼
         Tool execution
              │
              ▼
          State update
              │
              └───────► Agent
```

The best way I know to actually understand that is to implement a small one. Start with a
plain LLM → tool → LLM → answer loop, then add graph execution, then checkpointing, then
streaming, then human approval, then parallel tool calls, then retries and timeouts, then
multi-agent orchestration. Each step is a real design problem — especially checkpointing,
which forces you to decide what "resumable" means when half your state lives in an external
API's side effects.

This is also the one place where language choice earns its keep. A runtime, a scheduler and
an execution engine are exactly the kind of components where a systems language like Rust
pays off, and building the core there rather than in Python makes for a much less
interchangeable profile. It's an implementation advantage, though, not the story itself —
the story is still "I can build reliable agentic systems end to end."

## MCP and knowledge systems

This is where you start matching that posting almost line by line.

**MCP.** Don't just consume MCP servers — write one. Implement tools, resources, schemas,
error handling, authentication and streaming where it applies. Once you've shipped a server
and a client, the protocol stops being a checkbox on a JD and becomes something you have
opinions about.

**Knowledge graphs.** Embeddings are good at "what is this about" and bad at "who reports
to whom". A property graph handles the second kind of question directly:

```
 Person ──WORKS_AT──> Company
   │                     │
 KNOWS                 OWNS
   │                     │
   ▼                     ▼
 Person                Project
```

The interesting system is the hybrid one, where a question fans out to both retrieval
styles and the results are merged into a single context:

```
              User question
                    │
              ┌─────┴─────┐
              │           │
           Vector       Graph
           Search       Search
              │           │
              └─────┬─────┘
                    ▼
                 Context
                    │
                    ▼
                   LLM
```

On the vector side, pick one database and go deep rather than sampling four. Understand
collections, payloads, indexes and filtering; then dense versus sparse retrieval, metadata
filtering, reranking, and what idempotent upsert actually requires when your ingestion
pipeline runs twice. Knowing HNSW well enough to reason about recall-versus-latency
tradeoffs is worth more than having tried every managed vendor.

## The production engineering that portfolios skip

Most AI portfolios stop at "it works on my machine with a good prompt". The posting is
explicitly asking about the other half.

A useful exercise: take your agent and make it survive an LLM timeout, an API timeout, a
worker crash mid-run, a duplicate job, a network partition, a tool that returns garbage, a
model that emits invalid JSON, a rate limit, a partially completed execution, and a deploy
in the middle of all of it.

The shape of a system that can do that looks like:

```
                        ┌─────────────┐
                        │   Browser   │
                        └──────┬──────┘
                               │
                               ▼
                         API Gateway
                               │
                       ┌───────┴───────┐
                       │               │
                       ▼               ▼
                  Agent API       WebSocket / SSE
                       │
                       ▼
                 Agent Runtime
                       │
             ┌─────────┼─────────┐
             │         │         │
             ▼         ▼         ▼
          Postgres   Redis    Vector DB
             │
             ▼
          Job Queue
             │
        ┌────┴────┐
        ▼         ▼
     Worker 1  Worker 2
        │         │
        └────┬────┘
             │
       External APIs
             │
             ▼
        LLM Providers

        ┌──────────────────┐
        │  Observability   │
        │  OpenTelemetry   │
        │  Langfuse        │
        └──────────────────┘
```

Containerize it, deploy it, instrument it, then break it deliberately and fix what broke.
A trace of a failed run that you diagnosed and a postmortem you wrote are stronger evidence
than another demo video.

## Open source: three ecosystems, not twenty

Scattering small PRs across twenty AI repositories reads as noise. Picking three ecosystems
and going deep reads as a specialist.

The three I'd choose map directly onto the job: an **agent orchestration** project
(LangChain / LangGraph or a comparable runtime), the **MCP** ecosystem, and one **vector
database**. Observability tooling is a reasonable fourth if you find yourself drawn to it.

Within each, the ladder is the same:

```
use it
  ↓
read the source
  ↓
fix documentation
  ↓
fix small bugs
  ↓
add tests
  ↓
implement a feature
  ↓
own a subsystem
```

The goal isn't "I have a merged PR in LangGraph." The goal is being able to say you
understand agent state, checkpointing and execution well enough to have changed the runtime
— and then owning something small but real, like checkpoint recovery, streaming execution,
or an integration nobody else maintains.

Contributing at that level also does something a portfolio can't: it puts you in
conversation with maintainers, who are generally the people hiring for exactly these roles.
That's the difference between open source as career evidence and open source as green
squares.

## Build one serious system, not ten small ones

Ten small projects look like a tutorial history. One system that genuinely runs looks like
engineering.

If I were building the portfolio piece for this role, it would be a production-oriented
agent platform — a runtime with graph execution, state, checkpointing, streaming, tool
calling, retries, timeouts and human approval; memory across Postgres, a vector store and a
graph database; an MCP client and server; Docker, Kubernetes and CI/CD around it;
OpenTelemetry and Langfuse through it.

```
                    Agent Platform
                          │
       ┌──────────────────┼──────────────────┐
       │                  │                  │
     Runtime            Tools              Memory
       │                  │                  │
       │           ┌──────┼──────┐      ┌────┴────┐
       │           │      │      │      │         │
     Graph        MCP    REST    DB   Vector    Graph
       │
 ┌─────┼──────────┐
 │     │          │
State Checkpoint Streaming
 │
 └──────────────┐
                ▼
           PostgreSQL
```

The API surface is small and tells the whole story:

```
POST /agents
POST /runs
GET  /runs/:id
POST /runs/:id/approve
GET  /runs/:id/events
```

And it needs a front end — not a polished product, just enough React to watch a run
happen, see the tool calls stream in, and click approve when the agent pauses:

```
┌─────────────────────────────────────┐
│ Agent: Research Agent               │
├─────────────────────────────────────┤
│                                     │
│ Thinking...                         │
│                                     │
│ ├─ Search web                       │
│ ├─ Query database                   │
│ ├─ Analyze results                  │
│ └─ Waiting for approval             │
│                                     │
│              [Approve] [Reject]     │
└─────────────────────────────────────┘
```

That `/runs/:id/approve` endpoint and that approve button are worth more than they look.
Human-in-the-loop is on nearly every agent job description, and almost nobody's side
project actually implements resumable, approvable runs.

## The skill checklist

Roughly the depth I'd aim for in each area:

| Area | Target |
|---|---|
| Python | Advanced |
| Rust | Advanced |
| TypeScript | Comfortable |
| PostgreSQL | Strong |
| Redis | Strong |
| Docker | Strong |
| Kubernetes | Intermediate / Strong |
| REST | Strong |
| Async systems | Strong |
| Distributed systems | Strong |
| LLM APIs | Strong |
| Tool calling | Strong |
| Agent runtimes | Strong |
| RAG | Strong |
| Vector databases | Strong |
| Knowledge graphs | Intermediate |
| MCP | Strong |
| OpenTelemetry | Intermediate |
| Langfuse | Intermediate |
| React | Comfortable |
| CI/CD | Strong |

Note what isn't there: you don't need to be a frontend specialist. You need enough React and
TypeScript to ship the surface a customer touches, and no more.

## The thing I'd avoid

The failure mode is the tutorial treadmill:

```
Python → LangChain tutorial → RAG tutorial → LangGraph tutorial
       → multi-agent tutorial → another RAG tutorial
```

Every step feels productive and the result is a GitHub profile identical to thousands of
others, because the tutorials are identical too. Nothing in it answers the question the
hiring manager is actually asking, which is whether you can keep a non-deterministic system
running in production.

The order that does answer it runs the other way:

```
Distributed systems → LLM primitives → agent runtime internals
                    → MCP → retrieval → production infrastructure
                    → open source → real users
```

Same technologies, opposite direction. One of them produces someone who can use agent
frameworks; the other produces someone who could have written one.

## What the end state looks like

If the trajectory works, the profile reads something like this:

- **An agent runtime you built** — graph-based execution with tool calling, streaming,
  checkpointing, retries and human-in-the-loop, and the war stories from running it.
- **MCP** — clients and servers implemented, plus upstream contributions to the ecosystem.
- **Retrieval** — hybrid dense/sparse search with metadata filtering, idempotent ingestion
  and reranking, in one vector database you know properly.
- **Distributed systems** — async workers, retry policies, idempotent jobs, circuit
  breakers and failure recovery, in something that actually took traffic.
- **Infrastructure** — Docker, Kubernetes, CI/CD, OpenTelemetry, Langfuse.
- **Open source** — a handful of substantial contributions concentrated in two or three
  ecosystems, rather than scattered across twenty.

None of that is exotic. It's just the honest version of the job description, built in the
right order — backend fundamentals first, LLM primitives second, frameworks third, and
production reality running through all of it.
