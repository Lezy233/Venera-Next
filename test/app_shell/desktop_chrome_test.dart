import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';

void main() {
  test('search shortcut prefers reader, then favorites, then global', () {
    final chrome = DesktopChromeController();
    var global = 0;
    var reader = 0;
    final queries = <String>[];
    chrome.bindGlobalActions(
      openSettings: () {},
      openSearch: () => global++,
      navigate: (_) {},
      back: () {},
    );

    chrome.setFavoritesActive(true);
    chrome.setFavoritesSearchQuery(queries.add);
    chrome.submitSearch('favorites');
    expect(queries, ['favorites']);
    expect(global, 0);

    final readerQueries = <String>[];
    final submitted = <String>[];
    chrome.setReaderActions(
      DesktopReaderActions(
        filterChapters: readerQueries.add,
        submitChapterSearch: submitted.add,
        openSettings: () {},
        openChapters: () => reader++,
        toggleThumbnails: () {},
      ),
    );
    chrome.openSearchAction();
    expect(reader, 1);
    chrome.updateSearchQuery('reader');
    chrome.submitSearch('reader');
    expect(readerQueries.last, 'reader');
    expect(submitted, ['reader']);
    expect(queries, ['favorites']);

    chrome.setReaderActions(null);
    chrome.setFavoritesActive(false);
    chrome.updateSearchQuery('global');
    chrome.submitSearch('global');
    expect(queries, ['favorites']);
    expect(global, 1);
    chrome.setReaderActions(null);
  });

  test('settings shortcut prefers reader settings', () {
    final chrome = DesktopChromeController();
    var global = 0;
    var reader = 0;
    chrome.bindGlobalActions(
      openSettings: () => global++,
      openSearch: () {},
      navigate: (_) {},
      back: () {},
    );
    chrome.setReaderActions(
      DesktopReaderActions(
        openSettings: () => reader++,
        openChapters: () {},
        toggleThumbnails: () {},
      ),
    );
    chrome.openSettingsAction();
    expect(reader, 1);
    expect(global, 0);
    chrome.setReaderActions(null);
    chrome.openSettingsAction();
    expect(global, 1);
  });

  test('sidebar toggles call the registered callbacks only', () {
    final chrome = DesktopChromeController();
    var left = 0;
    var right = 0;
    chrome.toggleLeftSidebar();
    chrome.toggleRightSidebar();
    expect(left + right, 0);

    chrome.setLeftSidebar(
      available: true,
      expanded: true,
      toggle: () => left++,
    );
    chrome.setRightSidebar(
      available: true,
      expanded: false,
      toggle: () => right++,
    );
    chrome.toggleLeftSidebar();
    chrome.toggleRightSidebar();
    expect(left, 1);
    expect(right, 1);
  });
}
