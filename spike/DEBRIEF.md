# Spike Debrief — Single-Page LaTeX Article Render

Branch: `spike/article-render-mvp`. Not for merging. Read with the diff.

## 1. What worked

- **The `PageParser` contract is tiny and clean.** `pattern` + `parsePage(Page) → List<Node>` was enough; the rest of jaspr_content (route loading, layout, theming, sidebar, anchor extension, TOC extension) "just worked" once the parser emitted plausible `ElementNode`/`TextNode` output. The distilled `context/jaspr-content-parser-contract.md` predicted this accurately — no surprises from the API itself.
- **Sealed Block + Inline hierarchies match Pandoc 1:1.** `Block.fromJson(Map)` and `Inline.fromJson(Map)` switching on `t` was the obvious structure, and Dart's exhaustive `switch` on the sealed class made the parser's block/inline dispatch immediate and self-checking. Adding a new node tag is two edits: one constructor + one `case` in the parser.
- **`UnsupportedBlock(tag)` / `UnsupportedInline(tag)` as terminal placeholders.** Letting the decoder accept anything but tagging unknown nodes as `Unsupported` removed the temptation to crash on real-world Pandoc output and made "log-and-drop" trivial — one `case` in `_block` / `_inline`.
- **`jaspr create --template docs` + a single `parsers:` line + a sidebar entry is the entire wiring.** The path dependency, name collision (`Header`, `Image`, `Link`), and the URL routing quirk were the only friction. The template already had `HeadingAnchorsExtension` and `TableOfContentsExtension` registered, so the package didn't have to ship layout code.
- **Hand-written JSON fixtures in tests are fine.** Each MVP node got a ~10-line fixture. `expect(node as ElementNode, …)` reads OK; no fixture-loading machinery needed.

## 2. What was harder than expected

- **Header levels collided with jaspr_content's TOC contract.** `TableOfContentsExtension` skips `h1` entirely (the page-title slot). LaTeX `\section` lowers to Pandoc Header level 1, so the article's section heads were h1 in HTML and **never made it into the TOC**. The spike's solution was to demote every Pandoc header by one level (`h${level+1}`, clamped at h6) so `\section` → h2, `\subsection` → h3, etc. This satisfied the spike's acceptance criteria but **directly contradicts the MVP mapping table in `README.md`** ("Header n → h{n}, n=1 is chapter title"). The book design assumes a chapter h1 sits above the section h2's, which the TOC extension would already drop; an article has no chapter, so n=1 is the visible section header and must map to h2. The package needs a clear policy on level mapping that handles both cases (book with chapters; article without).
- **URL derivation strips only one extension.** `FilesystemLoader` builds URLs via `p.basenameWithoutExtension`, so `article.pandoc.json` becomes `/article.pandoc`, not `/article`. The sidebar had to be wired to `/article.pandoc`, and even that 404'd intermittently after a hot reload (only `/article.pandoc/` with a trailing slash worked reliably). The `.pandoc.json` convention is otherwise nice (it lets the parser pattern match), but the URL-side cost is real — either teach `FilesystemLoader` to strip multi-part extensions, or rename the on-disk file to `article.pj` / `article.pandocjson` and live with a less explicit suffix.
- **Name collisions on `Header`, `Image`, `Link` between the AST library and `jaspr_content` components.** The example app had to import with `hide Header, Image, Link`. Easy to fix but a signal: the AST class names should not shadow jaspr_content's public component surface. Pandoc-prefixed names (`PandocHeader`, `PandocImage`, `PandocLink`) or a private library would avoid this entirely. Either option is fine; just pick one.
- **Pandoc's nested-tuple JSON for AST attributes is unergonomic in Dart.** `Attr = [id, [classes], [[k,v]...]]` decoded fine but reads as `list[0] as String`, `(list[1] as List).cast<String>()`, `(list[2] as List).map((e) => ((e[0] as String, e[1] as String))).toList()`. Hand-decoders are tolerable for the spike, but the casts pile up and one wrong `as` blows up at runtime. A small handful of typed decoder helpers (`String _str(Object?)`, `List<T> _list<T>(Object?, T Function(Object?))`) would dampen this; without them every new node type re-derives the same pattern.
- **`Page` requires a `loader: RouteLoader` to construct.** This pushed me into adding a `PandocParser.parseJsonString(String)` static so tests don't have to spin up a fake `RouteLoader`. That static is the right primitive anyway (it's the actual computation), but it was a forced ergonomic improvement, not a designed one. Future work should treat "the function from JSON-string to `List<Node>`" as the public surface and `parsePage` as the thin adapter.

## 3. What was easier than expected

- **No `Component` work needed at all.** The MVP fully maps to `ElementNode` plus `TextNode`; `ComponentNode` stays unused. The README's instinct ("reserve `ComponentNode` for math, code blocks, etc.") looks correct.
- **Pandoc handles the LaTeX preamble, `\maketitle`, and `\tableofcontents` for us.** The JSON contains only the body blocks — no metadata-rendering work fell to the parser.
- **`Plain` had no surprise semantics.** It is just "inlines with no surrounding block." I wrap it in a `span` to keep the node tree well-formed, but the `_listItem` path unwraps single-Para items directly into `<li>` so the common case stays clean.

## 4. Recommendations — Dart code guidelines

Concrete things the spike makes me want written down:

1. **Naming**: do not collide with `jaspr_content` exports. Use `Pandoc` prefix (`PandocHeader`, `PandocImage`, `PandocLink`) **or** make the AST library `internal`/private and only export the parser + a `Document` facade. My preference: prefix.
2. **Sealed hierarchies for AST-like data**, with `static T fromJson(...)` constructors and a single `switch` in the entry-point. Don't introduce a visitor pattern — exhaustive switch + sealed gives you the same compile-time guarantee with one fewer level of indirection.
3. **JSON decoding style**: hand-write decoders for the spike's pre-flight, but agree on a small `_decode*` helper convention (`_str`, `_int`, `_list<T>(json, T Function(Object?))`, `_attr(json)`) so the cast-soup doesn't reappear everywhere. Forbid `json_serializable`/`freezed`/`build_runner` for the AST — the JSON is canonical Pandoc, not ours to evolve, and codegen would be heavier than the decoders themselves.
4. **Error policy**: at the AST decoder boundary, throw on **shape** errors (`as` failure on a known tag), wrap with the tag name and the offending sub-object. For **unknown tags** (new Pandoc nodes), decode into `Unsupported(tag)` and emit one debug log line per occurrence in the parser, not the decoder. Asserts are for invariants that should hold given correct upstream data; `throw` is for genuinely malformed JSON.
5. **Layout under `lib/src/`**: keep AST and parser as separate libraries (`pandoc_ast.dart`, `pandoc_parser.dart`). The parser depends on AST; AST depends on `dart:convert` only. No dependency from AST → `jaspr_content`. (The spike already follows this; codifying it stops drift.)
6. **Public surface**: expose only the parser + a tiny set of well-named types. Hide the `Unsupported*` node types from public exports if possible — they are an implementation detail of "tolerant decode."
7. **Public string-in, nodes-out helper**: a `PandocParser.parseJsonString(String) → List<Node>` (or a top-level `parsePandocJson`). Don't force tests to build a `Page` with a fake `RouteLoader`.
8. **Inline-flattening helper**: a `flattenInlinesToText(List<Inline>)` for the alt-text path and any other "I just need a string" sites. The spike inlined this once; the second site is when it becomes a real function.

## 5. Recommendations — TDD process

The hand-fixture test file is `test/pandoc_parser_test.dart`. Observations:

1. **Fixture style**: tiny inline `Map<String, Object?>` literals beat external `.pandoc.json` files for parser-unit tests. They're greppable, they show the JSON shape directly to readers, and they don't drift out of sync with the parser. Use external fixtures only for integration tests that exercise a realistic document end-to-end.
2. **Test coverage that paid off**: one assertion per MVP node tag, plus one for an unsupported tag in each of "block" and "inline" contexts. The "Code dropped from a Para" test caught a thinko about adjacent-whitespace behavior immediately.
3. **Skip-list-style tests**: I considered (and skipped) a test that asserts every known Pandoc tag in `MANUAL.txt` decodes without throwing. Worth adding later from a small generated table, but YAGNI for now — the integration test in the example app exercises every tag present in the real article.
4. **`MarkdownParser`-shaped golden tests are not worth it for MVP.** Comparing `List<Node>` shape is enough; converting to HTML in a test means pulling in jaspr's rendering pipeline (which needs `ServerApp` setup). Save that for a higher-level integration test if/when it pays off.
5. **What red-green-refactor felt like**: each node had a tight loop (write a one-block test, fail with a missing case, add a case, pass). The slow part was figuring out the *correct expectation* (e.g. the demoted-header decision, the OrderedList `start` attribute behavior). That mirrors what production AST work will feel like — the test cycle is fast; the design decisions are the bottleneck.
6. **Test directory layout**: flat `test/` is fine until `tests/<file>` mirrors `lib/src/<file>` one-to-one. Adopt mirroring as soon as a second parser module appears.

## 6. Recommendations — KISS / YAGNI directive

Forbid, in writing:

- **No JSON validation beyond what `as` casts give you.** Pandoc owns the schema; we don't.
- **No exception hierarchy.** `throw ArgumentError.value(json, 'block', 'unrecognised shape')` is good enough until a real consumer asks for richer errors.
- **No `pandoc_runner` / shelling out to Pandoc.** Confirmed by the spike: the JSON is the boundary, and it's small enough to commit.
- **No build-time code generation for AST decoders.** The hand-written decoders are ~200 LOC and never re-derived per node — they're as small as the codegen output would be, without the build_runner overhead.
- **No premature `ComponentNode` use.** The MVP doesn't need it. Adding a `ComponentNode`-emitting case for a future math/code feature should be done in the milestone that adds that feature, not now.
- **No "future-proof" parser configuration knobs.** Right now there's nothing to configure (no flags, no level offset, no extension list); resist the urge to add one until a real second use site exists.
- **Don't paper over the heading-level conflict with a config knob.** Pick one policy (demote, don't demote, demote-only-when-no-chapters) and document it. A "configurable" knob means three untested code paths.

Where simplicity paid off:
- **`Plain` → `<span>` plus `_listItem` unwrap.** Two trivial cases instead of inventing a `BareInlines` node.
- **`Attr` as a struct** rather than a Map. Decoding `[id, classes, kvs]` once and exposing fields is faster to read than dictionary-style attribute lookups everywhere.

## 7. Surprises

- **Pandoc's `Figure` shape has a `null` slot** for the "short caption" half of the `Caption` tuple. Didn't see it documented in `doc/filters.md`'s prose — only by reading the JSON. Worth a sentence in the package's internal note.
- **`OrderedList`'s style/delim enums (`DefaultStyle`, `DefaultDelim`) sit in the same JSON shape as the inline nodes (they have `t`) but are not nodes.** They're parameters; decoding them as Block/Inline would be wrong. I ignored them entirely. If we ever need numbered-list-style mapping (`(a)`, `i.`, etc.), they'll come back into scope.
- **Pandoc emits `Code` (inline) for `\texttt{...}` even when it would render fine as plain text.** The article has 11 `Code` inlines. With Code dropped, the rendered text still reads sensibly because the surrounding `Str`/`Space` carry the words around them. The visible cost of dropping `Code` was lower than I expected — a real argument for shipping the MVP without `<code>` rendering.
- **The docs template wires `HeadingAnchorsExtension` AND `TableOfContentsExtension` by default.** The `#` permalink anchors next to each heading came for free.
- **`jaspr serve`'s rebuild after the parser code change occasionally produced a transient 404 on `/article.pandoc`** (the trailing-slash variant kept working). Not investigated; flagging as a hot-reload quirk of the example app, not the parser.
- **The `Page` constructor's required `loader: RouteLoader` field** was the first time the layered architecture leaked into the parser's API surface. Easy to work around (static helper) but worth flagging.

## 8. What to throw away vs. what to keep

| File | Recommendation | Reasoning |
|---|---|---|
| `lib/src/pandoc_ast.dart` | **Lift the shape, not the code.** | The sealed-class layout is right. Rename the public classes (`PandocHeader`, `PandocImage`, `PandocLink`) before lifting, and extract `_str`/`_list`/`_attr` decoder helpers per recommendation #3. The current code conflates "what the data is" with "how we hand-decode it" — the lifted version should separate them. |
| `lib/src/pandoc_parser.dart` | **Lift the shape.** | The Block/Inline dispatch + the inline `_inlines` walker + the `_attrToAttrs` helper + the `_inlineText` flattener are all the right shape. The heading-demotion comment is honest about a design decision the canonical implementation must revisit. Don't lift verbatim — re-do once the level-mapping policy is decided. |
| `test/pandoc_parser_test.dart` | **Lift verbatim** *(after class renames)*. | The fixture style is the one I want. Read the recommendation in §5; carry the file across as the seed of the project's TDD examples. |
| `spike/example_app/` | **Keep the wiring; redo the contents.** | The recipe (parsers list, sidebar entry, symlinks, name-hide imports) is reusable. The actual content app should be regenerated from `jaspr create --template docs` in `example/` (no `spike/` prefix) and re-decorated. |
| `spike/article.tex` | **Keep as a sample fixture.** | Even after the spike, having a known-good LaTeX source whose Pandoc JSON exercises all MVP nodes is valuable for end-to-end smoke tests. Park under `example/sample/` once the canonical app exists. |
| `spike/article.pandoc.json` | **Keep, regenerate when `.tex` changes.** | Same reason. Commit it; it's tiny. |
| `lib/pandoc_jaspr.dart` (top-level export) | **Lift the shape.** | `library` + `export 'src/...'` is the standard Dart export shim. After renaming, the export list should hide `Unsupported*` types. |
| **Branch `spike/article-render-mvp`** | **Do not merge.** Keep around for reference, then delete after the canonical implementation lands. |

## Temptations resisted

Logging here in case they recur:

- "It'd be one more `case`" → adding `Code` / `CodeBlock` to MVP rendering. **Out of scope.**
- "I might as well decode `meta` too." **No — not used by the MVP layout.**
- "Let me write a `pandoc_runner` for local dev convenience." **No — out of scope; `pandoc` is run by the LaTeX repo.**
- "Should I add a `freezed` dependency?" **No — KISS directive in the making.**
- "Maybe `Attr` should be a record `(String, List<String>, List<(String, String)>)`." Decided: the named-fields class is clearer at every call site. A record is the right primitive if we need a quick local destructure inside one decoder.
- "Should I write a sub-class of `TableOfContentsExtension` to include h1?" **No — solved in the parser by demoting, and the design decision is documented for follow-up.**
