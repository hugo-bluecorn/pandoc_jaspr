# Spike — Single-Page LaTeX Article Render

> **You are a fresh Claude Code session, picked specifically to run this
> spike.** Treat this file as your contract. Everything you need is in this
> repository or linked from it. Stop and ask only if something here is
> internally inconsistent — do not redesign the package.

## What this spike is

A time-boxed, throwaway implementation that converts the LaTeX article in
`spike/article.tex` (via Pandoc's JSON AST) into a Jaspr page. The goal is
**learning**, not shipping. The output of this spike is:

1. A working end-to-end pipeline on a feature branch.
2. A written debrief in `spike/DEBRIEF.md` covering what's hard, what
   surprised you, and what the project's pending Dart guidelines, TDD
   process, and KISS/YAGNI directive should specifically include.

The debrief is the deliverable. The code is the experiment.

## Authorization to write Dart code

The project's main `CLAUDE.md` and `README.md` impose a gate:

> Do not write production `.dart` code in this repo yet.

**This spike is an explicit, scoped exception to that gate.** It exists
because writing some real code is the only honest way to discover what the
guidelines should require. Constraints on the exception:

- All work happens on a branch named `spike/article-render-mvp`. **Do not
  merge into `main`.** When the spike is complete, the branch stays put;
  someone reviews the debrief and the diff and decides what (if anything)
  from the spike is worth lifting into the canonical implementation.
- Spike `.dart` code is **non-canonical**. It does not need to follow
  rules that have not yet been written. It does need to be readable enough
  for the debrief to be useful.
- If this repo is not yet a git repo (`git status` errors), `git init`
  it first and make the initial commit on `main` before branching to
  `spike/article-render-mvp`.

## Scope — read this carefully

**In scope:**

- Reading `article.pandoc.json` (produced by `pandoc -f latex -t json
  spike/article.tex`) and emitting a Jaspr `Component` tree.
- The Pandoc AST nodes listed under "MVP scope" in `README.md`:
  `Header`, `Para`, `Plain`, `BulletList`, `OrderedList`, `Figure`, `Div`,
  `Str`/`Space`/`SoftBreak`, `LineBreak`, `Emph`, `Strong`, `Link`, `Image`.
- A single-page render of the whole article in a Jaspr `ContentApp` using
  `jaspr_content`'s `DocsLayout` (or the simplest layout that works).
- Building a TOC from the article's section headers via
  `jaspr_content`'s `TableOfContentsExtension`, and displaying it on the
  left side of the page.

**Out of scope for this spike:**

- Chapter splitting / one-route-per-chapter. The sample is
  `\documentclass{article}`, which has no `\chapter`. Render the whole
  document as a single page.
- Math, tables, code blocks, citations, footnotes, raw TeX, definition
  lists, line blocks, horizontal rules, block quotes, strikeout,
  underline, super/subscript, small-caps, quoted, span. **Drop these
  with a single debug-level log line per unhandled node and continue.**
  Do not error out.
- Shelling out to `pandoc` from Dart. Pre-convert by hand
  (`pandoc -f latex -t json spike/article.tex -o
  spike/article.pandoc.json`) and feed the JSON file.
- Production-quality error handling, JSON schema validation, custom
  exception hierarchies, etc. Asserts and `throw` with a clear message
  are fine for the spike.
- A `pandoc_runner` helper. Out.

If you find yourself wanting to expand scope mid-spike, **stop and write
the temptation into `DEBRIEF.md` instead.** Scope expansion in a spike is
the failure mode; resisting it is the value.

## Required reading before you start

In this repo:

1. `README.md` — the design doc. Especially "What this package is for",
   "How it maps to Jaspr", "MVP scope" (the node mapping table).
2. `CLAUDE.md` — the gate, the working style.
3. `context/jaspr-content-parser-contract.md` — distilled API contract
   for the `PageParser` interface and `Node` types. This is your most
   load-bearing reference.
4. `context/effective-dart-style.md` — naming, ordering, formatting.
5. `context/flutter-ai-rules.md` — the framework-agnostic top half
   (Interaction Guidelines, Code Quality, Dart Best Practices,
   Documentation Philosophy) applies. **Skip the Flutter-specific
   sections** (Material 3, GoRouter, layout widgets, accessibility for
   widgets). This is a pure-Dart Jaspr package, not a Flutter app.

In the cloned reference repos (outside this repo, read-only):

6. `/home/hugo/ai/context/github/jaspr/packages/jaspr_content/lib/src/page_parser/markdown_parser.dart` — the parser closest in shape to what you'll write. Use it as your style template.
7. `/home/hugo/ai/context/github/jaspr/packages/jaspr_content/lib/src/page_parser/html_parser.dart` — simpler reference.
8. `/home/hugo/ai/context/github/pandoc/MANUAL.txt` — canonical Block/Inline inventory if you hit a node you don't recognize.

Also load the project's memory under
`~/.claude/projects/-home-hugo-bluecorn-git-pandoc-jaspr/memory/`. The
`feedback-*` entries are binding — particularly the "simple-first,
repositionable components" feedback.

## Pre-flight checklist

The repo is already initialized (`git` will work), and the spike inputs
are pre-generated and committed on `main`:

- `spike/article.tex` — the LaTeX source.
- `spike/article.pandoc.json` — output of `pandoc -f latex -t json` (~12 KB,
  `pandoc-api-version` 1.23.1.1). **Use this directly — no need to install
  pandoc.**
- `spike/figures/sample.png` — a 100×100 placeholder PNG (83 bytes) so
  `\includegraphics` resolves cleanly if you ever do re-run pandoc.

What's still on you:

```bash
# In /home/hugo/bluecorn/git/pandoc_jaspr/

# 1. Dart is required. Confirm version (3.12.0 stable is installed on
#    the dev host as of 2026-05-19; the pubspec.yaml constraint
#    `sdk: ^3.11.5` accepts it).
dart --version

# 2. jaspr_cli is already installed on this host
#    (dart pub global activate jaspr_cli — version 0.23.1).
#    The pub-cache bin directory is NOT on PATH by default.
#    Export it for every shell session you use:
export PATH="$PATH:$HOME/.pub-cache/bin"
jaspr --version  # confirm: 0.23.1 or newer

# 3. Branch off main for the spike. Do NOT work on main.
git checkout -b spike/article-render-mvp

# 4. Eyeball the JSON to confirm shape before writing Dart.
python3 -m json.tool spike/article.pandoc.json | head -60
```

Optional — regenerate the JSON if you edit `article.tex`:

```bash
pandoc -f latex -t json spike/article.tex -o spike/article.pandoc.json
```

Pandoc 3.7.0.2 is already installed on this host.

## Starter sequence

A reasonable order — adjust if you have a better one, but document the
decision in `DEBRIEF.md`:

1. **Add dependencies.** `dart pub add jaspr jaspr_content`. Update the
   SDK constraint if the spike needs >=3.x for sealed classes / patterns.
2. **Delete the template `Awesome` class** in `lib/src/pandoc_jaspr_base.dart`
   and its test. The spike replaces them.
3. **Model the Pandoc AST.** A sealed `Block` and sealed `Inline` Dart
   hierarchy, plus a `PandocDocument` wrapper. Implement
   `fromJson(Map<String, Object?>)` factories that switch on the `t`
   discriminator. **Decode every node type the JSON contains**, even if
   you only render the MVP subset — so missing types throw a single clear
   error instead of a confusing one. For unsupported nodes, define them
   as simple `Unsupported(String tag)` placeholders rather than skipping
   the decoder entry entirely.
4. **Write `PandocParser implements PageParser`.** Pattern:
   `RegExp(r'.*\.pandoc\.json$')`. Inside `parsePage`, decode `page.content`,
   walk blocks/inlines, emit `List<Node>`. Map the MVP nodes per
   `README.md`'s table; log-and-drop the rest.
5. **Wire a minimal Jaspr `ContentApp` as a throwaway side-app** under
   `spike/example_app/` — a separate Dart project with its own
   `pubspec.yaml` that depends on `jaspr`, `jaspr_content`, and
   `path: ../..` back to `pandoc_jaspr`. Configure the `ContentApp` with
   `parsers: [PandocParser()]`, `extensions: [TableOfContentsExtension()]`,
   and a `DocsLayout`. Point the route loader at
   `spike/article.pandoc.json` (use whatever path resolution
   `jaspr_content` expects — likely relative to the example_app dir; if
   that's awkward, copy or symlink the JSON into the example_app's
   content directory).

   The fastest scaffold is `cd spike && jaspr create example_app`, then
   edit the generated files to plug in `PandocParser` and the route
   loader pointing at the article JSON.

6. **Run it.** From inside `spike/example_app/`:

   ```bash
   jaspr serve
   ```

   Open the URL `jaspr serve` reports (typically
   `http://localhost:8080`). Read what works and what looks wrong.
7. **Write tests.** Even without a written TDD process, write enough
   tests to convince yourself the parser maps each MVP node correctly.
   Use small hand-crafted JSON fixtures, not the full article. Note in
   `DEBRIEF.md` how the tests felt to write — that feedback shapes the
   TDD process.
8. **Write `spike/DEBRIEF.md`.** See the next section for what it must
   contain.

## Acceptance criteria

The spike is done when **all** of:

- `spike/article.pandoc.json` exists and is valid JSON.
- `dart analyze` passes (warnings allowed; errors not).
- `dart test` passes for whatever tests you wrote.
- `jaspr serve` from inside `spike/example_app/` starts cleanly and
  the article renders in a browser at the URL it reports. Headers,
  paragraphs, bullet and numbered lists, emphasis, strong, links, and
  the image reference all appear. The image may show as broken if
  asset resolution isn't wired up — that's acceptable for the spike;
  the parser must emit a valid `<img>` regardless.
- The TOC appears on the page with `Introduction`, `A Slightly Longer
  Section` (with two nested subsections), and `A Figure` as entries,
  each linking to the correct `#id` anchor. Verify the anchor targets
  match the heading ids elsewhere on the page.
- `spike/DEBRIEF.md` exists and answers the questions below.

## DEBRIEF.md — the actual deliverable

Required sections:

1. **What worked.** Where the design held up. Be specific — name files,
   patterns, library APIs.
2. **What was harder than expected.** Where you fought the design,
   wasted time, or backtracked. Most important section.
3. **What was easier than expected.** Where the design over-thought
   something.
4. **Specific recommendations for the project's Dart code guidelines.**
   Concrete rules the spike makes you wish existed — naming
   conventions for AST classes, sealed-class layout, JSON-decoder
   patterns, error-handling style, when to use `assert` vs `throw`,
   how to structure the `lib/src/` tree.
5. **Specific recommendations for the project's TDD process.** What
   fixtures should look like, what's worth testing vs. not, how the
   test layout should be organized, what the red-green-refactor loop
   actually felt like for AST work.
6. **Specific recommendations for the KISS/YAGNI directive.** Where the
   spike was tempted to over-build. Where simplicity paid off. What the
   directive should explicitly forbid.
7. **Surprises.** Anything that surprised you about Pandoc's JSON
   output, jaspr_content's API, the LaTeX article structure, etc.
8. **What to throw away vs. what to keep.** For each significant file
   in the spike, your recommendation: lift verbatim, lift the shape,
   discard.

The debrief should be readable in 10 minutes by someone who did not run
the spike.

## What NOT to do

- Do not merge `spike/article-render-mvp` into `main`.
- Do not modify files outside `spike/`, `lib/`, `test/`, `pubspec.yaml`,
  and `analysis_options.yaml`. The project's other docs (README.md,
  CLAUDE.md, context/) are read-only for this session.
- Do not expand scope to chapters, math, tables, code blocks, etc., no
  matter how easy it looks. Add the temptation to `DEBRIEF.md` instead.
- Do not add packages beyond `jaspr`, `jaspr_content`, and `test`
  unless you can justify each addition in `DEBRIEF.md`. No
  `json_serializable`, no `freezed`, no `build_runner` for the spike —
  hand-write the decoders. If that hurts, that's data the debrief needs.
- Do not invent project conventions you can't cite from
  `context/effective-dart-style.md` or `context/flutter-ai-rules.md`.
  When in doubt, defer the decision to the debrief.

## Done?

Open a PR titled `spike: article render MVP` against `main`, with the
debrief contents as the PR description. The PR is for **review and
discussion only** — do not merge it.
