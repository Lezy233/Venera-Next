import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/log.dart';

class _Page extends StatefulWidget {
  const _Page({super.key});

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends SettingsSaveState<_Page> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => withSettingsSaveFeedback(
    protectSettings(
      Column(
        children: [
          const Text('Body', key: ValueKey('body')),
          const Spacer(),
          TextButton(
            onPressed: () => taps++,
            child: const Text('Other control'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  for (final width in [375.0, 1280.0]) {
    testWidgets('failure and retry float without moving body at width $width', (
      tester,
    ) async {
      final muted = Log.isMuted;
      Log.isMuted = true;
      addTearDown(() => Log.isMuted = muted);
      registerShowMessageHandler((_, _) {});
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<_PageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _Page(key: key)),
        ),
      );
      final body = find.byKey(const ValueKey('body'));
      final position = tester.getTopLeft(body);
      final size = tester.getSize(body);
      final first = Completer<void>();
      final retry = Completer<void>();
      var attempts = 0;
      final saving = key.currentState!.saveSetting(
        'field',
        () => ++attempts == 1 ? first.future : retry.future,
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getTopLeft(body), position);
      // The floating feedback must not absorb input elsewhere on the page;
      // protectSettings retains its existing admission behavior while saving.
      await tester.tap(find.text('Other control'));
      expect(key.currentState!.taps, 1);
      first.completeError(StateError('save failed'));
      await tester.pump();
      expect(await saving, isFalse);
      expect(key.currentState!.hasSettingsSaveError, isTrue);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(tester.getTopLeft(body), position);
      expect(tester.getSize(body), size);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(attempts, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      retry.complete();
      await tester.pump();
      await key.currentState!.waitForSettingsSave();
      expect(key.currentState!.hasSettingsSaveError, isFalse);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Saved'), findsOneWidget);
      expect(tester.getTopLeft(body), position);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Saved'), findsNothing);
      expect(tester.getTopLeft(body), position);
      expect(tester.getSize(body), size);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
