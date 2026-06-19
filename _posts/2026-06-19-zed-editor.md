---
layout: post
title: "Zed Editor — Shortcuts and Settings"
date: 2026-06-19 00:00:00 +0530
categories: tools
tags: [zed, editor, productivity]
author: "Seroze"
published: true
---

*Zed is a fast, GPU-rendered editor written in Rust. This post covers the shortcuts you'll use daily and a few settings worth changing early on.*

---

## Installation

Download from [zed.dev](https://zed.dev). On Linux:

```bash
curl -f https://zed.dev/install.sh | sh
```

---

## Opening the settings file

Almost everything in Zed is configured via a JSON settings file. Open it with:

- `Ctrl+,` (Linux/Windows) / `Cmd+,` (Mac)

Or via the command palette (`Ctrl+Shift+P`) → type `open settings`.

---

## Essential shortcuts

All shortcuts use `Ctrl` on Linux/Windows and `Cmd` on Mac.

### Navigation

| Action | Linux/Windows | Mac |
|---|---|---|
| Toggle project file tree | `Ctrl+B` | `Cmd+B` |
| Quick open file | `Ctrl+P` | `Cmd+P` |
| Command palette | `Ctrl+Shift+P` | `Cmd+Shift+P` |
| Go to line | `Ctrl+G` | `Ctrl+G` |
| Go to definition | `F12` | `F12` |
| Find all references | `Shift+F12` | `Shift+F12` |
| Go to symbol in file | `Ctrl+Shift+O` | `Cmd+Shift+O` |
| Go to symbol in project | `Ctrl+T` | `Cmd+T` |
| Switch between recent files | `Ctrl+Tab` | `Ctrl+Tab` |

### Editing

| Action | Linux/Windows | Mac |
|---|---|---|
| Select next occurrence | `Ctrl+D` | `Cmd+D` |
| Select all occurrences | `Ctrl+Shift+L` | `Cmd+Shift+L` |
| Move line up / down | `Alt+Up` / `Alt+Down` | `Alt+Up` / `Alt+Down` |
| Duplicate line | `Ctrl+Shift+D` | `Cmd+Shift+D` |
| Delete line | `Ctrl+Shift+K` | `Cmd+Shift+K` |
| Toggle line comment | `Ctrl+/` | `Cmd+/` |
| Indent / outdent | `Tab` / `Shift+Tab` | `Tab` / `Shift+Tab` |
| Format document | `Ctrl+Shift+I` | `Cmd+Shift+I` |

### Search

| Action | Linux/Windows | Mac |
|---|---|---|
| Find in file | `Ctrl+F` | `Cmd+F` |
| Find in project | `Ctrl+Shift+F` | `Cmd+Shift+F` |
| Replace in file | `Ctrl+H` | `Cmd+H` |

### Panes and panels

| Action | Linux/Windows | Mac |
|---|---|---|
| Split editor right | `Ctrl+\` | `Cmd+\` |
| Close active tab | `Ctrl+W` | `Cmd+W` |
| Toggle terminal | `Ctrl+\`` | `Ctrl+\`` |
| Toggle git panel | `Ctrl+Shift+G` | `Cmd+Shift+G` |

---

## Disabling auto-completion

Auto-completion is useful day-to-day but distracting during coding interviews — it gives hints you shouldn't rely on when you're being evaluated.

Open settings (`Ctrl+,`) and add:

```json
{
  "show_completions_on_input": false
}
```

This stops completions from appearing as you type. You can still trigger them manually on demand with `Ctrl+Space` when you actually want a suggestion.

To turn it back on after the interview, either remove the setting or set it to `true`.

A cleaner approach if you switch modes often — keep two settings profiles or just toggle via the command palette:

```
Ctrl+Shift+P → "toggle auto complete"
```

---

## Other settings worth changing early

Open settings (`Ctrl+,`) and paste these in. Each line is independent — add only what you want.

```json
{
  "show_completions_on_input": false,

  "ui_font_size": 16,
  "buffer_font_size": 14,
  "buffer_font_family": "JetBrains Mono",

  "tab_size": 4,
  "hard_tabs": false,

  "autosave": "on_focus_change",

  "format_on_save": "on",

  "vim_mode": false,

  "theme": "One Dark"
}
```

**`autosave: on_focus_change`** — saves the file whenever you switch away from it. Eliminates the need to ever press `Ctrl+S`.

**`format_on_save`** — runs the formatter (Prettier, rustfmt, etc.) automatically on every save. Keeps code clean without thinking about it.

---

## The command palette

`Ctrl+Shift+P` opens the command palette — a searchable list of every action in Zed. If you can't remember a shortcut, open the palette and type what you want. It also shows the keyboard shortcut next to each action so you learn them over time.

Some useful ones to search for:

- `toggle inlay hints` — shows inferred types inline (useful for Rust/TypeScript)
- `revert file` — discard all unsaved changes in the current file
- `copy relative path` — copies the file path relative to the project root
- `sort lines` — sorts selected lines alphabetically

---

## Quick reference card

```
Ctrl+B          Toggle file tree
Ctrl+P          Open file
Ctrl+Shift+P    Command palette
Ctrl+,          Settings
Ctrl+Shift+F    Search in project
Ctrl+D          Select next match
Ctrl+/          Comment line
Ctrl+\          Split pane
Ctrl+`          Terminal
F12             Go to definition
```

**Interview prep:** set `"show_completions_on_input": false` in settings before you start. Toggle back with `Ctrl+Space` when you want a hint.
