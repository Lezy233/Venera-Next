import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/features/favorites/author_shelf_model.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorite_order.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/persistence_failure.dart';

FavoriteItem book(
  String id,
  String author, {
  int type = 0,
  List<String> tags = const [],
}) => FavoriteItem.withTime(
  id: id,
  name: 'Title $id $type',
  coverPath: 'cover-$id',
  author: author,
  type: ComicType(type),
  tags: tags,
  time: '2020-01-01 01:02:03',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LocalFavoritesManager manager;
  late Map<String, dynamic> implicit;
  late String series;
  const scope = FavoriteOrderScope.folder('A');
  const original = [('same', 0), ('b1', 0), ('same', 31), ('b2', 0)];
  setUp(() async {
    root = Directory.systemTemp.createTempSync('f10-v2-order-');
    App.dataPath = App.cachePath = root.path;
    implicit = appdata.implicitData;
    appdata.implicitData = {};
    manager = LocalFavoritesManager.independent();
    await manager.init();
    for (final folder in ['A', 'B']) {
      await manager.createFolder(folder);
      for (final item in [
        book('same', 'Alpha'),
        book('b1', 'Beta'),
        book('same', 'Alpha', type: 31),
        book('b2', 'Beta'),
      ]) {
        await manager.addComic(folder, item);
      }
    }
    series = (await manager.createSeries('Series')).id;
    await manager.addToSeries(series, manager.getFolderComics('A'));
  });
  tearDown(() async {
    await manager.closeAndWait();
    appdata.implicitData = implicit;
    App.dataPath = App.cachePath = Directory.systemTemp.path;
    root.deleteSync(recursive: true);
  });
  Future<void> move({
    Set<FavoriteIdentity> visible = const {('same', 0), ('same', 31)},
    bool Function()? current,
  }) => manager.moveAuthorShelfFavorite(
    folder: 'A',
    author: 'Alpha',
    comic: ('same', 31),
    neighbor: ('same', 0),
    before: true,
    visible: visible,
    token: manager.orderScopeToken(scope)!,
    generation: manager.connectionGeneration,
    dataPath: App.dataPath,
    isCurrent: current ?? () => true,
  );
  List<FavoriteIdentity> order(String folder) =>
      manager.getFolderComics(folder).map(favoriteIdentity).toList();
  List<FavoriteIdentity> shelf(String folder, String? author) =>
      authorShelves(
            manager.getFolderComics(folder),
            aliases: manager.orderAuthorAliases,
            orders: manager.authorShelfOrders(folder),
          )
          .firstWhere((group) => group.author == author)
          .items
          .map(favoriteIdentity)
          .toList();
  List<Map<String, Object?>> rows(String query) {
    final db = sqlite3.open(manager.databasePath);
    try {
      return db
          .select(query)
          .map((row) => Map<String, Object?>.of(row))
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

  Future<void> place(
    String folder,
    String? author,
    FavoriteIdentity moving,
    FavoriteIdentity neighbor,
  ) => manager.moveAuthorShelfFavorite(
    folder: folder,
    author: author,
    comic: moving,
    neighbor: neighbor,
    before: true,
    visible: authorShelves(
      manager.getFolderComics(folder),
      aliases: manager.orderAuthorAliases,
    ).firstWhere((g) => g.author == author).items.map(favoriteIdentity).toSet(),
    token: manager.orderScopeToken(FavoriteOrderScope.folder(folder))!,
    generation: manager.connectionGeneration,
    dataPath: App.dataPath,
    isCurrent: () => true,
  );

  test(
    'legacy ranks and malformed new ranks never write during reads',
    () async {
      await manager.setOrderScopeMode(scope, 'authorManual');
      sql("UPDATE favorite_author_order SET rank = -rank WHERE scope_id='A';");
      expect(shelf('A', 'Alpha'), [('same', 0), ('same', 31)]);
      expect(rows('SELECT * FROM favorite_author_shelf_order;'), isEmpty);
      await move();
      sql(
        "UPDATE favorite_author_shelf_order SET rank='bad' WHERE comic_type=31;",
      );
      final before = rows('SELECT * FROM favorite_author_shelf_order;');
      expect(shelf('A', 'Alpha'), [('same', 0), ('same', 31)]);
      expect(rows('SELECT * FROM favorite_author_shelf_order;'), before);
      sql('UPDATE favorite_author_shelf_order SET rank=0;');
      expect(shelf('A', 'Alpha'), [('same', 0), ('same', 31)]);
      sql('UPDATE favorite_author_shelf_order SET rank=-1;');
      expect(shelf('A', 'Alpha'), [('same', 0), ('same', 31)]);
    },
  );

  test(
    'hidden interior slot survives independent movement and ordinary reorder',
    () async {
      await manager.addComic('A', book('hidden', 'Alpha'));
      sql("UPDATE A SET display_order=2.5 WHERE id='hidden';");
      final before = order('A');
      await move();
      expect(shelf('A', 'Alpha'), [('same', 31), ('hidden', 0), ('same', 0)]);
      expect(order('A'), before);
      await manager.reorder(
        manager.getFolderComics('A').reversed.toList(),
        'A',
      );
      expect(shelf('A', 'Alpha'), [('same', 31), ('hidden', 0), ('same', 0)]);
      expect(shelf('B', 'Alpha'), [('same', 0), ('same', 31)]);
    },
  );

  test(
    'new members append, deleted/reclassified identities never revive old positions',
    () async {
      await move();
      await manager.addComic('A', book('new', 'Alpha'));
      expect(shelf('A', 'Alpha'), [('same', 31), ('same', 0), ('new', 0)]);
      await manager.deleteComicWithId('A', 'same', ComicType(31));
      expect(
        rows(
          "SELECT * FROM favorite_author_shelf_order WHERE folder_name='A' AND comic_id='same' AND comic_type=31;",
        ),
        isEmpty,
      );
      await manager.addComic('A', book('same', 'Alpha', type: 31));
      expect(shelf('A', 'Alpha'), [('same', 0), ('new', 0), ('same', 31)]);
      await manager.editTags('same', 'A', ['author:Other']);
      expect(shelf('A', 'Alpha'), [('new', 0)]);
      expect(
        rows(
          "SELECT * FROM favorite_author_shelf_order WHERE folder_name='A' AND author_key='[\"author\",\"Alpha\"]' AND comic_id='same';",
        ),
        isEmpty,
      );
      await manager.editTags('same', 'A', ['author:Alpha']);
      expect(shelf('A', 'Alpha').first, ('new', 0));
      expect(
        shelf('A', 'Alpha').skip(1),
        order('A').where((id) => id.$1 == 'same'),
      );
    },
  );

  test(
    'alias merges retain target order, splitting to fresh canonical does not copy',
    () async {
      await move();
      await place('A', 'Beta', ('b2', 0), ('b1', 0));
      final before = rows(
        'SELECT * FROM favorite_author_shelf_order ORDER BY author_key,rank;',
      );
      await appdata.updateImplicit(
        (draft) => draft['local_favorites_author_aliases'] = {'Alpha': 'Beta'},
      );
      expect(shelf('A', 'Beta'), [
        ('b2', 0),
        ('b1', 0),
        ('same', 0),
        ('same', 31),
      ]);
      expect(
        rows(
          'SELECT * FROM favorite_author_shelf_order ORDER BY author_key,rank;',
        ),
        before,
      );
      await appdata.updateImplicit(
        (draft) => draft['local_favorites_author_aliases'] = {'Alpha': 'Fresh'},
      );
      expect(shelf('A', 'Fresh'), [('same', 0), ('same', 31)]);
      expect(shelf('A', 'Beta'), [('b2', 0), ('b1', 0)]);
      expect(order('A'), original);
    },
  );

  test(
    'unknown and literal same display name use distinct persistent keys',
    () async {
      for (final id in ['u1', 'u2']) {
        await manager.addComic('A', book(id, ''));
      }
      for (final id in ['n1', 'n2']) {
        await manager.addComic('A', book(id, 'Unnamed author'));
      }
      await place('A', null, ('u2', 0), ('u1', 0));
      expect(shelf('A', null), [('u2', 0), ('u1', 0)]);
      expect(shelf('A', 'Unnamed author'), [('n1', 0), ('n2', 0)]);
      await place('A', 'Unnamed author', ('n2', 0), ('n1', 0));
      expect(shelf('A', null), [('u2', 0), ('u1', 0)]);
      expect(shelf('A', 'Unnamed author'), [('n2', 0), ('n1', 0)]);
      expect(manager.authorShelfOrders('A').keys.toSet(), {
        authorShelfStorageKey(null),
        authorShelfStorageKey('Unnamed author'),
      });
    },
  );

  test(
    'rename/delete-recreate migrate and retire order with folder lifecycle',
    () async {
      await move();
      await manager.setShelfState(
        folder: 'A',
        author: 'Alpha',
        state: AuthorShelfState.collapsed,
        token: manager.orderScopeToken(scope)!,
        generation: manager.connectionGeneration,
        dataPath: App.dataPath,
        isCurrent: () => true,
      );
      final oldToken = manager.orderScopeToken(scope);
      await manager.rename('A', 'Renamed');
      expect(shelf('Renamed', 'Alpha'), [('same', 31), ('same', 0)]);
      expect(
        manager.shelfState('Renamed', 'Alpha'),
        AuthorShelfState.collapsed,
      );
      expect(shelf('B', 'Alpha'), [('same', 0), ('same', 31)]);
      await manager.deleteFolder('Renamed');
      await manager.createFolder('A');
      await manager.addComic('A', book('same', 'Alpha'));
      await manager.addComic('A', book('same', 'Alpha', type: 31));
      expect(manager.orderScopeToken(scope), isNot(oldToken));
      expect(shelf('A', 'Alpha'), [('same', 0), ('same', 31)]);
      expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.normal);
      expect(manager.authorShelfOrders('A'), isEmpty);
    },
  );

  test(
    'whole database copy to a new directory retains shelf order and state',
    () async {
      await move();
      await manager.setShelfState(
        folder: 'A',
        author: 'Alpha',
        state: AuthorShelfState.expanded,
        token: manager.orderScopeToken(scope)!,
        generation: manager.connectionGeneration,
        dataPath: App.dataPath,
        isCurrent: () => true,
      );
      final databasePath = manager.databasePath;
      await manager.closeAndWait();
      final replacement = Directory('${root.path}/copy')..createSync();
      File(databasePath).copySync('${replacement.path}/local_favorite.db');
      App.dataPath = replacement.path;
      manager = LocalFavoritesManager.independent();
      await manager.init();
      expect(shelf('A', 'Alpha'), [('same', 31), ('same', 0)]);
      expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.expanded);
      expect(order('A'), original);
      expect(shelf('B', 'Alpha'), [('same', 0), ('same', 31)]);
    },
  );

  test(
    'real folder slots with full identities preserve all metadata, B and series',
    () async {
      final metadata = rows(
        'SELECT id,type,name,author,tags,time,cover_path FROM A ORDER BY id,type;',
      );
      final oldSeries = manager.seriesMemberIdentities(series).toSet();
      sql('UPDATE A SET display_order = display_order * 10 + 7;');
      final betaSlots = rows(
        "SELECT id,display_order FROM A WHERE author = 'Beta' ORDER BY id;",
      );
      await move();
      expect(order('A'), original);
      expect(shelf('A', 'Alpha'), [('same', 31), ('same', 0)]);
      expect(shelf('A', 'Beta'), [('b1', 0), ('b2', 0)]);
      expect(order('B'), original);
      expect(
        rows(
          'SELECT id,type,name,author,tags,time,cover_path FROM A ORDER BY id,type;',
        ),
        metadata,
      );
      expect(
        rows(
          "SELECT id,display_order FROM A WHERE author = 'Beta' ORDER BY id;",
        ),
        betaSlots,
      );
      expect(manager.seriesMemberIdentities(series).toSet(), oldSeries);
      await manager.closeAndWait();
      manager = LocalFavoritesManager.independent();
      await manager.init();
      expect(order('A'), original);
      expect(shelf('A', 'Alpha'), [('same', 31), ('same', 0)]);
    },
  );
  test('hidden matching author retains its exact display_order slot', () async {
    await manager.addComic('A', book('hidden', 'Alpha'));
    final before = rows("SELECT display_order FROM A WHERE id='hidden';");
    await move();
    expect(order('A'), [
      ('same', 0),
      ('b1', 0),
      ('same', 31),
      ('b2', 0),
      ('hidden', 0),
    ]);
    expect(rows("SELECT display_order FROM A WHERE id='hidden';"), before);
    expect(shelf('A', 'Alpha'), [('same', 31), ('same', 0), ('hidden', 0)]);
  });
  test(
    'SQLite mid-update abort restores both slots and retry is idempotent',
    () async {
      sql(
        "CREATE TRIGGER fail_shelf BEFORE INSERT ON favorite_author_shelf_order WHEN NEW.comic_type=0 AND NEW.comic_id='same' BEGIN SELECT RAISE(ABORT,'mid-write'); END;",
      );
      await expectLater(
        move(),
        throwsA(
          isA<PersistenceFailure>()
              .having(
                (failure) => failure.commitState,
                'commitState',
                PersistenceCommitState.notCommitted,
              )
              .having(
                (failure) => failure.cause,
                'cause',
                isA<SqliteException>(),
              ),
        ),
      );
      expect(order('A'), original);
      expect(shelf('A', 'Alpha'), [('same', 0), ('same', 31)]);
      sql('DROP TRIGGER fail_shelf;');
      await move();
      await move();
      expect(order('A'), original);
      expect(shelf('A', 'Alpha'), [('same', 31), ('same', 0)]);
    },
  );
  for (final change in ['delete', 'author', 'alias', 'recreate', 'dispose']) {
    test(
      'queued $change validates latest original library membership and owner',
      () async {
        final gate = Completer<void>();
        final entered = Completer<void>();
        final holding = AppDataOperations.instance.run(() async {
          entered.complete();
          await gate.future;
        });
        await entered.future;
        var active = true;
        final mutation = switch (change) {
          'delete' => manager.deleteComicWithId('A', 'same', ComicType(31)),
          'author' => manager.editTags('same', 'A', ['author:Other']),
          'alias' => appdata.updateImplicit(
            (draft) =>
                draft['local_favorites_author_aliases'] = {'Alpha': 'Other'},
          ),
          'recreate' => (() async {
            await manager.deleteFolder('A');
            await manager.createFolder('A');
          })(),
          _ => Future<void>.value(),
        };
        final pending = move(current: () => active);
        final rejected = expectLater(pending, throwsA(isA<Exception>()));
        if (change == 'dispose') active = false;
        gate.complete();
        await holding;
        await mutation;
        await rejected;
        expect(order('B'), original);
      },
    );
  }
  test(
    'queued full directory/connection replacement refuses old operation',
    () async {
      final token = manager.orderScopeToken(scope)!;
      final generation = manager.connectionGeneration;
      final path = App.dataPath;
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
        await manager.addComic('A', book('replacement', 'Alpha'));
      });
      await entered.future;
      final pending = manager.moveAuthorShelfFavorite(
        folder: 'A',
        author: 'Alpha',
        comic: ('same', 31),
        neighbor: ('same', 0),
        before: true,
        visible: {('same', 0), ('same', 31)},
        token: token,
        generation: generation,
        dataPath: path,
        isCurrent: () => true,
      );
      final rejected = expectLater(pending, throwsA(isA<Exception>()));
      gate.complete();
      await replacing;
      await rejected;
      expect(order('A'), [('replacement', 0)]);
    },
  );
  test(
    'shared works have independent persisted author order without folder writes',
    () async {
      await manager.editTags('same', 'A', ['author:Alpha', 'author:Beta']);
      final beforeBeta = shelf('A', 'Beta');
      await move();
      expect(shelf('A', 'Alpha'), [('same', 31), ('same', 0)]);
      expect(shelf('A', 'Beta'), beforeBeta);
      expect(order('A'), original);
    },
  );
}
