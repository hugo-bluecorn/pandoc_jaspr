# jaspr_content PageParser contract

> **Locally derived note.** Distilled from the cloned `jaspr` repo at
> `/home/hugo/ai/context/github/jaspr` for the spike session, so it does not
> have to re-derive the same information from the source.

This document captures *only* what a `PandocParser` implementation needs to
know to integrate cleanly into a Jaspr `ContentApp`. Nothing here is invented
— it is summarized from the files cited inline.

## The interface to implement

From `packages/jaspr_content/lib/src/page_parser/page_parser.dart`:

```dart
abstract class PageParser {
  /// The pattern that is used to match the page path.
  /// It must match the entire path, not just the file suffix. Regexes are allowed.
  Pattern get pattern;

  /// Parses the given [page] into a list of nodes.
  ///
  /// A [Node] is a tree structure that represents the content of a page,
  /// similar to HTML.
  List<Node> parsePage(Page page);
}
```

A `PandocParser` for the MVP would look like:

```dart
class PandocParser implements PageParser {
  const PandocParser();

  @override
  Pattern get pattern => RegExp(r'.*\.pandoc\.json$');

  @override
  List<Node> parsePage(Page page) {
    // page.content is the raw JSON string for *.pandoc.json files.
    // Decode it, walk the Block/Inline AST, emit Nodes.
    ...
  }
}
```

Consumers register it in a `ContentApp` alongside other parsers:

```dart
ContentApp(
  parsers: [PandocParser(), MarkdownParser(), HtmlParser()],
  extensions: [TableOfContentsExtension()],
  ...
);
```

The first parser whose `pattern` matches `page.path` wins.

## The Node tree to emit

From the same file:

```dart
sealed class Node {
  const Node();
}

class TextNode extends Node {
  const TextNode(this.text, {this.raw = false});
  final String text;
  final bool raw;          // true = inject as RawText (HTML), bypassing escaping
}

class ElementNode extends Node {
  const ElementNode(this.tag, this.attributes, this.children);
  final String tag;                       // e.g. 'p', 'h1', 'ul', 'em', 'a', 'img'
  final Map<String, String> attributes;   // HTML attrs verbatim
  final List<Node>? children;
}

class ComponentNode extends Node {
  ComponentNode(this.component);
  final Component component;              // a real Jaspr Component
}
```

**Rule of thumb for the MVP**:
- Pandoc `Str` / `Space` / `SoftBreak` → `TextNode`.
- Pandoc `Para`, `Header`, `BulletList`, `OrderedList`, `Emph`, `Strong`, `Link`, `Image`, `Figure`, `Div`, `LineBreak` → `ElementNode` with the obvious HTML tag.
- Reserve `ComponentNode` for future cases that need a real Jaspr component (math rendering, syntax-highlighted code blocks). The MVP does not need any.

## NodesBuilder — what runs after `parsePage`

From the same file, `NodesBuilder.build(nodes)` walks the `List<Node>`
returned by `parsePage` and converts each entry to a `Component`:

- `TextNode(text, raw: false)` → `Component.text(text)`.
- `TextNode(text, raw: true)` → `RawText(text)` (escapes nothing; use with caution).
- `ElementNode(tag, attrs, children)` → `Component.element(tag: tag, attributes: attrs, children: <recurse>)`.
- `ComponentNode(c)` → `c` directly.

Before that step, the builder also runs each registered `CustomComponent`
against the node, giving them first chance to claim a node and substitute a
component. The MVP's `PandocParser` does not need to register any
`CustomComponent`s — straight `ElementNode` mapping is sufficient.

## TableOfContentsExtension — what to feed it

From `packages/jaspr_content/lib/src/page_extension/table_of_contents_extension.dart`:

The extension walks the `List<Node>` looking for `ElementNode`s whose tag
matches `^h([1-6])$`. It pulls the heading id out of the `attributes['id']`
field and the text out of recursive `innerText`. So **as long as our parser
emits headers as `ElementNode('h1' | 'h2' | ...)` with an `id` attribute,
the extension does its job with zero additional wiring.**

The resulting `TableOfContents` object lands at `page.data['toc']`.

```dart
class TableOfContents {
  const TableOfContents(this.entries);
  final List<TocEntry> entries;
  Component build() => ul([..._buildToc(entries)]);  // default renderer
}

class TocEntry {
  TocEntry(this.text, this.id, this.children);
  final String text;
  final String id;
  final List<TocEntry> children;
}
```

A consumer-positionable component over this data (the user's "show
section anywhere" requirement) is a thin `StatelessComponent` that takes a
`TableOfContents` and renders it where it's mounted.

## What the parser does NOT need to handle

- Frontmatter. `Page` already parses YAML frontmatter before `parsePage`
  runs. The Pandoc JSON's `meta` object is the equivalent — the parser may
  surface it but the layout pipeline does not require it.
- Layout, theme, sidebar. All handled by `DocsLayout`, `ContentTheme`,
  `Sidebar`. The parser only emits `List<Node>`.
- Component registration. Out of scope for MVP.
- Asset rewriting. The `<img src="...">` value passes through verbatim;
  asset resolution is the consumer's `AssetManager`'s job.

## Reference files (in the cloned jaspr repo)

For the spike to consult directly when in doubt:

- `packages/jaspr_content/lib/src/page_parser/page_parser.dart` — the interface and the Node hierarchy. Authoritative.
- `packages/jaspr_content/lib/src/page_parser/markdown_parser.dart` — the closest existing parser to mirror in style. Read this before writing the Pandoc one.
- `packages/jaspr_content/lib/src/page_parser/html_parser.dart` — simpler reference for shape and constructor conventions.
- `packages/jaspr_content/lib/src/page_extension/table_of_contents_extension.dart` — confirms the ElementNode-with-id contract for headers.
- `packages/jaspr_content/lib/src/page.dart` — shows how `parsePage` is called and how the rest of the pipeline runs.
