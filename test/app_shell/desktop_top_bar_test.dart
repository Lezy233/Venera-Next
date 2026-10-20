import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/app_shell/desktop_top_bar.dart';

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
          // The custom title bar lives outside MaterialApp's Overlay: this
          // reproduces that placement so Tooltip usage would fail here.
          builder: (context, child) => Column(
            children: [
              const SizedBox(height: 36, child: DesktopLayoutControls()),
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

  testWidgets('search box accepts text and reports the query', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chrome = DesktopChromeController();
    addTearDown(chrome.dispose);
    final queries = <String>[];
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
  });
}
