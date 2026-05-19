# Spike Golden Test

A snapshot test for the article rendered through the full spike pipeline:
parser → jaspr_content → DocsLayout + latex.css → static HTML.

## Files

| File | Role |
|---|---|
| `article.html` | The committed golden — byte-for-byte snapshot of `spike/example_app/build/jaspr/article.pandoc` taken with the spike in its accepted state. |
| `check.sh` | Rebuild and diff. Exit 0 on match, 1 on mismatch. |
| `regenerate.sh` | Rebuild and overwrite `article.html`. Use when an intentional change has shifted the HTML. |

## Usage

```bash
# After making a change you do NOT expect to affect HTML output:
bash spike/golden/check.sh

# After making a change you DO expect to affect HTML output:
bash spike/golden/regenerate.sh
git add spike/golden/article.html
```

`jaspr build` from a clean state is deterministic for this site, so the
diff is meaningful (no spurious timestamp/hash churn). Re-confirmed by
building twice and diffing — zero bytes of drift.

## What's actually tested

The golden captures everything `jaspr build` produces for `/article.pandoc`:

- The HTML the parser emits per node (headings with ids, lists, figure,
  links, image, emphasis, strong, paragraphs).
- The DocsLayout chrome (header, sidebar, on-page TOC, footer slot).
- The `<link rel="stylesheet" href="/latex.css">` and
  `/latex-overrides.css` injected by `LatexDocsLayout.buildHead`.
- The docs template's `Image` custom-component wrap (the
  `<figure class="image zoomable">` nested inside our parser-emitted
  `<figure id="fig:sample">`).
- The inline `<style>` rules `DocsLayout._styles` ships.
- The `@jaspr_content:zoomable_image` HTML comment carrying the image
  metadata for the client.

If any of these shift unexpectedly the diff will surface it.

## What's NOT tested

- Visual fidelity (no headless browser; the golden is HTML, not pixels).
- The latex.css file's contents — that's vendored and treated as a
  third-party blob. Bumping it is a deliberate update.
- The runtime behavior of zoom/theme toggle (those are JS-driven).
- The other routes (`/`, `/about`). Add additional golden files if their
  HTML becomes interesting.

## Stability caveats

The build is currently deterministic, but this depends on:

- `jaspr_cli` version (currently 0.23.1).
- `jaspr_content` version (currently 0.5.2).
- `latex.css` version (vendored from `vincentdoerig/latex-css@master`,
  fetched 2026-05-19).

Bumping any of these may require a `regenerate.sh` pass.
