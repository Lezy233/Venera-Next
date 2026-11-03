import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/settings/reader_presets.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/quick_settings_panel.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/settings_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppdataImportCheckpoint before;
  const store = ReaderPresetStore();

  setUp(() async {
    root = Directory.systemTemp.createTempSync('f9-ui-');
    App.dataPath = App.cachePath = root.path;
    before = appdata.captureImportCheckpoint();
    appdata.settings['readerPresetBindings'] = {};
    appdata.settings['readerPresetSelections'] = {};
    appdata.settings['readerModePresets'] = [
      for (final id in ['A', 'B', 'C'])
        {
          'id': id,
          'name': id,
          'values': {'readerMode': 'galleryRightToLeft', 'readerSideMargin': 9},
          'modeBehavior': id == 'B' ? 'inherit' : 'fixed',
        },
    ];
    appdata.settings['disableSyncFields'] = 'proxy';
    await appdata.saveData(false);
  });
  tearDown(() async {
    await appdata.restoreImportCheckpoint(before, persist: false);
    root.deleteSync(recursive: true);
  });

  test('keyed recovery restores owned order despite concurrent CRUD', () {
    Map state(List<String> ids) => {
      'readerModePresets': [
        for (final id in ids) {'id': id, 'name': id},
      ],
    };
    final current = state(['C', 'A', 'D']);
    (current['readerModePresets'] as List).first['name'] = 'Renamed';
    final restored = restoreOwnedSettings(
      state(['A', 'B', 'C']),
      state(['C', 'A', 'B']),
      current,
    );
    expect((restored['readerModePresets'] as List).map((p) => p['id']), [
      'A',
      'C',
      'D',
    ]);
    expect((restored['readerModePresets'] as List)[1]['name'], 'Renamed');
  });

  testWidgets(
    'production management has isolated mouse drag and click alternatives',
    (tester) async {
      var applications = 0;
      final original =
          jsonDecode(jsonEncode(appdata.toJson()['settings'])) as Map;
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPresetManagement(
            store: store,
            onApplied: (_, _) => applications++,
          ),
        ),
      );
      expect(find.byType(ReorderableListView), findsOneWidget);
      final handle = find.byKey(const ValueKey('preset-drag-C'));
      expect(handle, findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('preset-drag-A'))),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await drain(tester);
      expect(store.list.map((p) => p.id), ['C', 'A', 'B']);
      final down = find.byKey(const ValueKey('preset-down-C'));
      expect(tester.widget<IconButton>(down).onPressed, isNotNull);
      await tester.tap(down, kind: PointerDeviceKind.mouse);
      await drain(tester);
      expect(store.list.map((p) => p.id), ['A', 'C', 'B']);
      final forward = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('preset-drag-A'))),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await forward.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 100));
      await forward.moveTo(
        tester.getCenter(find.byKey(const ValueKey('preset-drag-B'))) +
            const Offset(0, 140),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await forward.up();
      await drain(tester);
      expect(store.list.map((p) => p.id), ['C', 'B', 'A']);
      expect(applications, 0);
      final after = jsonDecode(jsonEncode(appdata.toJson()['settings'])) as Map;
      final library = after.remove('readerModePresets') as List;
      expect(after, Map.of(original)..remove('readerModePresets'));
      expect(
        {for (final p in library) p['id']: p},
        {for (final p in original['readerModePresets'] as List) p['id']: p},
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('preset-up-C')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('preset-down-A')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'drag keeps admitted identities when library changes before drop',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPresetManagement(
            store: store,
            onApplied: (_, _) => fail('must not apply'),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('preset-drag-C'))),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump(const Duration(milliseconds: 100));
      appdata.settings['readerModePresets'] = [
        {
          'id': 'X',
          'name': 'Concurrent new',
          'values': {'readerSideMargin': 7},
        },
        for (final p in store.list)
          {...p.toJson(), if (p.id == 'C') 'name': 'Renamed C'},
      ];
      await tester.pump();
      await gesture.moveTo(const Offset(40, 150));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await drain(tester);
      expect(store.list.map((p) => p.id), ['X', 'C', 'A', 'B']);
      expect(store.list[1].name, 'Renamed C');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'incomplete order recovery survives management reentry, disables writes and retries without replay',
    (tester) async {
      Widget page() => MaterialApp(
        home: ReaderPresetManagement(
          store: store,
          onApplied: (_, _) => fail('sorting must not apply'),
        ),
      );
      await tester.pumpWidget(page());
      final obstacle = Directory('${root.path}/syncdata.json.tmp')
        ..createSync();
      await tester.tap(
        find.byKey(const ValueKey('preset-up-C')),
        kind: PointerDeviceKind.mouse,
      );
      await drain(tester);
      expect(store.orderRecovery, isNotNull);
      expect(store.list.map((p) => p.id), ['A', 'B', 'C']);
      expect(find.text('Saved'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      expect(find.text('Save failed; recovery incomplete'), findsOneWidget);
      for (final button in tester.widgetList<IconButton>(
        find.byType(IconButton),
      )) {
        // Appbar back is independent of the library write controls.
        if (button.key is ValueKey<String> &&
            (button.key as ValueKey<String>).value.startsWith('preset-')) {
          expect(button.onPressed, isNull);
        }
      }
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'New preset'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widgetList<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .every((p) => !p.enabled),
        true,
      );
      obstacle.deleteSync();
      await tester.tap(find.text('Retry recovery'));
      await drain(tester);
      expect(store.orderRecovery, isNull);
      expect(store.list.map((p) => p.id), ['A', 'B', 'C']);
      expect(find.text('Saved'), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('preset-up-C')))
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [390.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Tab Enter Space retain same ID focus at width $width $brightness scale 1.6',
        (tester) async {
          tester.view.physicalSize = Size(width, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          appdata.settings['readerModePresets'] = [
            for (final p in store.list)
              {
                ...p.toJson(),
                if (p.id == 'B') 'name': 'A long recognizable preset name',
              },
          ];
          var applied = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: ReaderPresetManagement(
                store: store,
                onApplied: (_, _) => applied++,
              ),
            ),
          );
          await tabTo(tester, 'preset-up-B');
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await drain(tester);
          expect(store.list.map((p) => p.id), ['B', 'A', 'C']);
          expect(
            tester
                .widget<Focus>(find.byKey(const ValueKey('B')))
                .focusNode!
                .hasFocus,
            true,
          );
          await tabTo(tester, 'preset-down-B');
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await drain(tester);
          expect(store.list.map((p) => p.id), ['A', 'B', 'C']);
          expect(
            tester
                .widget<Focus>(find.byKey(const ValueKey('B')))
                .focusNode!
                .hasFocus,
            true,
          );
          expect(applied, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'global device comic and production quick panel show persisted library order and retain B or None',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const targets = [
        store,
        ReaderPresetStore(scope: ReaderPreferenceScope.device),
        ReaderPresetStore(
          scope: ReaderPreferenceScope.comic,
          comicId: 'book',
          sourceKey: 'local',
        ),
      ];
      await tester.runAsync(() async {
        for (final target in targets) {
          await target.apply('B', target.scope);
        }
        await store.move('C', 'A', before: true);
        await appdata.loadDataForTesting(root.path);
      });
      final preview = ReaderBrightnessPreview();
      addTearDown(preview.dispose);
      var effects = 0;
      for (final target in targets) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderPresetSelector(
                key: ValueKey(target.scope),
                store: target,
                onChanged: (_) => effects++,
              ),
            ),
          ),
        );
        final dropdown = find.byType(DropdownButtonFormField<String>);
        expect(
          tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
          'B',
        );
        expect(
          tester
              .widget<DropdownButton<String>>(
                find.descendant(
                  of: dropdown,
                  matching: find.byType(DropdownButton<String>),
                ),
              )
              .items!
              .map((i) => i.value),
          ['', 'C', 'A', 'B'],
        );
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('C').last).dy,
          lessThan(tester.getTopLeft(find.text('A').last).dy),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderQuickSettingsPanel(
              comicId: 'book',
              sourceKey: 'local',
              brightnessPreview: preview,
              isCurrent: () => true,
              onChanged: (_) => effects++,
              onAllSettings: () async {},
            ),
          ),
        ),
      );
      final dropdown = find.descendant(
        of: find.byType(ReaderPresetSelector),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      expect(
        tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
        'B',
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.descendant(
                of: dropdown,
                matching: find.byType(DropdownButton<String>),
              ),
            )
            .items!
            .map((i) => i.value),
        ['', 'C', 'A', 'B'],
      );
      expect(targets.last.selectedId, 'B');
      expect(effects, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => targets.last.clearSelection());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderPresetSelector(
              store: targets.last,
              onChanged: (_) => effects++,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        '',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> tabTo(WidgetTester tester, String key) async {
  for (var i = 0; i < 40; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final button = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<IconButton>();
    if (button?.key == ValueKey(key)) return;
  }
  fail('Tab did not reach $key');
}

Future<void> drain(WidgetTester tester) async {
  await tester.pumpAndSettle();
  var done = false;
  appdata.runPersistenceMaintenance((_) async {}).then((_) => done = true);
  for (var i = 0; i < 500 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done, true, reason: 'writer must finish within bounded drain');
  await tester.pumpAndSettle();
}
