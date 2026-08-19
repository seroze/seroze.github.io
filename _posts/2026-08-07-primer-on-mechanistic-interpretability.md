---
layout: post
title: "A primer on Mechanistic Interpretability"
date: 2026-08-07 00:00:00 +0530
categories: machine-learning
tags: [mechanistic_interpretability, interpretability, llm, transformers, ai_safety]
author: "Seroze"
published: true
---

*A running collection of mechanistic interpretability concepts worth knowing cold.*

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## What mechanistic interpretability is

TODO

## Why it matters

The short version: we are going to want to find bugs, systematic biases and outright flaws
in these models, and behaviour alone is a bad instrument for that. A model that is wrong for
a *reason* — a spurious feature it latched onto, a shortcut circuit that happens to work on
the eval set — looks exactly like a model that is right, until it doesn't. Reading the
mechanism is the difference between "it scored 94%" and "I know what it's doing on the other
6%."

The sharper version is alignment. We will soon need to detect unaligned behaviour in models
that are good enough to hide it, and the failure modes we already see all share the property
of looking fine from the outside:

- **Deception / alignment faking** — the model behaves as though aligned while pursuing some
  other objective, and behaves differently when it infers it isn't being watched. The whole
  point is that the output doesn't give it away.
- **Sycophancy** — the model tells you what you want to hear. Agreement is a very cheap way
  to score well with human raters, and it is indistinguishable from correctness whenever the
  rater can't check.
- **Reward hacking** — the model finds the efficient path to the reward rather than to the
  task: special-casing the test, gaming the grader, satisfying the metric while missing the
  intent.

In each case the output is the thing being optimised, so grading the output can't be the
check. That's the case for mechanistic interpretability: if you can identify the internal
features and circuits a model is actually running, you get evidence about *why* it produced
an answer — a channel the model isn't optimising against, and one that can catch the problem
before it shows up in behaviour.

Some of this can be measured behaviourally, though, and it's worth knowing how those numbers
are built before reading the papers. Work on collusion and self-monitoring — can a model
recognise output written by a copy of itself? — reports results as ROC curves and AUC, which
I wrote up separately in [What an ROC curve actually tells you]({% post_url 2026-08-19-roc-curves-and-auc %}).

## How to inspect neural networks

The basic move is to stop treating the network as a function from input to output and start
watching what happens inside it while it runs. Feed it inputs, record the activations, and
ask which neurons light up for which kind of task.

Two units of analysis come out of that:

- **Features** — what an individual neuron (or, more usefully, a direction in activation
  space) responds to. A feature is the network's internal representation of some property of
  the input: a token being a closing bracket, a name being French, a piece of text being
  written in the first person.
- **Circuits** — groups of features wired together across layers into a computation. A
  circuit is the *how*: the path by which some set of features gets read, combined and
  turned into the next feature or the final logit.

TODO

## The transformer, from an interpretability angle

TODO

## Features, circuits and superposition

TODO

## Sparse autoencoders

TODO

## Tools and libraries

TODO

## Open problems

TODO

## References

TODO
