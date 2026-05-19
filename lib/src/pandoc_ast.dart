// Spike-quality AST for Pandoc JSON. Sealed Block / Inline hierarchies plus
// fromJson decoders that recognise every node tag that appears in
// spike/article.pandoc.json. Unsupported tags decode to Unsupported(tag) so
// the parser can log-and-drop them rather than blowing up at decode time.

/// Pandoc `Attr = (Identifier, [Class], [(Key, Value)])`.
class Attr {
  const Attr(this.id, this.classes, this.keyValues);

  final String id;
  final List<String> classes;
  final List<(String, String)> keyValues;

  static const empty = Attr('', [], []);

  static Attr fromJson(Object? json) {
    final list = json as List;
    final id = list[0] as String;
    final classes = (list[1] as List).cast<String>();
    final kvs = (list[2] as List)
        .map((e) => ((e as List)[0] as String, e[1] as String))
        .toList(growable: false);
    return Attr(id, classes, kvs);
  }
}

/// A single `Target = (URL, Title)` from Pandoc.
class Target {
  const Target(this.url, this.title);
  final String url;
  final String title;

  static Target fromJson(Object? json) {
    final list = json as List;
    return Target(list[0] as String, list[1] as String);
  }
}

sealed class Block {
  const Block();

  static Block fromJson(Map<String, Object?> json) {
    final tag = json['t'] as String;
    final content = json['c'];
    return switch (tag) {
      'Header' => Header.fromJson(content as List),
      'Para' => Para(_decodeInlines(content as List)),
      'Plain' => Plain(_decodeInlines(content as List)),
      'BulletList' => BulletList(_decodeListItems(content as List)),
      'OrderedList' => OrderedList.fromJson(content as List),
      'Figure' => Figure.fromJson(content as List),
      'Div' => Div.fromJson(content as List),
      _ => UnsupportedBlock(tag),
    };
  }
}

class Header extends Block {
  const Header(this.level, this.attr, this.inlines);
  final int level;
  final Attr attr;
  final List<Inline> inlines;

  static Header fromJson(List<Object?> c) {
    return Header(
      c[0] as int,
      Attr.fromJson(c[1]),
      _decodeInlines(c[2] as List),
    );
  }
}

class Para extends Block {
  const Para(this.inlines);
  final List<Inline> inlines;
}

class Plain extends Block {
  const Plain(this.inlines);
  final List<Inline> inlines;
}

class BulletList extends Block {
  const BulletList(this.items);
  final List<List<Block>> items;
}

class OrderedList extends Block {
  const OrderedList(this.startNumber, this.items);
  final int startNumber;
  final List<List<Block>> items;

  static OrderedList fromJson(List<Object?> c) {
    final attrs = c[0] as List;
    final start = attrs[0] as int;
    // attrs[1] = NumberStyle, attrs[2] = NumberDelim — ignored in MVP.
    return OrderedList(start, _decodeListItems(c[1] as List));
  }
}

class Figure extends Block {
  const Figure(this.attr, this.caption, this.content);
  final Attr attr;
  final List<Block> caption;
  final List<Block> content;

  static Figure fromJson(List<Object?> c) {
    final attr = Attr.fromJson(c[0]);
    final captionList = c[1] as List; // [ShortCaption?, [Block]]
    final caption = _decodeBlocks(captionList[1] as List);
    final content = _decodeBlocks(c[2] as List);
    return Figure(attr, caption, content);
  }
}

class Div extends Block {
  const Div(this.attr, this.content);
  final Attr attr;
  final List<Block> content;

  static Div fromJson(List<Object?> c) {
    return Div(Attr.fromJson(c[0]), _decodeBlocks(c[1] as List));
  }
}

class UnsupportedBlock extends Block {
  const UnsupportedBlock(this.tag);
  final String tag;
}

sealed class Inline {
  const Inline();

  static Inline fromJson(Map<String, Object?> json) {
    final tag = json['t'] as String;
    final content = json['c'];
    return switch (tag) {
      'Str' => Str(content as String),
      'Space' => const Space(),
      'SoftBreak' => const SoftBreak(),
      'LineBreak' => const LineBreak(),
      'Emph' => Emph(_decodeInlines(content as List)),
      'Strong' => Strong(_decodeInlines(content as List)),
      'Link' => Link.fromJson(content as List),
      'Image' => Image.fromJson(content as List),
      _ => UnsupportedInline(tag),
    };
  }
}

class Str extends Inline {
  const Str(this.text);
  final String text;
}

class Space extends Inline {
  const Space();
}

class SoftBreak extends Inline {
  const SoftBreak();
}

class LineBreak extends Inline {
  const LineBreak();
}

class Emph extends Inline {
  const Emph(this.inlines);
  final List<Inline> inlines;
}

class Strong extends Inline {
  const Strong(this.inlines);
  final List<Inline> inlines;
}

class Link extends Inline {
  const Link(this.attr, this.inlines, this.target);
  final Attr attr;
  final List<Inline> inlines;
  final Target target;

  static Link fromJson(List<Object?> c) {
    return Link(
      Attr.fromJson(c[0]),
      _decodeInlines(c[1] as List),
      Target.fromJson(c[2]),
    );
  }
}

class Image extends Inline {
  const Image(this.attr, this.alt, this.target);
  final Attr attr;
  final List<Inline> alt;
  final Target target;

  static Image fromJson(List<Object?> c) {
    return Image(
      Attr.fromJson(c[0]),
      _decodeInlines(c[1] as List),
      Target.fromJson(c[2]),
    );
  }
}

class UnsupportedInline extends Inline {
  const UnsupportedInline(this.tag);
  final String tag;
}

class PandocDocument {
  const PandocDocument(this.apiVersion, this.blocks);
  final List<int> apiVersion;
  final List<Block> blocks;

  static PandocDocument fromJson(Map<String, Object?> json) {
    final api = (json['pandoc-api-version'] as List).cast<int>();
    final blocks = _decodeBlocks(json['blocks'] as List);
    return PandocDocument(api, blocks);
  }
}

List<Block> _decodeBlocks(List<Object?> raw) {
  return raw
      .map((e) => Block.fromJson(e as Map<String, Object?>))
      .toList(growable: false);
}

List<Inline> _decodeInlines(List<Object?> raw) {
  return raw
      .map((e) => Inline.fromJson(e as Map<String, Object?>))
      .toList(growable: false);
}

List<List<Block>> _decodeListItems(List<Object?> raw) {
  return raw
      .map((item) => _decodeBlocks(item as List<Object?>))
      .toList(growable: false);
}
