import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/favorites/author_shelf_model.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorite_order.dart';
import 'package:venera_next/foundation/comic_type.dart';

FavoriteItem item(
  String id,
  List<String> authors, {
  int type = 0,
  String fallback = '',
}) => FavoriteItem(
  id: id,
  name: id,
  coverPath: '',
  author: fallback,
  type: ComicType(type),
  tags: authors.map((name) => 'author:$name').toList(),
);

void main() {
  test(
    'all authors, namespace priority, alias and within-shelf identity dedup',
    () {
      final shared = item('same', [
        ' Zed ',
        'Beta',
        'Zed',
      ], fallback: 'Uploader');
      final groups = authorShelves(
        [
          shared,
          shared,
          item('same', ['Beta'], type: 31),
        ],
        aliases: {'Zed': 'Alpha'},
      );
      expect(groups.map((group) => group.author), ['Alpha', 'Beta']);
      expect(groups.first.items.map(favoriteIdentity), [('same', 0)]);
      expect(groups.last.items.map(favoriteIdentity), [
        ('same', 0),
        ('same', 31),
      ]);
    },
  );
  test(
    'unknown last and distinct from real Unnamed author, full order before visibility',
    () {
      final groups = authorShelves(
        [
          item('unknown', []),
          item('hidden', ['Zed']),
          item('named', ['Unnamed author']),
          item('beta', ['Beta']),
          item('visible', ['Zed']),
        ],
        visible: {('unknown', 0), ('named', 0), ('beta', 0), ('visible', 0)},
      );
      expect(groups.map((group) => group.author), [
        'Zed',
        'Unnamed author',
        'Beta',
        null,
      ]);
      expect(groups.first.items.single.id, 'visible');
      expect(
        authorShelfStorageKey(null),
        isNot(authorShelfStorageKey('Unnamed author')),
      );
    },
  );
  test('empty visible shelves disappear', () {
    expect(
      authorShelves([
        item('one', ['A']),
      ], visible: {}),
      isEmpty,
    );
  });
  test(
    'move uses independent shelf visible slots, hidden members unchanged',
    () {
      final members = [
        item('a1', ['A']),
        item('b1', ['B']),
        item('hidden', ['A']),
        item('a2', ['A']),
        item('b2', ['B']),
      ];
      final plan = planAuthorShelfMove(
        members: members,
        aliases: {},
        author: 'A',
        comic: ('a2', 0),
        neighbor: ('a1', 0),
        before: true,
        visible: {('a1', 0), ('a2', 0)},
      );
      expect(plan.items.map((item) => item.id), ['a2', 'hidden', 'a1']);
      expect(plan.items[1], same(members[2]));
      expect(members.map((item) => item.id), [
        'a1',
        'b1',
        'hidden',
        'a2',
        'b2',
      ]);
    },
  );
  test(
    'shared identities reorder one shelf without mutating the source projection',
    () {
      final plan = planAuthorShelfMove(
        members: [
          item('one', ['A', 'B']),
          item('two', ['A', 'B']),
        ],
        aliases: {},
        author: 'A',
        comic: ('two', 0),
        neighbor: ('one', 0),
        before: true,
        visible: {('one', 0), ('two', 0)},
      );
      expect(plan.items.map((item) => item.id), ['two', 'one']);
    },
  );
  test('changed author or missing full identity refuses stale move', () {
    expect(
      () => planAuthorShelfMove(
        members: [
          item('one', ['A']),
          item('two', ['B']),
        ],
        aliases: {},
        author: 'A',
        comic: ('two', 0),
        neighbor: ('one', 0),
        before: true,
        visible: {('one', 0), ('two', 0)},
      ),
      throwsFormatException,
    );
  });
  test('missing and malformed states default to normal', () {
    for (final value in [null, 4, {}, [], true, 'bad']) {
      expect(AuthorShelfState.decode(value), AuthorShelfState.normal);
    }
    for (final state in AuthorShelfState.values) {
      expect(AuthorShelfState.decode(state.name), state);
    }
  });
}
