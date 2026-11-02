import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/appdata.dart';

class SearchProfileSource {
  const SearchProfileSource({
    required this.sourceKey,
    required this.enabled,
    required this.options,
  });

  final String sourceKey;
  final bool enabled;
  final List<String> options;

  Map<String, dynamic> toJson() => {
    'source': sourceKey,
    'enabled': enabled,
    'options': options,
  };

  static SearchProfileSource? fromJson(Object? value) {
    if (value is! Map) return null;
    final source = value['source'];
    final options = value['options'];
    if (source is! String || options is! List) return null;
    return SearchProfileSource(
      sourceKey: source,
      enabled: value['enabled'] != false,
      options: options.whereType<String>().toList(growable: false),
    );
  }
}

class SearchProfile {
  const SearchProfile({
    required this.id,
    required this.name,
    required this.sources,
  });

  final String id;
  final String name;
  final List<SearchProfileSource> sources;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sources': sources.map((item) => item.toJson()).toList(),
  };

  static SearchProfile? fromJson(Object? value) {
    if (value is! Map || value['id'] is! String || value['name'] is! String) {
      return null;
    }
    final rawSources = value['sources'];
    if (rawSources is! List) return null;
    return SearchProfile(
      id: value['id'] as String,
      name: value['name'] as String,
      sources: rawSources
          .map(SearchProfileSource.fromJson)
          .whereType<SearchProfileSource>()
          .toList(growable: false),
    );
  }
}

class ResolvedSearchProfileSource {
  const ResolvedSearchProfileSource({
    required this.source,
    required this.options,
  });

  final ComicSource source;
  final List<String> options;
}

/// Appdata may publish a draft before reporting an IO failure. Retain its id
/// so the name form retries that creation instead of creating a duplicate.
class SearchProfileSaveFailure implements Exception {
  SearchProfileSaveFailure(this.profile, this.cause);
  final SearchProfile profile;
  final Object cause;
}

class SearchProfileManager extends ChangeNotifier {
  SearchProfileManager._();

  static final instance = SearchProfileManager._();

  List<SearchProfile> _decode(Object? raw) => raw is List
      ? raw.map(SearchProfile.fromJson).whereType<SearchProfile>().toList()
      : const [];

  List<SearchProfile> get all => _decode(appdata.settings['searchProfiles']);
  int _sequence = 0;
  String? get defaultId {
    final raw = appdata.settings['defaultSearchProfile'];
    return raw is String ? raw : null;
  }

  SearchProfile? get defaultProfile {
    final id = defaultId;
    return id == null ? null : all.where((item) => item.id == id).firstOrNull;
  }

  SearchProfile? byId(String id) =>
      all.where((item) => item.id == id).firstOrNull;

  String validateName(String raw, {String? exceptId}) =>
      _validateName(raw, all, exceptId: exceptId);

  String _validateName(
    String raw,
    List<SearchProfile> profiles, {
    String? exceptId,
  }) {
    final name = raw.trim();
    if (name.isEmpty) {
      throw const FormatException('Search profile name is empty');
    }
    if (name.length > 30) {
      throw const FormatException('Search profile name is too long');
    }
    if (profiles.any(
      (item) =>
          item.id != exceptId && item.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const FormatException('Search profile name already exists');
    }
    return name;
  }

  Future<SearchProfile> create(
    String rawName,
    List<SearchProfileSource> sources,
  ) async {
    SearchProfile? created;
    final snapshot = [
      for (final entry in sources)
        SearchProfileSource(
          sourceKey: entry.sourceKey,
          enabled: entry.enabled,
          options: List.unmodifiable(entry.options),
        ),
    ];
    try {
      await appdata.updateSettings((settings) {
        final profiles = _decode(settings['searchProfiles']);
        final name = _validateName(rawName, profiles);
        created = SearchProfile(
          id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
          name: name,
          sources: List.unmodifiable(snapshot),
        );
        settings['searchProfiles'] = [
          ...profiles.map((e) => e.toJson()),
          created!.toJson(),
        ];
      });
    } catch (error) {
      if (created != null && byId(created!.id) != null) {
        throw SearchProfileSaveFailure(created!, error);
      }
      rethrow;
    }
    notifyListeners();
    return created!;
  }

  Future<void> rename(String id, String rawName) async {
    await appdata.updateSettings((settings) {
      final profiles = _decode(settings['searchProfiles']);
      final name = _validateName(rawName, profiles, exceptId: id);
      settings['searchProfiles'] = [
        for (final profile in profiles)
          (profile.id == id
                  ? SearchProfile(id: id, name: name, sources: profile.sources)
                  : profile)
              .toJson(),
      ];
    });
    notifyListeners();
  }

  Future<void> update(String id, List<SearchProfileSource> sources) async {
    final snapshot = [
      for (final entry in sources)
        SearchProfileSource(
          sourceKey: entry.sourceKey,
          enabled: entry.enabled,
          options: List.unmodifiable(entry.options),
        ),
    ];
    await appdata.updateSettings((settings) {
      final profiles = _decode(settings['searchProfiles']);
      if (!profiles.any((e) => e.id == id)) {
        throw StateError('Search profile no longer exists');
      }
      settings['searchProfiles'] = [
        for (final profile in profiles)
          (profile.id == id
                  ? SearchProfile(
                      id: id,
                      name: profile.name,
                      sources: List.unmodifiable(snapshot),
                    )
                  : profile)
              .toJson(),
      ];
    });
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await appdata.updateSettings((settings) {
      settings['searchProfiles'] = _decode(
        settings['searchProfiles'],
      ).where((item) => item.id != id).map((item) => item.toJson()).toList();
      if (settings['defaultSearchProfile'] == id) {
        settings['defaultSearchProfile'] = null;
      }
    });
    notifyListeners();
  }

  Future<void> setDefault(String? id) async {
    await appdata.updateSettings((settings) {
      settings['defaultSearchProfile'] = id;
    });
    notifyListeners();
  }

  List<ResolvedSearchProfileSource> resolve(SearchProfile profile) {
    final resolved = <ResolvedSearchProfileSource>[];
    for (final entry in profile.sources) {
      if (!entry.enabled) continue;
      final source = ComicSource.find(entry.sourceKey);
      final data = source?.searchPageData;
      if (source == null || data == null) continue;
      final options = resolveSearchProfileOptions(data, entry.options);
      resolved.add(
        ResolvedSearchProfileSource(source: source, options: options),
      );
    }
    return resolved;
  }
}

List<SearchProfileSource> searchProfileSourcesFromGlobals() {
  final keys =
      (appdata.settings['searchSources'] as List?)?.whereType<String>() ??
      const <String>[];
  return [
    for (final key in keys)
      if (ComicSource.find(key)?.searchPageData != null)
        SearchProfileSource(
          sourceKey: key,
          enabled: true,
          options:
              (ComicSource.find(key)!.searchPageData!.searchOptions ??
                      const <SearchOptions>[])
                  .map((item) => item.defaultValue)
                  .toList(growable: false),
        ),
  ];
}

String searchProfileJson(SearchProfile profile) => jsonEncode(profile.toJson());

List<String> resolveSearchProfileOptions(
  SearchPageData data,
  List<String> stored,
) {
  final schema = data.searchOptions ?? const <SearchOptions>[];
  return List.unmodifiable([
    for (var i = 0; i < schema.length; i++)
      _validProfileOption(schema[i], i < stored.length ? stored[i] : null),
  ]);
}

String _validProfileOption(SearchOptions schema, String? value) {
  if (value == null) return schema.defaultValue;
  if (schema.type == 'multi-select') {
    try {
      final decoded = jsonDecode(value);
      return decoded is List &&
              decoded.every((e) => e is String && schema.options.containsKey(e))
          ? jsonEncode(decoded)
          : schema.defaultValue;
    } catch (_) {
      return schema.defaultValue;
    }
  }
  return schema.options.isEmpty || schema.options.containsKey(value)
      ? value
      : schema.defaultValue;
}
