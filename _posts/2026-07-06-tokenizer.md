---
layout: post
title: "Tokenizer"
date: 2026-07-06 00:00:00 +0530
categories: machine-learning
tags: [llm, tokenizer, unicode, utf_8]
author: "Seroze"
published: true
---

Before we can talk about tokenizers, we need to talk about how text is represented as bytes in the first place. Every modern tokenizer (including the byte-level BPE used by GPT-style models) operates on top of **UTF-8**, so understanding UTF-8 is step zero.

## UTF-8: the encoding underneath everything

Unicode assigns every character a number called a **code point** — `A` is U+0041, `é` is U+00E9, `अ` is U+0905, `😀` is U+1F600. But a code point is an abstract number; to store or transmit it, we need an encoding scheme that turns it into bytes. UTF-8 is that scheme, and it is by far the dominant one (essentially all of the web is UTF-8).

**A common misconception:** the "8" in UTF-8 does *not* mean every character fits in 8 bits. It means the encoding works in units of 8 bits (one byte). A single character can take **1 to 4 bytes** depending on its code point.

UTF-8 is a **variable-length** encoding. Here is exactly how the four sizes work:

| Bytes | Code point range     | Byte pattern                                  | Payload bits |
|-------|----------------------|-----------------------------------------------|--------------|
| 1     | U+0000 – U+007F      | `0xxxxxxx`                                    | 7            |
| 2     | U+0080 – U+07FF      | `110xxxxx 10xxxxxx`                           | 11           |
| 3     | U+0800 – U+FFFF      | `1110xxxx 10xxxxxx 10xxxxxx`                  | 16           |
| 4     | U+10000 – U+10FFFF   | `11110xxx 10xxxxxx 10xxxxxx 10xxxxxx`         | 21           |

The `x` bits carry the code point; the fixed prefix bits are structural:

- **1-byte characters** start with `0` — this makes UTF-8 fully backward-compatible with ASCII. Plain English text is byte-for-byte identical in ASCII and UTF-8.
- **Leading bytes** of multi-byte characters start with `110`, `1110`, or `11110` — the number of leading 1s tells you how many bytes the character occupies.
- **Continuation bytes** always start with `10`, so you can jump into the middle of a byte stream and resynchronize by scanning for the next byte that doesn't start with `10`.

A concrete example for each size:

```
'A'  = U+0041  → 41                    (1 byte,  ASCII)
'é'  = U+00E9  → C3 A9                 (2 bytes, Latin with accents, Greek, Cyrillic, ...)
'अ'  = U+0905  → E0 A4 85              (3 bytes, most Indic scripts, CJK, ...)
'😀' = U+1F600 → F0 9F 98 80           (4 bytes, emoji and other supplementary planes)
```

You can verify this in Python:

```python
>>> "A".encode("utf-8")
b'A'
>>> "é".encode("utf-8")
b'\xc3\xa9'
>>> "अ".encode("utf-8")
b'\xe0\xa4\x85'
>>> "😀".encode("utf-8")
b'\xf0\x9f\x98\x80'
>>> len("😀")            # one character...
1
>>> len("😀".encode())   # ...four bytes
4
```

So to repeat the key point: **UTF-8 is named for its 8-bit code unit, but a single character can span up to 4 bytes.** The clever prefix design gives it ASCII compatibility, self-synchronization, and coverage of all 1,114,112 possible Unicode code points.

## Why tokenizers care

This byte-level view is exactly where modern tokenizers start. A byte-level BPE tokenizer begins with a base vocabulary of just 256 tokens — one per possible byte value — which means it can represent *any* string in *any* language with zero out-of-vocabulary failures. From there, it learns merges of frequently co-occurring byte sequences to build up a vocabulary of subwords.

It also explains some tokenizer quirks you may have noticed: an emoji or a character from a non-Latin script often costs multiple tokens, because underneath it is 3–4 bytes that may not have been merged into a single token during training. English text tokenizes efficiently partly because it is 1 byte per character and heavily represented in training data.

In upcoming sections we'll build on this foundation to look at how BPE training and encoding actually work.
