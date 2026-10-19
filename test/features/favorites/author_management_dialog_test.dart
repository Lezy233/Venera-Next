import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/favorites/author_management_dialog.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/foundation/comic_type.dart';

FavoriteItem _item(String id, String author) => FavoriteItem(
  id: id,
  name: 'name $id',
  coverPath: '',
  author: author,
  type: const ComicType(17),
  tags: const [],
);

void main() {
  testWidgets('manage authors dialog opens and stays interactive', (
    tester,
  ) async {
    final comics = [
      _item('a', 'Alpha'),
      _item('b', 'Beta'),
      _item('c', 'Gamma'),
    ];
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFavoriteAuthorManagementDialog(
                context: context,
                comics: comics,
                aliases: const {},
                isCurrent: () => true,
                onChanged: (_) => changes++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Manage authors'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    // Dismissing must remove the barrier so the page is interactive again.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Manage authors'), findsNothing);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Manage authors'), findsOneWidget);
    expect(changes, 0);
  });
}
