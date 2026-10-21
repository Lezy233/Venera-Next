import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/settings/settings.dart';

void main() {
  testWidgets('settings keeps statistics and debug out of the main list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('Reading statistics'), findsNothing);
    expect(find.text('Debug'), findsNothing);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings stays single column at 600', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('Reading statistics'), findsNothing);
    expect(find.text('Debug'), findsNothing);
    expect(find.text('Display mode of comic tile'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[1000, 1400]) {
    testWidgets('settings lands on the first category at ${width.toInt()}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pump();

      expect(find.text('Reading statistics'), findsNothing);
      expect(find.text('Debug'), findsNothing);
      expect(find.text('Display mode of comic tile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
