// Spike PandocParser. Reads `*.pandoc.json` page content, decodes the AST,
// emits jaspr_content [Node]s for the MVP node subset. Unsupported nodes are
// logged once each and dropped.

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:jaspr_content/jaspr_content.dart';

import 'pandoc_ast.dart';

class PandocParser implements PageParser {
  const PandocParser();

  @override
  Pattern get pattern => RegExp(r'.*\.pandoc\.json$');

  @override
  List<Node> parsePage(Page page) => parseJsonString(page.content);

  /// Parses a raw `pandoc -t json` string. Exposed so tests can exercise the
  /// parser without spinning up a Page/RouteLoader pair.
  static List<Node> parseJsonString(String json) {
    final raw = jsonDecode(json) as Map<String, Object?>;
    final doc = PandocDocument.fromJson(raw);
    return _blocks(doc.blocks);
  }
}

List<Node> _blocks(List<Block> blocks) {
  final out = <Node>[];
  for (final b in blocks) {
    final node = _block(b);
    if (node != null) out.add(node);
  }
  return out;
}

Node? _block(Block block) {
  return switch (block) {
    // Spike-only: demote one level (h1→h2, h2→h3, …) so that
    // jaspr_content's TableOfContentsExtension (which skips h1) picks up
    // top-level Pandoc headers. See DEBRIEF.md for the tension this exposes.
    Header(:final level, :final attr, :final inlines) => ElementNode(
      'h${(level + 1).clamp(1, 6)}',
      _attrToAttrs(attr),
      _inlines(inlines),
    ),
    Para(:final inlines) => ElementNode('p', const {}, _inlines(inlines)),
    Plain(:final inlines) => ElementNode('span', const {}, _inlines(inlines)),
    BulletList(:final items) => ElementNode(
      'ul',
      const {},
      items.map(_listItem).toList(growable: false),
    ),
    OrderedList(:final startNumber, :final items) => ElementNode(
      'ol',
      startNumber == 1 ? const {} : {'start': '$startNumber'},
      items.map(_listItem).toList(growable: false),
    ),
    Figure(:final attr, :final caption, :final content) => ElementNode(
      'figure',
      _attrToAttrs(attr),
      [
        ..._blocks(content),
        if (caption.isNotEmpty)
          ElementNode('figcaption', const {}, _blocks(caption)),
      ],
    ),
    Div(:final attr, :final content) => ElementNode(
      'div',
      _attrToAttrs(attr),
      _blocks(content),
    ),
    UnsupportedBlock(:final tag) => _dropUnsupported('block', tag),
  };
}

Node _listItem(List<Block> blocks) {
  // A list item may contain multiple blocks; if it's a single Para, unwrap.
  if (blocks.length == 1 && blocks.first is Para) {
    final para = blocks.first as Para;
    return ElementNode('li', const {}, _inlines(para.inlines));
  }
  return ElementNode('li', const {}, _blocks(blocks));
}

List<Node> _inlines(List<Inline> inlines) {
  final out = <Node>[];
  for (final i in inlines) {
    final node = _inline(i);
    if (node != null) out.add(node);
  }
  return out;
}

Node? _inline(Inline inline) {
  return switch (inline) {
    Str(:final text) => TextNode(text),
    Space() => const TextNode(' '),
    SoftBreak() => const TextNode(' '),
    LineBreak() => const ElementNode('br', {}, null),
    Emph(:final inlines) => ElementNode('em', const {}, _inlines(inlines)),
    Strong(:final inlines) =>
      ElementNode('strong', const {}, _inlines(inlines)),
    Link(:final inlines, :final target, :final attr) => ElementNode(
      'a',
      {
        'href': target.url,
        if (target.title.isNotEmpty) 'title': target.title,
        ..._attrToAttrs(attr),
      },
      _inlines(inlines),
    ),
    Image(:final alt, :final target, :final attr) => ElementNode(
      'img',
      {
        'src': target.url,
        'alt': _inlineText(alt),
        if (target.title.isNotEmpty) 'title': target.title,
        ..._attrToAttrs(attr),
      },
      null,
    ),
    UnsupportedInline(:final tag) => _dropUnsupported('inline', tag),
  };
}

Null _dropUnsupported(String kind, String tag) {
  developer.log(
    'pandoc_jaspr: dropping unsupported $kind node "$tag"',
    name: 'pandoc_jaspr',
  );
  return null;
}

Map<String, String> _attrToAttrs(Attr attr) {
  if (attr.id.isEmpty && attr.classes.isEmpty && attr.keyValues.isEmpty) {
    return const {};
  }
  return {
    if (attr.id.isNotEmpty) 'id': attr.id,
    if (attr.classes.isNotEmpty) 'class': attr.classes.join(' '),
    for (final (k, v) in attr.keyValues) k: v,
  };
}

String _inlineText(List<Inline> inlines) {
  final buf = StringBuffer();
  for (final i in inlines) {
    switch (i) {
      case Str(:final text):
        buf.write(text);
      case Space():
      case SoftBreak():
        buf.write(' ');
      case LineBreak():
        buf.write('\n');
      case Emph(:final inlines):
      case Strong(:final inlines):
        buf.write(_inlineText(inlines));
      case Link(:final inlines):
        buf.write(_inlineText(inlines));
      case Image(:final alt):
        buf.write(_inlineText(alt));
      case UnsupportedInline():
        break;
    }
  }
  return buf.toString();
}
