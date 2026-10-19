import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/app_locale.dart';

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
