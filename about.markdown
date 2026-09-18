---
layout: page
title: About
permalink: /about/
---

This is a dev log — notes on whatever I'm building, breaking or reading about on a given day. I'm interested in mechanistic interpretability and compilers.

It's a log, not a publication. A lot of what's here started as a conversation with ChatGPT or Claude — I ask questions until something clicks, then summarize the useful part so I can find it again. Most posts are quick captures for my future self and I don't spend much time polishing them. The exception is when a post is trying to teach a concept — those I actually sit with and rewrite until the explanation holds up.

Nothing here is original research. I'm planning a separate portfolio blog for that, with findings of my own — work in progress.

## Open source contributions

### [evalscope](https://github.com/modelscope/evalscope) {#evalscope}

Evaluation framework for LLMs and VLMs.

- [#1673 — retry 200 responses that carry a gateway error payload](https://github.com/modelscope/evalscope/pull/1673). Some OpenAI-compatible gateways return an error with `200 OK`, and the OpenAI SDK happily deserializes that into a `ChatCompletion` with `choices=None` — so the failure surfaced outside the retry boundary with almost no diagnostics. Validation now happens inside it: the gateway's own error is reported, transient failures are retried, and deterministic 4xx ones fail fast.
- [#1678 — move litellm imports to module level](https://github.com/modelscope/evalscope/pull/1678). Three functions imported litellm lazily to keep the module importable without it. But litellm ships in `requirements/framework.txt`, so it installs with a plain `pip install evalscope`, and the model registry already gates the import a layer up.

### [smartcore](https://github.com/smartcorelib/smartcore) {#smartcore}

Machine learning and numerical computing in Rust.

- [#390 — replace unmaintained bincode with postcard](https://github.com/smartcorelib/smartcore/pull/390). bincode's final 3.0.0 release is a poison pill whose entire source is `compile_error!("https://xkcd.com/2347/")`, so any project Dependabot bumped to it stopped building. It was a dev-dependency used for serde round-trip assertions, and postcard is a drop-in for that. The SVM tests stayed on `serde_json` — postcard isn't self-describing, so it can't deserialize their `typetag::serde` trait objects.
- [#423 — remove duplicated RealNumber trait bound](https://github.com/smartcorelib/smartcore/pull/423). `GaussianNB` asked for `TX: Number + RealNumber + RealNumber` in four different places. It asks nothing extra of `TX`, which is why rustc and clippy both stayed quiet about it since the v0.4 generics rewrite.

You can browse everything by [tag](/tags/) or [search the archive](/search/).

For questions, corrections, or anything else, reach out on X — [@{{ site.twitter_username }}](https://x.com/{{ site.twitter_username }}).
