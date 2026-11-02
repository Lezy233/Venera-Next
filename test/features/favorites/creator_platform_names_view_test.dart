import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/favorites/creator_platform_names_view.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/favorites/local_favorites_page.dart';
import 'package:venera_next/features/history/history_manager.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/search/search_result_page.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/routing/app_navigation.dart';
import '../../support/creator_search_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LocalFavoritesManager manager;
  late HistoryManager history;
  late List<CreatorSearchSource> sources;
  late Map<String, dynamic> oldSettings;
  late Map<String, dynamic> oldImplicit;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('creator-ui-');
    App.dataPath = root.path;
    App.cachePath = root.path;
    App.isInitialized = false;
    oldSettings = Map.from(appdata.toJson()['settings'] as Map);
    oldImplicit = appdata.implicitData;
    appdata.implicitData = {
      'local_favorites_author_aliases': {
        'Other': 'Creator',
        'Second': 'Creator',
      },
      'local_favorites_author_filter': ['Creator'],
    };
    appdata.settings['language'] = 'en-US';
    appdata.settings['autoAddLanguageFilter'] = 'none';
    appdata.settings['comicListDisplayMode'] = 'paging';
    appdata.settings['favoritesFilterPanelOpen'] = true;
    appdata.settings['favoritesFilterPanelWidth'] = 260;
    sources = [
      CreatorSearchSource('nhentai', displayName: 'Platform A'),
      CreatorSearchSource('other', displayName: 'Platform B'),
    ];
    configureComicSourceRegistry(
      all: () => sources,
      find: (key) => sources.where((e) => e.key == key).firstOrNull,
      fromIntKey: (key) =>
          sources.where((e) => e.key.hashCode == key).firstOrNull,
      isEmpty: () => sources.isEmpty,
    );
    manager = LocalFavoritesManager.independent();
    history = HistoryManager.create();
    await manager.init();
    await history.init();
    await manager.createFolder('A');
    await manager.createFolder('B');
    FavoriteItem item(String id, String key, String author) => FavoriteItem(
      id: id,
      name: id,
      coverPath: '',
      author: author,
      type: ComicType(key.hashCode),
      tags: ['author:$author'],
    );
    await manager.addComic('A', item('one', 'nhentai', 'Creator'));
    await manager.addComic('B', item('same', 'nhentai', 'Other'));
    await manager.addComic('B', item('same', 'other', 'Second'));
  });
  Future<void> frames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    var done = false;
    Object? failure;
    appdata.writeImplicitData().then(
      (_) => done = true,
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    for (var i = 0; i < 200 && !done; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(done, isTrue);
    expect(failure, isNull);
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, {double width = 1280}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (_) async => false,
    );
    appNavigation.mainNavigatorKey = appNavigation.rootNavigatorKey;
    await tester.pumpWidget(
      FavoritesScope(
        manager: manager,
        child: HistoryScope(
          manager: history,
          child: MaterialApp(
            navigatorKey: appNavigation.rootNavigatorKey,
            home: Scaffold(
              body: LocalFavoritesPage(
                folder: 'A',
                showFolders: () {},
                onFolderSelected: (_, _) {},
                updateFolderList: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      var closed = false;
      Object? closeError;
      manager.closeAndWait().then(
        (_) => closed = true,
        onError: (Object e) {
          closeError = e;
          closed = true;
        },
      );
      for (var i = 0; i < 500 && !closed; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(closed, isTrue);
      expect(closeError, isNull);
      history.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });
  }

  tearDown(() async {
    oldSettings.forEach((k, v) => appdata.settings[k] = v);
    appdata.implicitData = oldImplicit;
    App.dataPath = Directory.systemTemp.path;
    configureComicSourceRegistry(
      all: () => [],
      find: (_) => null,
      fromIntKey: (_) => null,
      isEmpty: () => true,
    );
    appNavigation.mainNavigatorKey = null;
    root.deleteSync(recursive: true);
  });
  Finder getTree() => find.byType(CreatorPlatformNamesView);
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'production 260px desktop tree uses all folders, stays local, hides on zero/multi selection',
    (tester) async {
      await mount(tester);
      expect(getTree(), findsOneWidget);
      final tree = find.descendant(of: getTree(), matching: find.text('Other'));
      expect(tree, findsOneWidget);
      expect(
        find.descendant(of: getTree(), matching: find.text('Second')),
        findsOneWidget,
      );
      expect(find.text('Creator platform names'), findsOneWidget);
      expect(
        find.text('nhentai'),
        findsNothing,
      ); // unique display name needs no key
      expect(sources.every((s) => s.requests.isEmpty), isTrue);
      final pageState =
          tester.state(find.byType(LocalFavoritesPage)) as dynamic;
      pageState.setState(() => pageState.authorFilters = <String>{});
      await frames(tester);
      expect(find.text('Creator platform names'), findsNothing);
      pageState.setState(
        () => pageState.authorFilters = <String>{'Creator', 'Another'},
      );
      await frames(tester);
      expect(find.text('Creator platform names'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets(
      'production name Tab/$key opens exact ordinary source, defaults and pagination; returning retains filters',
      (tester) async {
        await mount(tester);
        final target = find.descendant(
          of: getTree(),
          matching: find.widgetWithText(TextButton, 'Other'),
        );
        await reveal(tester, target);
        // Traverse from the preceding platform heading to a name action.
        final node = Focus.of(
          tester.element(
            find.descendant(of: target, matching: find.byType(Text)),
          ),
        );
        node.requestFocus();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(key);
        await frames(tester);
        final result = tester.widget<SearchResultPage>(
          find.byType(SearchResultPage),
        );
        expect(result.text, 'Other');
        expect(result.sourceKey, 'nhentai');
        expect(result.options, ['normal']);
        expect(sources.first.requests.first.$1, 'Other');
        expect(sources.first.requests.first.$3, ['normal']);
        expect(sources.last.requests, isEmpty);
        await tester.tap(find.text('Next').first);
        await frames(tester);
        expect(sources.first.requests.last.$2, 2);
        expect(sources.first.requests.last.$1, 'Other');
        expect(sources.first.requests.last.$3, ['normal']);
        appNavigation.rootNavigatorKey.currentState!.pop();
        await frames(tester);
        expect(find.text('Creator platform names'), findsOneWidget);
        expect(
          (tester.state(find.byType(LocalFavoritesPage)) as dynamic)
              .authorFilters,
          {'Creator'},
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'production compact dialog tree follows local choices and search returns to same dialog',
    (tester) async {
      appdata.implicitData['local_favorites_author_filter'] = <String>[];
      await mount(tester, width: 375);
      await tester.tap(find.byTooltip('Filter').first);
      await frames(tester);
      expect(find.text('Creator platform names'), findsNothing);
      await tester.tap(find.text('Creator').last);
      await frames(tester);
      expect(find.text('Creator platform names'), findsOneWidget);
      final target = find.descendant(
        of: getTree(),
        matching: find.text('Other'),
      );
      await reveal(tester, target);
      await tester.tap(target);
      await frames(tester);
      expect(find.byType(SearchResultPage), findsOneWidget);
      appNavigation.rootNavigatorKey.currentState!.pop();
      await frames(tester);
      expect(find.text('Creator platform names'), findsOneWidget);
      // Underlying applied selection remains empty until filter Apply.
      expect(
        (tester.state(find.byType(LocalFavoritesPage, skipOffstage: false))
                as dynamic)
            .authorFilters,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'production add/edit save/cancel finishes dialog animation without disposed controller; delete persists',
    (tester) async {
      await mount(tester);
      final add = find.text('Add platform name');
      await reveal(tester, add);
      await tester.tap(add);
      await frames(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Platform name'),
        'Manual',
      );
      await tester.tap(find.text('Save').last);
      await frames(tester);
      final manual = find.descendant(
        of: getTree(),
        matching: find.text('Manual'),
      );
      expect(manual, findsOneWidget);
      final row = find.ancestor(of: manual, matching: find.byType(Row)).first;
      await reveal(tester, manual);
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await frames(tester);
      await tester.tap(find.text('Edit').last);
      await frames(tester);
      await tester.tap(find.text('Cancel').last);
      await frames(tester);
      expect(manual, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await frames(tester);
      await tester.tap(find.text('Edit').last);
      await frames(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Platform name'),
        'Updated',
      );
      await tester.tap(find.text('Save').last);
      await frames(tester);
      final updated = find.descendant(
        of: getTree(),
        matching: find.text('Updated'),
      );
      expect(manual, findsNothing);
      expect(updated, findsOneWidget);
      await reveal(tester, find.text('Add platform name'));
      await tester.tap(find.text('Add platform name'));
      await frames(tester);
      await tester.tap(find.text('Cancel').last);
      await frames(tester);
      final updatedRow = find
          .ancestor(of: updated, matching: find.byType(Row))
          .first;
      await reveal(tester, updated);
      await tester.tap(
        find.descendant(
          of: updatedRow,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await frames(tester);
      await tester.tap(find.text('Delete').last);
      await frames(tester);
      expect(updated, findsNothing);
      expect(tester.takeException(), isNull);
      expect(sources.every((s) => s.requests.isEmpty), isTrue);
    },
  );
  testWidgets(
    'duplicate platform names show keys; unavailable manual mapping stays disabled',
    (tester) async {
      sources = [CreatorSearchSource('nhentai'), CreatorSearchSource('other')];
      appdata.implicitData['creator_platform_names'] = {
        'version': 1,
        'entries': [
          {'anchor': 'Creator', 'sourceKey': 'missing', 'name': 'Offline name'},
        ],
      };
      await mount(tester);
      expect(find.text('Test platform · nhentai'), findsOneWidget);
      expect(find.text('Test platform · other'), findsOneWidget);
      expect(find.text('Source unavailable'), findsOneWidget);
      final offline = find.descendant(
        of: getTree(),
        matching: find.widgetWithText(TextButton, 'Offline name'),
      );
      expect(tester.widget<TextButton>(offline).onPressed, isNull);
      await reveal(tester, find.text('Test platform · nhentai'));
      await tester.tap(find.text('Test platform · nhentai'));
      await frames(tester);
      expect(sources.every((e) => e.requests.isEmpty), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'language setting is applied once exactly like ordinary manual search',
    (tester) async {
      appdata.settings['autoAddLanguageFilter'] = 'chinese';
      await mount(tester);
      final target = find.descendant(
        of: getTree(),
        matching: find.text('Other'),
      );
      await reveal(tester, target);
      await tester.tap(target);
      await frames(tester);
      final viaTree = sources.first.requests.last;
      appNavigation.rootNavigatorKey.currentState!.pop();
      await frames(tester);
      appNavigation.rootNavigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: SearchResultPage(
              text: 'Other',
              sourceKey: 'nhentai',
              options: ['normal'],
            ),
          ),
        ),
      );
      await frames(tester);
      expect(viaTree.$1, 'Other language:chinese');
      expect(viaTree.$1, sources.first.requests.last.$1);
      expect(viaTree.$3, sources.first.requests.last.$3);
      expect(tester.takeException(), isNull);
    },
  );
}
