import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/components/navigation_bar.dart';

void main() {
  const favoritesTab = 1;

  Future<(NaviPaneState, GlobalKey<NavigatorState>)> pumpShell(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: NaviPane(
          paneItems: [
            PaneItemEntry(
              label: 'Home',
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
            ),
            PaneItemEntry(
              label: 'Favorites',
              icon: Icons.local_activity_outlined,
              activeIcon: Icons.local_activity,
            ),
            PaneItemEntry(
              label: 'Explore',
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore,
            ),
            PaneItemEntry(
              label: 'Categories',
              icon: Icons.category_outlined,
              activeIcon: Icons.category,
            ),
          ],
          paneActions: const [],
          initialPage: favoritesTab,
          observer: NaviObserver(),
          navigatorKey: navigatorKey,
          pageBuilder: (index) => Center(child: Text('page $index')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (tester.state<NaviPaneState>(find.byType(NaviPane)), navigatorKey);
  }

  void expectChrome(DesktopChromeController chrome, Matcher active) {
    expect(chrome.favoritesActive, active);
  }

  testWidgets('favorites tab is a shell context only at its root', (
    tester,
  ) async {
    final (navi, navigatorKey) = await pumpShell(tester);
    final chrome = DesktopChromeController();
    addTearDown(chrome.dispose);

    void sync() => chrome.setFavoritesActive(navi.isTabRoot(favoritesTab));

    sync();
    expectChrome(chrome, isTrue);
    expect(navi.isTabRoot(0), isFalse);

    for (final index in [0, 2, 3]) {
      navi.updatePage(index);
      await tester.pumpAndSettle();
      sync();
      expectChrome(chrome, isFalse);
    }

    navi.updatePage(favoritesTab);
    await tester.pumpAndSettle();
    sync();
    expectChrome(chrome, isTrue);

    // A detail page pushed from favorites is a different shell context even
    // though the favorites tab stays mounted underneath.
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('comic detail')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    sync();
    expectChrome(chrome, isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    sync();
    expectChrome(chrome, isTrue);
  });
}
