import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorite_order.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_repository.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/comic_type.dart';

FavoriteItem book(
  String id, {
  int type = 0,
  String author = 'Alpha',
  List<String> tags = const [],
  String time = '2020-01-01 00:00:00',
}) => FavoriteItem.withTime(
  id: id,
  name: 'Title $id $type',
  author: author,
  tags: tags,
  type: ComicType(type),
  coverPath: '',
  time: time,
);

class _Repository extends FavoritesRepository {
  _Repository(super.db);
  bool forbidGlobalReconcile = false;
  @override
  void reconcileAuthorOrders() {
    if (forbidGlobalReconcile) {
      throw StateError('Unrelated operation scanned all author scopes');
    }
    super.reconcileAuthorOrders();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  App.dataPath = Directory.systemTemp.path;
  App.cachePath = Directory.systemTemp.path;
  late Directory root;
  late LocalFavoritesManager manager;
  late String oldPath;
  late Map<String, dynamic> oldImplicit;
  const folder = FavoriteOrderScope.folder('A');
  const all = FavoriteOrderScope.all();
  late FavoriteOrderScope series;
  List<FavoriteIdentity> order(FavoriteOrderScope scope) =>
      manager.authorOrderedComics(scope).map(favoriteIdentity).toList();
  Future<void> move(
    FavoriteOrderScope scope,
    FavoriteIdentity comic,
    FavoriteIdentity neighbor, {
    String author = 'Alpha',
    bool before = true,
  }) => manager.moveAuthorFavorite(
    scope: scope,
    token: manager.orderScopeToken(scope)!,
    generation: manager.connectionGeneration,
    dataPath: App.dataPath,
    comic: comic,
    neighbor: neighbor,
    author: author,
    before: before,
  );
  List<Map<String, Object?>> rows(String query) {
    final db = sqlite3.open(manager.databasePath);
    try {
      return db
          .select(query)
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    } finally {
      db.dispose();
    }
  }

  void sql(String query) {
    final db = sqlite3.open(manager.databasePath);
    try {
      db.execute(query);
    } finally {
      db.dispose();
    }
  }

  setUp(() async {
    oldPath = App.dataPath;
    oldImplicit = Map.of(appdata.implicitData);
    root = Directory.systemTemp.createTempSync('f10-storage-');
    App.dataPath = root.path;
    appdata.implicitData['local_favorites_author_aliases'] = <String, String>{};
    manager = LocalFavoritesManager.independent();
    await manager.init();
    await manager.createFolder('A');
    await manager.createFolder('B');
    for (final item in [
      book('same'),
      book('same', type: 31),
      book('beta', author: 'Beta'),
      book('missing', author: ''),
    ]) {
      await manager.addComic('A', item, manager.count('A'));
      await manager.addComic('B', item, manager.count('B'));
    }
    series = FavoriteOrderScope.series((await manager.createSeries('A')).id);
    await manager.addToSeries(series.id, manager.getFolderComics('A'));
    for (final scope in [
      folder,
      all,
      series,
      const FavoriteOrderScope.folder('B'),
    ]) {
      await manager.setOrderScopeMode(scope, 'authorManual');
    }
  });
  tearDown(() async {
    await manager.closeAndWait();
    appdata.implicitData = oldImplicit;
    App.dataPath = oldPath;
    root.deleteSync(recursive: true);
  });

  test(
    'typed views and complete identity are isolated, old fields unchanged, reopen persists',
    () async {
      final original = rows('SELECT rowid, * FROM A ORDER BY rowid;');
      final other = order(all);
      await move(folder, ('same', 31), ('same', 0));
      expect(order(folder), [
        ('same', 31),
        ('same', 0),
        ('beta', 0),
        ('missing', 0),
      ]);
      for (final scope in [all, series, const FavoriteOrderScope.folder('B')]) {
        expect(order(scope), other);
      }
      expect(rows('SELECT rowid, * FROM A ORDER BY rowid;'), original);
      await manager.setOrderScopeMode(folder, 'timeNewest');
      await manager.setOrderScopeMode(folder, 'authorManual');
      await manager.closeAndWait();
      await manager.init();
      expect(manager.orderScopeMode(folder), 'authorManual');
      expect(order(folder).take(2), [('same', 31), ('same', 0)]);
      expect(rows('SELECT rowid, * FROM A ORDER BY rowid;'), original);
    },
  );

  test(
    'author authority, first valid tag, explicit alias, case and missing author',
    () async {
      await manager.addComic(
        'A',
        book(
          'tag',
          author: 'Uploader',
          tags: ['artist:  ', 'artist:  Aaron   Name ', 'artist:Beta'],
        ),
      );
      await manager.addComic('A', book('lower', author: 'alpha'));
      appdata.implicitData['local_favorites_author_aliases'] = {
        'Aaron Name': 'Alpha',
      };
      expect(order(folder), [
        ('same', 0),
        ('same', 31),
        ('tag', 0),
        ('lower', 0),
        ('beta', 0),
        ('missing', 0),
      ]);
      expect(
        manager.getFolderComics('A').singleWhere((e) => e.id == 'tag').author,
        'Uploader',
      );
      await move(folder, ('tag', 0), ('same', 0));
      appdata.implicitData['local_favorites_author_aliases'] = {
        'Aaron Name': 'Beta',
      };
      expect(order(folder), [
        ('same', 0),
        ('same', 31),
        ('lower', 0),
        ('tag', 0),
        ('beta', 0),
        ('missing', 0),
      ]);
      await expectLater(
        move(folder, ('same', 0), ('tag', 0)),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'new member appends, removal/readd only clears its scope, rename migrates and recreate resets',
    () async {
      await move(folder, ('same', 31), ('same', 0));
      await manager.addComic(
        'A',
        book('new', time: '1900-01-01 00:00:00'),
        -30,
      );
      expect(order(folder).take(3), [('same', 31), ('same', 0), ('new', 0)]);
      await manager.deleteComicWithId('A', 'same', const ComicType(31));
      await manager.addComic('A', book('same', type: 31), -40);
      expect(order(folder).take(3), [('same', 0), ('new', 0), ('same', 31)]);
      final token = manager.orderScopeToken(folder);
      await manager.rename('A', 'Renamed');
      const renamed = FavoriteOrderScope.folder('Renamed');
      expect(manager.orderScopeToken(renamed), token);
      expect(order(renamed).take(3), [('same', 0), ('new', 0), ('same', 31)]);
      await manager.deleteFolder('Renamed');
      await manager.createFolder('Renamed');
      expect(manager.orderScopeToken(renamed), isNot(token));
      expect(manager.orderScopeMode(renamed), isNull);
      expect(order(series), [
        ('same', 0),
        ('same', 31),
        ('beta', 0),
        ('missing', 0),
      ]);
    },
  );

  test(
    'series remove/readd, delete and new stable ID do not revive order',
    () async {
      await move(series, ('same', 31), ('same', 0));
      final item = manager
          .getSeriesComics(series.id)
          .singleWhere((e) => e.id == 'same' && e.type.value == 31);
      await manager.removeFromSeries(series.id, [item]);
      await manager.addToSeries(series.id, [item]);
      expect(order(series).take(2), [('same', 0), ('same', 31)]);
      await manager.deleteSeries(series.id);
      final next = await manager.createSeries('A');
      expect(next.id, isNot(series.id));
      expect(
        manager.orderScopeToken(FavoriteOrderScope.series(next.id)),
        isNot(manager.orderScopeToken(series)),
      );
      expect(
        manager.orderScopeMode(FavoriteOrderScope.series(next.id)),
        isNull,
      );
      expect(order(folder).take(2), [('same', 0), ('same', 31)]);
    },
  );

  test('real SQLite failure rolls every rank back, retry is idempotent', () async {
    final original = rows(
      'SELECT * FROM favorite_author_order ORDER BY kind, scope_id, comic_id, comic_type;',
    );
    var notifications = 0;
    manager.addListener(() => notifications++);
    sql(
      "CREATE TRIGGER reject_f10 BEFORE UPDATE ON favorite_author_order WHEN NEW.comic_type = 31 BEGIN SELECT RAISE(ABORT, 'f10 failure'); END;",
    );
    await expectLater(
      move(folder, ('same', 31), ('same', 0)),
      throwsA(isA<Exception>()),
    );
    expect(
      rows(
        'SELECT * FROM favorite_author_order ORDER BY kind, scope_id, comic_id, comic_type;',
      ),
      original,
    );
    expect(notifications, 0);
    sql('DROP TRIGGER reject_f10;');
    await move(folder, ('same', 31), ('same', 0));
    await move(folder, ('same', 31), ('same', 0));
    expect(order(folder).take(2), [('same', 31), ('same', 0)]);
  });

  for (final change in ['delete', 'author', 'alias', 'recreate']) {
    test(
      'queued $change invalidates stale neighbor without reviving data',
      () async {
        final gate = Completer<void>();
        final entered = Completer<void>();
        final holding = AppDataOperations.instance.run(() async {
          entered.complete();
          await gate.future;
        });
        await entered.future;
        final mutation = switch (change) {
          'delete' => manager.deleteComicWithId(
            'A',
            'same',
            const ComicType(31),
          ),
          'author' => manager.editTags('same', 'A', ['artist:Other']),
          'alias' => appdata.updateImplicit((draft) {
            draft['local_favorites_author_aliases'] = {'Alpha': 'Other'};
          }),
          _ => (() async {
            await manager.deleteFolder('A');
            await manager.createFolder('A');
          })(),
        };
        final pending = move(folder, ('same', 31), ('same', 0));
        final rejected = expectLater(pending, throwsA(isA<Exception>()));
        gate.complete();
        await holding;
        await mutation;
        await rejected;
        expect(manager.count('B'), 4);
        expect(manager.getAllComics().length, 4);
      },
    );
  }

  test(
    'accepted old connection and directory cannot write a replacement',
    () async {
      final token = manager.orderScopeToken(folder)!;
      final generation = manager.connectionGeneration;
      final dataPath = App.dataPath;
      await manager.closeAndWait();
      await manager.init();
      await expectLater(
        manager.moveAuthorFavorite(
          scope: folder,
          token: token,
          generation: generation,
          dataPath: dataPath,
          comic: ('same', 31),
          neighbor: ('same', 0),
          author: 'Alpha',
          before: true,
        ),
        throwsA(isA<Exception>()),
      );
      final oldOrder = order(folder);
      App.dataPath = '${root.path}/different';
      await expectLater(
        manager.moveAuthorFavorite(
          scope: folder,
          token: token,
          generation: manager.connectionGeneration,
          dataPath: dataPath,
          comic: ('same', 31),
          neighbor: ('same', 0),
          author: 'Alpha',
          before: true,
        ),
        throwsA(isA<Exception>()),
      );
      App.dataPath = dataPath;
      expect(order(folder), oldOrder);
    },
  );

  test(
    'ordinary read/update transactions do not coordinate unrelated author ranks',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      final repository = _Repository(db)..initializeMetadata();
      repository.createFolder('Read');
      repository.addComic(
        'Read',
        book('read'),
        translatedTags: '',
        append: true,
      );
      repository.prepareForFollowUpdates('Read', clearData: false);
      repository.setOrderMode(
        const FavoriteOrderScope.folder('Read'),
        'authorManual',
        'token',
        repository.getFolderComics('Read'),
      );
      final ranks = repository.authorRanks(
        const FavoriteOrderScope.folder('Read'),
      );
      repository.forbidGlobalReconcile = true;
      repository.recordRead(
        ['Read'],
        'read',
        0,
        time: '2021-02-03 04:05:06',
        movement: 'end',
        trackingFolder: 'Read',
      );
      repository.applyFollowUpdate(
        'Read',
        book('read', author: 'Updated'),
        'new update',
        123,
      );
      repository.prepareForFollowUpdates('Read', clearData: true);
      repository.reorder('Read', [('read', 0)]);
      expect(repository.findComic('Read', 'read', 0)!.author, 'Updated');
      expect(
        repository.authorRanks(const FavoriteOrderScope.folder('Read')),
        ranks,
      );
    },
  );

  for (final remembered in [false, true]) {
    test(
      'delete receipt uses the comic deletion count, remembered=$remembered',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        final repository = FavoritesRepository(db)..initializeMetadata();
        repository.createFolder('Delete');
        for (final item in [book('same'), book('same', type: 31)]) {
          repository.addComic('Delete', item, translatedTags: '', append: true);
        }
        if (remembered) {
          repository.setOrderMode(
            const FavoriteOrderScope.folder('Delete'),
            'authorManual',
            'token',
            repository.getFolderComics('Delete'),
          );
        }
        expect(
          repository.deleteComics(['Delete'], [('same', 0), ('absent', 0)]),
          {
            'Delete': [('same', 0)],
          },
        );
        expect(repository.identities('Delete'), [('same', 31)]);
        expect(repository.deleteComics(['Delete'], [('same', 0)]), isEmpty);
      },
    );
  }

  test(
    'whole SQLite backup restores modes, ranks, series and metadata together',
    () async {
      await move(folder, ('same', 31), ('same', 0));
      final original = rows('SELECT rowid, * FROM A ORDER BY rowid;');
      final databasePath = manager.databasePath;
      await manager.closeAndWait();
      final backup = File(databasePath).readAsBytesSync();
      await manager.init();
      await move(folder, ('same', 0), ('same', 31));
      await manager.deleteSeries(series.id);
      await manager.closeAndWait();
      File(databasePath).writeAsBytesSync(backup, flush: true);
      await manager.init();
      expect(order(folder).take(2), [('same', 31), ('same', 0)]);
      expect(manager.orderScopeMode(folder), 'authorManual');
      expect(manager.seriesById(series.id)?.name, 'A');
      expect(manager.seriesMemberIdentities(series.id).length, 4);
      expect(rows('SELECT rowid, * FROM A ORDER BY rowid;'), original);
    },
  );

  test(
    'queued move cannot write a real replacement database in another directory',
    () async {
      final token = manager.orderScopeToken(folder)!;
      final generation = manager.connectionGeneration;
      final dataPath = App.dataPath;
      final gate = Completer<void>();
      final entered = Completer<void>();
      final replacing = AppDataOperations.instance.run(() async {
        entered.complete();
        await gate.future;
        await manager.closeAndWait();
        App.dataPath = '${root.path}/replacement';
        Directory(App.dataPath).createSync();
        await manager.init();
        await manager.createFolder('A');
        await manager.addComic('A', book('replacement'));
      });
      await entered.future;
      final pending = manager.moveAuthorFavorite(
        scope: folder,
        token: token,
        generation: generation,
        dataPath: dataPath,
        comic: ('same', 31),
        neighbor: ('same', 0),
        author: 'Alpha',
        before: true,
      );
      final rejected = expectLater(pending, throwsA(isA<Exception>()));
      gate.complete();
      await replacing;
      await rejected;
      expect(manager.getFolderComics('A').map(favoriteIdentity), [
        ('replacement', 0),
      ]);
      expect(manager.orderScopeMode(folder), isNull);
      expect(rows('SELECT * FROM favorite_author_order;'), isEmpty);
      await manager.closeAndWait();
      App.dataPath = dataPath;
      await manager.init();
      expect(order(folder).take(2), [('same', 0), ('same', 31)]);
    },
  );
}
