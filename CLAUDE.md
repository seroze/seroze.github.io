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
_layouts/        # Custom layouts (post.html has MathJax injected, home.html has pagination)
assets/images/   # Images used in posts
_config.yml      # Jekyll config (theme, kramdown, permalink, pagination settings)
index.html       # Homepage (must be .html, not .md — see Pagination)
tags.html        # Tag listing page
search.html      # Search UI (see Search)
search.json      # Liquid-generated search index (see Search)
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

### Never put a bare `|` inside inline math

Use `\lvert x \rvert` for absolute values and `\mid` for divisibility — **never a bare `|`** — in any `$$...$$` that shares a line with prose.

kramdown's native table syntax triggers on any line containing `|` characters. Inside a *standalone* `$$...$$` paragraph the math block wins and pipes are safe, but inline math on a text line (or in a list item) gets shredded: kramdown splits the line into table cells, which breaks the `$$` pairing, drops the bars, and leaks raw `$$` and `**` into the page. The damage is silent — no build error, just a mangled paragraph wrapped in a stray `<table>`.

To check a post before publishing, render it and look for the two tells:

```bash
# strip frontmatter first; ruby isn't installed locally, so use docker
docker run --rm -v "$PWD":/w -w /w ruby:3.2-slim \
  sh -c "gem install kramdown --no-document -q 2>/dev/null && kramdown --math-engine mathjax post.md" > out.html
grep -c '<table>' out.html   # 0, unless the post has a real table
grep -c '\$\$'    out.html   # always 0 — a survivor means unpaired delimiters
```

## Pagination

The homepage shows 10 posts per page using `jekyll-paginate` (v1, the only paginator GitHub Pages supports).

**_config.yml:**
```yaml
plugins:
  - jekyll-feed
  - jekyll-paginate
paginate: 10
paginate_path: "/page:num/"
```

Moving parts:
- The homepage **must be `index.html`** at the repo root — jekyll-paginate v1 silently ignores `index.md`/`index.markdown`. Don't rename it back.
- `_layouts/home.html` overrides minima's home layout: it iterates `paginator.posts` (not `site.posts`) and renders Newer/Older nav links with a "Page X of Y" indicator.
- Paginated pages land at `/page2/`, `/page3/`, etc. Page 1 is the root `/`.

## Search

Client-side search at `/search/`. GitHub Pages can't run server code or custom plugins, so the index is generated at build time by Liquid and filtered in the browser with vanilla JS. No dependencies, no build step, no external service.

Moving parts:
- `search.json` — a Liquid template looping `site.posts` into a JSON array. Indexes **title, url, date, tags, category and excerpt** (first paragraph, truncated to 250 chars) — *not* full post bodies.
- `search.html` — the UI at `/search/`. Fetches the index once on page load, then scores matches: every query term must appear somewhere, with title hits worth 10, tag/category 5, excerpt 1. Ties break newest-first. Keeps `?q=` in the URL so a search is linkable.

**`search.json` must not have a `title` in its frontmatter.** Minima's `header.html` builds the nav from every page in `site.pages` that has a title — give the JSON one and the raw index shows up as a nav link. `search.html` *does* have a title, which is how "Search" appears in the nav automatically.

**Why excerpts and not full text:** the whole index is downloaded before the first keystroke, so index size is the only real constraint (scanning 2,000 posts takes under 1 ms). At ~420 bytes/post the index is ~7 KB gzipped for 54 posts and stays under ~130 KB at 1,000 posts. Full post bodies average ~8.9 KB/post, which would blow past 1 MB somewhere around 300–500 posts.

The tradeoff: a term that appears only in the middle of a post won't be found. If that becomes annoying, the upgrade path is [Pagefind](https://pagefind.app) (shards the index, fetches only what a query needs) — but it needs a GitHub Actions build instead of the stock Pages build.

Posts with `published: false` are excluded automatically, since `site.posts` already omits them.

## Light/dark theming

Readers get dark mode from their OS by default, plus a toggle in the header that overrides it and persists.

Moving parts:
- `assets/main.scss` — imports minima, then declares CSS custom properties and re-points minima's colour-bearing selectors at them. minima 2.5.2 compiles colours straight into the stylesheet, so they **cannot** be swapped at runtime via Sass variables — hence the custom-property layer.
- `_includes/head.html` — a copy of minima 2.5.2's `head.html` plus the theme script. **minima 2.5.2 has no `custom-head.html` hook** (that arrived in 3.x), so overriding the whole include is the only way in. If you ever bump minima, re-copy the gem's `head.html` and re-apply the script block.

The theme script is inline and synchronous *on purpose*: it must set `data-theme` before first paint, or dark-mode readers get a white flash on every page load. Don't move it to an external file or add `defer`.

Three cascade layers, weakest to strongest:
1. light values on `:root`
2. `@media (prefers-color-scheme: dark)`, scoped `:root:not([data-theme="light"])` so an explicit light choice still wins
3. `:root[data-theme="dark"]`, written by the toggle

Because layers 2 and 3 have equal specificity, **the explicit-choice block must stay after the media query in the file.** Reordering silently breaks the toggle for anyone whose OS is set to dark.

Dark syntax highlighting is overridden separately — minima's rouge palette (bold-only keywords, `#998` comments) is close to unreadable on a dark background.

Known gap: the dark palette passes WCAG AA, but minima's inherited *light* values don't — `.post-meta` at `#828282` is 3.78:1 and links at `#2a7ae2` are 4.15:1, both under the 4.5:1 threshold. Changing `--muted` to `#6f6f6f` and `--link` to `#1a68c9` would fix it.

## Post timestamps

Always use `00:00:00 +0530` as the time in post frontmatter:

```yaml
date: YYYY-MM-DD 00:00:00 +0530
```

**Why:** GitHub Pages builds at UTC time. Any non-zero time in IST (+0530) may be ahead of UTC at build time, causing Jekyll to silently skip the post. `_config.yml` has `future: true` as a safety net, but always use midnight to avoid confusion.

`_config.yml` must also set `timezone: Asia/Kolkata`. Without it Jekyll renders dates in the *build* timezone (UTC on Pages), so `00:00:00 +0530` displays as 18:30 the previous day and **every post shows one day early** — on the homepage, on post pages, and in `search.json`. This is easy to miss locally, where the build machine is usually already in IST.

## Deploying

```bash
git add <files>
git commit -m "message"
git push origin main
```

GitHub Pages rebuilds automatically on push. Allow ~1 minute for changes to appear.
