import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_repository.dart';
import 'package:venera_next/features/favorites/favorite_series.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorite_selection.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';

FavoriteItem _comic(String id, int type) => FavoriteItem(
  id: id,
  name: '$id-$type',
  author: 'author',
  coverPath: '',
  type: ComicType(type),
  tags: const [],
);

void main() {
  late Database db;
  late FavoritesRepository repository;

  setUp(() {
    db = sqlite3.openInMemory();
    repository = FavoritesRepository(db);
    repository.initializeMetadata();
    for (final name in ['one', 'two']) {
      db.execute('''CREATE TABLE "$name" (
        id TEXT, type INT, name TEXT, author TEXT, tags TEXT,
        cover_path TEXT, time TEXT, translated_tags TEXT, display_order INT,
        PRIMARY KEY (id, type)
      );''');
    }
    repository.addComic(
      'one',
      _comic('same', 1),
      translatedTags: '',
      append: false,
    );
    repository.addComic(
      'two',
      _comic('same', 2),
      translatedTags: '',
      append: false,
    );
  });

  tearDown(() => db.dispose());

  test('old schema upgrades and metadata tables stay out of folder names', () {
    expect(repository.folderNames(), ['one', 'two']);
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'favorite_series%';",
      ),
      hasLength(2),
    );
  });

  test(
    'series CRUD, ordering, idempotent members and cross-source identity',
    () {
      repository.createSeries('s1', 'Saga', 0);
      repository.createSeries('s2', 'Other', 1);
      repository.addSeriesMembers('s1', [
        ('same', 1),
        ('same', 1),
        ('same', 2),
      ]);
      expect(repository.seriesMemberCount('s1'), 2);
      expect(
        repository.getSeriesComics('s1', repository.folderNames()),
        hasLength(2),
      );
      repository.reorderSeries(['s2', 's1']);
      expect(repository.series().map((item) => item.id), ['s2', 's1']);
      repository.renameSeries('s2', 'Renamed');
      expect(repository.seriesByIdForTest('s2')?.name, 'Renamed');
      repository.removeSeriesMembers('s1', [('same', 1)]);
      expect(repository.seriesMemberCount('s1'), 1);
      repository.deleteSeries('s2');
      expect(repository.series().map((item) => item.id), ['s1']);
    },
  );

  test('failed unique insert rolls back without damaging existing series', () {
    repository.createSeries('s1', 'Saga', 0);
    expect(
      () => repository.createSeries('s2', 'Saga', 1),
      throwsA(isA<SqliteException>()),
    );
    expect(repository.series().map((item) => item.id), ['s1']);
  });

  test('orphan cleanup removes only identities absent from every folder', () {
    repository.createSeries('s1', 'Saga', 0);
    repository.addComic(
      'two',
      _comic('same', 1),
      translatedTags: '',
      append: false,
    );
    repository.addSeriesMembers('s1', [('same', 1), ('missing', 1)]);
    repository.cleanupOrphanSeriesMembers(repository.folderNames());
    expect(repository.seriesMembers('s1'), [('same', 1)]);
    db.execute('DELETE FROM "one" WHERE id = ?;', ['same']);
    repository.cleanupOrphanSeriesMembers(repository.folderNames());
    expect(repository.seriesMembers('s1'), [('same', 1)]);
    db.execute('DELETE FROM "two" WHERE id = ?;', ['same']);
    repository.cleanupOrphanSeriesMembers(repository.folderNames());
    expect(repository.seriesMembers('s1'), isEmpty);
  });

  test('manager CRUD publishes one change and applies members', () async {
    final checkpoint = appdata.captureImportCheckpoint();
    final root = Directory.systemTemp.createTempSync(
      'favorite-series-manager-',
    );
    final manager = LocalFavoritesManager.independent();
    App.dataPath = root.path;
    App.cachePath = root.path;
    try {
      await manager.init();
      await manager.createFolder('library');
      await manager.addComic('library', _comic('manager-comic', 0));
      var changes = 0;
      manager.addListener(() => changes++);
      final series = await manager.createSeries('Manager series');
      await manager.addToSeries(series.id, [manager.getAllComics().single]);
      expect(manager.getSeriesComics(series.id).single.id, 'manager-comic');
      expect(changes, 2);
      await manager.renameSeries(series.id, 'Renamed');
      expect(manager.seriesById(series.id)?.name, 'Renamed');
      await manager.removeFromSeries(series.id, manager.getAllComics());
      expect(manager.seriesMemberIdentities(series.id), isEmpty);
    } finally {
      await manager.closeAndWait();
      await appdata.restoreImportCheckpoint(checkpoint, persist: false);
      root.deleteSync(recursive: true);
    }
  });

  test(
    'manager batch add is idempotent and preserves folder membership',
    () async {
      final checkpoint = appdata.captureImportCheckpoint();
      final root = Directory.systemTemp.createTempSync(
        'favorite-series-batch-',
      );
      final manager = LocalFavoritesManager.independent();
      App.dataPath = root.path;
      App.cachePath = root.path;
      try {
        await manager.init();
        await manager.createFolder('library');
        await manager.addComic('library', _comic('one', 0));
        await manager.addComic('library', _comic('two', 0));
        final series = await manager.createSeries('Batch series');
        final selected = manager.getAllComics();
        await manager.addToSeries(series.id, [...selected, ...selected]);
        expect(manager.seriesMemberIdentities(series.id), hasLength(2));
        expect(manager.folderComics('library'), 2);
        await manager.removeFromSeries(series.id, [selected.first]);
        expect(manager.seriesMemberIdentities(series.id), hasLength(1));
        expect(manager.folderComics('library'), 2);
      } finally {
        await manager.closeAndWait();
        await appdata.restoreImportCheckpoint(checkpoint, persist: false);
        root.deleteSync(recursive: true);
      }
    },
  );

  test('selection Escape guard consumes only active key-down Escape', () {
    var exits = 0;
    final escape = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.escape,
      logicalKey: LogicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    );
    final enter = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.enter,
      logicalKey: LogicalKeyboardKey.enter,
      timeStamp: Duration.zero,
    );
    expect(
      consumeFavoriteSelectionEscape(
        escape,
        active: true,
        onExit: () => exits++,
      ),
      isTrue,
    );
    expect(exits, 1);
    expect(
      consumeFavoriteSelectionEscape(
        enter,
        active: true,
        onExit: () => exits++,
      ),
      isFalse,
    );
    expect(
      consumeFavoriteSelectionEscape(
        escape,
        active: false,
        onExit: () => exits++,
      ),
      isFalse,
    );
    expect(exits, 1);
  });
}

extension on FavoritesRepository {
  FavoriteSeries? seriesByIdForTest(String id) =>
      series().where((item) => item.id == id).firstOrNull;
}
