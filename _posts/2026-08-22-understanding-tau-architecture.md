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

## First, build the toy version

I couldn't read tau's class list cold and get anything out of it. `AgentMessage`, `AgentEvent`, `AssistantMessageEvent`, `AgentHarness`, `CodingSession` — the names are fine, but a name only means something once you've felt the absence of the thing it names. So before going further I wrote the smallest agent that actually talks to a model, and read tau afterwards as *that, plus everything I skipped*.

Here's the whole thing. It runs against a local Ollama, so no API key and nothing to sign up for.

```python
from dataclasses import dataclass
from typing import Literal, Any

from abc import ABC, abstractmethod
import httpx
import asyncio

try:
    import readline  # noqa: F401  -- line editing + history for input()
except ImportError:
    pass

Role = Literal["system", "user", "assistant", "tool"]

"""
Agent
  │
┌────────────┼────────────┐
│            │            │
Conversation   LLMProvider   ToolRegistry
│            │            │
│            │       WeatherTool
│            │       SearchTool
│            │       BashTool
│            │
│      OllamaProvider
│      OpenAIProvider
│
├── UserMessage
├── AssistantMessage
├── SystemMessage
└── ToolMessage

"""

@dataclass(slots=True)
class Message(ABC):
    content: str

    @property
    @abstractmethod
    def role(self) -> Role:
        ...

    @abstractmethod
    def to_dict(self) -> dict[str, Any]:
        ...


@dataclass
class UserMessage(Message):

    # content: str

    @property
    def role(self) -> Role:
        return "user"

    def to_dict(self) -> dict[str, Any]:
        return {
            "role": "user",
            "content": self.content,
        }

@dataclass
class AssistantMessage(Message):

    # content: str

    @property
    def role(self) -> Role:
        return "assistant"

    def to_dict(self):
        return {
            "role": "assistant",
            "content": self.content,
        }


@dataclass(slots = True)
class SystemMessage(Message):
    # content: str

    @property
    def role(self) -> Role:
        return "system"

    def to_dict(self):
        return {
            "role": "system",
            "content": self.content,
        }

@dataclass(slots = True)
class ToolCall:
    """
        A ToolCall is not a Message.
        It's something inside an AssistantMessage.
    """
    content: str
    name: str
    arguments: dict[str, Any]
    tool_call_id: str # additional variables

    @property
    def role(self) -> Role:
        return "tool"

    def to_dict(self):
        return {
            "role": "tool",
            "content": self.content,
        }

class Tool(ABC):

    @property
    @abstractmethod
    def name(self):
        ...

    async def execute(
        self,
        arguments: dict[str, Any],
    ) -> str:
        ...


class WeatherTool(Tool):

    @property
    def name(self) -> str:
        return "weather"

    async def execute(
        self,
        arguments,
    ):
        ...


class ToolRegistry:

    def __init__(self):
        self._tools = {}

    def register(self, tool: Tool):
        self._tools[tool.name] = tool

    def get(self, name):
        return self._tools[name]

    # Now the agent simply asks
    # tool = registry.get(call.name)


class Conversation:

    """

    conversation.add(UserMessage("Hello"))
    conversation.add(AssistantMessage("Hi"))

    """

    def __init__(self):
        self._messages: list[Message] = []

    def add(self, message: Message):
        self._messages.append(message)

    @property
    def messages(self):
        return self._messages
        # return tuple(self._messages)

    def to_dict(self):
        return [
            m.to_dict() for m in self._messages
        ]


    def serialize(self):

        return [
            m.to_dict()
            for m in self._messages
        ]

class LLMProvider:
    async def generate(
        self,
        messages: list[Message]
    ) -> Message:
        ...

class OllamaProvider(LLMProvider):

    def __init__(self):

        self.base_url="http://localhost:11434/v1"
        self.api_key="ollama"

        self.client = httpx.AsyncClient(
            base_url = self.base_url,
            # api_key = self.api_key,
            timeout = 300,
        )


    async def generate(
        self,
        messages: list[Message]
    ) -> Message:

        payload = {
            "model" : "gpt-oss:20b",
            "messages" : [m.to_dict() for m in messages],
            "stream": False,
        }
        resp = await self.client.post(
            "/chat/completions",
            json = payload,
        )

        resp.raise_for_status()

        data = resp.json()

        return AssistantMessage(
            content = data["choices"][0]["message"]["content"],
        )

    async def aclose(self) -> None:
        await self.client.aclose()

class Agent:

    def __init__(
        self,
        provider: LLMProvider,
    ):
        self.provider = provider
        # self.history: list[Message] = []
        self.conversation = Conversation()

    async def chat(
        self,
        prompt: str
    ) -> str:

        self.conversation.add(
            UserMessage(prompt)
        )

        reply = await self.provider.generate(
            self.conversation.messages,
        )

        self.conversation.add(reply)

        return reply.content


async def repl(agent: Agent) -> None:

    """
    Read a prompt, send it through the agent, print the reply, repeat.
    /exit, /quit, Ctrl-D or Ctrl-C ends the session.
    """

    print('mini-agent ready. "/exit" or Ctrl-D to quit.')

    while True:

        try:
            # input() blocks, so keep it off the event loop
            prompt = await asyncio.to_thread(input, "\nyou> ")
        except (EOFError, KeyboardInterrupt):
            print()
            break

        prompt = prompt.strip()

        if not prompt:
            continue

        if prompt in {"/exit", "/quit"}:
            break

        try:
            reply = await agent.chat(prompt)
        except httpx.HTTPError as exc:
            # a dead ollama shouldn't kill the whole session
            print(f"\n[error] {exc}")
            continue

        print(f"\nagent> {reply}")


async def main() -> None:

    provider = OllamaProvider()
    agent = Agent(provider)

    try:
        await repl(agent)
    finally:
        await provider.aclose()


if __name__ == "__main__":
    asyncio.run(main())
```

That's a working chat agent. `Message` and its four subclasses are the vocabulary, `Conversation` owns the transcript, `LLMProvider` is the seam that lets Ollama be swapped for OpenAI without anything above it noticing, `Tool` and `ToolRegistry` are the beginnings of letting the model act, and `Agent.chat` is the whole brain: append the user's message, send the transcript, append the reply, return it.

Two things about it are worth staring at, because both are exactly where tau grows.

The first is that `Agent.chat` isn't a loop. It sends once and returns once. The moment you wire `ToolRegistry` into it, it has to become a loop — call the model, see whether the reply contains tool calls, run them, append the results as tool messages, call the model again, and keep going until it stops asking for tools. That loop is the actual definition of an agent, and everything tau calls a *harness* is that loop plus the bookkeeping it needs.

The second is that `provider.generate` returns a finished `AssistantMessage`. It waits for the whole response, then hands you the completed object. That's fine for a toy and unacceptable for anything you sit in front of, because you want to watch the model type. The instant you switch it to streaming, one return value becomes a sequence of partial things arriving over time — and you need names for those partial things. That's where tau's event types come from.

Hold onto that. `Message` here is `AgentMessage` there. The two event types tau has and this file doesn't are precisely the two things this file gave up: narration of the loop, and narration of a message being assembled.

One more thing about the tool half of that loop, since it's the part people
get wrong when they first build it. Every request carries the full schema of
every registered tool — not a handle, not a diff against last turn, the whole
`ToolRegistry` serialised out again, on turn one and on turn forty. The
provider keeps no memory of what you sent last time, so the request is the
entire state.

That sounds wasteful and mostly isn't. A tool schema is a name, a sentence of
description, and a small JSON Schema for its arguments — call it a hundred to a
few hundred tokens each. A dozen tools is a couple of thousand tokens of
overhead per request, which is real but small next to the transcript and tiny
next to the file contents a coding agent ends up pasting in. You pay it every
turn and barely notice.

What keeps it cheap is where you put it. The tool schemas go at the very front
of the request, ahead of anything that varies, because prefix caching matches
on exact prefixes: the provider reuses whatever leading bytes it has already
seen, and the first byte that differs invalidates everything after it. Tools
are the most stable thing in the whole payload, so leading with them means that
block is cached once and read back at a fraction of the cost for the rest of
the session. Put them after something that changes and you've given that up for
nothing.

Which is also the rule I'd carve into the wall: never put dynamic content in a
tool schema. No timestamp in the description, no current working directory
baked into an argument's docstring, no list of the files that happen to exist
right now. Each of those rewrites the cache prefix on every single request and
quietly turns your cheapest block into your most expensive one. A tool schema
describes what the tool *can* do, which doesn't change mid-session. Anything
that does change belongs in a message — the system prompt if it's per-session,
a user or tool message if it's per-turn.

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
