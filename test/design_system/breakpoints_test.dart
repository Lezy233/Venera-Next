import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/design_system/breakpoints.dart';

void main() {
  test('classifies the three window size classes at their boundaries', () {
    expect(Breakpoints.classify(0), WindowSizeClass.compact);
    expect(Breakpoints.classify(719.9), WindowSizeClass.compact);
    expect(Breakpoints.classify(720), WindowSizeClass.medium);
    expect(Breakpoints.classify(1199.9), WindowSizeClass.medium);
    expect(Breakpoints.classify(1200), WindowSizeClass.expanded);
    expect(Breakpoints.classify(2400), WindowSizeClass.expanded);
  });

  testWidgets('context helpers read the current window width', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late WindowSizeClass sizeClass;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            sizeClass = Breakpoints.of(context);
            expect(Breakpoints.isCompact(context), isFalse);
            expect(Breakpoints.isMedium(context), isTrue);
            expect(Breakpoints.isExpanded(context), isFalse);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(sizeClass, WindowSizeClass.medium);
  });
}
