---
layout: post
title: "Autoregressive Language Modeling"
date: 2026-07-07 00:00:00 +0530
categories: machine-learning
tags: [nlp, language-modeling, n-grams, neural-networks]
author: "Seroze"
published: true
---

*Notes from [CMU Advanced NLP — Autoregressive Language Modeling](https://www.youtube.com/watch?v=Ry-4oRYXtfA&list=PLqC25OT8ZpD15emhQhNjRLym77-sp2kAx&index=4), continuing from the [learned representations / CBOW post]({{ site.baseurl }}/learned-representations-nlp/). This lecture is about the single idea that powers modern LLMs: predict the next token, over and over.*

## What is a language model?

A language model assigns a probability to a sequence of tokens:

$$
P(X) = P(x_1, x_2, \dots, x_T)
$$

That single ability turns out to be remarkably useful. With it you can

* **score** candidate sentences — pick the more fluent transcription in speech recognition, or the better translation,
* **generate** text — sample sequences that the model considers probable,
* and, as it turns out, do almost everything modern LLMs do, since chat, summarization, and code completion are all "generate probable continuations."

## The autoregressive decomposition

Modeling $$P(X)$$ directly is intractable — there are astronomically many sequences. The trick is the **chain rule of probability**, which is exact (no approximation yet):

$$
P(X) = \prod_{t=1}^{T} P(x_t \mid x_1, \dots, x_{t-1})
$$

The probability of a sentence is the product of next-token probabilities, each conditioned on everything before it. For "I hate this movie":

```
P(I hate this movie) = P(I)
                     × P(hate  | I)
                     × P(this  | I hate)
                     × P(movie | I hate this)
                     × P(</s>  | I hate this movie)
```

(The end-of-sequence token `</s>` matters — without it, probabilities over sequences of different lengths don't sum to one.)

This is called **autoregressive** because the model consumes its own previous outputs as inputs for the next step. We've reduced "model a whole sentence" to a problem we already know from the CBOW post: **predict one word from context — a K-way classification over the vocabulary.** The only change is the training target: instead of a removed center word, it's always the *next* word.

## Count-based n-gram models

The classic approach makes a **Markov assumption**: the next word depends only on the previous $$n-1$$ words.

$$
P(x_t \mid x_1, \dots, x_{t-1}) \approx P(x_t \mid x_{t-n+1}, \dots, x_{t-1})
$$

Then just count occurrences in a corpus. For a bigram model:

$$
P(x_t \mid x_{t-1}) = \frac{\text{count}(x_{t-1}, x_t)}{\text{count}(x_{t-1})}
$$

This is simple, fast, and was the state of the art for decades. But it has two fundamental problems:

1. **Sparsity.** If an n-gram never appeared in training data, its probability is zero — and one zero kills the whole product. Smoothing techniques (add-one, interpolation, Kneser–Ney backoff) patch this, but it's a patch.
2. **No generalization.** Counts treat words as atoms. Seeing "I hate this movie" tells the model *nothing* about "I despise this film" — there is no notion of similarity between words.

That second problem is exactly what learned embeddings fix.

## Neural language models

The feed-forward neural LM (Bengio et al., 2003) applies the recipe from the previous post to next-word prediction:

```
previous n-1 words
      ↓ embedding lookup
      ↓ concatenate (order matters now — no bag of words!)
      ↓ hidden layer(s) with non-linearity, e.g. tanh(Wh + b)
      ↓ linear layer → K scores
      ↓ softmax
P(next word | context)
```

Note the difference from CBOW: the context embeddings are **concatenated, not summed**, because for language modeling word order matters — "dog bites man" and "man bites dog" should predict different continuations.

The payoff is generalization through shared representations: if "hate" and "despise" get similar embeddings, then evidence about one automatically transfers to the other. The sparsity problem largely dissolves — the model never assigns exactly zero, and similar contexts produce similar predictions even if never seen verbatim.

The remaining limitation is the fixed window: a feed-forward LM still only sees $$n-1$$ words back. Removing that limit is what recurrent networks, and later Transformers, are for.

## Training

Training maximizes the log-likelihood of the corpus, which is just cross-entropy loss at every position:

$$
\mathcal{L}(\theta) = -\sum_{t=1}^{T} \log P(x_t \mid x_{<t}; \theta)
$$

A key practical detail: during training we always condition on the **true** previous words from the corpus, not on the model's own (possibly wrong) predictions. This is called **teacher forcing**, and it means every position in a sentence is an independent classification example — trivially parallelizable.

## Evaluation: perplexity

The standard metric is **perplexity** — the exponentiated average negative log-likelihood on held-out text:

$$
\text{PPL} = \exp\!\left(-\frac{1}{T}\sum_{t=1}^{T} \log P(x_t \mid x_{<t})\right)
$$

The intuition: perplexity is the effective **branching factor** — a perplexity of 100 means the model is, on average, as uncertain as if it were choosing uniformly among 100 words at each step. Lower is better; a hypothetical perfect model that always knew the next word would have perplexity 1.

Two caveats worth remembering:

* Perplexities are only comparable **over the same vocabulary/tokenization** — changing the tokenizer changes the number.
* Better perplexity does not always mean better downstream behavior, though it correlates surprisingly well.

## Generation

Since the model gives $$P(x_t \mid x_{<t})$$, generating text is just **ancestral sampling**: sample a word from the distribution, append it to the context, and repeat until `</s>`.

```
context: <s>
sample:  I          → context: <s> I
sample:  hate       → context: <s> I hate
sample:  this       → context: <s> I hate this
sample:  movie      → context: <s> I hate this movie
sample:  </s>       → done
```

You can also take the argmax at each step (greedy decoding), or bias the distribution with a temperature — but the basic loop is the same, and it's still the loop running inside every LLM chat you have today.

## Takeaway

The whole lecture compresses into one line:

$$
P(X) = \prod_{t} P(x_t \mid x_{<t})
$$

Everything else is about how to model that conditional: with counts (n-grams — simple but sparse and unable to generalize), or with the embed → hidden layers → softmax classifier we built up in the CBOW post (dense, generalizing, and the direct ancestor of GPT-style models). Train it with cross-entropy on next-word prediction, measure it with perplexity, and generate by sampling one token at a time.
