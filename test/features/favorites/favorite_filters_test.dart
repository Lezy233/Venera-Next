import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/favorites/favorite_filters.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/foundation/comic_type.dart';

FavoriteItem _item({
  String id = 'id',
  String author = '',
  List<String> tags = const [],
  DateTime? time,
}) => FavoriteItem(
  id: id,
  name: 'name $id',
  coverPath: '',
  author: author,
  type: const ComicType(17),
  tags: tags,
  favoriteTime: time,
);

void main() {
  test('namespaced author tags win over the stored author', () {
    final comic = _item(
      author: 'uploader',
      tags: ['artist:乃莉助', 'translator:紫藤汉化组', 'genre:短篇'],
    );
    expect(favoriteAuthorValues(comic), ['乃莉助']);
  });

  test('multiple author tags are kept and deduplicated', () {
    final comic = _item(
      author: 'uploader',
      tags: ['artist:乃莉助', 'author:乃莉助 ', 'artist:第二作者'],
    );
    expect(favoriteAuthorValues(comic), ['乃莉助', '第二作者']);
  });

  test('falls back to the stored author with light normalization', () {
    expect(favoriteAuthorValues(_item(author: '  木の芽  ')), ['木の芽']);
    expect(favoriteAuthorValues(_item(author: ' A   B ')), ['A B']);
    expect(favoriteAuthorValues(_item(author: '  ')), isEmpty);
  });

  test('tag value strips only the first namespace separator', () {
    expect(favoriteTagValue('group:tag:tail'), 'tag:tail');
    expect(favoriteTagValue('純愛'), '純愛');
  });

  test('labels fall back to the raw value without translation data', () {
    expect(favoriteTagLabel('artist:純愛'), '純愛');
  });

  test('aliases resolve author values for filtering and sorting', () {
    final comic = _item(tags: ['artist:木の芽']);
    expect(favoriteAuthorValues(comic), ['木の芽']);
    expect(favoriteAuthorValues(comic, aliases: {'木の芽': 'Konomi'}), ['Konomi']);
    final sorted = sortFavoriteItems(
      [_item(id: 'b', author: 'B'), _item(id: 'a', author: 'A')],
      'authorAsc',
      aliases: {'A': 'Z', 'B': 'A'},
    );
    expect(sorted.map((e) => e.id), ['b', 'a']);
  });

  test('sorts by favorite time in both directions', () {
    final older = _item(id: 'a', time: DateTime.utc(2026, 1, 1));
    final newer = _item(id: 'b', time: DateTime.utc(2026, 2, 1));
    final items = [older, newer];
    expect(sortFavoriteItems(items, 'timeNewest').map((e) => e.id), ['b', 'a']);
    expect(sortFavoriteItems(items, 'timeOldest').map((e) => e.id), ['a', 'b']);
  });

  test('author sorting keeps unknown authors last in both directions', () {
    final alpha = _item(id: 'a', author: 'alpha');
    final beta = _item(id: 'b', author: 'beta');
    final none = _item(id: 'c', author: '');
    final items = [none, beta, alpha];
    expect(sortFavoriteItems(items, 'authorAsc').map((e) => e.id), [
      'a',
      'b',
      'c',
    ]);
    expect(sortFavoriteItems(items, 'authorDesc').map((e) => e.id), [
      'b',
      'a',
      'c',
    ]);
  });

  test('manual mode keeps the stored order', () {
    final items = [_item(id: 'b'), _item(id: 'a')];
    expect(sortFavoriteItems(items, 'manual').map((e) => e.id), ['b', 'a']);
  });
}
