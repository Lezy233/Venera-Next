import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:venera_next/features/reader/auto_reading.dart';
import 'package:venera_next/features/reader/gallery_data.dart';
import 'package:venera_next/features/reader/gallery_view.dart';
import 'package:venera_next/features/reader/page_layout.dart';
import 'package:venera_next/features/reader/platform_effects_controller.dart';
import 'package:venera_next/features/reader/progress_navigation.dart';
import 'package:venera_next/features/reader/reader_controller.dart';
import 'package:venera_next/features/reader/reader_viewport.dart';
import 'package:venera_next/features/reader/scaffold.dart';
import 'package:venera_next/features/reader/shell_data.dart';
import 'package:venera_next/features/reader/thumbnails.dart';
import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/foundation/reader_settings.dart';

// Exercise the real shell, thumbnail constraints, file decoding and PhotoView
// painting. Inspect final pixels, not widget fit properties or readiness alone.
void main() {
  for (final brightness in Brightness.values) {
    for (final position in ['left', 'right', 'bottom']) {
      for (final count in [1, 2]) {
        testWidgets('$brightness fixed $position, $count images use viewport', (
          tester,
        ) async {
          final fixture = _RenderingFixture(
            brightness: brightness,
            position: position,
            count: count,
          );
          addTearDown(() => fixture.dispose(tester));
          await fixture.mount(tester);
          await fixture.checkPixels(tester, 'initial');
          fixture.shell.currentState!.openOrClose();
          await tester.pumpAndSettle();
          await fixture.checkPixels(tester, 'chrome-open');
        });
      }
    }
  }

  for (final mode in ['collapsed', 'floating']) {
    testWidgets('$mode thumbnails preserve full viewport', (tester) async {
      final fixture = _RenderingFixture(
        collapsed: mode == 'collapsed',
        floating: mode == 'floating',
      );
      addTearDown(() => fixture.dispose(tester));
      await fixture.mount(tester);
      expect(tester.getSize(find.byType(ReaderGalleryView)), fixture.size);
      await fixture.checkPixels(tester, mode);
    });
  }

  for (final direction in ['ltr', 'rtl', 'vertical']) {
    testWidgets('$direction resize, unequal images, first/spread/tail pages', (
      tester,
    ) async {
      final fixture = _RenderingFixture(
        reverse: direction == 'rtl',
        vertical: direction == 'vertical',
        sources: const [
          Size(600, 900),
          Size(600, 900),
          Size(800, 1000),
          Size(1200, 800),
          Size(600, 900),
        ],
        cover: true,
        spreads: const {4},
      );
      addTearDown(() => fixture.dispose(tester));
      await fixture.mount(tester);
      await fixture.checkPixels(tester, 'cover');
      fixture.navigation.toPage(2, animated: false);
      await fixture.ready(tester);
      expect(fixture.viewport.current!.currentImageRange, (1, 3));
      await fixture.checkPixels(tester, 'mixed-pair');
      for (final size in [
        const Size(800, 600),
        const Size(390, 700),
        const Size(1280, 700),
      ]) {
        fixture.size = size;
        await fixture.mount(tester);
        await fixture.checkPixels(tester, 'resize-${size.width.toInt()}');
      }
      fixture.navigation.toPage(3, animated: false);
      await fixture.ready(tester);
      expect(fixture.viewport.current!.currentImageRange, (3, 4));
      await fixture.checkPixels(tester, 'spread');
      fixture.navigation.toPage(4, animated: false);
      await fixture.ready(tester);
      expect(fixture.viewport.current!.currentImageRange, (4, 5));
      await fixture.checkPixels(tester, 'tail');
      fixture.navigation.toPage(2, animated: false);
      await fixture.ready(tester);
      await fixture.checkPixels(tester, 'return-pair');
    });
  }
}

class _RenderingFixture {
  _RenderingFixture({
    this.brightness = Brightness.light,
    this.position = 'left',
    this.count = 2,
    this.collapsed = false,
    this.floating = false,
    this.reverse = false,
    this.vertical = false,
    this.cover = false,
    this.spreads = const {},
    this.sources = const [Size(600, 900), Size(600, 900)],
  }) {
    files = [
      for (var i = 0; i < sources.length; i++) _createPage(i, sources[i]),
    ];
    navigation = ReaderController(
      pageCount: () => data.totalPages,
      chapterCount: () => 1,
      animationEnabled: () => false,
      viewport: () => viewport.current,
      onChanged: () {},
      onPageChanged: () {},
      onError: (error, stack) => fail('$error'),
    )..replaceChapterImages([for (final file in files) 'file://${file.path}']);
    data = ReaderGalleryData(
      content: navigation.content,
      layout: ReaderPageLayout(
        imagesPerPage: count,
        singleImageOnFirstPage: cover,
        spreadImages: spreads,
      ),
      vertical: vertical,
      reverse: reverse,
      commentsAtEnd: false,
      firstChapter: true,
      lastChapter: true,
      preloadCount: 0,
      doubleTapCollect: false,
      centerLongPressZoom: false,
      pageAnimation: false,
      sourceKey: null,
      comicId: 'b5-controlled',
      chapterId: '1',
    );
  }

  final Brightness brightness;
  final String position;
  final int count;
  final bool collapsed, floating, reverse, vertical, cover;
  final Set<int> spreads;
  final List<Size> sources;
  Size size = const Size(1280, 700);
  final directory = Directory.systemTemp.createTempSync('b5-rendering-');
  final work = ImageWork();
  final favorites = ChangeNotifier();
  final viewport = ReaderViewportBinding();
  final repaint = GlobalKey();
  final shell = GlobalKey<ReaderScaffoldState>();
  late final List<File> files;
  late final ReaderController navigation;
  late final ReaderGalleryData data;

  File _createPage(int index, Size source) {
    final pixels = img.Image(
      width: source.width.toInt(),
      height: source.height.toInt(),
    );
    for (var y = 0; y < pixels.height; y++) {
      for (var x = 0; x < pixels.width; x++) {
        final rgb = y < 12
            ? [255, 0, 0]
            : y >= pixels.height - 12
            ? [0, 0, 255]
            : x < 12
            ? [0, 255, 0]
            : x >= pixels.width - 12
            ? [255, 255, 0]
            : [40 + (x ~/ 40 % 2) * 30, 150 + (y ~/ 40 % 2) * 30, 160];
        pixels.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }
    return File('${directory.path}/$index.png')
      ..writeAsBytesSync(img.encodePng(pixels));
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final preferences = ReaderSettings.resolve(
      global: {
        'readerThumbnailState': collapsed ? 'collapsed' : 'expanded',
        'readerThumbnailMode': floating ? 'floating' : 'fixed',
        'readerThumbnailPosition': position,
        'readerBrightnessEnabled': false,
        'showPageNumberInReader': false,
        'enableClockAndBatteryInfoInReader': false,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.purple,
            brightness: brightness,
          ).copyWith(surface: const Color(0xffff00ff)),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(1.6),
            disableAnimations: true,
          ),
          child: Material(
            child: ReaderScaffold(
              key: shell,
              data: ReaderShellData(
                comicId: 'b5-controlled',
                sourceKey: 'local',
                title: 'B5 rendering',
                chapterTitle: null,
                hasChapters: false,
                vertical: vertical,
                gallery: true,
                animating: false,
                onCommentsPage: false,
                swipeToCollect: false,
                preferences: preferences,
                automaticReading: AutoReadingStatus.stopped,
              ),
              progress: ReaderProgressRequest(
                identity: navigation,
                page: navigation.state.page,
                maxPage: data.imagePages,
                chapter: 1,
                maxChapter: 1,
                reversed: reverse,
                isCurrent: () => true,
                toPage: (_, {animated = true}) => true,
                toChapter: (_) => false,
              ),
              onExit: () async {},
              onFullscreen: null,
              onToggleAutomaticReading: () => false,
              acquireSidebarPause: () => () {},
              readImagePickContext: () => null,
              imageWork: work,
              orientation: ReaderOrientation.system,
              onRotate: null,
              onSystemUiChanged: (_) {},
              createChapterMenu: () => null,
              favoriteChanges: favorites,
              createFavoriteQuery: () => null,
              createImageFavorite: () => null,
              createImageExport: () => null,
              createSettings: () => null,
              createChapterComments: () => null,
              chapterNavigation: null,
              createThumbnails: () => ReaderThumbnailRequest(
                pages: [
                  for (var p = 1; p <= data.imagePages; p++)
                    ReaderThumbnailPage(p, ['file://${files.first.path}'], p),
                ],
                currentPage: () => navigation.state.page,
                isCurrent: () => true,
                select: (_) => true,
                sourceKey: null,
                comicId: 'b5-controlled',
                chapterId: '1',
              ),
              child: RepaintBoundary(
                key: repaint,
                child: ReaderGalleryView(
                  data: data,
                  imageWork: work,
                  navigation: navigation,
                  onViewportChanged: viewport.update,
                  onReady: () {},
                  onPageReported: (_, _) {},
                  onChapterChanged: () {},
                  onCollectImage: () {},
                  readerSize: () =>
                      tester.getSize(find.byType(ReaderGalleryView)),
                  readImage: (address) async => File(
                    Uri.parse(address.imageKey).toFilePath(),
                  ).readAsBytesSync(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await ready(tester);
  }

  Future<void> ready(WidgetTester tester) async {
    final gallery = tester.state<GalleryModeState>(
      find.byType(ReaderGalleryView),
    );
    for (var i = 0; i < 150 && !gallery.autoReadingReady; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => pumpEventQueue());
    }
    expect(
      gallery.autoReadingReady,
      isTrue,
      reason: 'Require real decoded frames',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> checkPixels(WidgetTester tester, String label) async {
    // Capture only the image subtree: chrome is an intentional overlay and is
    // checked by shell tests. Its presence must not change the image geometry.
    final boundary =
        repaint.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final range = viewport.current!.currentImageRange!;
    final indices = List.generate(range.$2 - range.$1, (i) => range.$1 + i);
    if (reverse) indices.sort((a, b) => b.compareTo(a));
    final failures = <String>[];
    await tester.runAsync(() async {
      final raster = await boundary.toImage();
      try {
        final bytes = (await raster.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var slot = 0; slot < indices.length; slot++) {
          final region = indices.length == 1
              ? Offset.zero & boundary.size
              : vertical
              ? Rect.fromLTWH(
                  0,
                  slot * boundary.size.height / indices.length,
                  boundary.size.width,
                  boundary.size.height / indices.length,
                )
              : Rect.fromLTWH(
                  slot * boundary.size.width / indices.length,
                  0,
                  boundary.size.width / indices.length,
                  boundary.size.height,
                );
          final markers = <String, Rect>{};
          for (var y = region.top.ceil(); y < region.bottom.floor(); y++) {
            for (var x = region.left.ceil(); x < region.right.floor(); x++) {
              final offset = (y * raster.width + x) * 4;
              final r = bytes.getUint8(offset),
                  g = bytes.getUint8(offset + 1),
                  b = bytes.getUint8(offset + 2);
              final name = r > 245 && g < 10 && b < 10
                  ? 'top'
                  : r < 10 && g < 10 && b > 245
                  ? 'bottom'
                  : r < 10 && g > 245 && b < 10
                  ? 'left'
                  : r > 245 && g > 245 && b < 10
                  ? 'right'
                  : null;
              if (name != null) {
                final pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
                markers[name] = markers[name]?.expandToInclude(pixel) ?? pixel;
              }
            }
          }
          final source = sources[indices[slot]];
          final scale = math.min(
            region.width / source.width,
            region.height / source.height,
          );
          final rendered = Size(source.width * scale, source.height * scale);
          final alignment = indices.length == 1
              ? Alignment.center
              : vertical
              ? (slot == 0 ? Alignment.bottomCenter : Alignment.topCenter)
              : (slot == 0 ? Alignment.centerRight : Alignment.centerLeft);
          final expected = alignment.inscribe(rendered, region);
          // Thresholded antialiased edge pixels may differ by one raster pixel.
          // 1.5px cannot hide the original 66px band or a lost edge marker.
          if (markers.length != 4) {
            failures.add('$label slot=$slot lost markers: $markers');
          } else {
            final actual = Rect.fromLTRB(
              markers['left']!.left,
              markers['top']!.top,
              markers['right']!.right,
              markers['bottom']!.bottom,
            );
            for (final delta in [
              actual.left - expected.left,
              actual.top - expected.top,
              actual.right - expected.right,
              actual.bottom - expected.bottom,
            ]) {
              if (delta.abs() > 1.5) {
                failures.add(
                  '$label slot=$slot source=$source viewport=${boundary.size} actual=$actual expected=$expected',
                );
                break;
              }
            }
          }
        }
      } finally {
        raster.dispose();
      }
    });
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    var done = false;
    final closing = work.dispose().whenComplete(() => done = true);
    while (!done) {
      await tester.pump();
      await tester.runAsync(() => pumpEventQueue());
    }
    await closing;
    navigation.dispose();
    favorites.dispose();
    directory.deleteSync(recursive: true);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}
