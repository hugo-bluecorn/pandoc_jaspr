// Spike-level parser coverage. Each test feeds a small hand-crafted
// `pandoc.json` document through PandocParser and asserts the emitted
// jaspr_content Node tree.

import 'dart:convert';

import 'package:jaspr_content/jaspr_content.dart';
import 'package:pandoc_jaspr/pandoc_jaspr.dart';
import 'package:test/test.dart';

/// Wraps [blocks] in a minimal pandoc JSON document and runs the parser.
List<Node> parse(List<Map<String, Object?>> blocks) {
  final doc = {
    'pandoc-api-version': [1, 23, 1, 1],
    'meta': <String, Object?>{},
    'blocks': blocks,
  };
  return PandocParser.parseJsonString(jsonEncode(doc));
}

/// Pandoc `Attr` literal helper.
List<Object?> attr(String id, [List<String> classes = const [], List<List<String>> kv = const []]) {
  return [id, classes, kv];
}

Map<String, Object?> str(String s) => {'t': 'Str', 'c': s};
Map<String, Object?> space() => {'t': 'Space'};

void main() {
  group('PandocParser pattern', () {
    test('matches *.pandoc.json', () {
      final p = const PandocParser().pattern;
      expect(p.matchAsPrefix('article.pandoc.json'), isNotNull);
      expect(p.matchAsPrefix('a/b/c.pandoc.json'), isNotNull);
      expect(p.matchAsPrefix('article.json'), isNull);
      expect(p.matchAsPrefix('article.md'), isNull);
    });
  });

  group('blocks', () {
    test('Header emits h{n+1} (demoted) with id', () {
      // The spike parser demotes Header level by 1 to satisfy
      // jaspr_content's TOC extension (which only picks up h2+).
      final nodes = parse([
        {
          't': 'Header',
          'c': [
            2,
            attr('sec:intro'),
            [str('Hello'), space(), str('World')],
          ],
        },
      ]);

      expect(nodes, hasLength(1));
      final h = nodes.single as ElementNode;
      expect(h.tag, 'h3');
      expect(h.attributes['id'], 'sec:intro');
      expect(h.children!.map((c) => (c as TextNode).text).join(), 'Hello World');
    });

    test('Header level 6 stays clamped at h6', () {
      final nodes = parse([
        {
          't': 'Header',
          'c': [
            6,
            attr(''),
            [str('Deep')],
          ],
        },
      ]);
      final h = nodes.single as ElementNode;
      expect(h.tag, 'h6');
    });

    test('Para emits p with inline children', () {
      final nodes = parse([
        {
          't': 'Para',
          'c': [str('Hi'), space(), str('there')],
        },
      ]);

      final p = nodes.single as ElementNode;
      expect(p.tag, 'p');
      expect(p.children!.map((c) => (c as TextNode).text).join(), 'Hi there');
    });

    test('BulletList wraps each item as li', () {
      final nodes = parse([
        {
          't': 'BulletList',
          'c': [
            [
              {
                't': 'Para',
                'c': [str('A')],
              },
            ],
            [
              {
                't': 'Para',
                'c': [str('B')],
              },
            ],
          ],
        },
      ]);

      final ul = nodes.single as ElementNode;
      expect(ul.tag, 'ul');
      expect(ul.children, hasLength(2));
      final li0 = ul.children![0] as ElementNode;
      expect(li0.tag, 'li');
      expect((li0.children!.single as TextNode).text, 'A');
    });

    test('OrderedList honours non-default start', () {
      final nodes = parse([
        {
          't': 'OrderedList',
          'c': [
            [
              3,
              {'t': 'DefaultStyle'},
              {'t': 'DefaultDelim'},
            ],
            [
              [
                {
                  't': 'Para',
                  'c': [str('A')],
                },
              ],
            ],
          ],
        },
      ]);

      final ol = nodes.single as ElementNode;
      expect(ol.tag, 'ol');
      expect(ol.attributes['start'], '3');
    });

    test('OrderedList with default start omits start attr', () {
      final nodes = parse([
        {
          't': 'OrderedList',
          'c': [
            [
              1,
              {'t': 'DefaultStyle'},
              {'t': 'DefaultDelim'},
            ],
            [
              [
                {
                  't': 'Para',
                  'c': [str('A')],
                },
              ],
            ],
          ],
        },
      ]);

      final ol = nodes.single as ElementNode;
      expect(ol.attributes.containsKey('start'), isFalse);
    });

    test('Figure emits <figure><img/><figcaption/></figure>', () {
      final nodes = parse([
        {
          't': 'Figure',
          'c': [
            attr('fig:demo'),
            [
              null,
              [
                {
                  't': 'Plain',
                  'c': [str('A'), space(), str('caption')],
                },
              ],
            ],
            [
              {
                't': 'Plain',
                'c': [
                  {
                    't': 'Image',
                    'c': [
                      attr(''),
                      [str('alt')],
                      ['img.png', ''],
                    ],
                  },
                ],
              },
            ],
          ],
        },
      ]);

      final fig = nodes.single as ElementNode;
      expect(fig.tag, 'figure');
      expect(fig.attributes['id'], 'fig:demo');
      // Plain emits its children bare — no <span> wrapper. So the figure's
      // content is the <img> directly followed by <figcaption>.
      final inner = fig.children!;
      expect(inner, hasLength(2));
      expect((inner.first as ElementNode).tag, 'img');
      expect((inner.last as ElementNode).tag, 'figcaption');
    });

    test('Plain at top level emits bare children, no <span>', () {
      final nodes = parse([
        {
          't': 'Plain',
          'c': [str('Hello'), space(), str('world')],
        },
      ]);

      expect(nodes, hasLength(3));
      expect((nodes[0] as TextNode).text, 'Hello');
      expect((nodes[1] as TextNode).text, ' ');
      expect((nodes[2] as TextNode).text, 'world');
    });

    test('Div passes attrs through', () {
      final nodes = parse([
        {
          't': 'Div',
          'c': [
            attr('warning-box', ['warning'], [['data-x', 'y']]),
            [
              {
                't': 'Para',
                'c': [str('Hi')],
              },
            ],
          ],
        },
      ]);

      final div = nodes.single as ElementNode;
      expect(div.tag, 'div');
      expect(div.attributes['id'], 'warning-box');
      expect(div.attributes['class'], 'warning');
      expect(div.attributes['data-x'], 'y');
    });

    test('Unsupported block is dropped', () {
      final nodes = parse([
        {'t': 'HorizontalRule'},
      ]);
      expect(nodes, isEmpty);
    });
  });

  group('inlines', () {
    test('Emph and Strong wrap children', () {
      final nodes = parse([
        {
          't': 'Para',
          'c': [
            {
              't': 'Emph',
              'c': [str('em')],
            },
            space(),
            {
              't': 'Strong',
              'c': [str('strong')],
            },
          ],
        },
      ]);

      final p = nodes.single as ElementNode;
      final em = p.children![0] as ElementNode;
      final strong = p.children![2] as ElementNode;
      expect(em.tag, 'em');
      expect(strong.tag, 'strong');
    });

    test('Link emits anchor with href and title', () {
      final nodes = parse([
        {
          't': 'Para',
          'c': [
            {
              't': 'Link',
              'c': [
                attr(''),
                [str('docs')],
                ['https://example.org', 'A title'],
              ],
            },
          ],
        },
      ]);

      final a = (nodes.single as ElementNode).children!.single as ElementNode;
      expect(a.tag, 'a');
      expect(a.attributes['href'], 'https://example.org');
      expect(a.attributes['title'], 'A title');
    });

    test('Image emits img with src and flattened alt', () {
      final nodes = parse([
        {
          't': 'Para',
          'c': [
            {
              't': 'Image',
              'c': [
                attr(''),
                [str('hello'), space(), str('alt')],
                ['fig.png', ''],
              ],
            },
          ],
        },
      ]);

      final img = (nodes.single as ElementNode).children!.single as ElementNode;
      expect(img.tag, 'img');
      expect(img.attributes['src'], 'fig.png');
      expect(img.attributes['alt'], 'hello alt');
      expect(img.children, isNull);
    });

    test('LineBreak emits <br>; SoftBreak emits space', () {
      final nodes = parse([
        {
          't': 'Para',
          'c': [
            str('a'),
            {'t': 'LineBreak'},
            str('b'),
            {'t': 'SoftBreak'},
            str('c'),
          ],
        },
      ]);

      final p = nodes.single as ElementNode;
      expect((p.children![0] as TextNode).text, 'a');
      expect((p.children![1] as ElementNode).tag, 'br');
      expect((p.children![2] as TextNode).text, 'b');
      expect((p.children![3] as TextNode).text, ' ');
      expect((p.children![4] as TextNode).text, 'c');
    });

    test('Unsupported inline (Code) is dropped', () {
      final nodes = parse([
        {
          't': 'Para',
          'c': [
            str('a'),
            space(),
            {
              't': 'Code',
              'c': [attr(''), 'x'],
            },
            space(),
            str('b'),
          ],
        },
      ]);

      final p = nodes.single as ElementNode;
      final texts = p.children!.map((c) => (c as TextNode).text).join();
      // Code disappears; the surrounding spaces (one on each side) survive,
      // so the visible text is 'a  b' (two spaces).
      expect(texts, 'a  b');
    });
  });
}
