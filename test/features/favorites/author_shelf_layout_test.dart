import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/author_shelf.dart';
import 'package:venera_next/features/favorites/author_shelf_model.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/comic_type.dart';
import '../../components/sidebar_presentation_test.dart' show settleSidebarWork;

void main() {
  App.dataPath = App.cachePath = Directory.systemTemp.path;
  for (final width in [390.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
          'production shelf width=$width $brightness text=$scale ceil grid and state animation',
          (tester) async {
            final root = Directory.systemTemp.createTempSync('f10-v2-layout-');
            final oldPath = App.dataPath;
            final oldCache = App.cachePath;
            final oldImplicit = appdata.implicitData;
            final oldSettings = Map<String, dynamic>.from(
              appdata.toJson()['settings'] as Map,
            );
            App.dataPath = App.cachePath = root.path;
            appdata.implicitData = {};
            appdata.settings['language'] = 'en-US';
            appdata.settings['blockedWords'] = <String>[];
            tester.view.physicalSize = Size(width, 2000);
            tester.view.devicePixelRatio = 1;
            final manager = LocalFavoritesManager.independent();
            await tester.runAsync(() async {
              await manager.init();
              await manager.createFolder('Shelf');
              for (var i = 0; i < 5; i++) {
                await manager.addComic(
                  'Shelf',
                  FavoriteItem(
                    id: '$i',
                    name: 'Long comic title $i repeated long title',
                    coverPath: '',
                    author: 'Very long author name repeated long author name',
                    type: ComicType(0),
                    tags: [],
                  ),
                );
              }
            });
            var columns = 2;
            configureComicWidgets(
              favoriteDisplayStateResolver: () => ComicFavoriteDisplayState(
                isGallery: true,
                galleryColumns: columns,
              ),
            );
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox());
              await settleSidebarWork(tester, () async {
                await appdata.writeImplicitData();
                await manager.closeAndWait();
              });
              configureComicWidgets();
              appdata.implicitData = oldImplicit;
              oldSettings.forEach(
                (key, value) => appdata.settings[key] = value,
              );
              App.dataPath = oldPath;
              App.cachePath = oldCache;
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              root.deleteSync(recursive: true);
            });
            final author = manager.getFolderComics('Shelf').first.author;
            Finder key(String kind) => find.byKey(
              ValueKey<(String, String, String?)>((kind, 'Shelf', author)),
            );
            Widget tree() => FavoritesScope(
              manager: manager,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 2000),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: CustomScrollView(
                      slivers: [
                        FavoriteFolderComics(
                          folder: 'Shelf',
                          shelves: true,
                          members: manager.getFolderComics('Shelf'),
                          comics: manager.getFolderComics('Shelf'),
                          aliases: const {},
                          isCurrent: () => true,
                        ),
                      ],
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

            await tester.pumpWidget(tree());
            await settle();
            final headerRect = tester.getRect(key('author-shelf-header'));
            final arrowRect = tester.getRect(key('author-shelf-arrow'));
            final nameRect = tester.getRect(key('author-shelf-name'));
            expect(arrowRect.right, closeTo(headerRect.right, .01));
            expect(arrowRect.left, greaterThanOrEqualTo(nameRect.right));
            final grid = key('author-shelf-grid');
            final tileHeight = tester
                .getSize(find.byType(ComicTile).first)
                .height;
            expect(tester.getSize(grid).height, closeTo(tileHeight * 3, .01));
            final normalSize = tester.getSize(grid);
            void sql(String query) {
              final db = sqlite3.open(manager.databasePath);
              try {
                db.execute(query);
              } finally {
                db.dispose();
              }
            }

            sql(
              "CREATE TRIGGER fail_shelf_save BEFORE INSERT ON favorite_author_shelf_states BEGIN SELECT RAISE(ABORT, 'controlled UI save failure'); END;",
            );
            await tester.tap(key('author-shelf-name'));
            await settle();
            expect(
              manager.shelfState('Shelf', author),
              AuthorShelfState.normal,
            );
            expect(
              find.text('Could not save author shelf. Try again.'),
              findsOneWidget,
            );
            expect(find.text('Saved'), findsNothing);
            sql('DROP TRIGGER fail_shelf_save;');
            await tester.tap(find.text('Retry'));
            await settle();
            expect(
              manager.shelfState('Shelf', author),
              AuthorShelfState.expanded,
            );
            expect(tester.getSize(grid), normalSize);
            // Local rows or an empty state stay below the unchanged grid.
            expect(find.text('Creator platform names'), findsOneWidget);
            await tester.tap(key('author-shelf-arrow'));
            await settle();
            expect(
              manager.shelfState('Shelf', author),
              AuthorShelfState.normal,
            );
            await tester.tap(key('author-shelf-arrow'));
            await tester.pump();
            await settleSidebarWork(
              tester,
              () => AppDataOperations.instance.run(() {}),
            );
            await tester.pump(const Duration(milliseconds: 80));
            final animated = find.byType(AnimatedSize).first;
            final intermediate = tester.getSize(animated).height;
            expect(intermediate, lessThanOrEqualTo(normalSize.height));
            expect(intermediate, greaterThanOrEqualTo(tileHeight));
            await tester.pumpAndSettle();
            expect(
              tester.getSize(key('author-shelf-scroll')).height,
              closeTo(tileHeight, .01),
            );
            columns = 3;
            appdata.settings['favoritesGalleryColumns'] = 3;
            await settle();
            await tester.tap(key('author-shelf-arrow'));
            await settle();
            final nextHeight = tester
                .getSize(find.byType(ComicTile).first)
                .height;
            expect(tester.getSize(grid).height, closeTo(nextHeight * 2, .01));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
