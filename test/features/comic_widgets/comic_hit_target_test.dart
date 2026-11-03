import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/models.dart';
import 'package:venera_next/features/comic_widgets/comic_tile.dart';

const title =
    'Long comic title repeated across the first and second visible lines';
const comic = Comic(title, '', 'same-id', '', [], '', 'source-a', null, null);

/// Text selection boxes locate actual glyph rows, rather than a widget center
/// that may fall on a different line or outside the visible title.
List<Rect> titleLines(WidgetTester tester) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(title), matching: find.byType(RichText)),
  );
  return paragraph
      .getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: title.length),
      )
      .map((box) => box.toRect().shift(paragraph.localToGlobal(Offset.zero)))
      .where((box) => box.height > 0)
      .toList();
}

void main() {
  setUp(() {
    final previous = Map<String, dynamic>.from(
      appdata.toJson()['settings'] as Map,
    );
    addTearDown(
      () => previous.forEach((key, value) => appdata.settings[key] = value),
    );
  });
  tearDown(configureComicWidgets);
  for (final favorite in [false, true]) {
    testWidgets('detailed first glyph row favorite=$favorite invokes once', (
      tester,
    ) async {
      var actions = 0;
      configureComicWidgets(
        tileStateResolver: (_) => ComicTileState(isFavorite: favorite),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 180,
              child: ComicTile(
                comic: comic,
                displayMode: ComicTileDisplayMode.detailed,
                onTap: () => actions++,
              ),
            ),
          ),
        ),
      );
      final line = titleLines(tester).first;
      final point = Offset(line.left + 3, line.center.dy);
      // Retained in red/green logs to make the blocked production coordinate explicit.
      debugPrint('B4 detailed favorite=$favorite first row=$line tap=$point');
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(actions, 1);
    });
  }
  testWidgets('aggregate simple title glyph row invokes once', (tester) async {
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SimpleComicTile(
            comic: comic,
            withTitle: true,
            onTap: () => actions++,
          ),
        ),
      ),
    );
    final line = titleLines(tester).first;
    final point = Offset(line.left + 3, line.center.dy);
    debugPrint('B4 simple title row=$line tap=$point');
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(actions, 1);
  });
  for (final viewport in [375.0, 1280.0]) {
    for (final mode in [
      'detailed',
      'brief',
      'compact-brief',
      'gallery',
      'compact-gallery',
    ]) {
      for (var flags = 0; flags < 8; flags++) {
        testWidgets(
          '$mode viewport=$viewport badges=$flags glyph rows and cover',
          (tester) async {
            tester.view.physicalSize = Size(viewport, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            appdata.settings['comicDisplayMode'] = mode.contains('brief')
                ? 'brief'
                : 'detailed';
            configureComicWidgets(
              tileStateResolver: (item) => item.sourceKey == 'source-b'
                  ? const ComicTileState()
                  : ComicTileState(
                      isFavorite: flags & 1 != 0,
                      historyPage: flags & 2 != 0 ? 3 : null,
                      historyMaxPage: 20,
                      hasNewUpdate: flags & 4 != 0,
                    ),
            );
            final actions = <(String, String)>[];
            final width = mode == 'detailed'
                ? (viewport == 375 ? 375.0 : 540.0)
                : mode.startsWith('compact-')
                ? 72.0
                : 160.0;
            final height = mode == 'detailed' ? 180.0 : 240.0;
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: width,
                        height: height,
                        child: ComicTile(
                          comic: comic,
                          displayMode: mode.contains('gallery')
                              ? ComicTileDisplayMode.gallery
                              : mode == 'detailed'
                              ? ComicTileDisplayMode.detailed
                              : null,
                          onTap: () => actions.add((comic.id, comic.sourceKey)),
                        ),
                      ),
                      if (width < viewport)
                        SizedBox(
                          width: 50,
                          height: height,
                          child: ComicTile(
                            comic: const Comic(
                              'Neighbor',
                              '',
                              'same-id',
                              '',
                              [],
                              '',
                              'source-b',
                              null,
                              null,
                            ),
                            displayMode: ComicTileDisplayMode.gallery,
                            onTap: () => actions.add(('same-id', 'source-b')),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
            final lines = titleLines(tester);
            expect(lines, isNotEmpty);
            if (mode == 'detailed' || mode == 'gallery') {
              expect(lines.length, greaterThanOrEqualTo(2));
            }
            final points = <Offset>[
              for (final line in lines)
                for (final x in [line.left + 2, line.center.dx, line.right - 2])
                  Offset(x, line.center.dy),
              // Explicit decoration coordinate and unobscured cover coordinate.
              const Offset(20, 18), Offset(40, height / 2),
            ];
            for (final point in points) {
              final before = actions.length;
              await tester.tapAt(point);
              await tester.pumpAndSettle();
              expect(
                actions.length,
                before + 1,
                reason: '$mode $flags at $point',
              );
              expect(actions.last, ('same-id', 'source-a'));
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  for (final viewport in [375.0, 1280.0]) {
    for (final width in [72.0, 87.0, 88.0]) {
      testWidgets('brief compact threshold width=$width viewport=$viewport', (
        tester,
      ) async {
        tester.view.physicalSize = Size(viewport, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        appdata.settings['comicDisplayMode'] = 'brief';
        configureComicWidgets(
          tileStateResolver: (_) => const ComicTileState(
            isFavorite: true,
            historyPage: 3,
            historyMaxPage: 20,
            hasNewUpdate: true,
          ),
        );
        var count = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 240,
                child: ComicTile(comic: comic, onTap: () => count++),
              ),
            ),
          ),
        );
        final bookmark = tester.getRect(find.byIcon(Icons.bookmark_rounded));
        // The icon's render box fills the badge; positions retain brief's 6,8.
        expect(bookmark.width, (width < 88 ? 18.0 : 24.0));
        final badge = find
            .ancestor(
              of: find.byIcon(Icons.bookmark_rounded),
              matching: find.byType(Container),
            )
            .first;
        expect(tester.getTopLeft(badge), const Offset(6, 8));
        for (final point in [
          titleLines(tester).first.center,
          const Offset(12, 16),
          const Offset(30, 100),
        ]) {
          final before = count;
          await tester.tapAt(point);
          await tester.pumpAndSettle();
          expect(count, before + 1);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('multi-line progress overlay retains tooltip and cover action', (
    tester,
  ) async {
    var count = 0;
    configureComicWidgets(
      tileStateResolver: (_) => const ComicTileState(
        isFavorite: true,
        hasNewUpdate: true,
        historyPage: 3,
        historyDescription: 'Progress',
        historyCompactDescription: 'Chapter 2\nPage 3',
        historyTooltipDescription: 'Full progress tooltip',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 375,
            height: 180,
            child: ComicTile(
              comic: comic,
              onTap: () => count++,
              displayMode: ComicTileDisplayMode.detailed,
            ),
          ),
        ),
      ),
    );
    final point = tester.getCenter(find.text('Page 3'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: point);
    await mouse.moveTo(point);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Full progress tooltip'), findsOneWidget);
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(count, 1);
    await mouse.removePointer();
  });
  testWidgets(
    'default detail route preserves source identity and hero once per coordinate',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      appNavigation.mainNavigatorKey = key;
      addTearDown(() => appNavigation.mainNavigatorKey = null);
      final routes = _RouteCounter();
      final opened = <(String, String, int?)>[];
      configureComicWidgets(
        tileStateResolver: (_) =>
            const ComicTileState(isFavorite: true, hasNewUpdate: true),
        comicPageBuilder:
            ({required id, required sourceKey, cover, title, heroID}) {
              opened.add((id, sourceKey, heroID));
              return const Scaffold(body: Text('Detail destination'));
            },
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [routes],
          home: const Scaffold(
            body: SizedBox(
              width: 375,
              height: 180,
              child: ComicTile(
                comic: comic,
                heroID: 42,
                displayMode: ComicTileDisplayMode.detailed,
              ),
            ),
          ),
        ),
      );
      final points = [
        titleLines(tester).first.center,
        titleLines(tester)[1].center,
        const Offset(20, 18),
      ];
      for (final point in points) {
        final before = routes.pushes;
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(routes.pushes, before + 1);
        expect(opened.last, ('same-id', 'source-a', 42));
        key.currentState!.pop();
        await tester.pumpAndSettle();
      }
      expect(opened, hasLength(3));
    },
  );
  testWidgets('existing keyboard activation and pressed feedback remain', (
    tester,
  ) async {
    var actions = 0;
    configureComicWidgets(
      tileStateResolver: (_) => const ComicTileState(isFavorite: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 375,
            height: 180,
            child: ComicTile(
              comic: comic,
              onTap: () => actions++,
              displayMode: ComicTileDisplayMode.detailed,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ClickInkWell), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(actions, 1);
    final gesture = await tester.startGesture(titleLines(tester).first.center);
    await tester.pump(const Duration(milliseconds: 80));
    final ink = tester.widget<InkWell>(find.byType(ClickInkWell));
    expect(ink.onTap, isNotNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(actions, 2);
  });
}

class _RouteCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}
