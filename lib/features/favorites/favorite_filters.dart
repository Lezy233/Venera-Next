import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/app_locale.dart';

import 'favorite_models.dart';

/// Everything after the first `namespace:` separator, or the whole tag when it
/// has no namespace. Only the first separator is stripped so values that
/// contain colons survive.
String favoriteTagValue(String tag) {
  final separator = tag.indexOf(':');
  return separator > 0 ? tag.substring(separator + 1) : tag;
}

/// Value shown for a tag in the favorites filter list.
String favoriteTagLabel(String tag) {
  final value = favoriteTagValue(tag);
  if (appLocale.languageCode == 'en') {
    return value;
  }
  return value.translateTagsToCN;
}

/// Author keys used to filter favorites.
///
/// Namespaced author tags are authoritative, matching how the favorites list
/// resolves its subtitle; the subtitle (the stored author for favorites without
/// author tags) is only a fallback so that an uploader never masquerades as an
/// author.
List<String> favoriteAuthorValues(Comic comic) {
  final tagAuthors = <String>[];
  for (final tag in comic.tags ?? const <String>[]) {
    final separator = tag.indexOf(':');
    if (separator <= 0) continue;
    if (!isAuthorNamespace(tag.substring(0, separator))) continue;
    final value = normalizeFavoriteAuthor(tag.substring(separator + 1));
    if (value.isNotEmpty && !tagAuthors.contains(value)) {
      tagAuthors.add(value);
    }
  }
  if (tagAuthors.isNotEmpty) return List.unmodifiable(tagAuthors);
  final author = normalizeFavoriteAuthor(comic.subtitle ?? '');
  return author.isEmpty ? const [] : [author];
}

/// Light normalization only: alias merging is a separate, user-confirmed step.
String normalizeFavoriteAuthor(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Ordering modes for the favorites list. `manual` keeps `display_order`.
const favoriteSortModes = [
  'manual',
  'timeNewest',
  'timeOldest',
  'authorAsc',
  'authorDesc',
];

bool isManualFavoriteSort(String mode) => mode == favoriteSortModes.first;

/// Returns a sorted copy for automatic modes; `manual` keeps the stored order.
List<FavoriteItem> sortFavoriteItems(List<FavoriteItem> items, String mode) {
  if (isManualFavoriteSort(mode)) return List.unmodifiable(items);
  final sorted = List<FavoriteItem>.of(items);
  sorted.sort((a, b) => _compareFavoriteItems(a, b, mode));
  return List.unmodifiable(sorted);
}

int _compareFavoriteItems(FavoriteItem a, FavoriteItem b, String mode) {
  int result;
  if (mode == 'authorAsc' || mode == 'authorDesc') {
    final left = _authorSortKey(a);
    final right = _authorSortKey(b);
    if (left.isEmpty != right.isEmpty) {
      // Favorites without a known author always sort last.
      return left.isEmpty ? 1 : -1;
    }
    result = mode == 'authorAsc'
        ? left.compareTo(right)
        : right.compareTo(left);
  } else {
    result = mode == 'timeNewest'
        ? b.time.compareTo(a.time)
        : a.time.compareTo(b.time);
  }
  if (result != 0) return result;
  result = a.name.compareTo(b.name);
  if (result != 0) return result;
  return a.id.compareTo(b.id);
}

String _authorSortKey(FavoriteItem comic) {
  final values = favoriteAuthorValues(comic);
  return values.isEmpty ? '' : values.first.toLowerCase();
}
