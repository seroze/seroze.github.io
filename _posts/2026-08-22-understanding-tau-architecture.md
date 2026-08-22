---
layout: post
title: "Understanding Tau's Architecture"
date: 2026-08-22 00:00:00 +0530
categories: llm
tags: [coding_agents, agents, llm, open_source, huggingface, python]
author: "Seroze"
published: true
---

Tau is a small terminal coding agent from Hugging Face, written in Python and published on PyPI as `tau-ai`. You point it at a repo, ask it to explain something or fix a stack trace, and it reads files, edits them, runs shell commands and streams what it is doing back at you. Nothing about that is novel by now — every agent does it. What makes Tau interesting is that it was written to be read.

Most coding agents you could learn from are either closed or enormous. Tau is neither. It splits into three packages that stack cleanly on top of each other: `tau_ai` turns whatever an LLM provider streams back into a provider-neutral stream of typed events, `tau_agent` is the harness that owns messages, tools, the agent loop and session state, and `tau_coding` is the actual coding environment built on top — file and shell tools, durable sessions, slash commands, and a Textual TUI. The core never learns that a terminal exists. The TUI is just one consumer of the event stream.

That layering is the part I want to work through, because it is the same decomposition you end up rediscovering if you try to build one of these yourself. Over the next few sections I'll go layer by layer and dig into how each piece works.

These are my own notes from reading the source, written as I go. Corrections welcome.

## tau_agent: messages are nouns, events are announcements

I started with `tau_agent` because it's the piece everything user-facing is built around — `tau_coding` is essentially a shell over it — and because within it there is a clear leaf to pull on. Three files sit next to each other and look confusingly similar at first: `messages.py`, `events.py`, and `provider_events.py`. All three define a pile of types, all three show up everywhere, and it isn't obvious why you need three.

The way to tell them apart is to ask what question each one answers.

`messages.py` defines `AgentMessage`, with seven roles. This is the transcript. It answers *what is in the conversation* — the durable record you'd serialise to a session file and replay later.

`events.py` defines `AgentEvent`, with ten types. This answers *what is the agent run doing right now*. It's ephemeral: a run starts, a tool gets requested, a message is appended, the run finishes. Nothing here survives past the run.

`provider_events.py` defines `AssistantMessageEvent`, with twelve types. This is one level finer still. It answers *how did a single assistant message get built, token by token* — the streaming deltas coming off the provider as the model types. Also ephemeral.

So you get a rough hierarchy of timescales:

| file | type | question | lifetime |
|---|---|---|---|
| `messages.py` | `AgentMessage` (7 roles) | what's in the transcript | durable |
| `events.py` | `AgentEvent` (10 types) | what's the run doing | ephemeral |
| `provider_events.py` | `AssistantMessageEvent` (12 types) | how is one message being assembled | ephemeral |

The detail that made it click for me was the import graph. Both event files import `messages.py`, and `messages.py` imports neither of them. Every event carries a message as its payload. That's the giveaway: messages are the nouns, and events are just wrappers announcing that something happened to a noun. Once you read it that way the duplication stops looking like duplication — there is exactly one representation of conversation content, and two different granularities of narration on top of it.
