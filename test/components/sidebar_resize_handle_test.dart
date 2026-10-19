import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/sidebar_resize_handle.dart';

Widget _host({
  required bool expanded,
  required VoidCallback onToggle,
  required ValueChanged<double> onDrag,
  required VoidCallback onDragEnd,
  bool enabled = true,
  bool mirror = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Row(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            width: 200,
            height: double.infinity,
            child: SidebarResizeHandle(
              expanded: expanded,
              enabled: enabled,
              mirror: mirror,
              onToggle: onToggle,
              onDrag: onDrag,
              onDragEnd: onDragEnd,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  double opacityOf(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('hover reveals the handle and tap toggles the sidebar', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      _host(
        expanded: true,
        onToggle: () => toggles++,
        onDrag: (_) {},
        onDragEnd: () {},
      ),
    );
    expect(opacityOf(tester), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(SidebarResizeHandle)));
    await tester.pump();

    expect(opacityOf(tester), 1);
    await tester.tap(find.byType(SidebarResizeHandle));
    expect(toggles, 1);
  });

  testWidgets('dragging reports horizontal deltas and finishes once', (
    tester,
  ) async {
    var total = 0.0;
    var ended = 0;
    await tester.pumpWidget(
      _host(
        expanded: false,
        onToggle: () {},
        onDrag: (delta) => total += delta,
        onDragEnd: () => ended++,
      ),
    );

    await tester.drag(find.byType(SidebarResizeHandle), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(total, greaterThan(0));
    expect(ended, 1);
  });

  testWidgets('disabled handle stays hidden and ignores pointers', (
    tester,
  ) async {
    var toggles = 0;
    var ended = 0;
    await tester.pumpWidget(
      _host(
        expanded: true,
        enabled: false,
        onToggle: () => toggles++,
        onDrag: (_) {},
        onDragEnd: () => ended++,
      ),
    );

    await tester.tap(find.byType(SidebarResizeHandle), warnIfMissed: false);
    await tester.drag(find.byType(SidebarResizeHandle), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(toggles, 0);
    expect(ended, 0);
    expect(opacityOf(tester), 0);
  });

  testWidgets('mirrored handle points towards its trailing edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        expanded: true,
        mirror: true,
        onToggle: () {},
        onDrag: (_) {},
        onDragEnd: () {},
      ),
    );
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);

    await tester.pumpWidget(
      _host(
        expanded: false,
        mirror: true,
        onToggle: () {},
        onDrag: (_) {},
        onDragEnd: () {},
      ),
    );
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });
}
