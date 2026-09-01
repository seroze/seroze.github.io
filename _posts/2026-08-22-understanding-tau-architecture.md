---
layout: post
title: "[Python] Understanding Tau’s Architecture"
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

## A taxonomy of messages.py

Having decided `messages.py` is the leaf worth pulling on, I read the whole file. It's about 280 lines and defines a dozen or so models, which sounds like a lot until you notice they aren't a dozen unrelated things. There are exactly two kinds of model in there, and keeping them straight is most of the file's design:

- **Content blocks** — the inside of a message. Discriminated by a `type` field.
- **Transcript messages** — the items in the history list. Discriminated by a `role` field.

Everything else is scaffolding, metering, or a satellite hanging off one specific message. Once you have that split the file reads in one pass.

### The scaffolding

Three things at the top that nothing else in the file will mention again, because they're doing their work invisibly.

`_to_camel` turns `tool_call_id` into `toolCallId`. Tau's wire format is camelCase — it's compatible with Pi's protocol, which is JavaScript-shaped — while the Python API is snake_case, as it should be. `current_timestamp_ms` returns Unix milliseconds and is used as the `default_factory` on every message.

Then `WireModel`, the base class everything inherits. It's four lines of `ConfigDict` and it's the one class to understand first:

```python
class WireModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        validate_by_name=True,
        validate_by_alias=True,
        serialize_by_alias=True,
        alias_generator=_to_camel,
    )
```

`extra="forbid"` means an unknown JSON key is an error rather than something silently dropped — if a provider starts sending a field Tau doesn't model, you find out immediately instead of losing data quietly. The two `validate_by_*` flags mean both spellings are accepted on input, so you can construct from Python with `tool_call_id=` or parse a payload with `toolCallId=` and both work. `serialize_by_alias` means output is always camelCase. That's why no other class in the file has to think about aliases at all.

### Metering

Two models, assistant-only. `UsageCost` holds USD floats — `input`, `output`, `cache_read`, `cache_write`, `total`. `Usage` holds token counts in the same shape, plus `cache_write_1h`, `reasoning`, `total_tokens`, and a nested `cost: UsageCost`.

The parallel structure is deliberate: same field names, tokens in one and dollars in the other. `cache_write_1h` being separate from `cache_write` is the extended-TTL cache write priced differently from the standard one, which connects back to the caching section above — the accounting model has to distinguish them because the biller does.

### Content blocks

Four of them, discriminated by `type`.

| class | `type` | payload | notes |
|---|---|---|---|
| `TextContent` | `"text"` | `text` | `text_signature` carries provider-side signing |
| `ThinkingContent` | `"thinking"` | `thinking` | `thinking_signature`, plus `redacted: bool` for encrypted reasoning |
| `ImageContent` | `"image"` | `data`, `mime_type` | `data` is base64 |
| `ToolCall` | `"toolCall"` | `id`, `name`, `arguments` | `thought_signature` is the Gemini-flavoured equivalent |

Then three union aliases, and these are the actual type-level contract of the file:

```python
type UserContent = str | list[TextContent | ImageContent]
type AssistantContent = TextContent | ThinkingContent | ToolCall
type ToolResultContent = TextContent | ImageContent
```

Read them as rules about which blocks are legal where. A user can send text and images but never a thinking block or a tool call. An assistant can produce text, thinking and tool calls but not images. A tool result can come back as text or an image, but it can't contain reasoning and it can't nest another tool call. None of that is enforced by a runtime check anywhere — it's enforced by the types, once, and then every message that references these aliases gets it for free.

The asymmetry worth noticing is that `UserContent` allows a bare `str` and the other two don't. That comes back in a moment.

### Transcript messages

Seven classes, discriminated by `role`, and they split into three tiers by how far they travel.

**Tier A — they cross the provider boundary.** These become turns in an actual API request.

`UserMessage` is the simplest model in the file: a `role`, a `content: UserContent`, a `timestamp`. That's it.

`AssistantMessage` is the heavyweight, and most of its weight is a distinction I liked: it records both what was asked for and what came back. `api` / `provider` / `model` are what the request specified; `response_model` / `response_provider` / `response_id` are what the provider actually says it served. Those diverge more often than you'd hope — an alias resolving to a dated snapshot, a router silently falling back — and if you only store the requested model your transcripts lie to you later. On top of that it carries `usage`, a `stop_reason`, an `error_message`, and a list of `diagnostics`.

`ToolResultMessage` carries `tool_call_id`, which pairs back to `ToolCall.id` and is the only thing linking a result to its request, plus `tool_name`, an `is_error` flag, free-form `details`, and `added_tool_names` for tools that register more tools when they run.

**Tier B — local to the session.** These never go to a provider as-is; they're converted first, by `message_to_user`.

`BashExecutionMessage` is for when the user ran a shell command in the REPL themselves rather than the model calling a tool. It holds `command`, `output`, `exit_code`, and flags for `cancelled` and `truncated`, plus a `full_output_path` when the output got spilled to a file. The interesting field is `exclude_from_context`: the message is in the transcript and shown on screen, but can be marked as not going to the model. That's the whole reason this tier exists.

`CustomMessage` is the escape hatch for host-application messages — status lines, notices, whatever the app on top wants in the scrollback. `custom_type` is a free string the host defines, and `display: bool` controls whether it's shown at all.

**Tier C — history rewriting.** Produced by the harness *about* the transcript rather than by anyone in the conversation.

`BranchSummaryMessage` has `summary` and `from_id`, and collapses an abandoned branch into a sentence. `CompactionSummaryMessage` has `summary` and `tokens_before`, and replaces trimmed history when the context window fills up. Both are the same idea: a summary string standing in for messages that are gone.

Three small satellites hang off `AssistantMessage` and nothing else. `AssistantDiagnosticError` is an exception rendered as data — `name`, `message`, `stack`, `code`. `AssistantMessageDiagnostic` wraps one of those with a `type` and a timestamp. And `StopReason` is a plain literal alias:

```python
StopReason = Literal["stop", "length", "toolUse", "error", "aborted"]
```

Finally the whole thing gets tied together:

```python
type AgentMessage = Annotated[
    UserMessage | AssistantMessage | ToolResultMessage
    | BashExecutionMessage | CustomMessage
    | BranchSummaryMessage | CompactionSummaryMessage,
    Field(discriminator="role"),
]
```

That `discriminator="role"` is what makes deserialising a session file cheap and safe — pydantic reads one field and knows exactly which model to build, instead of trying all seven and taking whichever doesn't explode.

### Three cross-cutting things

A few patterns run through the file rather than living in any one class, and they're the parts I'd actually steal.

**String content is construction sugar, never a second representation.** `AssistantMessage` and `ToolResultMessage` each have a `@model_validator(mode="before")` that accepts a plain string for `content` and promotes it to `[TextContent(text=...)]`. The docstring is explicit that this is for Python construction and tests only — the stored model and the serialised protocol are always block-based. This is the right way to have a convenience shorthand: normalise it at the boundary so nothing downstream ever has to ask "is this a string or a list this time". `UserMessage` doesn't need the validator, because there `str` is genuinely part of the type.

**`.text` is always computed, never stored.** `UserMessage`, `AssistantMessage`, `ToolResultMessage` and `CustomMessage` all expose a `text` property that walks the blocks and joins them; `AssistantMessage` adds `thinking_text` and `tool_calls` the same way. There's no cached flat string anywhere that could drift out of sync with the blocks.

**Timestamps are on every message and on no content block.** Ordering is a transcript concern, not a content concern. A block doesn't get to have an opinion about when it happened — only the message it lives in does.

The one thing that shows up everywhere and is pure tax is signatures: `text_signature`, `thinking_signature`, `thought_signature`. Three different fields on three different blocks, all doing the same job of carrying an opaque provider-issued token that has to be handed back verbatim on the next turn. That's the actual price of being provider-neutral over providers that cryptographically sign their own output — you can unify the shape of everything except the parts each vendor insists on making unique.
