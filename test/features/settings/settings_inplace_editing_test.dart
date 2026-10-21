import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/features/settings/setting_components.dart';
import 'package:venera_next/features/settings/settings_page.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/routing/app_navigation.dart';

Future<void> _open(
  WidgetTester tester,
  double width, {
  int category = 5,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: appNavigation.rootNavigatorKey,
      home: SettingsPage(initialPage: category),
    ),
  );
  await tester.pumpAndSettle();
  if (width < 720) {
    await tester.tap(find.text(category == 5 ? 'Network' : 'Explore'));
    await tester.pumpAndSettle();
  }
}

Future<void> _enter(WidgetTester tester, String title) async {
  final entry = find.widgetWithText(PopupWindowSetting, title);
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Finder get _editor => find.byType(PopUpWidgetScaffold);
SettingsSaveState _owner(WidgetTester tester) =>
    tester.element(_editor).findAncestorStateOfType<SettingsSaveState>()!;

void main() {
  setUp(() {
    final proxy = appdata.settings['proxy'];
    appdata.settings['proxy'] = 'direct';
    final muted = Log.isMuted;
    Log.isMuted = true;
    addTearDown(() {
      appdata.settings['proxy'] = proxy;
      Log.isMuted = muted;
    });
  });

  for (final width in [720.0, 1280.0]) {
    for (final entry in [
      ('Proxy', 5),
      ('DNS Overrides', 5),
      ('Explore Pages', 0),
      ('Category Pages', 0),
      ('Network Favorite Pages', 0),
      ('Search Sources', 0),
      ('Keyword blocking', 0),
      ('Comment keyword blocking', 0),
    ]) {
      testWidgets('${entry.$1} uses the right pane at $width', (tester) async {
        await _open(tester, width, category: entry.$2);
        await _enter(tester, entry.$1);
        expect(_editor, findsOneWidget);
        expect(PopupIndicatorWidget.maybeOf(tester.element(_editor)), isNull);
        expect(tester.getTopLeft(_editor).dx, greaterThanOrEqualTo(280));
        expect(appNavigation.rootNavigatorKey.currentState!.canPop(), isFalse);
        final sidebar = find.text('Settings');
        expect(sidebar, findsOneWidget);
        await tester.tap(
          find.descendant(of: _editor, matching: find.byTooltip('Back')),
        );
        await tester.pumpAndSettle();
        expect(_editor, findsNothing);
        expect(find.byType(PopupWindowSetting), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [600.0, 719.0, 720.0, 1280.0]) {
    testWidgets('proxy validation and back match at $width', (tester) async {
      await _open(tester, width);
      await _enter(tester, 'Proxy');
      final indicator = PopupIndicatorWidget.maybeOf(tester.element(_editor));
      expect(indicator != null, width < 720);
      final navigator = Navigator.of(tester.element(_editor));
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Host'),
        'localhost',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Port'),
        'invalid',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Port must be a number'), findsOneWidget);
      expect(_editor, findsOneWidget);
      await tester.tap(
        find.descendant(of: _editor, matching: find.byTooltip('Back')),
      );
      await tester.pumpAndSettle();
      expect(_editor, findsNothing);
      if (width >= 720) expect(navigator.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching categories discards the inline editor', (
    tester,
  ) async {
    await _open(tester, 1280);
    await _enter(tester, 'Proxy');
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(_editor, findsNothing);
    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PopupWindowSetting, 'Proxy'), findsOneWidget);
    expect(_editor, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline feedback retries without moving the form', (
    tester,
  ) async {
    await _open(tester, 1280);
    await _enter(tester, 'Proxy');
    final owner = _owner(tester);
    final body = find.text('Direct');
    final position = tester.getTopLeft(body);
    final pending = Completer<void>();
    final retry = Completer<void>();
    var attempts = 0;
    final saving = owner.saveSetting(
      'test',
      () => ++attempts == 1 ? pending.future : retry.future,
    );
    await tester.pump();
    expect(tester.getTopLeft(body), position);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('test failure'));
    await tester.pump();
    expect(await saving, isFalse);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.getTopLeft(body), position);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    retry.complete();
    await tester.pump();
    await owner.waitForSettingsSave();
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.getTopLeft(body), position);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline back waits for accepted saves', (tester) async {
    await _open(tester, 1280);
    await _enter(tester, 'Proxy');
    final owner = _owner(tester);
    final pending = Completer<void>();
    final saving = owner.saveSetting('test', () => pending.future);
    await tester.pump();
    // Feedback floats over the center; the existing header back remains usable.
    await tester.tap(
      find.descendant(of: _editor, matching: find.byTooltip('Back')),
    );
    await tester.pump();
    expect(_editor, findsOneWidget);
    pending.complete();
    await tester.pump();
    expect(await saving, isTrue);
    await tester.pumpAndSettle();
    expect(_editor, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
