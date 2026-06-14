# CLAUDE.md — Project Notes for seroze.github.io

## What this is

A Jekyll blog hosted on GitHub Pages at https://seroze.github.io.
The owner posts daily learnings here (currently being resurrected as of June 2026).

## Stack

- **Jekyll** with the `minima` theme
- **kramdown** as the markdown processor
- **MathJax 3** for LaTeX math rendering (loaded in `_layouts/post.html`)
- Deployed via GitHub Pages on push to `main`

## Project structure

```
_posts/          # All blog posts (date-prefixed .md files)
_layouts/        # Custom layouts (post.html has MathJax injected)
assets/images/   # Images used in posts
_config.yml      # Jekyll config (theme, kramdown, permalink settings)
tags.html        # Tag listing page
```

## Writing posts

Posts live in `_posts/` with the filename format: `YYYY-MM-DD-slug.md`

Frontmatter template:
```yaml
---
layout: post
title: "Post Title"
date: YYYY-MM-DD HH:MM:SS +0530
categories: machine-learning
tags: [tag1, tag2]
author: "Seroze"
published: true
---
```

## Math / LaTeX

kramdown mangles LaTeX if not configured correctly. The setup that works:

**_config.yml** must have:
```yaml
markdown: kramdown
kramdown:
  math_engine: mathjax
```

**Rules for writing math in posts:**
- Use `$$...$$` for both inline and block/display math — NOT single `$...$`
- kramdown only recognizes double-dollar as math delimiters
- kramdown outputs `\[...\]` for display math and `\(...\)` for inline math
- MathJax in `_layouts/post.html` is configured to render those delimiters

**Why single `$` breaks things:** kramdown treats `$` as a regular character and processes the content inside as markdown, escaping underscores and backslashes before MathJax ever sees it.

## Deploying

```bash
git add <files>
git commit -m "message"
git push origin main
```

GitHub Pages rebuilds automatically on push. Allow ~1 minute for changes to appear.
