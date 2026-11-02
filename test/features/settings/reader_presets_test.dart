import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/quick_settings_panel.dart';
import 'package:venera_next/features/settings/reader.dart';
import 'package:venera_next/features/settings/reader_presets.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';

Future<void> _drain(WidgetTester tester) async {
  var done = false;
  Object? failure;
  appdata
      .saveData(false)
      .then(
        (_) => done = true,
        onError: (Object error) {
          failure = error;
          done = true;
        },
      );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done, true);
  expect(failure, isNull);
  await tester.pumpAndSettle();
}

Finder get _presetDropdown => find.descendant(
  of: find.byType(ReaderPresetSelector),
  matching: find.byType(DropdownButtonFormField<String>),
);

Future<void> _select(WidgetTester tester, String id) async {
  tester.widget<DropdownButtonFormField<String>>(_presetDropdown).onChanged!(
    id,
  );
  await _drain(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  App.dataPath = App.cachePath = Directory.systemTemp.path;
  late Directory root;
  late Map previous;
  late String oldPath;
  setUp(() {
    oldPath = App.dataPath;
    previous = jsonDecode(jsonEncode(appdata.toJson()['settings'])) as Map;
    root = Directory.systemTemp.createTempSync('preset-ui-');
    App.dataPath = root.path;
    appdata.settings.resetGlobalReaderSettings();
    appdata.settings['readerModePresets'] = [];
    appdata.settings['readerPresetSelections'] = {};
    appdata.settings['deviceSpecificSettings'] = <String, dynamic>{};
    appdata.settings['comicSpecificSettings'] = <String, dynamic>{};
    appdata.settings['deviceId'] = 'preset-ui';
    appdata.settings['disableSyncFields'] = '';
  });
  tearDown(() {
    previous.forEach((key, value) => appdata.settings[key] = value);
    App.dataPath = oldPath;
    root.deleteSync(recursive: true);
  });

  testWidgets(
    'B3 applied preset survives selector destruction and JSON reload',
    (tester) async {
      appdata.settings['readerSideMargin'] = 16;
      final preset = await tester.runAsync(
        () => const ReaderPresetStore().createFromCurrent('Double page'),
      );
      appdata.settings['readerSideMargin'] = 0;
      Widget page() => MaterialApp(
        home: Scaffold(
          body: ReaderPresetSelector(
            store: const ReaderPresetStore(),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(page());
      await _select(tester, preset!.id);
      expect(find.text('Saved'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .initialValue,
        preset.id,
      );
      final disk =
          jsonDecode(File('${root.path}/appdata.json').readAsStringSync())
              as Map;
      expect(
        (disk['settings']['readerModePresets'] as List).single['id'],
        preset.id,
      );
      expect(disk['settings']['readerSideMargin'], 16);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .initialValue,
        preset.id,
      );
      await tester.pumpWidget(const SizedBox());
      (disk['settings'] as Map).forEach(
        (key, value) => appdata.settings[key as String] = value,
      );
      await tester.pumpWidget(page());
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .initialValue,
        preset.id,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final scope in ReaderSettingsScope.values) {
    testWidgets(
      'settings preset applies to selected $scope and restores its scoped identity',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        appdata.settings['readerMode'] = 'galleryRightToLeft';
        appdata.settings['readerSideMargin'] = 16;
        final preset = await tester.runAsync(
          () => const ReaderPresetStore().createFromCurrent('Manga'),
        );
        appdata.settings['readerSideMargin'] = 0;
        final changed = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderSettings(
                comicId: 'book',
                comicSource: 'local',
                onChanged: changed.add,
              ),
            ),
          ),
        );
        tester
            .widget<SegmentedButton<ReaderSettingsScope>>(
              find.byType(SegmentedButton<ReaderSettingsScope>),
            )
            .onSelectionChanged!({scope});
        await _drain(tester);
        await _select(tester, preset!.id);
        final target = ReaderPreferenceScope.values.firstWhere(
          (s) =>
              s.name ==
              (scope == ReaderSettingsScope.defaults ? 'global' : scope.name),
        );
        final store = ReaderPreferenceStore(
          settings: appdata.settings,
          scope: target,
          comicId: 'book',
          sourceKey: 'local',
        );
        expect(store.read(ReaderPreferences.readerSideMargin), 16);
        expect(changed, contains('readerMode'));
        tester
            .widget<SegmentedButton<ReaderSettingsScope>>(
              find.byType(SegmentedButton<ReaderSettingsScope>),
            )
            .onSelectionChanged!({ReaderSettingsScope.defaults});
        await _drain(tester);
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(_presetDropdown)
              .initialValue,
          scope == ReaderSettingsScope.defaults ? preset.id : '',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'settings management opens and supports validated create, rename, update, apply and confirmed delete',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ReaderSettings())),
      );
      expect(find.text('Reading mode presets'), findsOneWidget);
      await tester.tap(find.text('Manage presets…'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPresetManagement), findsOneWidget);
      expect(
        find.text(
          'No presets yet. Create one from your current reading settings.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('New preset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await _drain(tester);
      expect(find.text('Enter a preset name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Manga');
      await tester.tap(find.text('Save'));
      await _drain(tester);
      final id = const ReaderPresetStore().list.single.id;
      expect(find.text('Manga'), findsOneWidget);
      Future<void> menu(String label) async {
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await menu('Rename');
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.tap(find.text('Save'));
      await _drain(tester);
      expect(const ReaderPresetStore().list.single.id, id);
      appdata.settings['readerSideMargin'] = 22;
      await menu('Update to current settings');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        const ReaderPresetStore().list.single.values['readerSideMargin'],
        0,
      );
      await menu('Update to current settings');
      await tester.tap(find.text('Confirm'));
      await _drain(tester);
      expect(
        const ReaderPresetStore().list.single.values['readerSideMargin'],
        22,
      );
      appdata.settings['readerSideMargin'] = 0;
      await tester.tap(find.text('Apply'));
      await _drain(tester);
      expect(appdata.settings['readerSideMargin'], 22);
      await menu('Delete');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(const ReaderPresetStore().list, hasLength(1));
      await menu('Delete');
      await tester.tap(find.text('Confirm'));
      await _drain(tester);
      expect(const ReaderPresetStore().list, isEmpty);
      expect(appdata.settings['readerSideMargin'], 22);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .initialValue,
        '',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quick preset uses comic override, emits existing effect keys and full settings reads the same values',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appdata.settings['readerMode'] = 'galleryRightToLeft';
      appdata.settings['reverseTapToTurnPages'] = true;
      final preset = await tester.runAsync(
        () => const ReaderPresetStore().createFromCurrent('Manga'),
      );
      appdata.settings['readerMode'] = 'waterfallTopToBottom';
      appdata.settings['reverseTapToTurnPages'] = false;
      appdata.settings['readerBrightness'] = 75;
      final preview = ReaderBrightnessPreview();
      addTearDown(preview.dispose);
      final changed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderQuickSettingsPanel(
              comicId: 'book',
              sourceKey: 'local',
              brightnessPreview: preview,
              isCurrent: () => true,
              onChanged: changed.add,
              onAllSettings: () async {},
            ),
          ),
        ),
      );
      expect(readerQuickSettings[1], ReaderQuickSetting.preset);
      await _select(tester, preset!.id);
      expect(changed.toSet(), preset.values.keys.toSet());
      expect(
        appdata.settings.comicReaderModeOverride('book', 'local'),
        'galleryRightToLeft',
      );
      expect(appdata.settings['readerMode'], 'waterfallTopToBottom');
      expect(
        appdata.settings.getReaderSetting('book', 'local', 'readerBrightness'),
        75,
      );
      expect(find.text('Scope: This comic'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderSettings(comicId: 'book', comicSource: 'local'),
          ),
        ),
      );
      final value = tester
          .widgetList<Select>(find.byType(Select))
          .map((s) => s.current);
      expect(value, contains('Page turn (Right to Left)'));
      // The full form's typed scoped storage is the same one read by the panel.
      expect(
        ReaderPreferenceStore(
          settings: appdata.settings,
          scope: ReaderPreferenceScope.comic,
          comicId: 'book',
          sourceKey: 'local',
        ).read(ReaderPreferences.reverseTapToTurnPages),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'B3 failed compensation survives page recreation; retry recovery never applies',
    (tester) async {
      const store = ReaderPresetStore();
      appdata.settings['readerSideMargin'] = 0;
      final old = await tester.runAsync(() => store.createFromCurrent('Old'));
      appdata.settings['readerSideMargin'] = 16;
      final next = await tester.runAsync(() => store.createFromCurrent('New'));
      await tester.runAsync(
        () => store.apply(old!.id, ReaderPreferenceScope.global),
      );
      final effects = <String>[];
      Widget page() => MaterialApp(
        home: Scaffold(
          body: ReaderPresetSelector(store: store, onChanged: effects.add),
        ),
      );
      await tester.pumpWidget(page());
      final blocked = Directory('${root.path}/appdata.json.tmp')..createSync();
      tester
          .widget<DropdownButtonFormField<String>>(_presetDropdown)
          .onChanged!(next!.id);
      for (var i = 0; i < 100 && store.recovery == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(store.recovery, isNotNull);
      expect(effects, isEmpty);
      expect(find.text('Saved'), findsNothing);
      expect(appdata.settings['readerSideMargin'], 0);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .onChanged,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      expect(find.text('Save failed; recovery incomplete'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .initialValue,
        '',
      );
      blocked.deleteSync();
      await tester.tap(find.text('Retry recovery'));
      await _drain(tester);
      expect(store.recovery, isNull);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .initialValue,
        old!.id,
      );
      expect(effects, isEmpty);
      expect(find.text('Saved'), findsNothing);
      await _select(tester, next.id);
      expect(store.selectedId, next.id);
      expect(effects, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'B3 queued device apply stays with original identity and suppresses stale success',
    (tester) async {
      appdata.settings['readerSideMargin'] = 16;
      final preset = await tester.runAsync(
        () => const ReaderPresetStore().createFromCurrent('Device'),
      );
      appdata.settings['readerSideMargin'] = 0;
      final entered = Completer<void>();
      final release = Completer<void>();
      final holding = appdata.runPersistenceMaintenance((_) async {
        entered.complete();
        await release.future;
      });
      await tester.runAsync(() => entered.future);
      const store = ReaderPresetStore(scope: ReaderPreferenceScope.device);
      final effects = <String>[];
      Widget page() => MaterialApp(
        home: Scaffold(
          body: ReaderPresetSelector(store: store, onChanged: effects.add),
        ),
      );
      await tester.pumpWidget(page());
      tester
          .widget<DropdownButtonFormField<String>>(_presetDropdown)
          .onChanged!(preset!.id);
      appdata.settings['deviceId'] = 'other-device';
      await tester.pumpWidget(page());
      release.complete();
      await tester.runAsync(() => holding);
      await _drain(tester);
      expect(effects, isEmpty);
      expect(find.text('Saved'), findsNothing);
      expect(store.selectedId, isNull);
      expect(appdata.settings['deviceId'], 'other-device');
      appdata.settings['deviceId'] = 'preset-ui';
      await tester.pump();
      expect(store.selectedId, preset.id);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(_presetDropdown)
            .initialValue,
        preset.id,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
