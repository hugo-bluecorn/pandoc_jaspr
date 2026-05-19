# latex.css ↔ Jaspr / Pandoc Correspondence Audit

> Audit performed before wiring [vincentdoerig/latex-css](https://github.com/vincentdoerig/latex-css) into the spike. Two questions answered:
>
> 1. Do latex.css's selectors line up 1-to-1 with the HTML our Jaspr render produces?
> 2. Do they line up with the Pandoc JSON AST nodes the parser maps?
>
> The short answer is **yes, with one mandatory override and three optional upsides** — proceed.

## Method

- Fetched `style.css` from `github.com/vincentdoerig/latex-css@master` (785 lines, 101 unique selectors after dedup).
- Categorised selectors by whether they target a tag, a class, or a pseudo-state.
- Cross-referenced against:
  - the actual HTML produced by `jaspr serve` for `/article.pandoc/` (the spike's rendered article),
  - the parser's `_block` / `_inline` switches in `lib/src/pandoc_parser.dart`,
  - the README's MVP node-mapping table.
- Located the jaspr_content content wrapper at `packages/jaspr_content/lib/src/content.dart:33` (uses `<section class="content">`, not `<article>` — load-bearing for one finding below).

## Inventory: what latex.css styles

| Category | Count | Representative selectors |
|---|--:|---|
| Document-wide typography | ~8 | `html`, `body`, `:root`, `*::after`, `@font-face` |
| Headings | ~9 | `h1`–`h6`, `h1 + h2`, `h4 + h5`, `h5 + h6`, `h1:first-child` |
| Block elements (no class) | ~12 | `p`, `figure`, `figcaption`, `figcaption::before`, `img`, `table`, `td`, `caption`, `dl`, `dd`, `pre`, `pre code` |
| Inline elements (no class) | ~5 | `a:not([class])`, `a:focus`, `a:visited`, `code`, `kbd` |
| LaTeX-environment classes | ~10 | `.abstract`, `.abstract > h2`, `.author`, `.theorem`, `.lemma`, `.proof`, `.definition` + `::before`/`::after` markers |
| Sidenotes / footnotes | ~12 | `.sidenote`, `.sidenote-number`, `.sidenote-toggle:checked + .sidenote`, `.footnotes`, … |
| Article-level layout | 1 | `article > * + *` — *vertical rhythm rule, load-bearing, see §3* |
| TOC styling | ~3 | `nav ol`, `nav ol > li`, `nav ol > li::before` |
| Utility classes | ~30 | `.border-*-thick/thin`, `.col-N-l/r/c`, `.scroll-wrapper`, `.text-justify`, `.whitespace-nowrap`, `.break-all`, `.indent-pars`, `.no-indent`, `.latex-dark`, `body.libertinus`, `.latex span:nth-child(N)` |
| Misc | ~11 | `caption::before`, dark-mode prefs, reduced-motion, form controls (`select`, `textarea`), etc. |

**Totals:** 101 unique selectors. Roughly **30 fire on plain semantic HTML**, **45 are opt-in via class names**, and **25 target elements we don't emit** (tables, code, dl/dd, kbd, form controls — dead but harmless).

## §1 — latex.css selector → spike-emitted HTML

| latex.css selector group | Fires on our HTML? | Notes |
|---|---|---|
| `body`, `html`, `:root`, `*::after` | ✅ Always | Global typography (Latin Modern, sizing, spacing) applies to the whole page. |
| `h1`–`h6` and `h1 + h2`, `h4 + h5`, `h5 + h6`, `h1:first-child` | ✅ Yes | The parser's demoted output (h2/h3/h4) is fully covered. |
| `p` | ✅ Yes | Hits every `Para`. |
| `a:not([class])`, `a:focus`, `a:visited` | ✅ Yes | Our `<a>` carries only `href` / `title` / optional `id` — no class — so all three fire. |
| `figure`, `figcaption`, `figcaption::before` | ✅ Yes | Numbered figure-caption prefix renders. **Caveat:** the docs template's `Image` custom component wraps our `<figure>` in an outer `<figure class="image zoomable">`. Numbering may render twice; needs visual check. |
| `img` | ✅ Yes | `max-width: 100%` etc. apply. |
| `li` margin reset | ✅ Yes | Applies. |
| `ul[class]`, `ol[class]` margin reset | ❌ No | We emit unclassed `<ul>` / `<ol>`, so the reset doesn't fire — and that's correct: those lists keep their default LaTeX-like indented margins. The reset is intended for navigation lists. |
| `article > * + *` (1em between siblings) | ❌ **No — gap** | jaspr_content wraps content in `<section class="content">`, **not** `<article>` (`packages/jaspr_content/lib/src/content.dart:33`). The vertical-rhythm rule misses. Mandatory one-line override below. |
| `nav ol`, `nav ol > li`, `nav ol > li::before` | ❌ No | The docs layout renders the on-page TOC as a `<ul>` inside `<aside class="toc">`, not `<nav><ol>`. No conflict — the docs layout has its own TOC styling. |
| `table`, `td`, `caption`, `pre`, `code`, `kbd`, `dl`, `dd` | ❌ No | We don't emit any of these. Dead rules; cost is just a few bytes. |
| `em`, `strong` | ⚠️ Not explicitly styled | latex.css does not target them. Browser default italic / bold is the LaTeX-correct behavior — works, but no LaTeX-specific tuning. |

## §2 — Pandoc AST node → emitted HTML → latex.css coverage

| Pandoc AST node | Emits | latex.css coverage |
|---|---|---|
| `Header n` | `<h{n+1} id=…>` | ✅ Heading + adjacent-sibling spacing |
| `Para` | `<p>` | ✅ Margins, indent, justification |
| `Plain` | `<span>` *(see SELF_ASSESSMENT §4 — README says "bare children")* | ⚠️ `span` is not explicitly styled; inherits parent context. Fixing the parser bug removes the issue. |
| `BulletList` | `<ul><li>` | Partial — `li` margin reset fires; `<ul>` uses browser default (LaTeX-like) |
| `OrderedList` | `<ol [start=…]><li>` | Same as above |
| `Figure` | `<figure id=…>…<figcaption>` | ✅ `figure`, `figcaption`, numbered prefix |
| `Div` | `<div [id=…] [class=…]>` | 🟢 **Latent upside**: if a Pandoc author writes `\begin{theorem}…\end{theorem}` (or uses a fenced div `:::{.theorem}`), Pandoc emits `Div` with `class="theorem"` and latex.css's `.theorem`, `.lemma`, `.proof`, `.definition` rules auto-fire. Same for `.abstract`. The parser already passes Div classes through (`_attrToAttrs`). Zero MVP cost. |
| `Str` / `Space` / `SoftBreak` | `TextNode` | ✅ Inherits body typography |
| `LineBreak` | `<br>` | ✅ Browser default |
| `Emph` | `<em>` | ⚠️ Browser-default italic; LaTeX-correct but not tuned |
| `Strong` | `<strong>` | ⚠️ Same — browser-default bold |
| `Link` | `<a href=…>` | ✅ |
| `Image` | `<img src=… alt=…>` | ✅ Plus the docs template's `Image` custom component layers a zoomable wrapper |

## §3 — Gaps that matter

Ordered by impact.

1. **Mandatory: vertical rhythm.** `article > * + *` misses because jaspr_content wraps content in `<section class="content">`. **Fix:** ship a small override stylesheet (e.g. `spike/example_app/web/latex-overrides.css`) with:
   ```css
   section.content > * + * { margin-top: 1em; }
   ```
   One line; replicates the rule on the wrapper jaspr_content actually emits.

2. **Visual-check: figure double-wrap.** The docs template's `Image` custom component (registered with `zoom: true` in `main.server.dart`) wraps any `<img>` it sees in `<figure class="image zoomable"><img>…</figure>`. Our Pandoc `Figure` already emits `<figure id=…><img>…<figcaption>…`. Net result is nested `<figure>` elements; latex.css's `figcaption::before` numbering will fire on the inner figcaption, and the outer wrapper adds zoom CSS. Probably acceptable; confirm in the golden.

3. **Optional: map Pandoc `meta` (title, author, date).** latex.css has dedicated `.abstract`, `.author`, and `h1:first-child` rules tailored to the LaTeX `\maketitle` look. The parser currently drops `meta`. Mapping it later is free upside; not blocking the spike's golden.

4. **Latent: theorem / lemma / proof / definition / abstract environments.** Already work if the LaTeX uses them, because the parser passes Div classes through verbatim. Worth documenting as a feature once a real LaTeX manuscript exercises it.

5. **Linked: `Plain → <span>` parser bug** (SELF_ASSESSMENT §4). Independent of CSS, but the golden HTML will bake in the spurious `<span>` wrapper. Fixing the parser bug before capturing the golden is cleaner than retraining the golden later.

## §4 — Verdict

Correspondence is high. **No latex.css selector requires the parser to emit anything it doesn't already emit.** The 30-or-so plain-element selectors that fire automatically cover the MVP node set; the 45 class-driven selectors are opt-in (and the LaTeX-environment ones are latent freebies); the 25 selectors for tags we don't emit are inert.

The only structural gap is `article > * + *` not firing on `<section class="content">` — fixed by a one-line override.

**Proceed with: vendor latex.css + ship a small `latex-overrides.css` + link both from the layout.**

## §5 — Concrete changes to ship latex.css

1. Vendor `style.css` from `vincentdoerig/latex-css@master` into `spike/example_app/web/latex.css` (single file, no fonts needed — uses system Latin Modern fallbacks).
2. Add `spike/example_app/web/latex-overrides.css` with the `section.content > * + *` rule from §3.1.
3. Link both in the layout. The docs template's `Header` component takes a `meta:` slot, or we add a `<link>` via the `ContentApp`'s document-level configuration. (Spike-level: simplest is to inject via `head:` if `DocsLayout` supports it; otherwise put a `<link>` in `web/index.html`.)
4. (Optional but recommended) Fix `Plain → <span>` to emit bare children before capturing the golden.
5. `jaspr build` to produce `spike/example_app/build/jaspr/`.
6. Snapshot the article's HTML to `spike/golden/article.html` (or similar) and add a `dart test` or shell-based diff that re-runs the build and compares.

## §6 — Files surveyed

For the next session to retrace:

- `/tmp/latex.css` (downloaded from `https://raw.githubusercontent.com/vincentdoerig/latex-css/master/style.css`)
- `/home/hugo/ai/context/github/jaspr/packages/jaspr_content/lib/src/content.dart:33` — `section(classes: 'content', …)`
- `/home/hugo/ai/context/github/jaspr/packages/jaspr_content/lib/src/layouts/docs_layout.dart` — the layout we're using
- `spike/example_app/lib/main.server.dart` — `Image(zoom: true)` registration
- `lib/src/pandoc_parser.dart` — parser emits the HTML this audit measures
- `README.md` → MVP node-mapping table
- `spike/SELF_ASSESSMENT.md` §4 — the Plain → `<span>` bug
