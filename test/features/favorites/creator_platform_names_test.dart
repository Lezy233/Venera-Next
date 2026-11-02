import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/favorites/creator_platform_names.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/comic_type.dart';
import '../../support/comic_source_fixture.dart';

FavoriteItem item(String id, String source, String author) => FavoriteItem(
  id: id,
  name: id,
  coverPath: '',
  author: 'fallback',
  type: ComicType(source.hashCode),
  tags: ['author:$author'],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LocalFavoritesManager manager;
  late CreatorPlatformNamesStore store;
  late Map<String, dynamic> oldImplicit;
  var current = true;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('creator-names-');
    App.dataPath = root.path;
    App.isInitialized = false;
    appdata.settings['language'] = 'en-US';
    oldImplicit = appdata.implicitData;
    appdata.implicitData = {};
    final sources = [
      ComicSourceFixture(key: 'a'),
      ComicSourceFixture(key: 'b'),
    ];
    configureComicSourceRegistry(
      all: () => sources,
      find: (key) => sources.where((e) => e.key == key).firstOrNull,
      fromIntKey: (key) =>
          sources.where((e) => e.key.hashCode == key).firstOrNull,
      isEmpty: () => false,
    );
    manager = LocalFavoritesManager.independent();
    await manager.init();
    await manager.createFolder('one');
    await manager.createFolder('two');
    await manager.addComic('one', item('same', 'a', ' A  Name '));
    await manager.addComic('two', item('same', 'a', 'Other'));
    await manager.addComic('two', item('same', 'b', 'B Name'));
    appdata.implicitData['local_favorites_author_aliases'] = {
      'Other': 'A Name',
      'B Name': 'A Name',
    };
    current = true;
    store = CreatorPlatformNamesStore(manager, isCurrent: () => current);
    await store.refresh();
  });
  tearDown(() async {
    store.dispose();
    await manager.closeAndWait();
    appdata.implicitData = oldImplicit;
    App.dataPath = Directory.systemTemp.path;
    configureComicSourceRegistry(
      all: () => [],
      find: (_) => null,
      fromIntKey: (_) => null,
      isEmpty: () => true,
    );
    root.deleteSync(recursive: true);
  });
  test(
    'all folder rows retain same id/type different author metadata and same id different platform',
    () {
      expect(manager.getAllComics(), hasLength(2));
      expect(store.observed, hasLength(3));
      expect(store.rows('A Name').map((e) => '${e.sourceKey}/${e.name}'), [
        'a/A  Name',
        'a/Other',
        'b/B Name',
      ]);
      expect(
        observedCreatorNames([item('unknown', 'not-installed', 'X')]),
        isEmpty,
      );
    },
  );
  test('bad records are ignored and versioned JSON roundtrips', () {
    final data = CreatorPlatformNamesData.decode({
      'entries': [
        null,
        {},
        {'anchor': 'A', 'sourceKey': 'a', 'name': '  Exact  Text '},
        {'anchor': '', 'sourceKey': 'a', 'name': 'x'},
      ],
      'hidden': 'bad',
    });
    expect(data.entries.single.name, 'Exact  Text');
    expect(
      CreatorPlatformNamesData.decode(
        jsonDecode(jsonEncode(data.toJson())),
      ).entries,
      data.entries,
    );
  });
  test(
    'same-source multi names deduplicate exact trimmed values only and persist',
    () async {
      await store.change('A Name', sourceKey: 'a', name: ' Studio ');
      await store.change('A Name', sourceKey: 'a', name: 'Studio');
      await store.change('A Name', sourceKey: 'a', name: 'studio');
      final data = CreatorPlatformNamesData.decode(
        jsonDecode(
          File('${root.path}/implicitData.json').readAsStringSync(),
        )[creatorPlatformNamesKey],
      );
      expect(data.entries, hasLength(2));
      expect(data.entries.every((e) => e.anchor == 'A Name'), isTrue);
      expect(store.rows('A Name'), hasLength(5));
      await expectLater(
        store.change('A Name', sourceKey: 'a', name: '   '),
        throwsFormatException,
      );
    },
  );
  test(
    'editing/deleting observed rows hides originals across refresh, explicit add restores',
    () async {
      await store.change(
        'A Name',
        previous: store.rows('A Name').first,
        sourceKey: 'a',
        name: 'Correct',
      );
      await store.refresh();
      expect(
        store.rows('A Name').map((e) => e.name),
        isNot(contains('A  Name')),
      );
      final other = store.rows('A Name').firstWhere((e) => e.name == 'Other');
      await store.change('A Name', previous: other);
      await store.refresh();
      expect(store.rows('A Name').map((e) => e.name), isNot(contains('Other')));
      await store.change('A Name', sourceKey: 'a', name: 'Other');
      expect(
        store.rows('A Name').where((e) => e.name == 'Other'),
        hasLength(1),
      );
      expect(
        manager.allComics().map((e) => e.tags.single),
        contains('author: A  Name '),
      );
    },
  );
  test(
    'anchor follows alias merge and reset without copy or loss; stable sorted fallback anchor',
    () async {
      await store.change('A Name', sourceKey: 'a', name: 'Manual');
      appdata.implicitData['local_favorites_author_aliases'] = {
        'A Name': 'Merged',
        'Other': 'Merged',
        'B Name': 'Merged',
      };
      expect(
        store.rows('Merged').where((e) => e.name == 'Manual'),
        hasLength(1),
      );
      expect(store.rows('A Name'), isEmpty);
      appdata.implicitData['local_favorites_author_aliases'] = {};
      expect(
        store.rows('A Name').where((e) => e.name == 'Manual'),
        hasLength(1),
      );
      expect(store.rows('Other').where((e) => e.name == 'Manual'), isEmpty);
      appdata.implicitData['local_favorites_author_aliases'] = {
        'A Name': 'Z',
        'Other': 'Z',
      };
      await store.change('Z', sourceKey: 'b', name: 'Z record');
      final entries = CreatorPlatformNamesData.decode(
        appdata.implicitData[creatorPlatformNamesKey],
      ).entries;
      expect(entries.firstWhere((e) => e.name == 'Z record').anchor, 'A Name');
    },
  );
  test(
    'uninstalled manual source is retained and cannot be rebound to same display name',
    () async {
      await store.change('A Name', sourceKey: 'a', name: 'Manual');
      configureComicSourceRegistry(
        all: () => [ComicSourceFixture(key: 'b')],
        find: (key) => key == 'b' ? ComicSourceFixture(key: 'b') : null,
        fromIntKey: (_) => null,
        isEmpty: () => false,
      );
      await store.refresh();
      expect(
        store
            .rows('A Name')
            .any((e) => e.sourceKey == 'a' && e.name == 'Manual'),
        isTrue,
      );
    },
  );
  test(
    'latest draft serializes concurrent mutations without losing either name',
    () async {
      await Future.wait([
        store.change('A Name', sourceKey: 'a', name: 'One'),
        store.change('A Name', sourceKey: 'b', name: 'Two'),
      ]);
      expect(
        store.rows('A Name').map((e) => e.name),
        containsAll(['One', 'Two']),
      );
    },
  );
  test('page/selection retirement while queued rejects old edit', () async {
    final release = Completer<void>();
    final held = AppDataOperations.instance.run(() => release.future);
    final change = store.change('A Name', sourceKey: 'a', name: 'Old');
    final expectation = expectLater(change, throwsStateError);
    current = false;
    release.complete();
    await held;
    await expectation;
    expect(appdata.implicitData[creatorPlatformNamesKey], isNull);
  });
  test(
    'data directory or database generation replacement rejects old edit',
    () async {
      App.dataPath = '${root.path}/other';
      await expectLater(
        store.change('A Name', sourceKey: 'a', name: 'Old'),
        throwsStateError,
      );
      App.dataPath = root.path;
      await manager.closeAndWait();
      await expectLater(
        store.change('A Name', sourceKey: 'a', name: 'Old'),
        throwsStateError,
      );
    },
  );
  test('failed durable write restores old valid mappings', () async {
    await store.change('A Name', sourceKey: 'a', name: 'Before');
    final before = jsonEncode(appdata.implicitData[creatorPlatformNamesKey]);
    File('${root.path}/implicitData.json').deleteSync();
    Directory('${root.path}/implicitData.json').createSync();
    await expectLater(
      store.change('A Name', sourceKey: 'a', name: 'Failed'),
      throwsA(anything),
    );
    expect(jsonEncode(appdata.implicitData[creatorPlatformNamesKey]), before);
  });
}
