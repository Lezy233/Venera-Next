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
    expect(find.byIcon(Icons.dashboard_customize_outlined), findsOneWidget);
    expect(find.byIcon(Icons.vertical_split), findsNWidgets(2));
  });
}
