import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorite_order.dart';
import 'package:venera_next/features/favorites/author_shelf_model.dart';
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
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';
import 'package:venera_next/features/reader/reader.dart';
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
    for (final change in [
      'none',
      'escape',
      'cross',
      'add',
      'delete',
      'author',
      'alias',
      'rename',
      'dispose',
      'failure',
      'alternative',
      'alternativeKeyboard',
      'shortDetail',
      'shortRead',
    ]) {
      testWidgets(
        'production ${collapsed ? "collapsed" : "normal"} mouse long press change=$change',
        (tester) async {
          final root = Directory.systemTemp.createTempSync('f10-v2-drag-');
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
          appdata.settings['blockedWords'] = <String>[];
          appdata.settings['favoritesFilterPanelOpen'] = false;
          tester.view.physicalSize = const Size(1280, 1000);
          tester.view.devicePixelRatio = 1;
          final manager = LocalFavoritesManager.independent();
          await tester.runAsync(() async {
            await manager.init();
            await manager.createFolder('Shelf');
            for (final id in ['a1', 'b1', 'a2', 'b2']) {
              await manager.addComic(
                'Shelf',
                FavoriteItem(
                  id: id,
                  name: id,
                  author: id.startsWith('a') ? 'Alpha' : 'Beta',
                  coverPath: '',
                  type: ComicType(0),
                  tags: [],
                ),
              );
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

          List<String> shelfOrder(String author) =>
              authorShelves(
                    manager.getFolderComics('Shelf'),
                    orders: manager.authorShelfOrders('Shelf'),
                  )
                  .firstWhere((group) => group.author == author)
                  .items
                  .map((item) => item.id)
                  .toList();

          await settle();
          if (collapsed) {
            await tester.tap(find.byTooltip('Collapse author shelf').first);
            await settle();
          }
          void sql(String query) {
            final db = sqlite3.open(manager.databasePath);
            try {
              db.execute(query);
            } finally {
              db.dispose();
            }
          }

          if (change == 'shortDetail' || change == 'shortRead') {
            appdata.settings['onClickFavorite'] = change == 'shortDetail'
                ? 'viewDetail'
                : 'read';
            await settle();
            final title = find.text('a1');
            await tester.tap(title);
            expect(routes.pushes.length, 2);
            final route = routes.pushes.last as AppPageRoute;
            final destination = route.builder(tester.element(title));
            expect(
              destination,
              change == 'shortDetail'
                  ? isA<ComicPage>()
                  : isA<ReaderWithLoading>(),
            );
            // Check real admission and destination without mounting a fake local
            // comic reader/details backend; these are protected in their suites.
            appNavigation.rootNavigatorKey.currentState!.pop();
            await settle();
            expect(manager.getFolderComics('Shelf').map((item) => item.id), [
              'a1',
              'b1',
              'a2',
              'b2',
            ]);
            return;
          }
          if (change == 'alternative' || change == 'alternativeKeyboard') {
            await tester.tap(find.byTooltip('Reorder within author').first);
            await settle();
            expect(
              tester
                  .widget<PopupMenuItem<(FavoriteIdentity, bool)>>(
                    find.ancestor(
                      of: find.text('Move up'),
                      matching: find.byType(
                        PopupMenuItem<(FavoriteIdentity, bool)>,
                      ),
                    ),
                  )
                  .enabled,
              isFalse,
            );
            if (change == 'alternativeKeyboard') {
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            } else {
              await tester.tap(find.text('Move down'));
            }
            await settle();
            expect(manager.getFolderComics('Shelf').map((item) => item.id), [
              'a1',
              'b1',
              'a2',
              'b2',
            ]);
            expect(shelfOrder('Alpha'), ['a2', 'a1']);
            expect(shelfOrder('Beta'), ['b1', 'b2']);
            expect(
              routes.pushes.where((route) => route is! PopupRoute).length,
              1,
            );
            return;
          }
          if (change == 'failure') {
            sql(
              "CREATE TRIGGER fail_move BEFORE INSERT ON favorite_author_shelf_order WHEN NEW.comic_id = 'a1' BEGIN SELECT RAISE(ABORT, 'controlled mid-move failure'); END;",
            );
          }
          final origin = tester.getCenter(find.text('a2'));
          final target = tester.getCenter(
            find.text(change == 'cross' ? 'b1' : 'a1'),
          );
          debugPrint(
            'F10 v2 drag collapsed=$collapsed from=$origin to=$target routes=${routes.pushes.length}',
          );
          final previousFocus = FocusManager.instance.primaryFocus;
          final gesture = await tester.startGesture(
            origin,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 100),
          );
          if (change == 'escape') {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pump();
          } else if ([
            'add',
            'delete',
            'author',
            'alias',
            'rename',
          ].contains(change)) {
            await settleSidebarWork(tester, () async {
              switch (change) {
                case 'add':
                  await manager.addComic(
                    'Shelf',
                    FavoriteItem(
                      id: 'new',
                      name: 'New',
                      author: 'Alpha',
                      coverPath: '',
                      type: ComicType(0),
                      tags: [],
                    ),
                  );
                case 'delete':
                  await manager.deleteComicWithId('Shelf', 'a1', ComicType(0));
                case 'rename':
                  await manager.rename('Shelf', 'Renamed');
                case 'author':
                  final item =
                      manager.getComic('Shelf', 'a2', ComicType(0)).detached()
                        ..author = 'Other';
                  await manager.updateInfo(
                    'Shelf',
                    item,
                    generation: manager.connectionGeneration,
                  );
                case 'alias':
                  await appdata.updateImplicit(
                    (draft) => draft['local_favorites_author_aliases'] = {
                      'Alpha': 'Other',
                    },
                  );
              }
            });
          } else if (change == 'dispose') {
            await tester.pumpWidget(const SizedBox());
          }
          await gesture.moveTo(target);
          await tester.pump(const Duration(milliseconds: 100));
          await gesture.up();
          await settle();
          expect(
            routes.pushes.length,
            1,
            reason: 'Long press drag must not open a comic',
          );
          if (change == 'failure') {
            expect(manager.getFolderComics('Shelf').map((item) => item.id), [
              'a1',
              'b1',
              'a2',
              'b2',
            ]);
            expect(
              find.text('Could not save favorite order. Try again.'),
              findsOneWidget,
            );
            expect(find.text('Saved'), findsNothing);
            expect(shelfOrder('Alpha'), ['a1', 'a2']);
            sql('DROP TRIGGER fail_move;');
            await tester.tap(find.text('Retry'));
            await settle();
          } else if (change != 'none') {
            expect(
              manager
                  .getFolderComics(change == 'rename' ? 'Renamed' : 'Shelf')
                  .map((item) => item.id),
              [
                if (change != 'delete') 'a1',
                'b1',
                'a2',
                'b2',
                if (change == 'add') 'new',
              ],
            );
            if (change == 'escape') {
              expect(FocusManager.instance.primaryFocus, previousFocus);
              appdata.settings['onClickFavorite'] = 'viewDetail';
              await tester.tap(find.text('a1'));
              expect(
                routes.pushes.length,
                2,
                reason: 'Escape restores a later short primary click',
              );
              final route = routes.pushes.last as AppPageRoute;
              expect(
                route.builder(tester.element(find.text('a1'))),
                isA<ComicPage>(),
              );
              appNavigation.rootNavigatorKey.currentState!.pop();
              await settle();
            }
            expect(tester.takeException(), isNull);
            return;
          }
          expect(manager.getFolderComics('Shelf').map((item) => item.id), [
            'a1',
            'b1',
            'a2',
            'b2',
          ]);
          expect(shelfOrder('Alpha'), ['a2', 'a1']);
          expect(shelfOrder('Beta'), ['b1', 'b2']);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
