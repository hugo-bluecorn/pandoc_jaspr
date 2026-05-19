# pandoc_jaspr spike vs. `/home/hugo/for_fun/latex_jaspr`

> Both projects render a LaTeX-styled document with Jaspr. They have made
> opposite architectural choices about almost every CSS decision. This
> note catalogs the differences and where each approach pays.

## 30-second TL;DR

| Dimension | pandoc_jaspr spike | latex_jaspr |
|---|---|---|
| **What it renders** | Generic Pandoc JSON AST → docs-site article | One specific LaTeX document (Jake Ryan resume) with macro-faithful Jaspr components |
| **CSS source** | Vendored third-party `latex.css` (785 lines) + small override file | 100% hand-authored, per-component, Dart-emitted |
| **CSS authoring** | External `.css` files linked via `<link>` | Dart `@css static List<StyleRule>` per component + global `theme.dart` |
| **Layout host** | `jaspr_content`'s `DocsLayout` (header, sidebar, on-page TOC) | Plain `Document(body: App())`, no chrome |
| **Typography** | Generic "looks-like-LaTeX" CSS via Vincent Doerig's library | Self-hosted Computer Modern (CMU Serif) `.otf` files matched to the actual pdflatex output of the source `.tex` |
| **Fonts** | System Latin Modern fallbacks via OS | Vendored `.otf` files under `web/fonts/`, declared in one hand-written `fonts.css` |
| **Theme switching** | jaspr_content's `ContentTheme` + `ThemeToggle` (dark/light) — partly broken by latex.css cascade | Per-route font swap (CMU Serif / Fira Sans / Roboto / Noto Sans / Source Sans Pro / XCharter) via `.font-*` wrapper classes; no dark mode |
| **Cascade layers in `<head>`** | 5: ContentTheme reset → ContentTheme tokens → DocsLayout `_styles` → latex.css → latex-overrides.css | 2: `@import fonts.css` → consolidated `@css`-emitted `<style>` block |
| **Output size per route** | ~44 KB | ~10 KB |

The two projects sit at opposite ends of the **generic-vs-bespoke** axis.
The spike trades fidelity for generality; latex_jaspr trades generality
for fidelity.

## 1. CSS sourcing: vendored third-party vs. hand-authored per-component

### pandoc_jaspr spike

External, vendored:

```
spike/example_app/web/
├── latex.css            # 785 lines — vincentdoerig/latex-css, MIT
└── latex-overrides.css  # ~20 lines — body reset + section.content rhythm
```

Linked via `<link rel="stylesheet">` injected by a `LatexDocsLayout`
subclass that overrides `buildHead`.

**Sourcing philosophy**: pull a known-good "looks like LaTeX" stylesheet
off the shelf. Don't write CSS by hand.

**Cost paid**: third-party CSS is opinionated about body-level layout,
theme variables, link colors, and font-family — which collides with the
host layout's assumptions (see `spike/LATEX_CSS_CASCADE_AUDIT.md`).
Fixing those collisions is now spike maintenance.

### latex_jaspr

Hand-authored. Every component carries its own styles:

```dart
class ResumeArticle extends StatelessComponent {
  // ...
  @css
  static List<StyleRule> get styles => [
    css('.resume').styles(
      maxWidth: 523.44.pt,
      margin: Spacing.symmetric(vertical: 36.pt, horizontal: Unit.auto),
      padding: Spacing.zero,
      textAlign: TextAlign.left,
    ),
  ];
}
```

(523.44pt isn't arbitrary — it matches the .tex's effective `\textwidth`
after the `\addtolength` margin tweaks for a4paper.)

Global styles in one place (`lib/constants/theme.dart`):

```dart
@css
List<StyleRule> get styles => [
  css('html, body').styles(
    margin: Margin.zero,
    padding: Padding.zero,
    fontFamily: const FontFamily.list([
      FontFamily('CMU Serif'), FontFamilies.serif,
    ]),
    fontSize: 11.pt,
    color: const Color('#000'),
    lineHeight: 1.2.em,
  ),
  css('a').styles(
    color: const Color('inherit'),
    textDecoration: const TextDecoration(line: TextDecorationLine.underline),
  ),
  // ...per-font wrapper classes...
];
```

**Sourcing philosophy**: every CSS rule is derived from a specific line
of LaTeX in the source document. The comments cite the LaTeX construct
each rule maps to (`\titleformat{\section}…`, `\extracolsep{\fill}`, etc.).

**Cost paid**: every new visual feature needs new Dart code. No
prebuilt "make it look LaTeX" button — but every rule is intentional.

## 2. Font handling

### pandoc_jaspr spike

latex.css declares no `@font-face`. It relies on system fonts via:

```css
font-family: 'Latin Modern', Georgia, Cambria, 'Times New Roman', Times, serif;
```

If the user's machine has Latin Modern installed, great. Otherwise it
falls back to Georgia. No fonts are vendored. There's a `body.libertinus`
opt-in for Libertinus if the user has it.

**Trade-off**: zero-config, but the actual rendering depends on what the
viewer's OS has. Same site can look subtly different on different boxes.

### latex_jaspr

Vendors actual `.otf` files for six font families under `web/fonts/`:

```
web/fonts/
├── cmunrm.otf  cmunbx.otf  cmunti.otf  cmunbi.otf       # CMU Serif
├── firasans/   FiraSans-{Regular,Bold,Italic,BoldItalic}.otf
├── roboto/     Roboto-{Regular,Bold,Italic,BoldItalic}.ttf
├── notosans/   NotoSans-{...}.ttf
├── sourcesanspro/  SourceSansPro-{...}.otf
└── xcharter/   XCharter-{Roman,Bold,Italic,BoldItalic}.otf
```

Declared in a hand-written `web/fonts/fonts.css` (because Jaspr's typed
`css.fontFace()` builder doesn't support `font-weight`):

```css
@font-face {
    font-family: "CMU Serif";
    src: url("/fonts/cmunrm.otf");
}
@font-face {
    font-family: "CMU Serif";
    font-weight: bold;
    src: url("/fonts/cmunbx.otf");
}
/* …italic, bold-italic… */
```

Imported once at the Document level:

```dart
runApp(Document(
  title: 'Jake Ryan',
  styles: [css.import('fonts/fonts.css')],
  body: App(),
));
```

**Trade-off**: deterministic — every viewer sees Computer Modern
glyphs, not OS-dependent fallbacks. Page weight increases per route
(font files served from `/fonts/`), but each viewer caches them across
routes.

**Why this matters for our spike**: latex.css's typographic claim
("looks like LaTeX") rests on the viewer happening to have Latin Modern.
For most Linux/macOS users this is true if they have texlive; for
typical Windows or mobile viewers it's false. A faithful renderer
should vendor the fonts.

## 3. CSS authoring model: linked files vs. `@css`

### pandoc_jaspr spike

Stylesheets live as plain `.css` files served from `web/`. The
`LatexDocsLayout` subclass adds `<link>` elements in `buildHead`. Two
strict separations exist:

- **Static CSS in `web/`** — `latex.css`, `latex-overrides.css`.
- **Dart-emitted CSS** — every `jaspr_content` layout (`DocsLayout._styles`)
  and theme reset (`ContentTheme.build()`) are still Dart-side, baked
  into the HTML via inline `<style>`.

So the spike runs **both** styles of CSS authoring side by side. The
spike adds external CSS but inherits Dart-emitted CSS from
`jaspr_content`.

### latex_jaspr

CSS is **always** Dart-emitted via `@css static List<StyleRule>` —
except for the one `fonts.css` (justified specifically by the
`css.fontFace` limitation, with the comment citing
`apps/fluttercon` in the jaspr repo as the precedent).

The build consolidates every component's `@css` declaration into one
inline `<style>` block per page. Cascade order is the order Jaspr
serializes them — predictable.

**Pros of per-component `@css`:**

- Style and component live in the same file → grep-friendly.
- Refactor a component, refactor its styles.
- No cross-file selector conflicts to track manually.
- CSS that is actually used ships; unused selectors don't.

**Cons:**

- Selectors are global despite living per-component (CLAUDE.md flags
  this explicitly: "`@css` is not style-scoped. Use unique class
  names"). The discipline is "every component picks a unique class
  prefix" (`.resume-…`).
- Pseudo-classes / variables / media queries / keyframes require the
  `raw: {...}` escape hatch when the typed `Styles` API doesn't
  cover them. The spike has no equivalent friction because it just
  writes hand CSS.

## 4. Cascade design

This is where the projects diverge most dramatically.

### pandoc_jaspr spike: a 5-layer cascade

Documented in detail at `spike/LATEX_CSS_CASCADE_AUDIT.md`:

```
1. ContentTheme reset (Dart-emitted, body { margin: 0 })
2. ContentTheme tokens (Dart-emitted, :host,html { font-family: Open Sans })
3. DocsLayout._styles (Dart-emitted, .docs/.header/.sidebar/main/.content layout)
4. latex.css (linked, body { max-width 80ch; margin: 0 auto; … })
5. latex-overrides.css (linked, body reset + section.content > * + * rhythm)
```

Conflicts are inevitable because latex.css and the ContentTheme/DocsLayout
trio both make body-level decisions. The cascade audit catalogs nine
conflict zones; one was a render-breaking layout collapse (fixed); the
rest are still-active visual bleeds (chrome font goes serif, chrome
links go LaTeX-red, theme toggle is a no-op for article body).

### latex_jaspr: a 2-layer cascade

```
1. fonts.css (linked, @font-face only)
2. Consolidated @css block (Dart-emitted, all component + theme styles)
```

There is **no third-party stylesheet**. Every rule is intentional and
written for this app. Cascade conflicts can only arise between rules
this project's own author wrote — and the discipline of unique class
prefixes per component sidesteps even that.

**Net effect**: cascade behavior is fully predictable. The
"chrome-font-goes-serif" class of bug that bit the spike is structurally
impossible here, because there is no chrome to bleed into.

## 5. Layout host

### pandoc_jaspr spike

`DocsLayout` from jaspr_content gives us — out of the box —

- Sticky header
- Sticky sidebar with collapsible nav
- On-page table-of-contents aside (via `TableOfContentsExtension`)
- Light/dark theme toggle
- Heading anchor links
- Responsive breakpoints (mobile/tablet/desktop)

…all of which is roughly 110 lines of Dart in `docs_layout.dart` (the
`_styles` static), implementing flex/grid/sticky positioning.

That's a lot of chrome to add CSS-collision surface for free. The price
of having it is the cascade conflicts above.

### latex_jaspr

`Document(body: App())` — App is a `Router` with six routes — each
`Page` is a thin `<div class="font-*">` wrapper around `<ResumeBody>`.
No chrome. The page IS the resume.

This is fine because the project's content is *a single document*. The
trade-off would not scale to "render a 12-chapter book with a TOC and
chapter navigation" — that's where the spike's choice to adopt
jaspr_content pays.

## 6. Page footprint

| | spike `/article.pandoc` | latex_jaspr `/` |
|---|--:|--:|
| HTML bytes | 44,356 | 9,956 |
| `<style>` blocks | 1 (inline) | 2 (`@import fonts.css` + main block) |
| `<link rel="stylesheet">` | 2 (latex.css + overrides) | 0 |
| Reusable `@css` rules baked into HTML | many (DocsLayout chrome) | all (consolidated) |
| Cached after first load | latex.css + latex-overrides.css + fonts (OS) | fonts.css + .otf files |

The spike's HTML is ~4.4× larger per route, mostly because DocsLayout's
inline `<style>` block carries the layout chrome. latex_jaspr's HTML is
nearly content-only.

## 7. What each project could learn from the other

### What pandoc_jaspr could borrow from latex_jaspr

1. **Vendor the font.** Drop a `CMU Serif` or `Latin Modern` `.otf` set
   under `web/fonts/` and a `fonts.css` declaring them. Stop trusting
   the viewer's OS to have Latin Modern.
2. **Per-component `@css` for the article-specific styles** (the
   parser-emitted output). Right now the spike has zero project-side
   CSS — *all* visual decisions live in latex.css. A `pandoc-article`
   wrapper class with project-defined typography would scope the look
   to the article content and stop bleeding into chrome.
3. **Cite the source.** latex_jaspr's CSS comments name the LaTeX
   construct each rule mirrors (`// \titleformat{\section}{…}`). Useful
   discipline for a project whose contract is "render LaTeX faithfully."
4. **Reproduction recipe** (`RECREATE.md`). Granular enough that a
   second person could rebuild the project from an empty directory.
   pandoc_jaspr would benefit when the spike gets re-attempted.

### What latex_jaspr could borrow from pandoc_jaspr

1. **A real parser**. latex_jaspr hand-transcribes the .tex file into
   Jaspr components. That's deliberate (CLAUDE.md says a general
   "LaTeX → Jaspr compiler is explicitly out of scope"). For a single
   resume, manual transcription is fine. For a 12-chapter book, the
   spike's Pandoc-JSON → AST → Node-tree pipeline is the right tool.
2. **jaspr_content's TOC + heading anchors + image zoom** — free
   chrome features that latex_jaspr would have to reimplement if it
   ever needed them.
3. **Multi-route content via `jaspr_content`'s `FilesystemLoader`**
   over jaspr_router's hand-coded routes. Each chapter becomes a file
   in `content/` automatically.

## 8. Where each approach is the right answer

- **One specific document, want pixel-faithful match to a known LaTeX
  PDF**: do what latex_jaspr does. Vendor the fonts, hand-transcribe,
  every rule justified by a .tex line.
- **Many documents, sourced from `pandoc -t json` AST**, content
  authored elsewhere, web rendering is a downstream consumer:
  do what the spike is trying to do. Layered toolchain
  (parser + jaspr_content + theme).

The interesting question for pandoc_jaspr's canonical implementation is
whether to **adopt some of latex_jaspr's per-component CSS habits**
(scoped, project-authored, cited) **on top of jaspr_content** — which
would address the cascade-conflict surface without giving up the
toolchain benefits. This is essentially "Option B" from
`spike/LATEX_CSS_CASCADE_AUDIT.md` §scoping-strategy.

## Files surveyed

- `/home/hugo/for_fun/latex_jaspr/CLAUDE.md` — architecture, Jaspr
  quirks, "don't fight the structure" guidance.
- `/home/hugo/for_fun/latex_jaspr/RECREATE.md` — step-by-step rebuild.
- `/home/hugo/for_fun/latex_jaspr/pubspec.yaml` — deps: `jaspr`,
  `jaspr_router`. **No `jaspr_content`.**
- `/home/hugo/for_fun/latex_jaspr/lib/main.server.dart` — `Document(...)`
  one-liner with `css.import('fonts/fonts.css')`.
- `/home/hugo/for_fun/latex_jaspr/lib/constants/theme.dart` — global
  `@css` block: `html,body`, `a`, `.font-*` wrappers.
- `/home/hugo/for_fun/latex_jaspr/lib/components/resume/*.dart` — eight
  components, each carrying its own `@css static List<StyleRule>`.
- `/home/hugo/for_fun/latex_jaspr/web/fonts/fonts.css` — 132 lines of
  `@font-face` for CMU Serif / Fira Sans / Roboto / Noto Sans / Source
  Sans Pro / XCharter.
- `/home/hugo/for_fun/latex_jaspr/build/jaspr/index.html` — 9956 bytes.
- `spike/example_app/build/jaspr/article.pandoc` — 44356 bytes.
