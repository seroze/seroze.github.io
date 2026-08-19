---
layout: post
title: "The Residual Stream in a Transformer"
date: 2026-08-19 00:00:00 +0530
categories: machine-learning
tags: [transformers, interpretability, deep_learning, machine_learning]
author: "Seroze"
published: true
---

The cleanest way to think about a transformer is that there is one vector per token running from the embedding all the way to the unembedding, and every layer only ever *adds* to it. That vector is the residual stream.

![Attention and MLP blocks reading from and writing back into the residual stream]({{ site.baseurl }}/assets/images/residual-stream.svg)

Each block reads the stream, computes something, and writes the result back as a sum:

$$x_{\ell+1} = x_{\ell} + \mathrm{Attn}(x_{\ell}) + \mathrm{MLP}(x_{\ell})$$

Nothing is overwritten, so the stream behaves like a shared bus: an early head can write a feature that a much later MLP picks up, and the two communicate without any layer in between knowing about it. It also means you can decompose the final logits into a sum of contributions from every block — which is exactly what makes mechanistic interpretability tractable.

Short explainer video: [Residual stream, in 60 seconds](https://www.youtube.com/shorts/9SKLIFev_ho)
