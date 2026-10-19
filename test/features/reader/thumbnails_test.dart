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
          body: ReaderThumbnailsView(
            request: request,
            onSelect: (page) => request.select(page),
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Thumbnails'), findsOneWidget);
    await tester.tap(find.text('3'));
    expect(selectedPage, 3);
  });
}
