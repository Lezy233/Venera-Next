import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/favorites/local_favorites_page.dart';
import 'package:venera_next/features/favorites/author_shelf_model.dart';
import 'package:venera_next/features/favorites/creator_platform_names.dart';
import 'package:venera_next/features/search/search_result_page.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/routing/app_navigation.dart';
import '../../support/creator_search_source.dart';
import '../../components/sidebar_presentation_test.dart' show settleSidebarWork;

class _History extends Fake implements HistoryManager {
  @override
  History? find(String id, ComicType type) => null;
}

class _Routes extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
}

class _MutableSource extends CreatorSearchSource {
  _MutableSource(super.key);
  String defaultOption = 'normal';
  @override
  SearchPageData get searchPageData {
    final data = super.searchPageData;
    final option = data.searchOptions!.single;
    return SearchPageData(
      [SearchOptions(option.options, option.label, option.type, defaultOption)],
      data.loadPage,
      data.loadNext,
    );
  }
}

void main() {
  App.dataPath = App.cachePath = Directory.systemTemp.path;
  testWidgets('production folder offers multi-author shelves with separate state controls', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('f10-v2-ui-');
    final oldPath = App.dataPath;
    final oldCache = App.cachePath;
    final oldImplicit = appdata.implicitData;
    final oldSettings = Map<String, dynamic>.from(
      appdata.toJson()['settings'] as Map,
    );
    final oldNavigator = appNavigation.mainNavigatorKey;
    App.dataPath = App.cachePath = root.path;
    appdata.implicitData = {};
    appdata.settings['language'] = 'en-US';
    appdata.settings['autoAddLanguageFilter'] = 'none';
    appdata.settings['blockedWords'] = <String>[];
    appdata.settings['favoritesFilterPanelOpen'] = true;
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    final sources = [_MutableSource('a'), _MutableSource('b')];
    configureComicSourceRegistry(
      all: () => sources,
      find: (key) => sources.where((e) => e.key == key).firstOrNull,
      fromIntKey: (_) => null,
      isEmpty: () => false,
    );
    final manager = LocalFavoritesManager.independent();
    await tester.runAsync(() async {
      await manager.init();
      await manager.createFolder('Shelf');
      await manager.addComic(
        'Shelf',
        FavoriteItem(
          id: 'shared',
          name: 'Shared work',
          coverPath: '',
          author: 'Uploader',
          type: ComicType(0),
          tags: ['author:Alpha', 'author:Beta'],
        ),
      );
    });
    final routes = _Routes();
    appNavigation.mainNavigatorKey = appNavigation.rootNavigatorKey;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await settleSidebarWork(tester, () async {
        await appdata.writeImplicitData();
        await manager.closeAndWait();
      });
      configureComicSourceRegistry(
        all: () => [],
        find: (_) => null,
        fromIntKey: (_) => null,
        isEmpty: () => true,
      );
      appNavigation.mainNavigatorKey = oldNavigator;
      appdata.implicitData = oldImplicit;
      oldSettings.forEach((key, value) => appdata.settings[key] = value);
      App.dataPath = oldPath;
      App.cachePath = oldCache;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      root.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      FavoritesScope(
        manager: manager,
        child: HistoryScope(
          manager: _History(),
          child: MaterialApp(
            navigatorKey: appNavigation.rootNavigatorKey,
            navigatorObservers: [routes],
            home: Scaffold(
              body: LocalFavoritesPage(
                folder: 'Shelf',
                showFolders: () {},
                onFolderSelected: (_, _) {},
                updateFolderList: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialRoutes = routes.pushes.length;
    debugPrint(
      'F10 v2 entry Manual at ${tester.getCenter(find.text('Manual').first)} tiles=${find.byType(ComicTile).evaluate().length} actualRoutes=$initialRoutes requests=${sources.map((e) => e.requests.length).toList()}',
    );
    await tester.tap(find.text('Manual').first);
    await tester.pumpAndSettle();
    final shelfChoice = find.text('Author shelves');
    // The v1 label is accepted only to reach its actual production behavior
    // during the initial red run; v2 must expose the new label below.
    final choice = shelfChoice.evaluate().isNotEmpty
        ? shelfChoice.last
        : find.text('Author → manual order').last;
    debugPrint('F10 v2 choice at ${tester.getCenter(choice)}');
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await settleSidebarWork(
      tester,
      () => AppDataOperations.instance.run(() {}),
    );
    await tester.pumpAndSettle();
    debugPrint(
      'F10 v2 selected tiles=${find.byType(ComicTile).evaluate().length} actualRoutes=${routes.pushes.length} requests=${sources.map((e) => e.requests.length).toList()}',
    );
    expect(routes.pushes.whereType<PopupRoute>().length, 1);
    expect(routes.pushes.length, initialRoutes + 1); // Only the real sort menu.
    expect(sources.every((source) => source.requests.isEmpty), isTrue);
    expect(
      find.byType(ComicTile),
      findsNWidgets(2),
      reason: 'Shared work belongs to both Alpha and Beta shelves',
    );
    expect(find.byTooltip('Collapse author shelf'), findsNWidgets(2));
    expect(find.text('Author shelves'), findsOneWidget);

    Future<void> settle() async {
      await tester.pumpAndSettle();
      await settleSidebarWork(
        tester,
        () => AppDataOperations.instance.run(() {}),
      );
      await tester.pumpAndSettle();
    }

    Finder arrow(String author) => find.byKey(
      ValueKey<(String, String, String?)>((
        'author-shelf-arrow',
        'Shelf',
        author,
      )),
    );
    Finder name(String author) => find.byKey(
      ValueKey<(String, String, String?)>((
        'author-shelf-name',
        'Shelf',
        author,
      )),
    );
    await tester.tapAt(
      tester.getCenter(find.text('Shared work').first),
      buttons: kSecondaryMouseButton,
    );
    await settle();
    await tester.tap(find.text('Select').last);
    await settle();
    expect(find.text('Selected 1 comics'), findsOneWidget);
    // The second UI instance toggles the same business identity, rather than
    // creating a second selection or opening a comic.
    await tester.tap(find.text('Shared work').last);
    await settle();
    expect(find.text('Selected 1 comics'), findsNothing);
    expect(routes.pushes.where((route) => route is! PopupRoute).length, 1);
    await tester.tap(arrow('Alpha'));
    await settle();
    expect(manager.shelfState('Shelf', 'Alpha'), AuthorShelfState.collapsed);
    await tester.tap(name('Alpha'));
    await settle();
    expect(manager.shelfState('Shelf', 'Alpha'), AuthorShelfState.collapsed);
    await tester.tap(arrow('Alpha'));
    await settle();
    expect(manager.shelfState('Shelf', 'Alpha'), AuthorShelfState.normal);

    // Expand through the actual author button. The shared F7 view loads local
    // rows only, and navigation is observed on the real main navigator.
    appdata.implicitData[creatorPlatformNamesKey] = {
      'entries': [
        {'anchor': 'Alpha', 'sourceKey': 'a', 'name': 'Bound name'},
        {'anchor': 'Alpha', 'sourceKey': 'a', 'name': 'Second name'},
        {'anchor': 'Alpha', 'sourceKey': 'b', 'name': 'Bound name'},
        {'anchor': 'Alpha', 'sourceKey': 'missing', 'name': 'Offline name'},
      ],
    };
    await tester.tap(name('Alpha'));
    await settle();
    expect(manager.shelfState('Shelf', 'Alpha'), AuthorShelfState.expanded);
    expect(find.text('Bound name'), findsNWidgets(2));
    expect(find.text('Second name'), findsOneWidget);
    // The comic's observed local source and the explicit missing source both
    // remain visible; neither supports ordinary source search.
    expect(find.text('Source unavailable'), findsNWidgets(2));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Offline name'))
          .onPressed,
      isNull,
    );
    expect(sources.every((source) => source.requests.isEmpty), isTrue);
    final memory = appdata.settings['searchSelection'];
    sources.first.defaultOption = 'other'; // Change after the panel was built.
    await Scrollable.ensureVisible(
      tester.element(find.text('Bound name').first),
      alignment: .2,
    );
    await tester.pumpAndSettle();
    debugPrint(
      'F10 v2 bound search at ${tester.getCenter(find.text('Bound name').first)}',
    );
    await tester.tap(find.text('Bound name').first);
    await settle();
    expect(find.byType(SearchResultPage), findsOneWidget);
    expect(sources.first.requests, hasLength(1));
    expect(sources.first.requests.single.$1, 'Bound name');
    expect(sources.first.requests.single.$2, 1);
    expect(sources.first.requests.single.$3, ['other']);
    expect(sources.last.requests, isEmpty);
    expect(routes.pushes.where((route) => route is! PopupRoute).length, 2);
    expect(appdata.settings['searchSelection'], memory);
    appNavigation.rootNavigatorKey.currentState!.pop();
    await settle();
    // A source can disappear after the enabled row was rendered. The actual
    // click must validate again and cannot route or request another source.
    final removed = sources.removeAt(0);
    await Scrollable.ensureVisible(
      tester.element(find.text('Bound name').first),
      alignment: .2,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bound name').first);
    await settle();
    expect(routes.pushes.where((route) => route is! PopupRoute).length, 2);
    expect(removed.requests, hasLength(1));
    expect(sources.single.requests, isEmpty);
    sources.insert(0, removed);
    await Scrollable.ensureVisible(
      tester.element(arrow('Alpha')),
      alignment: .2,
    );
    await tester.pumpAndSettle();
    await tester.tap(arrow('Alpha'));
    await settle();
    expect(manager.shelfState('Shelf', 'Alpha'), AuthorShelfState.normal);

    // Give both shelves overflow, then drive actual pointer signals with each
    // Shift key, checking the parent and neighboring controller independently.
    await tester.runAsync(() async {
      for (var i = 0; i < 8; i++) {
        await manager.addComic(
          'Shelf',
          FavoriteItem(
            id: 'extra$i',
            name: 'Extra $i',
            coverPath: '',
            author: '',
            type: ComicType(0),
            tags: ['author:Alpha', 'author:Beta'],
          ),
        );
        await manager.addComic(
          'Shelf',
          FavoriteItem(
            id: 'gamma$i',
            name: 'Gamma $i',
            coverPath: '',
            author: 'Gamma',
            type: ComicType(0),
            tags: [],
          ),
        );
      }
    });
    await settle();
    for (final author in ['Alpha', 'Beta']) {
      await Scrollable.ensureVisible(
        tester.element(arrow(author)),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      await tester.tap(arrow(author));
      await settle();
    }
    Finder strip(String author) => find.byKey(
      ValueKey<(String, String, String?)>((
        'author-shelf-scroll',
        'Shelf',
        author,
      )),
    );
    final alpha = tester
        .widget<SingleChildScrollView>(strip('Alpha'))
        .controller!;
    final beta = tester
        .widget<SingleChildScrollView>(strip('Beta'))
        .controller!;
    expect(
      tester.getSize(strip('Alpha')).height,
      tester.getSize(strip('Beta')).height,
    );
    await Scrollable.ensureVisible(
      tester.element(strip('Alpha')),
      alignment: .2,
    );
    await tester.pumpAndSettle();
    final parentState = Scrollable.of(tester.element(strip('Alpha')));
    ScrollPosition parent() => parentState.position;
    for (final shift in [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    ]) {
      final oldParent = parent().pixels;
      final oldNeighbor = beta.offset;
      final oldAlpha = alpha.offset;
      await tester.sendKeyDownEvent(shift);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(strip('Alpha')),
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pumpAndSettle();
      expect(alpha.offset, oldAlpha + 100);
      expect(beta.offset, oldNeighbor);
      expect(parent().pixels, oldParent);
      await tester.sendKeyUpEvent(shift);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(strip('Alpha')),
        scrollDelta: const Offset(0, 1000000),
      ),
    );
    await tester.pumpAndSettle();
    expect(alpha.offset, alpha.position.maxScrollExtent);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(strip('Alpha')),
        scrollDelta: const Offset(0, -1000000),
      ),
    );
    await tester.pumpAndSettle();
    expect(alpha.offset, alpha.position.minScrollExtent);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    final beforeNativeParent = parent().pixels;
    final beforeNativePosition = parent();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(strip('Alpha')),
        scrollDelta: const Offset(100, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(alpha.offset, 100);
    expect(parent().pixels, beforeNativeParent);
    debugPrint(
      'F10 v2 native parent position replaced=${!identical(parent(), beforeNativePosition)} old=${beforeNativePosition.pixels} live=${parent().pixels} axis=${parent().axis}',
    );
    final oldAlpha = alpha.offset;
    final oldParent = parent().pixels;
    debugPrint(
      'F10 v2 before ordinary wheel alpha=${alpha.offset} parent=$oldParent max=${parent().maxScrollExtent} position=${tester.getCenter(strip('Alpha'))} shifts=${HardwareKeyboard.instance.isShiftPressed}',
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(strip('Alpha')),
        scrollDelta: const Offset(0, 100),
      ),
    );
    await tester.pumpAndSettle();
    expect(alpha.offset, oldAlpha);
    debugPrint(
      'F10 v2 after ordinary wheel alpha=${alpha.offset} parent=${parent().pixels} max=${parent().maxScrollExtent} stale=${beforeNativePosition.pixels}',
    );
    expect(parent().axis, Axis.vertical);
    expect(parent().pixels, greaterThan(oldParent));
    await tester.runAsync(
      () => manager.addComic(
        'Shelf',
        FavoriteItem(
          id: 'unknown',
          name: 'Unknown work',
          coverPath: '',
          author: '',
          type: ComicType(0),
          tags: [],
        ),
      ),
    );
    await settle();
    parent().jumpTo(parent().maxScrollExtent);
    await tester.pumpAndSettle();
    final unknown = find.byKey(
      const ValueKey<(String, String, String?)>((
        'author-shelf-name',
        'Shelf',
        null,
      )),
    );
    await Scrollable.ensureVisible(tester.element(unknown), alignment: .2);
    await tester.pumpAndSettle();
    await tester.tap(unknown);
    await settle();
    expect(find.text('No platform names'), findsOneWidget);
    expect(sources.first.requests, hasLength(1));
    expect(sources.last.requests, isEmpty);
    expect(routes.pushes.where((route) => route is! PopupRoute).length, 2);
    expect(tester.takeException(), isNull);
  });
}
