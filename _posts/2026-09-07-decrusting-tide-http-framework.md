---
layout: post
title: "[Rust] Decrusting the tide crate (HTTP framework in rust)"
date: 2026-09-07 00:00:00 +0530
categories: rust
tags: [rust, tide, http, web_frameworks, libraries]
author: "Seroze"
published: true
---

[tide](https://github.com/http-rs/tide) is one of the older async web frameworks in
Rust, built under the `http-rs` organisation around 2019. It lost the popularity contest
— if you're shipping something today you almost certainly want axum — but it is a much
better codebase to *read* than the frameworks that won. It's small, the abstractions are
ordinary, and there is very little type-level machinery standing between you and the
request lifecycle. You can hold the whole thing in your head.

A minimal app is about what you'd expect:

```rust
use tide::Request;

#[async_std::main]
async fn main() -> tide::Result<()> {
    let mut app = tide::new();

    app.at("/hello").get(|_| async {
        Ok("Hello, world!")
    });

    app.listen("127.0.0.1:8080").await?;
    Ok(())
}
```

The thing I want to start with isn't `Server` or the router, though. It's the
dependency list. Tide is unusually honest about how little of the work it does itself,
and once you know which crate owns which job, reading the source stops being a hunt.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Tide is mostly glue

The `http-rs` project was an experiment in making HTTP components reusable across
projects instead of each framework growing its own parser, its own `Request` type and
its own router. Tide is what you get when you take that seriously: it parses no HTTP,
defines no `Request`, and implements no route matching. What's left — routing tables,
the middleware pipeline, and the ergonomics of pulling data out of a request — is the
framework.

Here's roughly how the crates stack up:

```
                  Your application
                         │
                       tide
                         │
        ┌────────────────┼─────────────────┐
        │                │                 │
 route-recognizer    http-types       async-session
        │                │
        │        async-std / futures
        │                │
        └────────┬───────┘
                 │
             async-h1
                 │
              TCP socket
```

And here is the same picture as a request actually travelling through it:

```
TCP socket
    │  async-std accepts the connection
    ▼
async-h1            parse HTTP/1 bytes
    ▼
http-types::Request
    ▼
route-recognizer    match path, extract params
    ▼
middleware chain
    ▼
your handler        returns a Response
    ▼
http-types::Response
    ▼
async-h1            serialise back to bytes
    ▼
TCP socket
```

## The dependencies, one line each

**`http-types`** is the important one. It defines `Request`, `Response`, `Body`,
`Method`, `Headers`, `Mime`, `StatusCode`, `Url` — effectively a standard library for
HTTP. When your handler takes a `tide::Request<State>`, what it's mostly holding is an
`http_types::Request`. Tide wraps it rather than replacing it.

**`route-recognizer`** is the router. `app.at("/users/:id")` registers a pattern here,
and a later `GET /users/42` comes back as "matched `/users/:id`, with `id = "42"`".
Internally it's a radix tree, i.e. a compressed trie over path segments.

**`async-h1`** is the HTTP/1 codec. Bytes off the socket go in, an `http-types` request
comes out; a response goes in, bytes come out. It knows nothing about routes.

**`async-std`** is the runtime. Tide bet on async-std at a time when the runtime
question was genuinely open. It supplies the TCP listener, task spawning, timers, async
filesystem and the synchronisation primitives — the same surface Tokio offers, from the
other camp. This is the single biggest reason tide reads as a period piece today.

**`futures`** is the async plumbing everything else is written against: combinators,
`Stream`, `Sink`, channels, the utility traits. An `async fn` is just a thing returning
`impl Future`, and this crate is where the vocabulary for manipulating those lives.

**`async-session`** handles cookies, session IDs and the session store behind
`req.session_mut()`, so session middleware doesn't have to care where the data actually
sits.

**`serde`** is what makes `req.body_json()` work on your own structs.

**`log`** — tide emits log events and prints nothing itself, which is the right call for
a library.

**`pin-project`** is an implementation detail that looks scarier than it is. An async
block compiles to a self-referential state machine, so once it has started running it
can't be moved; `pin-project` is the safe way to reach a pinned field of a pinned
struct. You need it to hand-write futures and streams, and almost never otherwise.

**`surf` and `http-client`** aren't part of the server at all. They were the companion
client, and the point of them was that both sides speak `http-types` — a request you
built for the client is the same type the server hands your handler.

## A reading order

Bottom-up works better than following `lib.rs` down, because the bottom is where the
concrete types live:

1. `http-types` — the core HTTP abstractions everything else passes around.
2. `route-recognizer` — path matching and parameter extraction.
3. `async-h1` — how raw bytes become a request and a response becomes bytes.
4. tide itself — `src/lib.rs`, then `server.rs`, `route.rs`, `router.rs`,
   `middleware/`, `request.rs` and `response.rs`, following the call chain from
   `app.listen(...)` until it reaches an endpoint.
5. `futures` — as much as you need, whenever the async model gets in the way.

The rest of this post walks through them one at a time.

## http-types

TODO

## route-recognizer

TODO

## async-h1

TODO

## async-std and futures

TODO

## The tide server itself

TODO

## What I took away from it

TODO
