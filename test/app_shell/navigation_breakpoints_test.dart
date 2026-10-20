import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/navigation_bar.dart';

void main() {
  Future<NaviPaneState> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final observer = NaviObserver();
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
              icon: Icons.star_outline,
              activeIcon: Icons.star,
            ),
          ],
          paneActions: const [],
          pageBuilder: (page) => const Scaffold(body: SizedBox.expand()),
          observer: observer,
          navigatorKey: GlobalKey<NavigatorState>(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<NaviPaneState>(find.byType(NaviPane));
  }

  testWidgets('600px keeps the compact top and bottom navigation', (
    tester,
  ) async {
    final state = await pumpAt(tester, 600);

    expect(state.controller.value, 0);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('1000px switches to the side rail', (tester) async {
    final state = await pumpAt(tester, 1000);

    expect(state.controller.value, 2);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('1400px keeps the side rail', (tester) async {
    final state = await pumpAt(tester, 1400);

    expect(state.controller.value, 3);
    expect(find.text('Home'), findsNothing);
  });
}
