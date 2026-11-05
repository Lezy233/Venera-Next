import 'dart:convert';
import 'favorite_filters.dart';
import 'favorite_models.dart';
import 'favorite_order.dart';

enum AuthorShelfState {
  collapsed,
  normal,
  expanded;

  static AuthorShelfState decode(Object? value) =>
      values.where((state) => state.name == value).firstOrNull ?? normal;
}

/// Null is the unknown-author identity, distinct from every literal name.
typedef AuthorShelfAuthor = String?;

String authorShelfStorageKey(AuthorShelfAuthor author) =>
    jsonEncode(author == null ? ['unknown'] : ['author', author]);

class AuthorShelfGroup {
  const AuthorShelfGroup(this.author, this.items);
  final AuthorShelfAuthor author;
  final List<FavoriteItem> items;
}

List<AuthorShelfAuthor> authorShelfAuthors(
  FavoriteItem item,
  Map<String, String> aliases,
) {
  final authors = favoriteAuthorValues(item, aliases: aliases);
  return authors.isEmpty ? [null] : authors;
}

/// Build order from full membership before applying visibility. Never uses
/// alphabetical order, legacy ranks, or the folder-name ordering table.
List<AuthorShelfGroup> authorShelves(
  List<FavoriteItem> members, {
  Map<String, String> aliases = const {},
  Set<FavoriteIdentity>? visible,
  Map<String, Map<FavoriteIdentity, int>> orders = const {},
}) {
  final groups = <AuthorShelfAuthor, List<FavoriteItem>>{};
  final seen = <(AuthorShelfAuthor, FavoriteIdentity)>{};
  for (final item in members) {
    for (final author in authorShelfAuthors(item, aliases)) {
      final group = groups.putIfAbsent(author, () => []);
      if (seen.add((author, favoriteIdentity(item)))) {
        group.add(item);
      }
    }
  }
  List<FavoriteItem> projected(AuthorShelfAuthor author) =>
      orderAuthorShelfItems(
            groups[author]!,
            orders[authorShelfStorageKey(author)] ?? const {},
          )
          .where(
            (item) =>
                visible == null || visible.contains(favoriteIdentity(item)),
          )
          .toList();
  return [
    for (final entry in groups.entries)
      if (entry.key != null && projected(entry.key).isNotEmpty)
        AuthorShelfGroup(entry.key, List.unmodifiable(projected(entry.key))),
    if (groups.containsKey(null) && projected(null).isNotEmpty)
      AuthorShelfGroup(null, List.unmodifiable(projected(null))),
  ];
}

/// Valid saved ranks precede new members; ties use the current folder projection.
/// Reading malformed rows never repairs storage or omits an actual member.
List<FavoriteItem> orderAuthorShelfItems(
  List<FavoriteItem> members,
  Map<FavoriteIdentity, int> ranks,
) {
  final positions = {
    for (var i = 0; i < members.length; i++) favoriteIdentity(members[i]): i,
  };
  final result = List<FavoriteItem>.of(members);
  int? valid(FavoriteItem item) {
    final rank = ranks[favoriteIdentity(item)];
    return rank != null && rank >= 0 ? rank : null;
  }

  result.sort((a, b) {
    final ra = valid(a), rb = valid(b);
    if (ra == null && rb != null) return 1;
    if (ra != null && rb == null) return -1;
    final compared = ra == null || rb == null ? 0 : ra.compareTo(rb);
    return compared != 0
        ? compared
        : positions[favoriteIdentity(a)]!.compareTo(
            positions[favoriteIdentity(b)]!,
          );
  });
  return result;
}

class AuthorShelfMove {
  const AuthorShelfMove(this.items);
  final List<FavoriteItem> items;
}

AuthorShelfMove planAuthorShelfMove({
  required List<FavoriteItem> members,
  required Map<String, String> aliases,
  required AuthorShelfAuthor author,
  required FavoriteIdentity comic,
  required FavoriteIdentity neighbor,
  required bool before,
  required Set<FavoriteIdentity> visible,
  Map<FavoriteIdentity, int> ranks = const {},
}) {
  final complete = orderAuthorShelfItems(
    members
        .where((item) => authorShelfAuthors(item, aliases).contains(author))
        .toList(),
    ranks,
  );
  final slots = <int>[];
  for (var i = 0; i < complete.length; i++) {
    if (visible.contains(favoriteIdentity(complete[i]))) {
      slots.add(i);
    }
  }
  final group = [for (final slot in slots) complete[slot]];
  final moving = group
      .where((item) => favoriteIdentity(item) == comic)
      .firstOrNull;
  if (moving == null ||
      comic == neighbor ||
      !group.any((item) => favoriteIdentity(item) == neighbor)) {
    throw const FormatException(
      'Favorite author group changed. Refresh and try again.',
    );
  }
  group.remove(moving);
  group.insert(
    group.indexWhere((item) => favoriteIdentity(item) == neighbor) +
        (before ? 0 : 1),
    moving,
  );
  final result = List<FavoriteItem>.of(complete);
  for (var i = 0; i < slots.length; i++) {
    result[slots[i]] = group[i];
  }
  return AuthorShelfMove(List.unmodifiable(result));
}
