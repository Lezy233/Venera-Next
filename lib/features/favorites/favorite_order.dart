import 'favorite_filters.dart';
import 'favorite_models.dart';

typedef FavoriteIdentity = (String, int);

enum FavoriteOrderScopeKind { all, folder, series }

/// A display scope never shares a namespace with a folder or a series.
class FavoriteOrderScope {
  const FavoriteOrderScope.all() : kind = FavoriteOrderScopeKind.all, id = '';
  const FavoriteOrderScope.folder(this.id)
    : kind = FavoriteOrderScopeKind.folder;
  const FavoriteOrderScope.series(this.id)
    : kind = FavoriteOrderScopeKind.series;
  final FavoriteOrderScopeKind kind;
  final String id;
}

FavoriteIdentity favoriteIdentity(FavoriteItem item) =>
    (item.id, item.type.value);

Map<String, String> favoriteAuthorAliases(Object? stored) => stored is Map
    ? {
        for (final entry in stored.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      }
    : const {};

String favoriteOrderAuthor(FavoriteItem item, Map<String, String> aliases) =>
    favoriteAuthorValues(item, aliases: aliases).firstOrNull ?? '';

int compareFavoriteOrderAuthors(String a, String b) {
  if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
  final result = a.toLowerCase().compareTo(b.toLowerCase());
  return result == 0 ? a.compareTo(b) : result;
}

List<FavoriteItem> authorManualFavoriteItems(
  List<FavoriteItem> items,
  Map<FavoriteIdentity, int> ranks,
  Map<String, String> aliases,
) {
  final seed = {
    for (var i = 0; i < items.length; i++) favoriteIdentity(items[i]): i,
  };
  return List.of(items)..sort((a, b) {
    final author = compareFavoriteOrderAuthors(
      favoriteOrderAuthor(a, aliases),
      favoriteOrderAuthor(b, aliases),
    );
    if (author != 0) return author;
    final left = ranks[favoriteIdentity(a)];
    final right = ranks[favoriteIdentity(b)];
    if (left != null && right != null) return left.compareTo(right);
    if (left != null || right != null) return left != null ? -1 : 1;
    if (ranks.isEmpty) {
      return seed[favoriteIdentity(a)]!.compareTo(seed[favoriteIdentity(b)]!);
    }
    final time = a.time.compareTo(b.time);
    if (time != 0) return time;
    final id = a.id.compareTo(b.id);
    return id != 0 ? id : a.type.value.compareTo(b.type.value);
  });
}
