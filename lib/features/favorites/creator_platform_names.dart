import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'favorite_filters.dart';
import 'favorite_models.dart';
import 'favorites_manager.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';

const creatorPlatformNamesKey = 'creator_platform_names';

Map<String, String> creatorAliases([Map<String, dynamic>? data]) {
  final raw = (data ?? appdata.implicitData)['local_favorites_author_aliases'];
  return raw is Map
      ? {
          for (final e in raw.entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        }
      : {};
}

String creatorForAnchor(String anchor, Map<String, String> aliases) =>
    aliases[anchor] ?? anchor;

@immutable
class CreatorPlatformName {
  const CreatorPlatformName(this.anchor, this.sourceKey, this.name);
  final String anchor;
  final String sourceKey;
  final String name;
  Map<String, String> toJson() => {
    'anchor': anchor,
    'sourceKey': sourceKey,
    'name': name,
  };
  static CreatorPlatformName? decode(Object? raw) {
    if (raw is! Map) return null;
    final anchor = raw['anchor'];
    final source = raw['sourceKey'];
    final name = raw['name'];
    if (anchor is! String ||
        source is! String ||
        name is! String ||
        anchor.trim().isEmpty ||
        source.trim().isEmpty ||
        name.trim().isEmpty) {
      return null;
    }
    return CreatorPlatformName(
      normalizeFavoriteAuthor(anchor),
      source,
      name.trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CreatorPlatformName &&
      other.anchor == anchor &&
      other.sourceKey == sourceKey &&
      other.name == name;
  @override
  int get hashCode => Object.hash(anchor, sourceKey, name);
}

class CreatorPlatformNamesData {
  CreatorPlatformNamesData({
    Iterable<CreatorPlatformName> entries = const [],
    Iterable<CreatorPlatformName> hidden = const [],
  }) : entries = entries.toSet(),
       hidden = hidden.toSet();
  final Set<CreatorPlatformName> entries;
  final Set<CreatorPlatformName> hidden;
  factory CreatorPlatformNamesData.decode(Object? raw) {
    Iterable<CreatorPlatformName> read(String key) =>
        raw is Map && raw[key] is List
        ? (raw[key] as List)
              .map(CreatorPlatformName.decode)
              .whereType<CreatorPlatformName>()
        : const [];
    return CreatorPlatformNamesData(
      entries: read('entries'),
      hidden: read('hidden'),
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'entries': entries.map((e) => e.toJson()).toList(),
    'hidden': hidden.map((e) => e.toJson()).toList(),
  };
}

/// Call with allComics(), which preserves distinct metadata in each folder.
List<CreatorPlatformName> observedCreatorNames(Iterable<FavoriteItem> rows) {
  final result = <CreatorPlatformName>{};
  for (final comic in rows) {
    final key = comic.sourceKey;
    if (key.startsWith('Unknown:')) continue;
    final names = <String>[];
    for (final tag in comic.tags) {
      final separator = tag.indexOf(':');
      if (separator > 0 && isAuthorNamespace(tag.substring(0, separator))) {
        final name = tag.substring(separator + 1).trim();
        if (name.isNotEmpty) names.add(name);
      }
    }
    if (names.isEmpty && comic.author.trim().isNotEmpty) {
      names.add(comic.author.trim());
    }
    for (final name in names) {
      result.add(CreatorPlatformName(normalizeFavoriteAuthor(name), key, name));
    }
  }
  return result.toList();
}

class CreatorPlatformRow {
  CreatorPlatformRow(this.sourceKey, this.name);
  final String sourceKey;
  final String name;
}

List<CreatorPlatformRow> creatorPlatformRows(
  String creator,
  Iterable<CreatorPlatformName> observed,
  CreatorPlatformNamesData data,
  Map<String, String> aliases,
) {
  final rows = <(String, String)>{};
  for (final item in [
    ...observed.where((e) => !data.hidden.contains(e)),
    ...data.entries,
  ]) {
    if (creatorForAnchor(item.anchor, aliases) == creator) {
      rows.add((item.sourceKey, item.name));
    }
  }
  return [for (final row in rows) CreatorPlatformRow(row.$1, row.$2)]
    ..sort((a, b) {
      final source = a.sourceKey.compareTo(b.sourceKey);
      return source == 0 ? a.name.compareTo(b.name) : source;
    });
}

/// Owns one store generation and data directory. Edits join appdata's latest
/// draft, with admission checked again when that draft actually executes.
class CreatorPlatformNamesStore extends ChangeNotifier {
  CreatorPlatformNamesStore(this.manager, {required this.isCurrent})
    : _generation = manager.connectionGeneration,
      _path = App.dataPath;
  final LocalFavoritesManager manager;
  final bool Function() isCurrent;
  final int _generation;
  final String _path;
  List<CreatorPlatformName> observed = [];
  bool get active =>
      isCurrent() &&
      App.dataPath == _path &&
      manager.connectionGeneration == _generation;
  void checkCurrent() {
    if (!active) throw StateError('Creator edit is no longer active');
  }

  Future<void> refresh() => AppDataOperations.instance.access(() {
    checkCurrent();
    observed = observedCreatorNames(manager.allComics());
    checkCurrent();
    notifyListeners();
  });
  List<CreatorPlatformRow> rows(String creator) => creatorPlatformRows(
    creator,
    observed,
    CreatorPlatformNamesData.decode(
      appdata.implicitData[creatorPlatformNamesKey],
    ),
    creatorAliases(),
  );

  Future<void> change(
    String creator, {
    CreatorPlatformRow? previous,
    String? sourceKey,
    String? name,
  }) async {
    checkCurrent();
    final aliasSnapshot = jsonEncode(creatorAliases());
    final cleanName = name?.trim();
    if (sourceKey != null &&
        (sourceKey.isEmpty || cleanName == null || cleanName.isEmpty)) {
      throw const FormatException('Platform name is empty');
    }
    Object? before;
    Object? written;
    var edited = false;
    try {
      await appdata.updateImplicit((draft) {
        checkCurrent();
        final aliases = creatorAliases(draft);
        if (jsonEncode(aliases) != aliasSnapshot) {
          throw StateError('Creator edit is no longer active');
        }
        final known = observedCreatorNames(manager.allComics());
        final data = CreatorPlatformNamesData.decode(
          draft[creatorPlatformNamesKey],
        );
        bool belongs(CreatorPlatformName e) =>
            creatorForAnchor(e.anchor, aliases) == creator;
        if (previous != null) {
          bool matches(CreatorPlatformName e) =>
              belongs(e) &&
              e.sourceKey == previous.sourceKey &&
              e.name == previous.name;
          data.entries.removeWhere(matches);
          data.hidden.addAll(known.where(matches));
        }
        if (sourceKey != null) {
          final anchors =
              known.where(belongs).map((e) => e.anchor).toSet().toList()
                ..sort();
          final anchor = anchors.contains(creator)
              ? creator
              : anchors.firstOrNull ?? normalizeFavoriteAuthor(creator);
          data.hidden.removeWhere(
            (e) =>
                belongs(e) && e.sourceKey == sourceKey && e.name == cleanName,
          );
          // Same-source identical values are idempotent, across all anchors in this group.
          if (!data.entries.any(
            (e) =>
                belongs(e) && e.sourceKey == sourceKey && e.name == cleanName,
          )) {
            data.entries.add(
              CreatorPlatformName(anchor, sourceKey, cleanName!),
            );
          }
        }
        before = draft[creatorPlatformNamesKey];
        written = data.toJson();
        draft[creatorPlatformNamesKey] = written;
        edited = true;
      });
    } catch (_) {
      // updateImplicit publishes its draft before durable IO. Restore this key
      // only while it still contains our failed value; never overwrite newer work.
      if (edited &&
          App.dataPath == _path &&
          jsonEncode(appdata.implicitData[creatorPlatformNamesKey]) ==
              jsonEncode(written)) {
        if (before == null) {
          appdata.implicitData.remove(creatorPlatformNamesKey);
        } else {
          appdata.implicitData[creatorPlatformNamesKey] = before;
        }
      }
      rethrow;
    }
    if (active) notifyListeners();
  }
}
