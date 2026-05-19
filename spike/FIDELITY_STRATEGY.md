# Fidelity Strategy — What Is the Project Faithful To?

> Captured from a design discussion mid-spike. Not a decision yet — a
> framing the canonical implementation needs to make a call on, with the
> trade-offs already on the table.
>
> Companion to `LATEX_CSS_AUDIT.md`, `LATEX_CSS_CASCADE_AUDIT.md`, and
> `COMPARED_LATEX_JASPR.md`. Read those for the evidence behind the
> trade-offs below; this doc is the question they all converge on.

## The question

"As close to LaTeX as possible" has two practically different meanings,
and `pandoc_jaspr` and `/home/hugo/for_fun/latex_jaspr` sit at opposite
ends of them:

### Reading A — looks like a LaTeX *paper*

A single-page document where `<body>` *is* the article. No header. No
sidebar. No theme toggle. Margins, line length, and typography all
mirror a `.tex` compiled by `pdflatex`.

This is what `latex_jaspr` does: hand-authored CSS per component,
vendored Computer Modern fonts, every rule traceable to a specific
LaTeX construct in the source. ~10 KB per route, two-layer CSS cascade,
zero conflict surface.

### Reading B — renders LaTeX *content* in a web-native reader

A multi-chapter manuscript where the web rendering adds chrome the
print PDF doesn't have — sidebar navigation between chapters, in-page
TOC, responsive layout, optional dark mode, deep-linkable section
anchors.

This is what the spike does, and what `README.md` sketches in the
"two-pane reader" diagram. The chrome comes from `jaspr_content`'s
`DocsLayout` for free; the LaTeX look comes from a generic third-party
`latex.css` stacked on top. ~44 KB per route, five-layer CSS cascade,
conflict surface catalogued in `LATEX_CSS_CASCADE_AUDIT.md`.

## Why this matters

The two readings have **different fidelity ceilings**:

- **Reading A's ceiling is high** because nothing else is fighting the
  author's typographic decisions. If the manuscript specifies XCharter,
  you vendor XCharter. If it specifies 11pt body with 1.2em leading,
  you write that exact rule. The PDF and the web page can be nearly
  pixel-identical.
- **Reading B's ceiling is lower** because the third-party `latex.css`
  encodes *its* idea of what LaTeX looks like — Latin Modern fallbacks,
  red links, 1.8 line-height, 80ch text width, etc. A real manuscript
  asking for 9pt Charter with 1.1em leading will *resemble* but not
  match its PDF.

If the author's book has specific typographic intent (chosen fonts,
chosen sizes, chosen margins), Reading A is the only way to honor it.
If the author just wants "a web page that visually says LaTeX,"
Reading B is enough.

## The hybrid worth considering

It is not all-or-nothing. The spike picked the most "jaspr_content-ish"
path; latex_jaspr picked the least. A middle path:

> **Keep `jaspr_content`** for `FilesystemLoader`, multi-route,
> `TableOfContentsExtension`, `HeadingAnchorsExtension`. **Drop the
> third-party `latex.css`.** Author the article-content CSS by hand,
> scoped to a `pandoc-article` wrapper around the parser's output.
> **Vendor the fonts** the manuscript actually uses.

This keeps the chrome and the toolchain — the things `jaspr_content`
gives the spike that `latex_jaspr` would have to reimplement — but
moves all article typography under project control. Cascade collapses
from five layers to four (the third-party CSS layer disappears), and
all four are project code, so conflicts are intentional rather than
discovered. Same architectural shape as **Option B** in
`LATEX_CSS_CASCADE_AUDIT.md` §scoping-strategy.

The fidelity insight `latex_jaspr` adds on top: **don't rely on a
generic "looks like LaTeX" library — match a *specific* LaTeX
font/macro set the way `latex_jaspr` matches `Jakes-Resume.tex`**.

## Decision the canonical implementation needs to make

Pick which question to answer:

| Question | Implication |
|---|---|
| "Match the author's specific PDF as closely as the browser allows." | Reading A discipline applied to a book. Vendor the manuscript's fonts. Project-authored CSS per Pandoc node type. Cite the LaTeX source for non-obvious rules. Treat the third-party `latex.css` as research, not as runtime code. |
| "Make any Pandoc-source manuscript look reasonably LaTeX-y in a browser." | Reading B is enough. The spike's current shape is on the right track; the cascade conflicts are the cost. The remaining work is scoping latex.css to article content only (Option C) or rescoping its selectors to a wrapper (Option B). |
| "Both — match the PDF when the manuscript supplies the fonts, else fall back to a generic LaTeX look." | Hardest. Likely overengineered for an MVP. Worth revisiting once a real consumer has hit the limits of Reading B. |

`README.md`'s current scope — "minimal MVP, text + images, ~12 Pandoc
node types" — is closer to Reading B. But the project's longer-term
contract (the author writes a book in Kile, wants it on the web) is
closer to Reading A. **The MVP and the long-term goal point in
different directions on this axis.** Naming this tension now means it
doesn't have to be re-discovered later.

## Open questions for the next session

1. **What's the author's actual typographic intent for their manuscript?**
   Does the `.tex` declare a font package (`\usepackage{charter}`,
   `\usepackage{fontspec}…`)? Does it customize margins? If yes, the
   project should plan for Reading A; the MVP can be Reading B but the
   path forward is clear.
2. **Is the `latex.css` chrome bleed (sidebar in serif, links in red)
   acceptable as a permanent state, or is it a spike-only stopgap?**
   That answer determines whether canonical work should rescope latex.css
   or drop it.
3. **If the canonical implementation goes Reading B, is a "looks like a
   LaTeX paper" preview mode useful** — a route that strips the chrome
   and renders the article alone in a near-pdflatex view? That'd be a
   small extension; the parser doesn't change, only a second layout
   without sidebar / header / TOC.

## What to write into the project's KISS / YAGNI directive

From this discussion:

- **Pick one fidelity reading and stick with it for the MVP.** Don't
  build for both at once.
- **If Reading A**: vendor fonts, hand-author CSS, cite the source.
  Forbid third-party "LaTeX-look" CSS libraries.
- **If Reading B**: cap the CSS work at "the article looks
  recognisably LaTeX-y"; defer pixel-fidelity to a later milestone.
- **In either case**: scope third-party CSS to the article content,
  never to `body`. The spike's structural-collapse bug was the cost
  of letting latex.css touch the document root.
