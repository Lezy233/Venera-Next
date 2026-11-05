import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/features/favorites/author_shelf_model.dart';
import 'package:venera_next/features/favorites/favorite_order.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LocalFavoritesManager manager;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('f10-v2-state-');
    App.dataPath = App.cachePath = root.path;
    manager = LocalFavoritesManager.independent();
    await manager.init();
    await manager.createFolder('A');
    await manager.createFolder('B');
  });
  tearDown(() async {
    await manager.closeAndWait();
    App.dataPath = App.cachePath = Directory.systemTemp.path;
    root.deleteSync(recursive: true);
  });
  Future<void> save(
    String folder,
    String? author,
    AuthorShelfState state, {
    bool Function()? current,
  }) => manager.setShelfState(
    folder: folder,
    author: author,
    state: state,
    token: manager.orderScopeToken(FavoriteOrderScope.folder(folder))!,
    generation: manager.connectionGeneration,
    dataPath: App.dataPath,
    isCurrent: current ?? () => true,
  );
  void sql(String query) {
    final db = sqlite3.open(manager.databasePath);
    try {
      db.execute(query);
    } finally {
      db.dispose();
    }
  }

  test(
    'two folders and unknown identity persist across close and new manager',
    () async {
      await save('A', 'Alpha', AuthorShelfState.collapsed);
      await save('B', 'Alpha', AuthorShelfState.expanded);
      await save('A', null, AuthorShelfState.expanded);
      await save('A', 'Unnamed author', AuthorShelfState.collapsed);
      await manager.closeAndWait();
      manager = LocalFavoritesManager.independent();
      await manager.init();
      expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.collapsed);
      expect(manager.shelfState('B', 'Alpha'), AuthorShelfState.expanded);
      expect(manager.shelfState('A', null), AuthorShelfState.expanded);
      expect(
        manager.shelfState('A', 'Unnamed author'),
        AuthorShelfState.collapsed,
      );
      expect(manager.folderNames, containsAll(['A', 'B']));
      expect(
        manager.folderNames,
        isNot(contains('favorite_author_shelf_states')),
      );
    },
  );
  test('rename migrates, delete and recreate do not resurrect state', () async {
    await save('A', 'Alpha', AuthorShelfState.expanded);
    await manager.rename('A', 'Renamed');
    expect(manager.shelfState('Renamed', 'Alpha'), AuthorShelfState.expanded);
    await manager.deleteFolder('Renamed');
    await manager.createFolder('Renamed');
    expect(manager.shelfState('Renamed', 'Alpha'), AuthorShelfState.normal);
  });
  test('bad persisted data reads normal without repairing writes', () async {
    await save('A', 'Alpha', AuthorShelfState.expanded);
    for (final bad in ["'wrong'", '42', 'NULL']) {
      sql('UPDATE favorite_author_shelf_states SET state = $bad;');
      expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.normal);
    }
    expect(manager.shelfState('A', 'Missing'), AuthorShelfState.normal);
    final db = sqlite3.open(manager.databasePath);
    expect(
      db
          .select('SELECT state FROM favorite_author_shelf_states;')
          .single['state'],
      isNull,
    );
    db.dispose();
  });
  test(
    'full database backup and directory replacement contain shelf states',
    () async {
      await save('A', 'Alpha', AuthorShelfState.expanded);
      final original = manager.databasePath;
      await manager.closeAndWait();
      final replacement = Directory('${root.path}/replacement')..createSync();
      File(original).copySync('${replacement.path}/local_favorite.db');
      App.dataPath = replacement.path;
      manager = LocalFavoritesManager.independent();
      await manager.init();
      expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.expanded);
      expect(manager.shelfState('B', 'Alpha'), AuthorShelfState.normal);
    },
  );
  test(
    'alias changes resolve only exact new canonical state without guessing',
    () async {
      await save('A', 'Alpha', AuthorShelfState.collapsed);
      expect(
        manager.shelfState('A', 'Canonical Alpha'),
        AuthorShelfState.normal,
      );
      expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.collapsed);
    },
  );
  test('real SQLite abort preserves previous state and retry succeeds', () async {
    await save('A', 'Alpha', AuthorShelfState.collapsed);
    sql(
      "CREATE TRIGGER fail_state BEFORE UPDATE ON favorite_author_shelf_states BEGIN SELECT RAISE(ABORT, 'controlled state failure'); END;",
    );
    await expectLater(
      save('A', 'Alpha', AuthorShelfState.expanded),
      throwsA(isA<SqliteException>()),
    );
    expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.collapsed);
    sql('DROP TRIGGER fail_state;');
    await save('A', 'Alpha', AuthorShelfState.expanded);
    expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.expanded);
  });
  test(
    'queued state cannot enter replacement folder or disposed page',
    () async {
      final gate = Completer<void>();
      final entered = Completer<void>();
      final holding = AppDataOperations.instance.run(() async {
        entered.complete();
        await gate.future;
      });
      await entered.future;
      var active = true;
      final pending = save(
        'A',
        'Alpha',
        AuthorShelfState.collapsed,
        current: () => active,
      );
      final checked = expectLater(pending, throwsFormatException);
      active = false;
      gate.complete();
      await holding;
      await checked;
      expect(manager.shelfState('A', 'Alpha'), AuthorShelfState.normal);
    },
  );
}
