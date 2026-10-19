import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/thumbnails.dart';

void main() {
  testWidgets('thumbnail sidebar lists pages and reports selection', (
    tester,
  ) async {
    var selectedPage = 0;
    final request = ReaderThumbnailRequest(
      pages: const [
        ReaderThumbnailPage(1, ['file:///missing/a.png'], 1),
        ReaderThumbnailPage(2, ['file:///missing/b.png'], 2),
        ReaderThumbnailPage(3, ['file:///missing/c.png'], 3),
      ],
      currentPage: () => 2,
      isCurrent: () => true,
      select: (page) {
        selectedPage = page;
        return true;
      },
      sourceKey: null,
      comicId: 'comic',
      chapterId: 'chapter',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 600,
            child: ReaderThumbnailsView(
              request: request,
              vertical: true,
              reverse: false,
              size: 240,
              onSelect: (page) => request.select(page),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    tester
        .widget<ReaderThumbnailsView>(find.byType(ReaderThumbnailsView))
        .onSelect(3);
    expect(selectedPage, 3);
  });

  testWidgets('horizontal thumbnail strip fills the given height', (
    tester,
  ) async {
    final request = ReaderThumbnailRequest(
      pages: const [
        ReaderThumbnailPage(1, ['file:///missing/a.png'], 1),
        ReaderThumbnailPage(2, ['file:///missing/b.png'], 2),
      ],
      currentPage: () => 1,
      isCurrent: () => true,
      select: (_) => true,
      sourceKey: null,
      comicId: 'comic',
      chapterId: 'chapter',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 600,
              height: 140,
              child: ReaderThumbnailsView(
                request: request,
                vertical: false,
                reverse: true,
                size: 140,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsOneWidget);
    expect(tester.getSize(find.byType(ReaderThumbnailsView)).width, 600);
  });
}
