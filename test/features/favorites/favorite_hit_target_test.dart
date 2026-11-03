import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorites.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/favorites/local_favorites_page.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/reader/reader.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/routing/app_navigation.dart';

const _name = 'Long favorite title across the first and second visible lines';

class _Routes extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
}

void main() {
  App.dataPath = Directory.systemTemp.path;
  App.cachePath = Directory.systemTemp.path;
  for (final gallery in [false, true]) {
    for (final preference in ['viewDetail', 'read']) {
      testWidgets(
        'production favorites gallery=$gallery preference=$preference title/cover/menu/selection',
        (tester) async {
          final root = Directory.systemTemp.createTempSync('b4-favorites-');
          final previousPath = App.dataPath;
          final previousCache = App.cachePath;
          final previous = Map<String, dynamic>.from(
            appdata.toJson()['settings'] as Map,
          );
          final implicit = Map<String, dynamic>.from(appdata.implicitData);
          App.dataPath = root.path;
          App.cachePath = root.path;
          final manager = LocalFavoritesManager.independent();
          final history = HistoryManager.create();
          final navigator = appNavigation.rootNavigatorKey;
          final oldMain = appNavigation.mainNavigatorKey;
          appNavigation.mainNavigatorKey = navigator;
          appdata.settings['language'] = 'en-US';
          appdata.settings['onClickFavorite'] = preference;
          appdata.settings['favoritesDisplayMode'] = gallery
              ? 'gallery'
              : 'list';
          appdata.settings['favoritesGalleryColumns'] = 4;
          appdata.settings['blockedWords'] = <String>[];
          appdata.implicitData['local_favorites_read_filter'] = 'All';
          final routes = _Routes();
          final copied = <String>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                copied.add((call.arguments as Map)['text'] as String);
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          configureComicWidgets(
            comicPageBuilder:
                ({required id, required sourceKey, cover, title, heroID}) =>
                    ComicPage(
                      id: id,
                      sourceKey: sourceKey,
                      cover: cover,
                      title: title,
                      heroID: heroID,
                    ),
            tileStateResolver: (_) => const ComicTileState(
              isFavorite: true,
              hasNewUpdate: true,
              historyPage: 3,
            ),
            favoriteDisplayStateResolver: () => ComicFavoriteDisplayState(
              isGallery: gallery,
              galleryColumns: 4,
            ),
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 400));
            await tester.runAsync(() async {
              await appdata.writeImplicitData();
              await manager.debugWaitForHashedIdsRefresh();
              manager.close();
              history.close();
            });
            configureComicWidgets();
            appNavigation.mainNavigatorKey = oldMain;
            previous.forEach((key, value) => appdata.settings[key] = value);
            appdata.implicitData = implicit;
            App.dataPath = previousPath;
            App.cachePath = previousCache;
            root.deleteSync(recursive: true);
          });
          await tester.runAsync(() async {
            await manager.init();
            await history.init();
            await manager.createFolder('B4');
            for (var index = 0; index < 2; index++) {
              await manager.addComic(
                'B4',
                FavoriteItem(
                  id: 'book-$index',
                  name: index == 0 ? _name : 'Neighbor favorite',
                  coverPath: '',
                  author: '',
                  type: ComicType.local,
                  tags: const [],
                ),
              );
            }
            await manager.debugWaitForHashedIdsRefresh();
          });
          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            FavoritesScope(
              manager: manager,
              child: HistoryScope(
                manager: history,
                child: MaterialApp(
                  navigatorKey: navigator,
                  navigatorObservers: [routes],
                  home: Scaffold(
                    body: LocalFavoritesPage(
                      folder: 'B4',
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
          List<Offset> points() {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.text(_name),
                matching: find.byType(RichText),
              ),
            );
            final lines = paragraph.getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: _name.length),
            );
            final tile = find.ancestor(
              of: find.text(_name),
              matching: find.byType(ComicTile),
            );
            return [
              for (final line in lines)
                paragraph.localToGlobal(line.toRect().center),
              tester.getTopLeft(tile) + const Offset(20, 18),
            ];
          }

          for (final point in points()) {
            final before = routes.pushes.length;
            await tester.tapAt(point);
            // Observe the real route produced by the production favorites callback
            // before mounting its unrelated detail/reader services (no network).
            expect(routes.pushes.length, before + 1);
            final route = routes.pushes.last as AppPageRoute;
            final destination = route.builder(navigator.currentContext!);
            if (preference == 'viewDetail') {
              expect(destination, isA<ComicPage>());
              final page = destination as ComicPage;
              expect((page.id, page.sourceKey), ('book-0', 'local'));
              final tile = tester.widget<ComicTile>(
                find.ancestor(
                  of: find.text(_name),
                  matching: find.byType(ComicTile),
                ),
              );
              expect(page.heroID, tile.heroID);
            } else {
              expect(destination, isA<ReaderWithLoading>());
              final page = destination as ReaderWithLoading;
              expect((page.id, page.sourceKey), ('book-0', 'local'));
            }
            navigator.currentState!.removeRoute(route);
            await tester.pumpAndSettle();
            expect(routes.pushes.length, before + 1);
          }
          final beforeMenu = routes.pushes.length;
          await tester.tapAt(points().first, buttons: kSecondaryMouseButton);
          await tester.pumpAndSettle();
          expect(routes.pushes.length, beforeMenu + 1); // menu only
          expect(find.text('Copy Title'), findsOneWidget);
          await tester.tap(find.text('Copy Title'));
          await tester.pumpAndSettle();
          expect(routes.pushes.length, beforeMenu + 1);
          expect(copied, [_name]);
          // Independent Details menu action is always a single detail route,
          // including when the card's primary action is direct reading.
          await tester.tapAt(points().first, buttons: kSecondaryMouseButton);
          await tester.pumpAndSettle();
          final beforeDetail = routes.pushes.length;
          await tester.tap(find.text('Details'));
          expect(routes.pushes.length, beforeDetail + 1);
          final route = routes.pushes.last as AppPageRoute;
          final detail = route.builder(navigator.currentContext!) as ComicPage;
          expect((detail.id, detail.sourceKey), ('book-0', 'local'));
          navigator.currentState!.removeRoute(route);
          await tester.pumpAndSettle();
          await tester.longPressAt(
            tester.getCenter(find.text('Neighbor favorite')),
          );
          await tester.pumpAndSettle();
          final beforeSelect = routes.pushes.length;
          await tester.tapAt(points().first);
          await tester.pumpAndSettle();
          expect(routes.pushes.length, beforeSelect);
          var grid = tester.widget<SliverGridComics>(
            find.byType(SliverGridComics),
          );
          expect(
            grid.selections!.keys.map((e) => e.id),
            unorderedEquals(['book-0', 'book-1']),
          );
          await tester.tapAt(points().last);
          await tester.pumpAndSettle();
          grid = tester.widget<SliverGridComics>(find.byType(SliverGridComics));
          expect(grid.selections!.keys.map((e) => e.id), ['book-1']);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SliverGridComics>(find.byType(SliverGridComics))
                .selections,
            isEmpty,
          );
          expect(routes.pushes.length, beforeSelect);
          await tester.tapAt(points().first);
          expect(routes.pushes.length, beforeSelect + 1);
          final resumedRoute = routes.pushes.last as AppPageRoute;
          final resumed = resumedRoute.builder(navigator.currentContext!);
          expect(
            resumed,
            preference == 'viewDetail'
                ? isA<ComicPage>()
                : isA<ReaderWithLoading>(),
          );
          navigator.currentState!.removeRoute(resumedRoute);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
