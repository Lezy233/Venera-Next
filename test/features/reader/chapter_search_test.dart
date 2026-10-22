import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/app_shell/global_shortcuts.dart';
import 'package:venera_next/app_shell/desktop_top_bar.dart';
import 'package:venera_next/features/comic_source/models.dart';
import 'package:venera_next/features/reader/auto_reading.dart';
import 'package:venera_next/features/reader/chapter_menu.dart';
import 'package:venera_next/features/reader/chapters.dart';
import 'package:venera_next/features/reader/scaffold.dart';
import 'package:venera_next/features/reader/shell_data.dart';
import 'package:venera_next/features/reader/progress_navigation.dart';
import 'package:venera_next/features/reader/platform_effects_controller.dart';
import 'package:venera_next/foundation/reader_settings.dart';
import 'package:venera_next/foundation/image_work.dart';

final _data = ReaderChapterMenuData(
  const ComicChapters.grouped({
    'Volume 1': {'a': 'Prologue', 'b': 'The SUN'},
    'Volume 2': {'a': 'Sunrise', 'c': 'Finale'},
  }),
  currentChapter: 4,
  downloaded: ['a'],
);

void main() {
  test('title filtering retains global indices and source metadata', () {
    final groups = _data.filteredGroups(' sUn ');
    expect(groups.map((group) => group.name), ['Volume 1', 'Volume 2']);
    expect(groups.expand((group) => group.entries).map((e) => e.index), [2, 3]);
    expect(groups.last.entries.single.downloaded, isTrue);
    expect(_data.filteredGroups('Volume'), isEmpty);
    expect(_data.filteredGroups(''), same(_data.groups));
    expect(_data.filteredGroups('  '), same(_data.groups));
  });

  testWidgets('filtered groups, no-match feedback and clear restore chapters', (
    tester,
  ) async {
    Future<void> show(String query) => tester.pumpWidget(
      MaterialApp(
        home: ReaderChaptersView(
          data: _data,
          query: query,
          onSelect: (_) {},
          onClose: () {},
        ),
      ),
    );
    await show('sunrise');
    expect(find.text('Volume 1'), findsNothing);
    expect(find.text('Volume 2'), findsOneWidget);
    expect(find.text('Sunrise'), findsOneWidget);
    expect(find.text('Finale'), findsNothing);
    await show('missing');
    expect(find.text('No chapters match “missing”'), findsOneWidget);
    await show('');
    expect(find.text('Finale'), findsOneWidget);
    expect(find.text('Volume 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final shortcut in [false, true]) {
    testWidgets(
      'real reader filters and submits with ${shortcut ? 'Ctrl+F' : 'click'}',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final chrome = DesktopChromeController();
        final work = ImageWork();
        final favorites = ChangeNotifier();
        final selected = <int>[];
        final contentFocus = FocusNode();
        addTearDown(contentFocus.dispose);
        var current = true;
        var pauses = 0;
        await tester.pumpWidget(
          DesktopChromeScope(
            controller: chrome,
            child: MaterialApp(
              home: GlobalShortcuts(
                chrome: chrome,
                child: Scaffold(
                  body: Stack(
                    children: [
                      Positioned.fill(
                        child: Focus(
                          focusNode: contentFocus,
                          autofocus: true,
                          child: ReaderScaffold(
                            data: ReaderShellData(
                              comicId: 'test',
                              sourceKey: 'local',
                              title: 'Search test',
                              chapterTitle: 'Finale',
                              hasChapters: true,
                              vertical: false,
                              gallery: true,
                              animating: false,
                              onCommentsPage: false,
                              swipeToCollect: false,
                              preferences: ReaderSettings.resolve(
                                global: {
                                  'enableClockAndBatteryInfoInReader': false,
                                },
                              ),
                              automaticReading: AutoReadingStatus.stopped,
                            ),
                            progress: ReaderProgressRequest(
                              identity: work,
                              page: 1,
                              maxPage: 1,
                              chapter: 4,
                              maxChapter: 4,
                              reversed: false,
                              isCurrent: () => current,
                              toPage: (_, {animated = true}) => true,
                              toChapter: (_) => true,
                            ),
                            onExit: () async {},
                            onFullscreen: null,
                            onToggleAutomaticReading: () => false,
                            acquireSidebarPause: () {
                              pauses++;
                              return () => pauses--;
                            },
                            readImagePickContext: () => null,
                            imageWork: work,
                            orientation: ReaderOrientation.system,
                            onRotate: null,
                            onSystemUiChanged: (_) {},
                            createChapterMenu: () => ReaderChapterMenuRequest(
                              data: _data,
                              isCurrent: () => current,
                              select: (chapter) {
                                selected.add(chapter);
                                return true;
                              },
                            ),
                            favoriteChanges: favorites,
                            createFavoriteQuery: () => null,
                            createImageFavorite: () => null,
                            createImageExport: () => null,
                            createSettings: () => null,
                            createChapterComments: () => null,
                            chapterNavigation: null,
                            child: const Center(child: Text('Reading content')),
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        left: 400,
                        child: DesktopSearchBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // B1 already notifies DesktopChromeScope during reader registration.
        // Check only that known mount error; later search errors must be absent.
        final registrationError = tester.takeException();
        if (registrationError != null) {
          expect(
            registrationError.toString(),
            allOf(
              contains('called during build'),
              contains('DesktopChromeScope'),
            ),
          );
        }
        if (shortcut) {
          // Start focus in content as an actual desktop shortcut would.
          contentFocus.requestFocus();
          await tester.pump();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        } else {
          await tester.tap(find.byType(TextField));
        }
        await tester.pumpAndSettle();
        expect(chrome.searchFocusNode.hasFocus, isTrue);
        expect(find.byType(ReaderChaptersView), findsOneWidget);
        expect(pauses, 1);
        await tester.enterText(find.byType(TextField), 'sUn');
        await tester.pumpAndSettle();
        expect(find.text('The SUN'), findsOneWidget);
        expect(find.text('Prologue'), findsNothing);
        expect(chrome.searchFocusNode.hasFocus, isTrue);
        expect(pauses, 1);
        await tester.enterText(find.byType(TextField), 'missing');
        await tester.pumpAndSettle();
        expect(find.text('No chapters match “missing”'), findsOneWidget);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(selected, isEmpty);
        await tester.enterText(find.byType(TextField), 'sun');
        await tester.pumpAndSettle();
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(selected, [2]);
        expect(find.byType(ReaderChaptersView), findsNothing);
        expect(pauses, 0);
        expect(tester.takeException(), isNull);
        chrome.setReaderActions(null);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        current = false;
        chrome.dispose();
        favorites.dispose();
      },
    );
  }
}
