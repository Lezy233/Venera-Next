import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/favorites/favorite_filters.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/foundation/comic_type.dart';

FavoriteItem _item({String author = '', List<String> tags = const []}) =>
    FavoriteItem(
      id: 'id',
      name: 'name',
      coverPath: '',
      author: author,
      type: const ComicType(17),
      tags: tags,
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
}
