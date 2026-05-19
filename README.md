# pandoc_jaspr

A Dart package that converts [Pandoc](https://pandoc.org/) output into [Jaspr](https://github.com/schultek/jaspr) components, so a LaTeX book can be rendered as a Jaspr-driven static website (e.g. GitHub Pages).

> **Status:** design stage. No production code yet. This document captures the locked-in MVP design. See "Pending before implementation" at the bottom for the project gates that must be in place before any `.dart` is written.

## What this package is for

The author writes a book in LaTeX (edited in Kile). They want to publish the same content on the web as a two-pane reader — a table-of-contents sidebar on the left, the current chapter on the right — without maintaining a separate web-only copy of the manuscript.

`pandoc_jaspr` is the glue. It consumes Pandoc's JSON AST and exposes Jaspr primitives (a parser, a chapter splitter, a TOC component) that a Jaspr app composes into whatever layout the author wants.

## The two-repo workflow

```
  ┌──────────────────────────┐                ┌──────────────────────────┐
  │ LaTeX project (own repo) │                │ Jaspr project (own repo) │
  │                          │                │                          │
  │   main.tex               │   pandoc -f    │   build/book.pandoc.json │
  │   chapters/*.tex         │  latex -t json │            │             │
  │   figures/*.png          │ ─────────────► │            ▼             │
  │   mybook.kilepr          │                │   uses pandoc_jaspr      │
  │                          │                │            │             │
  │   edited in Kile         │                │            ▼             │
  └──────────────────────────┘                │   jaspr build → static   │
                                              │   HTML → GitHub Pages    │
                                              └──────────────────────────┘
```

- The **LaTeX repo** stays clean: Kile project, `.tex` sources, figures, bibliography. Nothing Dart/Jaspr-related leaks in.
- The **Jaspr repo** consumes a pre-converted `*.pandoc.json` file. Pandoc itself does not need to be installed on the Jaspr build machine (e.g. the GitHub Pages CI runner).
- The handoff is the JSON file. It can be committed into the Jaspr repo, pulled in as a build artifact from the LaTeX repo's CI, or wired in however the author prefers — `pandoc_jaspr` does not care.

## Canonical LaTeX book layout (input)

The package assumes a standard multi-file Kile book project:

```
mybook/
  mybook.kilepr
  main.tex                   # \documentclass{book}, \include's chapters
  preamble.tex
  chapters/
    ch01-introduction.tex    # each starts with \chapter{Title}
    ch02-foo.tex
    ...
  figures/
    fig01.png                # PNG/JPG/SVG only — PDF figures don't render in browsers
  references.bib             # not used in MVP
```

`pandoc -f latex -t json main.tex` produces **one flat JSON document for the whole book** — Pandoc follows `\include`/`\input` transparently. With the `book` documentclass, `\chapter` lowers to a level-1 header, `\section` to level 2, etc.

## How it maps to Jaspr

The Jaspr-side integration uses [`jaspr_content`](https://pub.dev/packages/jaspr_content), which already provides every piece of UI infrastructure we need:

| Jaspr_content piece | Role |
|---|---|
| `PageParser` | Interface our `PandocParser` implements. |
| `Node` / `ElementNode` / `TextNode` / `ComponentNode` | Intermediate tree our parser emits. |
| `TableOfContentsExtension` | Walks the parsed nodes, builds a `TableOfContents` of `TocEntry { text, id, children }`. |
| `DocsLayout`, `Sidebar`, `SidebarGroup` | The two-pane reader layout. |
| `Image` component | Rendering `\includegraphics`. |

The package itself ships only what's missing:

1. A Dart model of the Pandoc AST (sealed `Block` and `Inline` hierarchies).
2. A JSON decoder for `*.pandoc.json`.
3. `PandocParser implements PageParser` — maps the MVP node subset to a `Node` tree, drops the rest with a debug log.
4. A book splitter that divides the AST into chapters on `Header level=1` boundaries.
5. A standalone `TocList`-style component that renders a `TableOfContents` as a nested `<ul>` of anchor links — positionable anywhere by the consumer.

The example app under `example/` will compose these into a small `ContentApp` with a sample book.

## MVP scope

**Pandoc AST nodes the parser maps to HTML:**

| Pandoc | HTML / Node | Notes |
|---|---|---|
| `Header n attr inlines` | `<h{n} id=…>` | n=1 is chapter title, used as route boundary |
| `Para inlines` | `<p>` | |
| `Plain inlines` | bare children | Used inside list items, figure captions |
| `BulletList` | `<ul><li>…` | |
| `OrderedList` | `<ol><li>…` | List style attrs ignored in MVP |
| `Figure attr caption blocks` | `<figure id=…>` with `<figcaption>` | |
| `Div attr blocks` | `<div class=… id=…>` | Passes through attrs verbatim |
| `Str` / `Space` / `SoftBreak` | `TextNode` | |
| `LineBreak` | `<br>` | |
| `Emph` / `Strong` | `<em>` / `<strong>` | |
| `Link attr inlines (url, title)` | `<a href=…>` | |
| `Image attr alt (url, title)` | `<img src=… alt=…>` | |

**Dropped with a debug log (out of MVP, future milestones):**
`Math`, `RawInline`, `RawBlock`, `Code`, `CodeBlock`, `Table`, `Note`, `Cite`, `DefinitionList`, `LineBlock`, `HorizontalRule`, `BlockQuote`, `Strikeout`, `Underline`, `Superscript`, `Subscript`, `SmallCaps`, `Quoted`, `Span`.

This covers the bulk of straightforward narrative prose with figures. Math, tables, code blocks, and citations are the obvious "next" milestones but are not part of MVP.

## Routing

- One route per chapter.
- Chapters are derived by splitting the book AST on `Header level=1` boundaries.
- Each chapter's URL slug comes from the chapter header's id. Pandoc auto-generates an id from the title (`\chapter{The Beginning}` → `the-beginning`). Authors who want stable URLs even if a chapter title changes should use `\label{ch:intro}` in the `.tex`.
- The book-wide TOC (chapters and their sections) is computed once from the full AST and passed to the sidebar.

## Component philosophy

Every Jaspr component this package exposes must be positionable anywhere by the consumer — none are coupled to a particular layout. Defaults (e.g. a starter `DocsLayout` configuration in the example app) are convenience, not contract. The author wants to be able to drop the section TOC into a right-rail, a floating drawer, or inline at the top of a chapter without forking anything.

## What's intentionally out

The package does **not**:

- Shell out to Pandoc. Pandoc runs in the LaTeX repo's workflow, not at Jaspr build time. (A tiny optional `dart:io` helper for local dev convenience may be added later but is not part of the core surface.)
- Handle LaTeX it can't already get through Pandoc. If Pandoc can't parse it, this package can't help.
- Try to be a general-purpose Pandoc binding. The AST is modeled in full so the decoder doesn't break on unknown nodes, but the Jaspr mapping only covers what the MVP needs.
- Generate `.dart` source files at build time. Output is a runtime `Component` tree, matching the pattern used by `MarkdownParser` and `HtmlParser` in `jaspr_content`.

## Dart language and ecosystem target

- SDK: target the latest released stable Dart. As of 2026-05-19 that's **3.11.x** (3.11.6 was released 2026-05-05). 3.12 and 3.13 exist in the SDK changelog but are still marked "Unreleased."
- Lints: keep `lints: ^6.0.0` (the current pin).
- Sealed classes + exhaustive switch expressions are the right tool for the Block/Inline model — both have been stable since Dart 3.0.

## Pending before implementation

Three things must exist in this repo before any production `.dart` is written:

1. **Dart code guidelines for this project** — style, naming, sealed-class conventions, JSON decoding approach, error handling, public-API surface rules.
2. **A TDD process** — test layout, fixture strategy (small handcrafted `*.pandoc.json` fixtures vs. real Pandoc invocations), coverage expectations, red-green-refactor discipline.
3. **An explicit KISS / YAGNI directive** for this project — so future scope-creep can be rejected by pointing at a written rule rather than relitigated.

Until these are in place, work in this repo is limited to design, documentation, and memory.

### Sources surveyed (no adoption yet)

The following have been investigated as possible inputs to the three gates. **None are adopted at this time.** Listed for future reference:

- **Official Flutter/Dart AI documentation** — https://docs.flutter.dev/ai (AI Rules + Agent Skills + AI Coding Assistants). Framework-agnostic Dart guidance applies in full; Flutter-specific content does not.
- **`dart-lang/skills`** — https://github.com/dart-lang/skills. Official Dart-team SKILL.md collection (unit tests, package dependency resolution, static analysis fixes).
- **`very_good_analysis`** — https://pub.dev/packages/very_good_analysis. VGV's strict lint ruleset (~188 rules vs ~101 in `package:lints/recommended`).
- **VGV Wingspan** — https://github.com/VeryGoodOpenSource/vgv-wingspan. Tech-agnostic Claude Code plugin for SDLC workflow (`/brainstorm` → `/plan` → `/build` → `/review`). Cloned locally at `/home/hugo/ai/context/github/VeryGoodOpenSource/vgv-wingspan` for reference.
- **VGV AI Flutter Plugin** — https://github.com/VeryGoodOpenSource/vgv-ai-flutter-plugin. 13 skills across architecture, testing, accessibility, security, etc. Mostly Flutter-specific; only Architecture, Testing, License Compliance, and SDK-upgrade skills transfer to a pure-Dart package.

**Decision deferred (2026-05-19):** none of the above are installed or referenced from this repo's config yet. The next decision is which combination informs each of the three gates.

## Reference repositories

Locally checked out for research (not part of the build):

- Jaspr: `/home/hugo/ai/context/github/jaspr` — particularly `packages/jaspr_content/lib/`
- Pandoc: `/home/hugo/ai/context/github/pandoc` — particularly `doc/filters.md` and `MANUAL.txt`
- Dart SDK: `/home/hugo/ai/context/github/dart-lang/sdk` — `CHANGELOG.md` for language-feature provenance
