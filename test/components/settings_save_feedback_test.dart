import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/design_system/breakpoints.dart';
import 'package:venera_next/design_system/tokens.dart';
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
    for (final inset in [0.0, 24.0, AppSizes.titleBarHeight]) {
      for (final consumed in [false, true]) {
        testWidgets(
          'feedback paint clears shell: width=$width inset=$inset consumed=$consumed',
          (tester) async {
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
                home: Scaffold(
                  body: Stack(
                    children: [
                      Positioned.fill(
                        top: consumed ? inset : 0,
                        // Model both an unconsumed WindowFrame inset and a nested
                        // editor whose parent has already consumed that inset.
                        child: MediaQuery(
                          data: MediaQueryData(
                            size: Size(width, 800),
                            padding: EdgeInsets.only(top: consumed ? 0 : inset),
                          ),
                          child: Row(
                            children: [
                              if (!Breakpoints.classify(width).isCompact)
                                const SizedBox(
                                  width: AppSizes.settingsSidebarWidth,
                                ),
                              Expanded(child: _Page(key: key)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: inset,
                        child: const ColoredBox(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            );
            final body = find.byKey(const ValueKey('body'));
            final initialBody = tester.getRect(body);
            void expectVisible() {
              final feedback = find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.liveRegion == true,
              );
              final box = tester.renderObject<RenderBox>(feedback);
              final painted = MatrixUtils.transformRect(
                box.getTransformTo(null),
                box.paintBounds,
              );
              final band = Rect.fromLTWH(0, 0, width, inset);
              expect(
                painted.overlaps(band),
                isFalse,
                reason: 'paint=$painted shell=$band',
              );
              expect(painted.top, inset);
              expect(painted.bottom, lessThanOrEqualTo(800));
              expect(
                painted.left,
                greaterThanOrEqualTo(
                  Breakpoints.classify(width).isCompact
                      ? 0
                      : AppSizes.settingsSidebarWidth,
                ),
              );
              expect(painted.right, lessThanOrEqualTo(width));
              expect(tester.getRect(body), initialBody);
            }

            final blocked = Completer<void>();
            final retry = Completer<void>();
            var attempts = 0;
            final saving = key.currentState!.saveSetting(
              'field',
              () => ++attempts == 1 ? blocked.future : retry.future,
            );
            await tester.pump();
            expectVisible();
            blocked.completeError(StateError('save failed'));
            await tester.pump();
            expect(await saving, isFalse);
            expect(find.text('Retry'), findsOneWidget);
            expectVisible();
            // A real tap verifies the retry is reachable below the shell.
            await tester.tap(find.text('Retry'));
            await tester.pump();
            expect(attempts, 2);
            expectVisible();
            retry.complete();
            await tester.pump();
            await key.currentState!.waitForSettingsSave();
            expect(find.text('Saved'), findsOneWidget);
            expectVisible();
            await tester.pump(const Duration(seconds: 2));
            expect(find.text('Saved'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
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
