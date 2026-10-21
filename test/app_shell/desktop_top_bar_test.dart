import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/app_shell/desktop_top_bar.dart';
import 'package:venera_next/components/overlay_host.dart';

void main() {
  testWidgets('layout controls render above the app Overlay', (tester) async {
    final chrome = DesktopChromeController()
      ..setFavoritesActive(true)
      ..setLeftSidebar(available: true, expanded: true, toggle: () {})
      ..setRightSidebar(available: true, expanded: false, toggle: () {});
    addTearDown(chrome.dispose);

    await tester.pumpWidget(
      DesktopChromeScope(
        controller: chrome,
        child: MaterialApp(
          // The custom title bar hosts its own Overlay so tooltips can render
          // outside MaterialApp's Navigator overlay.
          builder: (context, child) => Column(
            children: [
              const SizedBox(
                height: 36,
                child: OverlayHost(child: DesktopLayoutControls()),
              ),
              Expanded(child: child!),
            ],
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('sidebar toggles stay visible but disabled without favorites', (
    tester,
  ) async {
    final chrome = DesktopChromeController();
    addTearDown(chrome.dispose);

    await tester.pumpWidget(
      DesktopChromeScope(
        controller: chrome,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 36,
              child: OverlayHost(child: DesktopLayoutControls()),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byTooltip('Only available on Favorites'), findsNWidgets(2));
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons, hasLength(2));
    expect(buttons.every((button) => button.onPressed == null), isTrue);
  });

  testWidgets(
    'registered favorites sidebars stay disabled under a pushed page',
    (tester) async {
      // The favorites page remains mounted below a pushed detail page, so its
      // sidebar registration is still present, but the shell context is not.
      final chrome = DesktopChromeController()
        ..setFavoritesActive(false)
        ..setLeftSidebar(available: true, expanded: true, toggle: () {})
        ..setRightSidebar(available: true, expanded: false, toggle: () {});
      addTearDown(chrome.dispose);

      await tester.pumpWidget(
        DesktopChromeScope(
          controller: chrome,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 36,
                child: OverlayHost(child: DesktopLayoutControls()),
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Only available on Favorites'), findsNWidgets(2));
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
      expect(buttons, hasLength(2));
      expect(buttons.every((button) => button.onPressed == null), isTrue);
    },
  );

  testWidgets('search box accepts text and reports the query', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chrome = DesktopChromeController();
    addTearDown(chrome.dispose);
    final queries = <String>[];
    chrome.setFavoritesActive(true);
    chrome.setFavoritesSearchQuery(queries.add);

    await tester.pumpWidget(
      DesktopChromeScope(
        controller: chrome,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: DesktopSearchBox())),
        ),
      ),
    );
    await tester.pump();
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'hello');
    expect(queries.last, 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(queries.last, 'hello');
    await tester.enterText(field, '');
    expect(queries.last, '');
    expect(
      tester.widget<TextField>(field).decoration!.hintText,
      'Search favorites',
    );
  });

  testWidgets('command center is hidden below the expanded breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chrome = DesktopChromeController();
    addTearDown(chrome.dispose);

    await tester.pumpWidget(
      DesktopChromeScope(
        controller: chrome,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: DesktopSearchBox())),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
  });
}
