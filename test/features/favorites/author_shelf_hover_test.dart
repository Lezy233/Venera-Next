import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/author_shelf.dart';
import 'package:venera_next/features/favorites/author_shelf_model.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorite_order.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/routing/app_navigation.dart';
import '../../support/creator_search_source.dart';
import '../../components/sidebar_presentation_test.dart' show settleSidebarWork;

class _Routes extends NavigatorObserver {
  int count = 0;
  int menus = 0;
  @override
  void didPush(Route route, Route? previousRoute) {
    count++;
    if (route is PopupRoute) menus++;
  }
}

void main() {
  App.dataPath = App.cachePath = Directory.systemTemp.path;
  for (final brightness in Brightness.values) {
    for (final collapsed in [false, true]) {
      for (final gallery in [false, true]) {
        testWidgets(
          'hover ${brightness.name} ${collapsed ? "collapsed" : "normal"} ${gallery ? "gallery" : "detailed"}',
          (tester) async {
            final root = Directory.systemTemp.createTempSync('f10-v22-hover-');
            final oldPath = App.dataPath,
                oldCache = App.cachePath,
                oldImplicit = appdata.implicitData;
            final oldSettings = Map<String, dynamic>.from(
              appdata.toJson()['settings'] as Map,
            );
            final oldNavigator = appNavigation.mainNavigatorKey;
            App.dataPath = App.cachePath = root.path;
            appdata.implicitData = {};
            appdata.settings['language'] = 'en-US';
            appdata.settings['blockedWords'] = <String>[];
            tester.view.physicalSize = const Size(1280, 1600);
            tester.view.devicePixelRatio = 1;
            final sources = [
              CreatorSearchSource('a'),
              CreatorSearchSource('b'),
            ];
            configureComicSourceRegistry(
              all: () => sources,
              find: (key) => sources.where((s) => s.key == key).firstOrNull,
              fromIntKey: (_) => null,
              isEmpty: () => false,
            );
            configureComicWidgets(
              favoriteDisplayStateResolver: () => ComicFavoriteDisplayState(
                isGallery: gallery,
                galleryColumns: 4,
              ),
            );
            final manager = LocalFavoritesManager.independent();
            await tester.runAsync(() async {
              await manager.init();
              await manager.createFolder('Shelf');
              for (final id in ['C1', 'C2']) {
                await manager.addComic(
                  'Shelf',
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
              if (collapsed) {
                for (final author in ['Alpha', 'Beta']) {
                  await manager.setShelfState(
                    folder: 'Shelf',
                    author: author,
                    state: AuthorShelfState.collapsed,
                    token: manager.orderScopeToken(
                      const FavoriteOrderScope.folder('Shelf'),
                    )!,
                    generation: manager.connectionGeneration,
                    dataPath: App.dataPath,
                    isCurrent: () => true,
                  );
                }
              }
            });
            final db = sqlite3.open(manager.databasePath);
            db.execute(
              "INSERT INTO favorite_author_shelf_states VALUES ('__hover_probe__','audit','0');",
            );
            for (final table in [
              'favorite_author_shelf_order',
              'favorite_author_shelf_states',
            ]) {
              for (final op in ['INSERT', 'UPDATE', 'DELETE']) {
                final ref = op == 'DELETE' ? 'OLD' : 'NEW';
                db.execute(
                  "CREATE TRIGGER hover_${table}_$op AFTER $op ON $table WHEN $ref.folder_name!='__hover_probe__' BEGIN UPDATE favorite_author_shelf_states SET state=CAST(state AS INT)+1 WHERE folder_name='__hover_probe__'; END;",
                );
              }
            }
            db.execute(
              "CREATE TRIGGER hover_folder AFTER UPDATE ON Shelf BEGIN UPDATE favorite_author_shelf_states SET state=CAST(state AS INT)+1 WHERE folder_name='__hover_probe__'; END;",
            );
            int writes() => int.parse(
              db
                      .select(
                        "SELECT state FROM favorite_author_shelf_states WHERE folder_name='__hover_probe__';",
                      )
                      .single['state']
                  as String,
            );
            final routes = _Routes(), boundary = GlobalKey();
            appNavigation.mainNavigatorKey = appNavigation.rootNavigatorKey;
            var selected = false, reduced = false;
            late StateSetter rebuild;
            var primary = 0;
            final members = manager.getFolderComics('Shelf');
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox());
              await settleSidebarWork(tester, () async {
                await manager.closeAndWait();
              });
              db.dispose();
              configureComicWidgets();
              configureComicSourceRegistry(
                all: () => [],
                find: (_) => null,
                fromIntKey: (_) => null,
                isEmpty: () => true,
              );
              appNavigation.mainNavigatorKey = oldNavigator;
              appdata.implicitData = oldImplicit;
              oldSettings.forEach((k, v) => appdata.settings[k] = v);
              App.dataPath = oldPath;
              App.cachePath = oldCache;
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              root.deleteSync(recursive: true);
            });
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: FavoritesScope(
                  manager: manager,
                  child: MaterialApp(
                    navigatorKey: appNavigation.rootNavigatorKey,
                    navigatorObservers: [routes],
                    theme: ThemeData(brightness: brightness),
                    home: StatefulBuilder(
                      builder: (context, setState) {
                        rebuild = setState;
                        return MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(disableAnimations: reduced),
                          child: Scaffold(
                            body: Column(
                              children: [
                                SizedBox(
                                  width: 320,
                                  height: 200,
                                  child: ComicTile(
                                    key: const ValueKey('ordinary-control'),
                                    comic: members.first,
                                    displayMode: gallery
                                        ? ComicTileDisplayMode.gallery
                                        : ComicTileDisplayMode.detailed,
                                    onTap: () => primary++,
                                  ),
                                ),
                                Expanded(
                                  child: CustomScrollView(
                                    slivers: [
                                      FavoriteFolderComics(
                                        folder: 'Shelf',
                                        shelves: true,
                                        members: members,
                                        comics: members,
                                        aliases: const {},
                                        isCurrent: () => true,
                                        selections: selected
                                            ? {members.first: true}
                                            : null,
                                        onTap: (_, _) => primary++,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            Finder instance(String author, String id) => find.byKey(
              ValueKey<(String, String?, FavoriteIdentity)>((
                'Shelf',
                author,
                (id, 0),
              )),
            );
            final current = instance('Alpha', 'C1'),
                neighbor = instance('Alpha', 'C2'),
                shared = instance('Beta', 'C1');
            expect(current, findsOneWidget);
            expect(shared, findsOneWidget);
            final geometry = tester.getRect(current);
            Offset sample(Finder finder) {
              final rect = tester.getRect(finder);
              return Offset(rect.left + 2, rect.center.dy);
            }

            Future<int> pixel(Finder finder) async {
              final point = sample(finder);
              final render =
                  boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              return (await tester.runAsync(() async {
                final frame = await render.toImage(pixelRatio: 1);
                final data = await frame.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                final offset =
                    (point.dy.floor() * frame.width + point.dx.floor()) * 4;
                final bytes = data!.buffer.asUint8List();
                final rgba =
                    (bytes[offset] << 24) |
                    (bytes[offset + 1] << 16) |
                    (bytes[offset + 2] << 8) |
                    bytes[offset + 3];
                frame.dispose();
                return rgba;
              }))!;
            }

            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            const outside = Offset(1270, 1590);
            await mouse.addPointer(location: outside);
            await tester.pumpAndSettle();
            Future<void> move(Offset point) async {
              await mouse.moveTo(point);
              await tester.pumpAndSettle();
            }

            final control = find.byKey(const ValueKey('ordinary-control'));
            final controlBefore = await pixel(control);
            await move(tester.getCenter(control));
            final controlHover = await pixel(control);
            expect(
              controlHover,
              isNot(controlBefore),
              reason: 'Same theme/mode ordinary ComicTile must visibly hover',
            );
            await move(outside);
            final before = await pixel(current),
                neighborBefore = await pixel(neighbor),
                sharedBefore = await pixel(shared);
            final title = find.descendant(
              of: current,
              matching: find.text('C1'),
            );
            await move(tester.getCenter(title));
            final hovered = await pixel(current);
            debugPrint(
              'F10 v2.2 ${brightness.name} collapsed=$collapsed gallery=$gallery title=${tester.getCenter(title)} sample=${sample(current)} control=$controlBefore->$controlHover shelf=$before->$hovered routes=${routes.count} primary=$primary writes=${writes()} requests=${sources.map((s) => s.requests.length).toList()}',
            );
            expect(
              hovered,
              isNot(before),
              reason:
                  'Production shelf final painted background must change under a real mouse',
            );
            expect(await pixel(neighbor), neighborBefore);
            expect(await pixel(shared), sharedBefore);
            await move(outside);
            await mouse.moveTo(tester.getCenter(title));
            await tester.pump();
            await tester.pump(
              Duration(milliseconds: AppMotion.fast.inMilliseconds ~/ 2),
            );
            final halfway = await pixel(current);
            expect(halfway, isNot(before));
            expect(halfway, isNot(hovered));
            await tester.pump(AppMotion.fast);
            expect(await pixel(current), hovered);
            for (final point in [
              Offset(geometry.left + 25, geometry.top + 30),
              sample(current),
            ]) {
              await move(outside);
              expect(await pixel(current), before);
              await move(point);
              expect(await pixel(current), isNot(before));
            }
            await move(
              tester.getCenter(
                find.descendant(of: neighbor, matching: find.text('C2')),
              ),
            );
            expect(await pixel(current), before);
            expect(await pixel(neighbor), isNot(neighborBefore));
            await move(outside);
            expect(await pixel(neighbor), neighborBefore);
            rebuild(() => selected = true);
            await tester.pumpAndSettle();
            final selectedBefore = await pixel(current);
            expect(selectedBefore, isNot(before));
            await move(tester.getCenter(title));
            expect(await pixel(current), isNot(selectedBefore));
            await move(outside);
            expect(await pixel(current), selectedBefore);
            expect(selected, isTrue);
            rebuild(() => reduced = true);
            await tester.pumpAndSettle();
            await mouse.moveTo(tester.getCenter(title));
            await tester.pump();
            expect(await pixel(current), isNot(selectedBefore));
            await move(outside);
            expect(await pixel(current), selectedBefore);
            expect(tester.getRect(current), geometry);
            expect(routes.count, 1);
            expect(primary, 0);
            expect(writes(), 0);
            expect(sources.every((s) => s.requests.isEmpty), isTrue);
            Future<(int, int)> menuPixels(Finder card) async {
              await tester.tapAt(
                tester.getCenter(card),
                buttons: kSecondaryMouseButton,
                kind: PointerDeviceKind.mouse,
              );
              await tester.pumpAndSettle();
              final row = find.ancestor(
                of: find.text('Copy Title'),
                matching: find.byType(InkWell),
              );
              expect(row, findsOneWidget);
              await move(outside);
              final idle = await pixel(row);
              await move(tester.getCenter(row));
              final over = await pixel(row);
              debugPrint(
                'menu card=$card sample=${sample(row)} rgba=$idle->$over',
              );
              await move(outside);
              expect(await pixel(row), idle);
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              return (idle, over);
            }

            final ordinaryMenu = await menuPixels(control);
            expect(ordinaryMenu.$2, isNot(ordinaryMenu.$1));
            final shelfMenu = await menuPixels(current);
            expect(
              shelfMenu,
              ordinaryMenu,
              reason:
                  'Shelf right-click menu must retain original theme hover pixels',
            );
            expect(routes.count, 3);
            expect(routes.menus, 2);
            expect(primary, 0);
            expect(writes(), 0);
            expect(sources.every((s) => s.requests.isEmpty), isTrue);
            if (!collapsed) {
              await tester.tap(
                find.byKey(
                  const ValueKey<(String, String, String?)>((
                    'author-shelf-name',
                    'Shelf',
                    'Alpha',
                  )),
                ),
              );
              await tester.pumpAndSettle();
              await settleSidebarWork(
                tester,
                () => AppDataOperations.instance.run(() {}),
              );
              await tester.pumpAndSettle();
              final expected = writes();
              expect(
                manager.shelfState('Shelf', 'Alpha'),
                AuthorShelfState.expanded,
              );
              expect(tester.getSize(current), geometry.size);
              await move(tester.getCenter(title));
              expect(await pixel(current), isNot(selectedBefore));
              await move(outside);
              expect(await pixel(current), selectedBefore);
              expect(writes(), expected);
            }
            Future<void> settle() async {
              await tester.pumpAndSettle();
              await settleSidebarWork(
                tester,
                () => AppDataOperations.instance.run(() {}),
              );
              await tester.pumpAndSettle();
            }

            Future<void> drag({required bool escape}) async {
              final origin = tester.getCenter(
                find.descendant(of: neighbor, matching: find.text('C2')),
              );
              final target = tester.getCenter(title);
              await mouse.moveTo(origin);
              await mouse.down(origin);
              await tester.pump(
                kLongPressTimeout + const Duration(milliseconds: 100),
              );
              if (escape) {
                await tester.sendKeyEvent(LogicalKeyboardKey.escape);
                await tester.pump();
              }
              await mouse.moveTo(target);
              await tester.pump();
              await mouse.up();
              await settle();
              await move(outside);
              expect(await pixel(current), selectedBefore);
              expect(await pixel(neighbor), neighborBefore);
              await move(tester.getCenter(title));
              expect(await pixel(current), isNot(selectedBefore));
              await move(outside);
              expect(await pixel(current), selectedBefore);
            }

            await drag(escape: false);
            final saved = manager.authorShelfOrders('Shelf');
            expect(saved[authorShelfStorageKey('Alpha')], {
              ('C2', 0): 0,
              ('C1', 0): 1,
            });
            expect(saved[authorShelfStorageKey('Beta')], isNull);
            expect(manager.getFolderComics('Shelf').map((item) => item.id), [
              'C1',
              'C2',
            ]);
            final beforeEscape = writes();
            await drag(escape: true);
            expect(manager.authorShelfOrders('Shelf'), saved);
            expect(writes(), beforeEscape);
            expect(routes.count, 3);
            expect(routes.menus, 2);
            expect(primary, 0);
            expect(selected, isTrue);
            expect(sources.every((s) => s.requests.isEmpty), isTrue);
            await tester.tapAt(tester.getCenter(title));
            await tester.pumpAndSettle();
            expect(primary, 1, reason: 'Short click after Escape acts exactly once');
            expect(routes.count, 3);
            expect(writes(), beforeEscape);
            expect(sources.every((s) => s.requests.isEmpty), isTrue);
            await mouse.removePointer();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
