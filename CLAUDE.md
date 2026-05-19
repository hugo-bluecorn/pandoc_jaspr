# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read first

**The authoritative design document is `README.md`** in this repo. Read it before doing anything beyond the most trivial task — it captures the locked-in MVP scope, the two-repo workflow, the LaTeX project assumptions, the Pandoc-AST-to-Jaspr mapping, the routing model, and the explicit out-of-scope list.

Memory under `~/.claude/projects/-home-hugo-bluecorn-git-pandoc-jaspr/memory/` captures user/project/feedback context — load it via the auto-memory mechanism.

## Implementation is gated

**Do not write production `.dart` code in this repo yet.** Three project artifacts must exist first:

1. Dart code guidelines for this project (style, naming, sealed-class conventions, JSON decoding approach, error handling).
2. A TDD process (test layout, fixture strategy, coverage expectations).
3. An explicit KISS / YAGNI directive.

If asked to implement features before these exist, surface the gap and propose establishing the missing artifact first. Design discussion, documentation updates, and memory writes are not gated.

**Sources surveyed but not adopted (2026-05-19):** Official Flutter/Dart AI docs, `dart-lang/skills`, `very_good_analysis`, VGV Wingspan (cloned at `/home/hugo/ai/context/github/VeryGoodOpenSource/vgv-wingspan`), VGV AI Flutter Plugin. See README.md → "Sources surveyed" and the relevant memory entries for details. Do not assume any of these are in use until the user explicitly chooses.

## Spike work — `spike/` is a scoped exception to the gate

There is an authorized spike in `spike/` whose purpose is to discover what the three pending artifacts should require. A separate Claude session is invoked via `spike/SPIKE.md` and is allowed to write `.dart` code, but **only on the branch `spike/article-render-mvp`** and only against `spike/article.tex`. The spike's deliverable is `spike/DEBRIEF.md`, not the code. The branch does not merge to `main`.

If you are not the spike session, do not modify anything under `spike/` and do not write production `.dart` outside the spike exception. See memory `project-spike-is-authorized-exception` for the full constraints.

## Context directory — `context/`

`context/` holds reference material for spike and (later) implementation sessions:

- `flutter-ai-rules.md` — official Flutter/Dart AI rules (fetched verbatim, framework-agnostic top half applies; Flutter-specific bottom half does not).
- `effective-dart-style.md` — canonical Dart style guide (fetched from dart.dev).
- `jaspr-content-parser-contract.md` — locally derived note distilling the `PageParser` / `Node` / `NodesBuilder` contract from the cloned jaspr repo.

These are reference, not policy. They inform the eventual code guidelines but do not by themselves constitute adoption.

## Repo state

This is still a `dart create`-style scaffold:

- `lib/src/pandoc_jaspr_base.dart` contains the template `Awesome` class. It is placeholder, not real code. The implementation outline in `README.md` is what should replace it.
- `pubspec.yaml` has no dependencies. The real implementation will need `jaspr` and `jaspr_content`.
- `test/pandoc_jaspr_test.dart` only tests the placeholder.
- `lints: ^6.0.0` is the right modern pin — keep it.
- `sdk: ^3.11.5` is fine; latest released stable as of 2026-05-19 is 3.11.6. Do not target 3.12 or 3.13 — both are still unreleased per the SDK CHANGELOG.

## Commands

```bash
dart pub get
dart analyze
dart test
dart test test/pandoc_jaspr_test.dart -n NAME   # single test by name
dart format .
```

## Reference repositories (read-only, outside this repo)

- Jaspr — `/home/hugo/ai/context/github/jaspr`
  - `packages/jaspr_content/lib/src/page_parser/page_parser.dart` — the `PageParser` / `Node` / `NodesBuilder` contract `PandocParser` will implement.
  - `packages/jaspr_content/lib/src/page_parser/markdown_parser.dart`, `html_parser.dart` — style references.
  - `packages/jaspr_content/lib/src/page_extension/table_of_contents_extension.dart` — produces `TableOfContents` / `TocEntry`; reused as-is.
  - `packages/jaspr_content/lib/src/layouts/docs_layout.dart`, `lib/components/sidebar.dart` — the two-pane layout pieces reused in the example app.
- Pandoc — `/home/hugo/ai/context/github/pandoc`
  - `MANUAL.txt` — canonical Block/Inline inventory.
  - `doc/filters.md` — the JSON AST shape (same shape as `pandoc -t json` output).
- Dart SDK — `/home/hugo/ai/context/github/dart-lang/sdk`
  - `CHANGELOG.md` — language-feature provenance, current release status.

## Working style for this project

- The user prefers exposing primitives over baked-in layouts. Every Jaspr component this package exports must be positionable anywhere by the consumer — never coupled to a particular layout. See the "Component philosophy" section in README.md.
- The user prefers terse, scoped responses and explicit "we can expand later" framing over speculative future-proofing.
- The user works in a two-repo setup: LaTeX project (edited in Kile) and Jaspr consumer (deployed as GitHub Pages) live in separate git repos. The handoff is the `*.pandoc.json` file. Do not propose designs that assume the `.tex` source is reachable from the Jaspr build.
