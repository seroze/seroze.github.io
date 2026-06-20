---
layout: post
title: "Relearning HTML — The Building Blocks"
date: 2026-06-21 00:00:00 +0530
categories: web
tags: [html, web, frontend]
author: "Seroze"
published: true
---

*I'm picking up HTML again from scratch. This post is my running set of notes on the fundamentals — the document skeleton, semantic elements, and the bits I keep forgetting.*

---

## The document skeleton

Every HTML page starts with the same boilerplate. It's worth typing this out by hand a few times until it sticks:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>My Page</title>
  </head>
  <body>
    <h1>Hello, world</h1>
    <p>This is my first page.</p>
  </body>
</html>
```

A few things I had to remind myself of:

- `<!DOCTYPE html>` tells the browser to use standards mode. Without it you get "quirks mode" and old, inconsistent rendering.
- `<head>` holds metadata — things the user doesn't see directly (title, charset, links to CSS).
- `<body>` is the visible content.
- `lang="en"` and `charset="UTF-8"` matter for accessibility and correct character rendering.

## Semantic elements

Instead of wrapping everything in `<div>`, HTML5 gives you tags that describe *meaning*. This helps screen readers, SEO, and your own sanity:

```html
<header>Site title and nav</header>
<nav>Links</nav>
<main>
  <article>
    <h2>A blog post</h2>
    <section>...</section>
  </article>
  <aside>Sidebar</aside>
</main>
<footer>Copyright</footer>
```

Rule of thumb I'm trying to follow: reach for a semantic tag first, and only fall back to `<div>` when nothing else fits.

## Text basics

```html
<h1>–<h6>   <!-- headings, in order of importance -->
<p>          <!-- paragraph -->
<strong>     <!-- important (bold) -->
<em>         <!-- emphasis (italic) -->
<br />       <!-- line break -->
<hr />       <!-- thematic break -->
```

One thing that bit me: headings should follow a logical order (`h1` → `h2` → `h3`), not be chosen for their size. Sizing is a CSS concern.

## Links and images

```html
<a href="https://example.com">A link</a>
<a href="/about">An internal link</a>

<img src="cat.jpg" alt="A sleepy cat" />
```

`alt` text isn't optional in my book — it's what screen readers announce and what shows when the image fails to load.

## Lists

```html
<ul>
  <li>Unordered item</li>
</ul>

<ol>
  <li>Ordered item</li>
</ol>
```

## What's next

Next I want to dig into **forms** (`<input>`, `<label>`, validation) and how HTML connects to CSS for layout. I'll post those notes as I go.
