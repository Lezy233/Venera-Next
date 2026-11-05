import 'package:venera_next/foundation/sqlite_transaction.dart';
import 'package:sqlite3/sqlite3.dart';
import 'favorite_models.dart';
import 'favorite_row.dart';
import 'favorite_series.dart';
import 'favorite_order.dart';
import 'author_shelf_model.dart';

/// Favorite persistence on a caller-owned connection; no cache or notifications.
class FavoritesRepository {
  FavoritesRepository(this.db, {this.shelfAliases});
  final Database db;
  final Map<String, String> Function()? shelfAliases;

  void initializeMetadata() => _membershipTransaction(() {
    db.execute('''CREATE TABLE IF NOT EXISTS favorite_author_shelf_order (
      folder_name TEXT NOT NULL, author_key TEXT NOT NULL,
      comic_id TEXT NOT NULL, comic_type INTEGER NOT NULL, rank INTEGER,
      PRIMARY KEY(folder_name, author_key, comic_id, comic_type));''');
    db.execute('''CREATE TABLE IF NOT EXISTS favorite_author_shelf_states (
      folder_name TEXT NOT NULL, author_key TEXT NOT NULL, state TEXT,
      PRIMARY KEY(folder_name, author_key));''');
    db.execute('''CREATE TABLE IF NOT EXISTS favorite_order_scopes (
      kind TEXT NOT NULL, scope_id TEXT NOT NULL, token TEXT NOT NULL,
      mode TEXT NOT NULL, PRIMARY KEY(kind, scope_id));''');
    db.execute('''CREATE TABLE IF NOT EXISTS favorite_author_order (
      kind TEXT NOT NULL, scope_id TEXT NOT NULL, comic_id TEXT NOT NULL,
      comic_type INTEGER NOT NULL, rank INTEGER NOT NULL,
      PRIMARY KEY(kind, scope_id, comic_id, comic_type));''');
    db.execute(
      'CREATE TABLE IF NOT EXISTS folder_order (folder_name TEXT PRIMARY KEY, order_value INT);',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS folder_sync (folder_name TEXT PRIMARY KEY, source_key TEXT, source_folder TEXT);',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_series (
        id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, display_order INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_series_items (
        series_id TEXT NOT NULL, comic_id TEXT NOT NULL, comic_type INTEGER NOT NULL,
        PRIMARY KEY (series_id, comic_id, comic_type),
        FOREIGN KEY (series_id) REFERENCES favorite_series(id) ON DELETE CASCADE
      );
    ''');
  });

  List<FavoriteSeries> series() => db
      .select(
        'SELECT id, name, display_order FROM favorite_series ORDER BY display_order, id;',
      )
      .map(
        (row) => FavoriteSeries(
          id: row['id'] as String,
          name: row['name'] as String,
          displayOrder: row['display_order'] as int,
        ),
      )
      .toList();

  FavoriteSeries createSeries(
    String id,
    String name,
    int order,
  ) => _membershipTransaction(() {
    db.execute(
      'INSERT INTO favorite_series (id, name, display_order) VALUES (?, ?, ?);',
      [id, name, order],
    );
    return FavoriteSeries(id: id, name: name, displayOrder: order);
  });

  void renameSeries(String id, String name) => _transaction(() {
    db.execute('UPDATE favorite_series SET name = ? WHERE id = ?;', [name, id]);
  });

  void deleteSeries(String id) => _membershipTransaction(() {
    deleteOrderScope(FavoriteOrderScope.series(id));
    db.execute('DELETE FROM favorite_series_items WHERE series_id = ?;', [id]);
    db.execute('DELETE FROM favorite_series WHERE id = ?;', [id]);
  });

  void reorderSeries(List<String> ids) => _transaction(() {
    for (var i = 0; i < ids.length; i++) {
      db.execute('UPDATE favorite_series SET display_order = ? WHERE id = ?;', [
        i,
        ids[i],
      ]);
    }
  });

  List<(String, int)> seriesMembers(String seriesId) => db
      .select(
        'SELECT comic_id, comic_type FROM favorite_series_items WHERE series_id = ?;',
        [seriesId],
      )
      .map((row) => (row['comic_id'] as String, row['comic_type'] as int))
      .toList();

  void addSeriesMembers(
    String seriesId,
    Iterable<(String, int)> identities,
  ) => _membershipTransaction(() {
    for (final (id, type) in identities) {
      db.execute(
        'INSERT OR IGNORE INTO favorite_series_items (series_id, comic_id, comic_type) VALUES (?, ?, ?);',
        [seriesId, id, type],
      );
    }
  });

  void removeSeriesMembers(
    String seriesId,
    Iterable<(String, int)> identities,
  ) => _membershipTransaction(() {
    for (final (id, type) in identities) {
      removeOrderMember(FavoriteOrderScope.series(seriesId), (id, type));
      db.execute(
        'DELETE FROM favorite_series_items WHERE series_id = ? AND comic_id = ? AND comic_type = ?;',
        [seriesId, id, type],
      );
    }
  });

  int seriesMemberCount(String seriesId) =>
      db.select(
            'SELECT COUNT(*) AS c FROM favorite_series_items WHERE series_id = ?;',
            [seriesId],
          ).first['c']
          as int;

  void cleanupOrphanSeriesMembers(
    Iterable<String> folders,
  ) => _membershipTransaction(() {
    final identities = db.select(
      'SELECT series_id, comic_id, comic_type FROM favorite_series_items;',
    );
    for (final row in identities) {
      final id = row['comic_id'] as String;
      final type = row['comic_type'] as int;
      final exists = folders.any((folder) => comicExists(folder, id, type));
      if (!exists) {
        db.execute(
          'DELETE FROM favorite_series_items WHERE series_id = ? AND comic_id = ? AND comic_type = ?;',
          [row['series_id'], id, type],
        );
      }
    }
  });

  List<FavoriteItem> getSeriesComics(
    String seriesId,
    Iterable<String> folders,
  ) {
    final result = <FavoriteItem>[];
    for (final (id, type) in seriesMembers(seriesId)) {
      for (final folder in folders) {
        final item = findComic(folder, id, type);
        if (item != null) {
          result.add(item);
          break;
        }
      }
    }
    return result;
  }

  Set<String> _columns(String folder) => db
      .select('PRAGMA table_info(${_table(folder)});')
      .map((row) => row['name'] as String)
      .toSet();

  void migrateTranslatedTags(
    List<String> folders,
    String Function(List<String>) translate,
  ) => _transaction(() {
    for (final folder in folders) {
      if (_columns(folder).contains('translated_tags')) continue;
      db.execute(
        'ALTER TABLE ${_table(folder)} ADD COLUMN translated_tags TEXT;',
      );
      for (final item in getFolderComics(folder)) {
        db.execute(
          'UPDATE ${_table(folder)} SET translated_tags = ? WHERE id = ? AND type = ?;',
          [translate(item.tags), item.id, item.type.value],
        );
      }
    }
  });

  bool isPreparedForFollowUpdates(String folder) => _columns(
    folder,
  ).containsAll(['last_update_time', 'has_new_update', 'last_check_time']);

  void prepareForFollowUpdates(String folder, {required bool clearData}) =>
      _transaction(() {
        final columns = _columns(folder);
        for (final (name, type) in [
          ('last_update_time', 'TEXT'),
          ('has_new_update', 'INT'),
          ('last_check_time', 'INT'),
        ]) {
          if (!columns.contains(name)) {
            db.execute('ALTER TABLE ${_table(folder)} ADD COLUMN $name $type;');
          }
        }
        if (clearData) {
          db.execute('UPDATE ${_table(folder)} SET has_new_update = 0;');
        }
      });

  void createFolder(String folder) => _membershipTransaction(() {
    db.execute('''
      CREATE TABLE ${_table(folder)} (
        id TEXT, name TEXT, author TEXT, type INT, tags TEXT, cover_path TEXT,
        time TEXT, display_order INT, translated_tags TEXT,
        PRIMARY KEY (id, type)
      );
    ''');
  });

  void renameFolder(String before, String after) => _membershipTransaction(() {
    if (_hasShelfOrders) {
      db.execute(
        'UPDATE favorite_author_shelf_order SET folder_name = ? WHERE folder_name = ?;',
        [after, before],
      );
    }
    if (_hasShelfStates) {
      db.execute(
        'UPDATE favorite_author_shelf_states SET folder_name = ? WHERE folder_name = ?;',
        [after, before],
      );
    }
    if (_hasAuthorOrders) {
      for (final table in ['favorite_order_scopes', 'favorite_author_order']) {
        db.execute(
          'UPDATE $table SET scope_id = ? WHERE kind = ? AND scope_id = ?;',
          [after, 'folder', before],
        );
      }
    }
    db.execute('ALTER TABLE ${_table(before)} RENAME TO ${_table(after)};');
    db.execute(
      'UPDATE folder_order SET folder_name = ? WHERE folder_name = ?;',
      [after, before],
    );
    db.execute(
      'UPDATE folder_sync SET folder_name = ? WHERE folder_name = ?;',
      [after, before],
    );
  });

  void linkFolderToNetwork(String folder, String source, String networkFolder) {
    db.execute(
      'INSERT OR REPLACE INTO folder_sync (folder_name, source_key, source_folder) VALUES (?, ?, ?);',
      [folder, source, networkFolder],
    );
  }

  bool isLinkedToNetworkFolder(
    String folder,
    String source,
    String networkFolder,
  ) => db.select(
    'SELECT 1 FROM folder_sync WHERE folder_name = ? AND source_key = ? AND source_folder = ?;',
    [folder, source, networkFolder],
  ).isNotEmpty;

  (String?, String?) findLinked(String folder) {
    final rows = db.select(
      'SELECT source_key, source_folder FROM folder_sync WHERE folder_name = ?;',
      [folder],
    );
    return rows.isEmpty
        ? (null, null)
        : (rows.first['source_key'], rows.first['source_folder']);
  }

  Map<String, List<(String, int)>> deleteComics(
    List<String> folders,
    Iterable<(String, int)> identities, {
    String? schema,
  }) => _membershipTransaction(() {
    final requested = identities.toSet();
    final removed = <String, List<(String, int)>>{};
    for (final folder in folders) {
      for (final (id, type) in requested) {
        if (_removeRecord(folder, id, type, schema: schema)) {
          (removed[folder] ??= []).add((id, type));
        }
      }
    }
    return removed;
  });

  void deleteFolder(String folder) => _membershipTransaction(() {
    if (_hasShelfOrders) {
      db.execute(
        'DELETE FROM favorite_author_shelf_order WHERE folder_name = ?;',
        [folder],
      );
    }
    if (_hasShelfStates) {
      db.execute(
        'DELETE FROM favorite_author_shelf_states WHERE folder_name = ?;',
        [folder],
      );
    }
    deleteOrderScope(FavoriteOrderScope.folder(folder));
    db.execute('DROP TABLE ${_table(folder)};');
    db.execute('DELETE FROM folder_order WHERE folder_name = ?;', [folder]);
    db.execute('DELETE FROM folder_sync WHERE folder_name = ?;', [folder]);
  });

  bool addComic(
    String folder,
    FavoriteItem item, {
    required String translatedTags,
    required bool append,
    int? order,
    String? updateTime,
    String? schema,
  }) => _membershipTransaction(() {
    if (comicExists(folder, item.id, item.type.value, schema: schema)) {
      return false;
    }
    final position =
        order ??
        (append
            ? maxValue(folder, schema: schema) + 1
            : minValue(folder, schema: schema) - 1);
    db.execute(
      '''
      INSERT INTO ${_qualifiedTable(folder, schema)}
        (id, name, author, type, tags, cover_path, time, translated_tags, display_order)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''',
      [
        item.id,
        item.name,
        item.author,
        item.type.value,
        item.tags.join(','),
        item.coverPath,
        item.time,
        translatedTags,
        position,
      ],
    );
    if (updateTime != null &&
        db
            .select(
              'PRAGMA ${schema == null ? '' : '${_table(schema)}.'}table_info(${_table(folder)});',
            )
            .any((row) => row['name'] == 'last_update_time')) {
      db.execute(
        'UPDATE ${_qualifiedTable(folder, schema)} SET last_update_time = ? WHERE id = ? AND type = ?;',
        [updateTime, item.id, item.type.value],
      );
    }
    if (schema == null) _reconcileShelfFolder(folder);
    return true;
  });

  void updateOrder(List<String> folders) => _transaction(() {
    for (var i = 0; i < folders.length; i++) {
      db.execute(
        'INSERT OR REPLACE INTO folder_order (folder_name, order_value) VALUES (?, ?);',
        [folders[i], i],
      );
    }
  });

  void addTagTo(String folder, String id, String tag) => _transaction(() {
    db.execute('UPDATE ${_table(folder)} SET tags = ? || tags WHERE id = ?;', [
      '$tag,',
      id,
    ]);
    _reconcileShelfFolder(folder);
  });

  void updateInfo(String folder, FavoriteItem item) => _transaction(() {
    db.execute(
      'UPDATE ${_table(folder)} SET name = ?, author = ?, cover_path = ?, tags = ? WHERE id = ? AND type = ?;',
      [
        item.name,
        item.author,
        item.coverPath,
        item.tags.join(','),
        item.id,
        item.type.value,
      ],
    );
    _reconcileShelfFolder(folder);
  });

  /// Metadata and tracking time are one logical commit. An unchanged time
  /// preserves an unread update flag from a previous check.
  bool applyFollowUpdate(
    String folder,
    FavoriteItem item,
    String? updateTime,
    int checkedAt,
  ) => _transaction(() {
    final row = db.select(
      'SELECT last_update_time FROM ${_table(folder)} WHERE id = ? AND type = ?;',
      [item.id, item.type.value],
    ).firstOrNull;
    if (row == null) throw StateError('Favorite no longer exists');
    updateInfo(folder, item);
    if (updateTime == null || row['last_update_time'] == updateTime) {
      updateCheckTime(folder, item.id, item.type.value, checkedAt);
      return false;
    }
    return updateUpdateTime(
      folder,
      item.id,
      item.type.value,
      updateTime,
      checkedAt,
    );
  });

  void transferToFolders(
    String source,
    List<String> targets,
    List<(String, int)> identities, {
    required bool move,
  }) => _membershipTransaction(() {
    for (final target in targets) {
      copyMany(source, target, identities);
    }
    if (move) deleteComics([source], identities);
  });

  T _transaction<T>(T Function() action) => runSqliteTransaction(db, action);

  int _membershipDepth = 0;
  T _membershipTransaction<T>(T Function() action) => _transaction(() {
    _membershipDepth++;
    try {
      final result = action();
      if (_membershipDepth == 1) reconcileAuthorOrders();
      return result;
    } finally {
      _membershipDepth--;
    }
  });

  void _copyRecord(
    String source,
    String target,
    String id,
    int type,
    int order, {
    required bool ignoreExisting,
  }) {
    db.execute(
      '''
      INSERT ${ignoreExisting ? 'OR IGNORE ' : ''}INTO ${_table(target)}
        (id, name, author, type, tags, cover_path, time, display_order)
      SELECT id, name, author, type, tags, cover_path, time, ?
      FROM ${_table(source)} WHERE id = ? AND type = ?;
    ''',
      [order, id, type],
    );
    _reconcileShelfFolder(target);
  }

  bool _removeRecord(String folder, String id, int type, {String? schema}) {
    final table = schema == null
        ? _table(folder)
        : '${_table(schema)}.${_table(folder)}';
    db.execute('DELETE FROM $table WHERE id = ? AND type = ?;', [id, type]);
    final removed = db.updatedRows > 0;
    if (removed && schema == null && _hasShelfOrders) {
      db.execute(
        'DELETE FROM favorite_author_shelf_order WHERE folder_name = ? AND comic_id = ? AND comic_type = ?;',
        [folder, id, type],
      );
    }
    if (removed && schema == null && _hasAuthorOrders) {
      removeOrderMember(FavoriteOrderScope.folder(folder), (id, type));
    }
    return removed;
  }

  /// Single moves leave the source intact when the destination already exists.
  bool moveFavorite(String source, String target, String id, int type) =>
      _membershipTransaction(() {
        if (comicExists(target, id, type)) return false;
        _copyRecord(
          source,
          target,
          id,
          type,
          minValue(target) - 1,
          ignoreExisting: false,
        );
        _removeRecord(source, id, type);
        return true;
      });

  void moveMany(
    String source,
    String target,
    Iterable<(String, int)> identities,
  ) => _transferMany(source, target, identities, removeSource: true);

  void copyMany(
    String source,
    String target,
    Iterable<(String, int)> identities,
  ) => _transferMany(source, target, identities, removeSource: false);

  void _transferMany(
    String source,
    String target,
    Iterable<(String, int)> identities, {
    required bool removeSource,
  }) {
    if (source == target) return;
    _membershipTransaction(() {
      var order = maxValue(target) + 1;
      for (final (id, type) in identities) {
        _copyRecord(source, target, id, type, order, ignoreExisting: true);
        // Batch moves preserve the existing merge policy: keep destination
        // metadata on conflicts and remove the matching source record.
        if (removeSource) _removeRecord(source, id, type);
        order++;
      }
    });
  }

  static String _table(String folder) => '"${folder.replaceAll('"', '""')}"';

  static String _qualifiedTable(String folder, String? schema) =>
      schema == null ? _table(folder) : '${_table(schema)}.${_table(folder)}';

  List<String> folderNames() {
    final folders =
        db
            .select("SELECT name FROM sqlite_master WHERE type='table';")
            .map((row) => row['name'] as String)
            .toList()
          ..remove('folder_sync')
          ..remove('folder_order')
          ..remove('favorite_series')
          ..remove('favorite_series_items');
    folders.remove('favorite_order_scopes');
    folders.remove('favorite_author_order');
    folders.remove('favorite_author_shelf_states');
    folders.remove('favorite_author_shelf_order');
    final knownFolders = folders.toSet();
    final orders = <String, int>{};
    for (final row in db.select(
      'SELECT folder_name, order_value FROM folder_order;',
    )) {
      final name = row['folder_name'];
      if (name is String && knownFolders.contains(name)) {
        orders.putIfAbsent(name, () => row['order_value'] as int);
      }
    }
    folders.sort((a, b) => (orders[a] ?? 0) - (orders[b] ?? 0));
    return folders;
  }

  String? orderToken(FavoriteOrderScope scope) =>
      db.select(
            'SELECT token FROM favorite_order_scopes WHERE kind = ? AND scope_id = ?;',
            [scope.kind.name, scope.id],
          ).firstOrNull?['token']
          as String?;

  AuthorShelfState shelfState(
    String folder,
    AuthorShelfAuthor author,
  ) => AuthorShelfState.decode(
    db.select(
      'SELECT state FROM favorite_author_shelf_states WHERE folder_name = ? AND author_key = ?;',
      [folder, authorShelfStorageKey(author)],
    ).firstOrNull?['state'],
  );

  void setShelfState(
    String folder,
    AuthorShelfAuthor author,
    AuthorShelfState state,
  ) => _transaction(() {
    db.execute(
      'INSERT INTO favorite_author_shelf_states (folder_name, author_key, state) VALUES (?, ?, ?) ON CONFLICT(folder_name, author_key) DO UPDATE SET state = excluded.state;',
      [folder, authorShelfStorageKey(author), state.name],
    );
  });

  String? orderMode(FavoriteOrderScope scope) {
    final mode =
        db.select(
              'SELECT mode FROM favorite_order_scopes WHERE kind = ? AND scope_id = ?;',
              [scope.kind.name, scope.id],
            ).firstOrNull?['mode']
            as String?;
    return mode == '' ? null : mode;
  }

  Map<FavoriteIdentity, int> authorRanks(FavoriteOrderScope scope) => {
    for (final row in db.select(
      'SELECT comic_id, comic_type, rank FROM favorite_author_order WHERE kind = ? AND scope_id = ?;',
      [scope.kind.name, scope.id],
    ))
      (row['comic_id'] as String, row['comic_type'] as int): row['rank'] as int,
  };

  void setOrderMode(
    FavoriteOrderScope scope,
    String mode,
    String token,
    List<FavoriteItem> members,
  ) => _transaction(() {
    db.execute(
      'INSERT INTO favorite_order_scopes (kind, scope_id, token, mode) VALUES (?, ?, ?, ?) ON CONFLICT(kind, scope_id) DO UPDATE SET mode = excluded.mode;',
      [scope.kind.name, scope.id, token, mode],
    );
    if (mode == 'authorManual') reconcileOrder(scope, members);
  });

  void deleteOrderScope(FavoriteOrderScope scope) {
    if (!_hasAuthorOrders) return;
    for (final table in ['favorite_order_scopes', 'favorite_author_order']) {
      db.execute('DELETE FROM $table WHERE kind = ? AND scope_id = ?;', [
        scope.kind.name,
        scope.id,
      ]);
    }
  }

  void removeOrderMember(FavoriteOrderScope scope, FavoriteIdentity identity) {
    db.execute(
      'DELETE FROM favorite_author_order WHERE kind = ? AND scope_id = ? AND comic_id = ? AND comic_type = ?;',
      [scope.kind.name, scope.id, identity.$1, identity.$2],
    );
  }

  /// Seed once from the existing view order; subsequent additions append by
  /// collection time and full identity. No author names are persisted.
  void reconcileOrder(FavoriteOrderScope scope, List<FavoriteItem> members) {
    final ranks = authorRanks(scope);
    final known = members.map(favoriteIdentity).toSet();
    for (final identity in ranks.keys.where((id) => !known.contains(id))) {
      removeOrderMember(scope, identity);
    }
    final additions = members
        .where((item) => !ranks.containsKey(favoriteIdentity(item)))
        .toList();
    if (ranks.isNotEmpty) {
      additions.sort((a, b) {
        final time = a.time.compareTo(b.time);
        if (time != 0) return time;
        final id = a.id.compareTo(b.id);
        return id != 0 ? id : a.type.value.compareTo(b.type.value);
      });
    }
    var rank = ranks.values.fold<int>(-1, (a, b) => a > b ? a : b) + 1;
    for (final item in additions) {
      db.execute(
        'INSERT INTO favorite_author_order (kind, scope_id, comic_id, comic_type, rank) VALUES (?, ?, ?, ?, ?);',
        [scope.kind.name, scope.id, item.id, item.type.value, rank++],
      );
    }
  }

  void writeAuthorGroup(
    FavoriteOrderScope scope,
    List<FavoriteIdentity> group,
  ) {
    final ranks = authorRanks(scope);
    final slots = group.map((id) => ranks[id]!).toList()..sort();
    for (var i = 0; i < group.length; i++) {
      db.execute(
        'UPDATE favorite_author_order SET rank = ? WHERE kind = ? AND scope_id = ? AND comic_id = ? AND comic_type = ?;',
        [slots[i], scope.kind.name, scope.id, group[i].$1, group[i].$2],
      );
    }
  }

  /// Reconcile membership within the caller's transaction, including views
  /// affected by removing the final local reference to a comic.
  void reconcileAuthorOrders() {
    if (!_hasAuthorOrders) return;
    final folders = folderNames();
    for (final scope in [
      const FavoriteOrderScope.all(),
      for (final folder in folders) FavoriteOrderScope.folder(folder),
      for (final item in series()) FavoriteOrderScope.series(item.id),
    ]) {
      db.execute(
        "INSERT OR IGNORE INTO favorite_order_scopes (kind, scope_id, token, mode) VALUES (?, ?, lower(hex(randomblob(16))), '');",
        [scope.kind.name, scope.id],
      );
    }
    for (final row in db.select(
      'SELECT kind, scope_id FROM favorite_order_scopes;',
    )) {
      final id = row['scope_id'] as String;
      final scope = switch (row['kind']) {
        'folder' => FavoriteOrderScope.folder(id),
        'series' => FavoriteOrderScope.series(id),
        _ => const FavoriteOrderScope.all(),
      };
      if (orderMode(scope) != 'authorManual' && authorRanks(scope).isEmpty) {
        continue;
      }
      final members = switch (scope.kind) {
        FavoriteOrderScopeKind.all => getAllComics(folders),
        FavoriteOrderScopeKind.folder =>
          folders.contains(id) ? getFolderComics(id) : <FavoriteItem>[],
        FavoriteOrderScopeKind.series => getSeriesComics(id, folders),
      };
      reconcileOrder(scope, members);
    }
  }

  bool get _hasShelfStates => db
      .select(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='favorite_author_shelf_states';",
      )
      .isNotEmpty;

  bool get _hasAuthorOrders => db
      .select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'favorite_order_scopes';",
      )
      .isNotEmpty;

  int count(String folder) =>
      db.select('SELECT COUNT(*) AS c FROM ${_table(folder)};').first['c']
          as int;

  int maxValue(String folder, {String? schema}) =>
      db
              .select(
                'SELECT MAX(display_order) AS value FROM ${_qualifiedTable(folder, schema)};',
              )
              .first['value']
          as int? ??
      0;

  int minValue(String folder, {String? schema}) =>
      db
              .select(
                'SELECT MIN(display_order) AS value FROM ${_qualifiedTable(folder, schema)};',
              )
              .first['value']
          as int? ??
      0;

  List<FavoriteItem> getFolderComics(String folder, {int? limit}) => db
      .select(
        'SELECT * FROM ${_table(folder)} ORDER BY display_order${limit == null ? "" : " LIMIT ?"};',
        limit == null ? [] : [limit],
      )
      .map(favoriteItemFromRow)
      .toList();

  List<FavoriteItem> getAllComics(Iterable<String> folders) {
    final result = <FavoriteItem>{};
    for (final folder in folders) {
      result.addAll(
        db.select('SELECT * FROM ${_table(folder)};').map(favoriteItemFromRow),
      );
    }
    return result.toList();
  }

  List<FavoriteItemWithFolderInfo> allComics(Iterable<String> folders) => [
    for (final folder in folders)
      for (final row in db.select('SELECT * FROM ${_table(folder)};'))
        FavoriteItemWithFolderInfo(favoriteItemFromRow(row), folder),
  ];

  Map<(String, int), int> referenceCounts(
    Iterable<String> folders,
    Iterable<(String, int)> requested,
  ) {
    final identities = requested.toSet().toList();
    final counts = <(String, int), int>{};
    // Keep each statement below legacy SQLite's 999 bound-variable limit.
    for (final folder in folders) {
      for (var start = 0; start < identities.length; start += 400) {
        final chunk = identities.skip(start).take(400).toList();
        final placeholders = List.filled(chunk.length, '(?, ?)').join(',');
        final rows = db.select(
          'SELECT id, type FROM ${_table(folder)} WHERE (id, type) IN (VALUES $placeholders);',
          [
            for (final (id, type) in chunk) ...[id, type],
          ],
        );
        for (final row in rows) {
          final identity = (row['id'] as String, row['type'] as int);
          counts[identity] = (counts[identity] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  List<(String, int)> identities(
    String folder, {
    bool updatedOnly = false,
  }) => db
      .select(
        'SELECT id, type FROM ${_table(folder)}${updatedOnly ? " WHERE has_new_update = 1" : ""};',
      )
      .map((row) => (row['id'] as String, row['type'] as int))
      .toList();

  List<FavoriteItem> exportComics(String folder) => db
      .select('SELECT * FROM ${_table(folder)};')
      .map(favoriteItemFromRow)
      .toList();

  void editTags(String folder, String id, List<String> tags) =>
      _transaction(() {
        db.execute('UPDATE ${_table(folder)} SET tags = ? WHERE id = ?;', [
          tags.join(','),
          id,
        ]);
        _reconcileShelfFolder(folder);
      });

  /// Returns folders actually changed, only after all writes commit.
  List<String> recordRead(
    Iterable<String> folders,
    String id,
    int type, {
    required String time,
    required String? movement,
    required String? trackingFolder,
  }) => _transaction(() {
    final changed = <String>[];
    for (final folder in folders) {
      if (!comicExists(folder, id, type)) continue;
      final position = switch (movement) {
        'start' => minValue(folder) - 1,
        'end' => maxValue(folder) + 1,
        _ => null,
      };
      db.execute(
        'UPDATE ${_table(folder)} SET ${position == null ? "" : "display_order = ?, "}${folder == trackingFolder ? "has_new_update = 0, " : ""}time = ? WHERE id = ? AND type = ?;',
        [?position, time, id, type],
      );
      changed.add(folder);
    }
    return changed;
  });

  bool updateUpdateTime(
    String folder,
    String id,
    int type,
    String updateTime,
    int checkedAt,
  ) => _transaction(() {
    final oldTime = db.select(
      'SELECT last_update_time FROM ${_table(folder)} WHERE id = ? AND type = ?;',
      [id, type],
    ).first['last_update_time'];
    final changed = oldTime != updateTime;
    db.execute(
      'UPDATE ${_table(folder)} SET last_update_time = ?, has_new_update = ?, last_check_time = ? WHERE id = ? AND type = ?;',
      [updateTime, changed ? 1 : 0, checkedAt, id, type],
    );
    return changed;
  });

  void updateCheckTime(String folder, String id, int type, int checkedAt) {
    db.execute(
      'UPDATE ${_table(folder)} SET last_check_time = ? WHERE id = ? AND type = ?;',
      [checkedAt, id, type],
    );
  }

  int countUpdates(String folder) =>
      db
              .select(
                'SELECT COUNT(*) AS c FROM ${_table(folder)} WHERE has_new_update = 1;',
              )
              .first['c']
          as int;

  List<FavoriteItemWithUpdateInfo> getComicsWithUpdatesInfo(
    String folder, {
    bool updatedOnly = false,
  }) => db
      .select(
        'SELECT * FROM ${_table(folder)}${updatedOnly ? " WHERE has_new_update = 1" : ""};',
      )
      .map(favoriteItemWithUpdateInfoFromRow)
      .toList();

  void markAsRead(String folder, String id, int type) {
    db.execute(
      'UPDATE ${_table(folder)} SET has_new_update = 0 WHERE id = ? AND type = ?;',
      [id, type],
    );
  }

  void markComicsAsRead(String folder, Iterable<(String, int)> identities) =>
      _transaction(() {
        for (final (id, type) in identities.toSet()) {
          markAsRead(folder, id, type);
        }
      });

  void reorder(
    String folder,
    Iterable<(String, int)> identities,
  ) => _transaction(() {
    var order = 0;
    for (final (id, type) in identities) {
      db.execute(
        'UPDATE ${_table(folder)} SET display_order = ? WHERE id = ? AND type = ?;',
        [order++, id, type],
      );
    }
  });

  bool get _hasShelfOrders => db
      .select(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='favorite_author_shelf_order';",
      )
      .isNotEmpty;

  Map<String, Map<FavoriteIdentity, int>> shelfOrders(String folder) {
    if (!_hasShelfOrders) return {};
    final result = <String, Map<FavoriteIdentity, int>>{};
    for (final row in db.select(
      'SELECT author_key,comic_id,comic_type,rank FROM favorite_author_shelf_order WHERE folder_name = ?;',
      [folder],
    )) {
      final key = row['author_key'],
          id = row['comic_id'],
          type = row['comic_type'],
          rank = row['rank'];
      if (key is String &&
          id is String &&
          type is int &&
          rank is int &&
          rank >= 0) {
        (result[key] ??= {})[(id, type)] = rank;
      }
    }
    return result;
  }

  /// Caller owns the transaction. No ordinary folder order or other author row
  /// is touched, including when both shelves contain the same comic identity.
  void writeShelfOrder(
    String folder,
    String authorKey,
    List<FavoriteItem> next,
  ) {
    db.execute(
      'DELETE FROM favorite_author_shelf_order WHERE folder_name = ? AND author_key = ?;',
      [folder, authorKey],
    );
    for (var i = 0; i < next.length; i++) {
      db.execute(
        'INSERT INTO favorite_author_shelf_order (folder_name,author_key,comic_id,comic_type,rank) VALUES (?,?,?,?,?);',
        [folder, authorKey, next[i].id, next[i].type.value, i],
      );
    }
  }

  /// Called only by membership/author mutations, and only loads a folder if it
  /// already has saved shelf rows. Reads/mark-read never perform reconciliation.
  void _reconcileShelfFolder(String folder) {
    if (!_hasShelfOrders) return;
    final keys = db
        .select(
          'SELECT DISTINCT author_key FROM favorite_author_shelf_order WHERE folder_name = ?;',
          [folder],
        )
        .map((row) => row['author_key'])
        .toSet();
    if (keys.isEmpty) return;
    final groups = authorShelves(
      getFolderComics(folder),
      aliases: shelfAliases?.call() ?? const {},
      orders: shelfOrders(folder),
    );
    final active = {
      for (final group in groups)
        authorShelfStorageKey(group.author): group.items,
    };
    for (final key in keys) {
      writeShelfOrder(folder, key as String, active[key] ?? const []);
    }
  }

  List<FavoriteItem> _searchFirstToken(String folder, String token) => db
      .select(
        'SELECT * FROM ${_table(folder)} WHERE name LIKE ? OR author LIKE ? OR tags LIKE ? OR translated_tags LIKE ?;',
        List.filled(4, '%$token%'),
      )
      .map(favoriteItemFromRow)
      .toList();

  static bool _matches(FavoriteItem item, String token) =>
      item.name.contains(token) ||
      item.author.contains(token) ||
      item.tags.any((tag) => tag.contains(token));

  List<FavoriteItem> searchInFolder(String folder, String keyword) {
    final tokens = keyword.split(' ');
    return _searchFirstToken(folder, tokens.first)
        .where((item) => tokens.skip(1).every((token) => _matches(item, token)))
        .toList();
  }

  List<FavoriteItem> search(Iterable<String> folders, String keyword) {
    final tokens = keyword.split(' ');
    final candidates = <FavoriteItem>{};
    for (final folder in folders) {
      candidates.addAll(_searchFirstToken(folder, tokens.first));
      // Preserve the existing folder-level cutoff before secondary filtering.
      if (candidates.length > 200) break;
    }
    return candidates.where((item) {
      return tokens.skip(1).every((token) {
        token = token.trim();
        return token.isEmpty || _matches(item, token);
      });
    }).toList();
  }

  bool comicExists(
    String folder,
    String id,
    int type, {
    String? schema,
  }) => db.select(
    'SELECT 1 FROM ${_qualifiedTable(folder, schema)} WHERE id = ? AND type = ? LIMIT 1;',
    [id, type],
  ).isNotEmpty;

  FavoriteItem? findComic(String folder, String id, int type) {
    final rows = db.select(
      'SELECT * FROM ${_table(folder)} WHERE id = ? AND type = ?;',
      [id, type],
    );
    return rows.isEmpty ? null : favoriteItemFromRow(rows.first);
  }

  List<String> findFolders(Iterable<String> folders, String id, int type) => [
    for (final folder in folders)
      if (comicExists(folder, id, type)) folder,
  ];
}
