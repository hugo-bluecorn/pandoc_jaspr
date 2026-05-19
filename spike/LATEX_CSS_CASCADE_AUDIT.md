# latex.css Cascade Audit (follow-up)

> Companion to `spike/LATEX_CSS_AUDIT.md`. The first audit was a **selector
> correspondence** check — does each latex.css selector target an element we
> emit? — and it confirmed coverage was high. What it did **not** check was
> the **cascade** between latex.css and the four other CSS layers already in
> the page. That gap caused the structural collapse we hit on first wire-up
> (paragraphs one-word-per-line, TOC overlapping the heading).
>
> This document is the deeper analysis the first audit should have included.

## What the first audit missed

The first audit answered:

> If the user adds a `<p>` to the page, does latex.css have a rule that
> targets it?

But it never asked:

> If latex.css's `body { max-width: 80ch; margin: 0 auto; padding: 2rem }`
> overrides the host page's `<body>`, what does that do to the host
> layout's flex containers?

The first question is about **selector coverage**. The second is about
**cascade conflict** — what wins when both stylesheets target the same
element, and what cascades to children unexpectedly.

A latex.css selector that "fires" can fire **destructively** when the host
layout assumed nothing else was touching that element.

## The four CSS layers in play

The page head, in cascade order, contains:

| Order | Layer | Source | What it sets |
|---|---|---|---|
| 1 | **ContentTheme reset** | `jaspr_content/lib/src/theme/_reset.dart` | `* { box-sizing: border-box }`, `html { line-height: 1.5em }`, `body { margin: 0 }`, `a { color: inherit; text-decoration: inherit }`, `b, strong { font-weight: bolder }`, plus a normalize-style reset for forms/tables. |
| 2 | **ContentTheme tokens** | `theme.dart`'s `build()`, via the `ContentTheme(...)` passed to `ContentApp`. | `:host,html { font-family: 'Open Sans', system-ui, ... }`, `body { color: …; background-color: … }` (when theme tokens are defined). Active in our setup — see `main.server.dart`. |
| 3 | **DocsLayout `_styles`** | `docs_layout.dart:77-191` | Layout chrome only: positioning of `.docs`, `.header-container`, `.sidebar-container`, `main`, `.content-container`, `aside.toc`, plus their child typography (`.content-header h1 { font-size: 2rem }`, `aside.toc h3 { font-size: .875rem }`, `aside.toc li { font-size: 14px }`). No body-level rules. |
| 4 | **latex.css** | Vendored `spike/example_app/web/latex.css` (linked by `LatexDocsLayout.buildHead`). | A full LaTeX-document stylesheet — body layout, typography, link colors, headings, environments, dark mode, etc. |
| 5 | **latex-overrides.css** | Our spike-authored overrides. | Currently: reset of latex.css's destructive body rules + `section.content > * + *` substitute for `article > * + *`. |

latex.css being **last among the linked stylesheets** means it wins
specificity ties against everything before it. That's the root cause of
every conflict below.

## Conflict-by-conflict analysis

Severity legend: 🔴 broke layout (already fixed); 🟠 visible bleed
into docs chrome (still active); 🟡 subtle / cosmetic; 🟢 harmless or
desired.

### 🔴 A. Body-level layout collapse (FIXED)

| Property | latex.css | host layout assumption |
|---|---|---|
| `max-width` | `80ch` | full viewport width — DocsLayout's fixed header, sticky sidebar, and sticky on-page TOC all position relative to body bounds |
| `margin` | `0 auto` | `0` (ContentTheme reset) — recentring breaks fixed positioning |
| `padding` | `2rem 1.25rem` | `0` — adds unexpected gutter |
| `min-height` | `100vh` | unset — forces extra height |
| `overflow-x` | `hidden` | unset — clips horizontally scrolling content |

**Why this happened.** latex.css is designed for documents where `<body>`
**is** the article (a single-page LaTeX paper). DocsLayout treats `<body>`
as a chrome container with flex children. The two contracts are
incompatible at the body level.

**Resolution applied.** `latex-overrides.css` resets `max-width / margin /
padding / min-height / overflow-x` on body. **Keeps** inherited typography
(`font-family`, `line-height`, `color`, `background-color`, `hyphens`,
`text-rendering`) on body — because those need to cascade to the article
content.

### 🟠 B. Font-family bleed into docs chrome (ACTIVE)

| Layer | Selector | font-family |
|---|---|---|
| ContentTheme tokens (layer 2) | `:host,html` | `'Open Sans', ui-sans-serif, system-ui, …` |
| latex.css (layer 4) | `body` | `'Latin Modern', Georgia, Cambria, 'Times New Roman', Times, serif` |

latex.css's `body` is the closer ancestor for every text node, and CSS
`font-family` is inherited. So **every text node on the page** — sidebar
links, header title, on-page TOC, footer, dialog content — renders in
serif, not the Open Sans the docs template ships with.

This is visible in the screenshot: "My Docs", "Overview", "Content",
"About", "Article" are all in Latin Modern serif.

**Whether that's a problem** is a design call. For a LaTeX-styled docs
site it may be desired (uniform serif). For a docs site with a typographic
distinction between "chrome = sans-serif" and "article = serif", it isn't.

### 🟠 C. Link-color bleed into chrome (ACTIVE)

| Layer | Selector | color |
|---|---|---|
| ContentTheme reset | `a` | `inherit` (link inherits surrounding text color) |
| latex.css | `a, a:visited` | `var(--link-visited)` — red (`hsl(0, 100%, 33%)`) |

latex.css's `a, a:visited` has equal specificity (0,0,1) to the reset's
`a`, but comes later, so it wins. **Every link** on the page is now
LaTeX-red, including:

- sidebar entries (Overview / Content / About / Article)
- on-page TOC entries
- header logo `<a href="/">`
- github-button link
- our parser-emitted article links

For some of these (TOC, article body), red is fine and arguably desired.
For sidebar/header chrome it's a visual surprise.

The narrower `a:not([class])` rule (`text-decoration-skip-ink: auto`) is
benign — it just enables under-the-baseline ink-skipping. The color rule
is the broad one.

### 🟡 D. Line-height bleed (ACTIVE)

| Layer | Selector | line-height |
|---|---|---|
| ContentTheme reset | `html` | `1.5em` |
| ContentTheme reset | `body` | `inherit` (so effectively 1.5em) |
| latex.css | `body` | `1.8` |

latex.css's 1.8 line-height cascades to every text node. Sidebar items,
TOC entries, and header text get a bit looser than the docs designer
intended. Cosmetic, not structural.

### 🟠 E. Theme system overlap (ACTIVE)

Two **independent dark-mode systems** are active simultaneously:

| System | Trigger | What it does |
|---|---|---|
| ContentTheme | `data-theme="dark"` on `<html>` — toggled by `ThemeToggle()` | Re-binds `--*-token` CSS variables for the docs chrome |
| latex.css | `@media (prefers-color-scheme: dark)` on `.latex-dark-auto`, OR `.latex-dark` class manually applied | Re-binds `--body-color` / `--body-bg-color` |

Because we don't apply `.latex-dark` or `.latex-dark-auto` to the body,
latex.css's dark-mode rules effectively never fire. The body
`color`/`background-color` stays at latex.css's light-mode values
regardless of what the user picks in the ThemeToggle.

**Net effect:** the theme toggle changes the docs chrome but not the
article body. The article stays light (latex.css's default) even after
the user toggles dark mode. A separate (smaller) consequence: the docs
template's `ContentTheme(background: ...)` value is silently overridden by
latex.css on body — the slate/zinc background tokens configured in
`main.server.dart` don't apply.

### 🟢 F. Heading typography overlap (PARTIALLY ALIGNED)

| Layer | Selector | Effect |
|---|---|---|
| latex.css | `h1` | `font-size: 2.5rem; line-height: 3.25rem; margin-bottom: 1.625rem` |
| latex.css | `h2` | `font-size: 1.7rem; line-height: 2rem; margin-top: 3rem` |
| latex.css | `h3`–`h6` | individual size + spacing |
| DocsLayout | `.content-header h1` | `font-size: 2rem; line-height: 2.25rem` |
| DocsLayout | `aside.toc h3` | `font-size: .875rem` |

DocsLayout's chrome-h1 (the page-title h1 the docs layout injects) and
chrome-h3 (the "On this page" TOC heading) win on specificity (one class
+ one tag = 0,1,1 vs latex.css's bare `h1`/`h3` = 0,0,1). Good — chrome
headings stay at chrome sizes.

But **our article headings** (parser-emitted h2/h3/h4) match the bare
latex.css selectors and get LaTeX heading typography. Also good — that's
the point.

No conflict here, **provided we accept latex.css's heading sizes as the
canonical "article heading" sizes**. They're slightly larger than the
docs designer's article-heading sizes would have been, but they're the
LaTeX-correct sizes.

### 🟡 G. Paragraph rules bleed (LATENT)

latex.css has `p { margin-top: 1rem }`, plus opt-in `.indent-pars p
{ text-indent: var(--text-indent-size) }`. We don't add `.indent-pars`, so
the indent doesn't activate. But `p { margin-top: 1rem }` fires on every
`<p>` — including the docs template's `.content-header p` (the page
description paragraph). That paragraph already has `margin-top: .75rem`
from DocsLayout, and `.content-header p` has higher specificity (0,1,1),
so the docs layout wins. **No actual conflict.**

### 🟢 H. Image rules (DESIRED)

latex.css's `img { max-width: 100%; height: auto; display: block }`
applies to:

- the sidebar logo (`<img src="/images/logo.svg">`)
- the article's figure image
- the GitHub button avatar

The `max-width: 100%` is the intended sane default; doesn't break the
chrome.

### 🟢 I. Anchor-link `outline` styling (DESIRED)

`a:focus { outline: 2px solid var(--link-focus-outline) }` provides a
visible focus ring on every link. Improvement over the docs default. No
conflict.

## What's actually broken right now

After our current `latex-overrides.css`, the layout is intact. The
remaining active bleeds are:

| Item | Severity | User-visible? |
|---|---|---|
| Sidebar / header text in Latin Modern serif | 🟠 B | Yes (screenshot confirms) |
| Sidebar / header links in LaTeX-red | 🟠 C | Yes (screenshot confirms) |
| Line-height 1.8 in chrome | 🟡 D | Subtle |
| Theme-toggle doesn't affect article colors | 🟠 E | Yes (toggle is a no-op for body) |
| ContentTheme background token overridden | 🟠 E | Body bg ≠ what main.server.dart configures |

None of these are bugs in the spike's stated acceptance criteria — the
page renders, the article is styled, the golden test diffs cleanly. But
they're **design tensions** worth deciding before the canonical
implementation.

## Recommended scoping strategy

The fundamental design choice is **where latex.css's stylings apply**:

| Option | What | Trade-off |
|---|---|---|
| **A. Everywhere (status quo)** | Let latex.css style body and inherit into all chrome | Uniform LaTeX look across the page. Costs: chrome typography surprises (serif headers, red sidebar links), dual-theme conflict, ContentTheme bg ignored. |
| **B. Article-content only** | Scope latex.css's typography & link colors to `section.content` (the wrapper jaspr_content emits around the parsed Pandoc tree). Chrome keeps its sans-serif Open Sans + theme-toggle-aware colors. | Cleanest separation. Costs: a wrapper-rewrite pass on latex.css (~15 selectors need rescoping: `body`, `p`, `a, a:visited`, `h1`–`h6`, `figure`, `figcaption`, `img`, `nav ol`, etc.). The dark-mode story stays clean because we drop latex.css's `body`-level color rules and let ContentTheme drive theming. |
| **C. Body but with chrome-restoring overrides** | Keep latex.css as-is. Add `latex-overrides.css` rules that re-assert chrome typography (font-family, line-height, link color) on `.docs .header-container`, `.docs .sidebar-container`, `.docs aside.toc`. | Smaller diff than B (~5 override rules vs a latex.css rewrite). Costs: the dark-mode conflict remains; ContentTheme bg still overridden. Brittle if DocsLayout adds new chrome zones. |

**Recommendation: Option B**, for the canonical implementation. For the
**spike**, Option C is fine — quicker, illustrates the trade-off without
diverging from upstream latex.css.

## Proposed Option-C overrides

If we want to extend `latex-overrides.css` now to neutralise the bleeds:

```css
/* Restore docs-chrome typography (latex.css's body font/line-height
 * inherits into every chrome zone). */
.docs .header-container,
.docs .sidebar-container,
.docs aside.toc {
  font-family:
    'Open Sans', ui-sans-serif, system-ui, sans-serif,
    'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol',
    'Noto Color Emoji';
  line-height: 1.5;
}

/* Restore chrome link colors (latex.css makes every link red). */
.docs .header-container a,
.docs .sidebar-container a,
.docs aside.toc a {
  color: inherit;
}

/* Let ContentTheme drive body color/background; drop latex.css's. */
body {
  color: inherit;
  background-color: inherit;
}
```

The body `color: inherit; background-color: inherit` rule un-pins
latex.css's hard-coded body colors and lets ContentTheme's earlier rule
(`body { color: ContentColors.text; background-color: ContentColors.background }`)
flow back into effect — including the dark-mode toggle.

## Where this leaves the spike

**No code changes required to satisfy SPIKE.md's acceptance criteria.**
The current state passes the golden test, renders the article, and the
audit findings are documented.

**Open question for the user:** apply the Option-C overrides now (small
spike-scoped fix), defer Option B to the canonical implementation, or
leave the spike at status quo and document the bleeds for review?

## What to write into the canonical Dart guidelines

From the cascade-conflict experience, the project's CSS-integration
guidance should include:

1. **For every third-party stylesheet, audit cascade-conflict before
   wiring.** A "does this selector match an element I emit?" check is
   necessary but not sufficient. Also check: does it set body-level
   layout properties? What does it inherit into descendants? Does it
   shadow a host theme system (color tokens, dark-mode triggers)?
2. **Prefer scoped CSS to whole-document CSS for embedded styling.**
   When a stylesheet is designed for "the whole document is the
   content," scope it to the content wrapper before linking.
3. **Document the cascade order** when multiple stylesheets are loaded.
   "latex.css after ContentTheme tokens" is load-bearing; reversing it
   would change behavior.
4. **Verify in-browser, not just by selector enumeration.** The first
   audit produced a clean analysis. It didn't catch the bug because the
   bug only appears when the page actually renders. Run `jaspr serve`
   and look before declaring done.
