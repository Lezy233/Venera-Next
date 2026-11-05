import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorite_order.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/favorites/local_favorites_page.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
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

void main() {
  App.dataPath = App.cachePath = Directory.systemTemp.path;
  for (final collapsed in [false, true]) {
    testWidgets(
      'shared works have independent ${collapsed ? "collapsed" : "normal"} shelf orders',
      (tester) async {
        final root = Directory.systemTemp.createTempSync(
          'f10-v21-independent-',
        );
        final oldPath = App.dataPath, oldCache = App.cachePath;
        final oldImplicit = appdata.implicitData;
        final oldSettings = Map<String, dynamic>.from(
          appdata.toJson()['settings'] as Map,
        );
        final oldNavigator = appNavigation.mainNavigatorKey;
        App.dataPath = App.cachePath = root.path;
        appdata.implicitData = {};
        appdata.settings['language'] = 'en-US';
        appdata.settings['blockedWords'] = <String>[];
        appdata.settings['favoritesFilterPanelOpen'] = false;
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        final sources = [CreatorSearchSource('a'), CreatorSearchSource('b')];
        configureComicSourceRegistry(
          all: () => sources,
          find: (key) =>
              sources.where((source) => source.key == key).firstOrNull,
          fromIntKey: (_) => null,
          isEmpty: () => false,
        );
        final manager = LocalFavoritesManager.independent();
        await tester.runAsync(() async {
          await manager.init();
          for (final folder in ['Shelf', 'Other']) {
            await manager.createFolder(folder);
            for (final id in ['C1', 'C2']) {
              await manager.addComic(
                folder,
                FavoriteItem(
                  id: id,
                  name: id,
                  coverPath: '',
                  author: '',
                  type: ComicType(0),
                  tags: ['author:Alpha', 'author:Beta'],
                ),
              );
            }
          }
          await manager.setOrderScopeMode(
            const FavoriteOrderScope.folder('Shelf'),
            'authorManual',
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
        Future<void> settle() async {
          await tester.pumpAndSettle();
          await settleSidebarWork(
            tester,
            () => AppDataOperations.instance.run(() {}),
          );
          await tester.pumpAndSettle();
        }

        await settle();
        if (collapsed) {
          for (final author in ['Alpha', 'Beta']) {
            await tester.tap(
              find.byKey(
                ValueKey<(String, String, String?)>((
                  'author-shelf-arrow',
                  'Shelf',
                  author,
                )),
              ),
            );
            await settle();
          }
        }
        Finder shelf(String author) => find.byKey(
          ValueKey<(String, String, String?)>((
            collapsed ? 'author-shelf-scroll' : 'author-shelf-grid',
            'Shelf',
            author,
          )),
        );
        List<String> titles(String author) => tester
            .widgetList<ComicTile>(
              find.descendant(
                of: shelf(author),
                matching: find.byType(ComicTile),
              ),
            )
            .map((tile) => tile.comic.title)
            .toList();
        Future<void> move(String author, String moving, String neighbor) async {
          final origin = tester.getCenter(
            find.descendant(of: shelf(author), matching: find.text(moving)),
          );
          final target = tester.getCenter(
            find.descendant(of: shelf(author), matching: find.text(neighbor)),
          );
          debugPrint(
            'F10 v2.1 $author collapsed=$collapsed $moving $origin -> $neighbor $target',
          );
          final pointer = await tester.startGesture(
            origin,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 100),
          );
          await pointer.moveTo(target);
          await tester.pump(const Duration(milliseconds: 100));
          await pointer.up();
          await settle();
          debugPrint(
            'F10 v2.1 actualRoutes=${routes.pushes.length} requests=${sources.map((source) => source.requests.length).toList()} Alpha=${titles("Alpha")} Beta=${titles("Beta")} folder=${manager.getFolderComics("Shelf").map((item) => item.id).toList()}',
          );
          expect(routes.pushes, hasLength(1));
          expect(sources.every((source) => source.requests.isEmpty), isTrue);
        }

        expect(titles('Alpha'), ['C1', 'C2']);
        expect(titles('Beta'), ['C1', 'C2']);
        final headersBefore = ['Alpha', 'Beta']
            .map(
              (a) => tester.getTopLeft(
                find.byKey(
                  ValueKey<(String, String, String?)>((
                    'author-shelf-header',
                    'Shelf',
                    a,
                  )),
                ),
              ),
            )
            .toList();
        await move('Alpha', 'C2', 'C1');
        expect(titles('Alpha'), ['C2', 'C1']);
        expect(titles('Beta'), ['C1', 'C2']);
        expect(manager.getFolderComics('Shelf').map((item) => item.id), [
          'C1',
          'C2',
        ]);
        expect(manager.getFolderComics('Other').map((item) => item.id), [
          'C1',
          'C2',
        ]);
        expect(
          ['Alpha', 'Beta'].map(
            (a) => tester.getTopLeft(
              find.byKey(
                ValueKey<(String, String, String?)>((
                  'author-shelf-header',
                  'Shelf',
                  a,
                )),
              ),
            ),
          ),
          headersBefore,
        );
        await move('Beta', 'C2', 'C1');
        expect(titles('Beta'), ['C2', 'C1']);
        expect(titles('Alpha'), ['C2', 'C1']);
        await move('Beta', 'C1', 'C2');
        expect(titles('Beta'), ['C1', 'C2']);
        expect(titles('Alpha'), ['C2', 'C1']);
        expect(
          find.text('Could not save favorite order. Try again.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
