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

  for (final scope in ReaderSettingsScope.values) {
    testWidgets(
      'settings preset applies to selected $scope and keeps reminder across scope changes',
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
          preset.id,
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
}
