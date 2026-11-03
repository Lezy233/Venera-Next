import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_layout.dart';
import 'package:venera_next/foundation/reader_preferences.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppdataImportCheckpoint checkpoint;
  const global = ReaderPresetStore();
  const device = ReaderPresetStore(scope: ReaderPreferenceScope.device);
  const comic = ReaderPresetStore(
    scope: ReaderPreferenceScope.comic,
    comicId: 'book',
    sourceKey: 'a',
  );
  const other = ReaderPresetStore(
    scope: ReaderPreferenceScope.comic,
    comicId: 'book',
    sourceKey: 'b',
  );
  final alternatives = <String, Object>{
    'readerMode': 'galleryLeftToRight',
    'autoReaderMode': true,
    'pagedReaderMode': 'galleryTopToBottom',
    'longStripReaderMode': 'waterfallTopToBottom',
    'readerScreenPicNumberForPortrait': 2,
    'readerScreenPicNumberForLandscape': 2,
    'showSingleImageOnFirstPage': true,
    'limitImageWidth': false,
    'readerSideMargin': 17,
    'splitDualPage': true,
    'splitDualPageInvert': true,
    'enablePageAnimation': false,
    'enableTapToTurnPages': false,
    'reverseTapToTurnPages': true,
    'enableDoubleTapToZoom': false,
    'longPressAction': 'none',
    'longPressZoomPosition': 'center',
    'quickCollectImage': 'DoubleTap',
    'enableTurnPageByVolumeKey': false,
  };
  ReaderPreferenceStore values(ReaderPresetStore target, [Settings? draft]) =>
      ReaderPreferenceStore(
        settings: draft ?? appdata.settings,
        scope: target.scope,
        comicId: target.comicId,
        sourceKey: target.sourceKey,
      );
  Future<void> edit(ReaderPresetStore target, String key, Object value) =>
      appdata.updateSettings((draft) {
        if (key == 'readerMode' &&
            target.scope == ReaderPreferenceScope.comic) {
          values(target, draft).writeComicModeOverride(value as String);
        } else {
          values(target, draft).writeRaw(key, value);
        }
      });
  Future<void> reload() => appdata.loadDataForTesting(root.path);
  setUp(() async {
    checkpoint = appdata.captureImportCheckpoint();
    root = Directory.systemTemp.createTempSync('b3-binding-');
    App.dataPath = App.cachePath = root.path;
    appdata.settings.resetGlobalReaderSettings();
    appdata.settings['readerModePresets'] = [];
    appdata.settings['readerPresetSelections'] = {};
    appdata.settings['readerPresetBindings'] = {};
    appdata.settings['deviceId'] = 'binding-device';
    appdata.settings['deviceSpecificSettings'] = {};
    appdata.settings['comicSpecificSettings'] = {};
    appdata.settings['comicLayoutDetections'] = {};
    appdata.settings['disableSyncFields'] = '';
  });
  tearDown(() async {
    await appdata.restoreImportCheckpoint(checkpoint, persist: false);
    root.deleteSync(recursive: true);
  });

  for (final target in [global, device, comic]) {
    for (final preference in readerPresetPreferences) {
      test(
        '${target.scope.name} partial binding edits ${preference.key} only and reloads',
        () async {
          appdata.settings['readerModePresets'] = [
            {
              'id': 'partial',
              'name': 'Partial',
              'values': {'readerSideMargin': 3},
            },
          ];
          appdata.settings['readerMode'] = 'continuousTopToBottom';
          await target.apply('partial', target.scope);
          expect(
            values(target).read(ReaderPreferences.readerMode),
            'continuousTopToBottom',
          );
          await edit(target, preference.key, alternatives[preference.key]!);
          final expected = preference.normalize(alternatives[preference.key]);
          expect(target.selectedId, 'partial');
          expect(target.list.single.name, 'Partial');
          expect(target.list.single.values[preference.key], expected);
          expect(target.list.single.values.keys.toSet(), {
            'readerSideMargin',
            preference.key,
          });
          // Auto remains an independent input; ordinary edits never snapshot it.
          if (preference.key != 'autoReaderMode') {
            expect(
              target.list.single.values.containsKey('autoReaderMode'),
              false,
            );
          }
          expect(values(target).read(preference), expected);
          await reload();
          expect(target.selectedId, 'partial');
          expect(target.list.single.values[preference.key], expected);
          if (preference.key == 'readerMode') {
            expect(
              appdata.settings.readerSettings('book', 'a').readerMode,
              expected,
            );
          }
        },
      );
    }
  }

  test(
    'same ID shares; distinct IDs, source identities and unbound records isolate',
    () async {
      final a = await global.createFromCurrent('A');
      final b = await global.createFromCurrent('B');
      await global.apply(a.id, global.scope);
      await device.apply(a.id, device.scope);
      await comic.apply(b.id, comic.scope);
      await other.apply(a.id, other.scope);
      appdata.settings.setReaderSetting(
        'independent',
        'a',
        'readerSideMargin',
        8,
      );
      appdata.settings.setEnabledComicSpecificSettings(
        'independent',
        'a',
        true,
      );
      await edit(device, 'readerSideMargin', 21);
      expect(values(global).read(ReaderPreferences.readerSideMargin), 21);
      expect(values(other).read(ReaderPreferences.readerSideMargin), 21);
      expect(values(comic).read(ReaderPreferences.readerSideMargin), 0);
      expect(
        appdata.settings.readerSettings('independent', 'a').readerSideMargin,
        8,
      );
      await reload();
      expect(
        [
          global.selectedId,
          device.selectedId,
          comic.selectedId,
          other.selectedId,
        ],
        [a.id, a.id, b.id, a.id],
      );
      await edit(comic, 'readerMode', 'galleryTopToBottom');
      expect(
        appdata.settings.readerSettings('book', 'a').readerMode,
        'galleryTopToBottom',
      );
      expect(
        appdata.settings.readerSettings('book', 'b').readerMode,
        a.values['readerMode'],
      );
    },
  );

  test(
    'A/B, rename, explicit update, None independent edit, delete keep latest effects',
    () async {
      final a = await global.createFromCurrent('A');
      final b = await global.createFromCurrent('B');
      await global.apply(a.id, global.scope);
      await device.apply(a.id, device.scope);
      await edit(global, 'readerSideMargin', 19);
      await global.apply(b.id, global.scope);
      await edit(global, 'readerSideMargin', 27);
      await global.apply(a.id, global.scope);
      expect(values(global).read(ReaderPreferences.readerSideMargin), 19);
      await global.rename(a.id, 'Renamed');
      expect(global.selectedId, a.id);
      expect(global.list.first.name, 'Renamed');
      await global.clearSelection();
      expect(global.selectedId, isNull);
      expect(values(global).read(ReaderPreferences.readerSideMargin), 19);
      await edit(global, 'readerSideMargin', 9);
      expect(values(device).read(ReaderPreferences.readerSideMargin), 19);
      await global.updateFromCurrent(a.id);
      expect(values(device).read(ReaderPreferences.readerSideMargin), 9);
      await comic.apply(a.id, comic.scope);
      await global.delete(a.id);
      expect(device.selectedId, isNull);
      expect(comic.selectedId, isNull);
      expect(values(device).read(ReaderPreferences.readerSideMargin), 9);
      expect(values(comic).read(ReaderPreferences.readerSideMargin), 9);
      await reload();
      expect(global.list.single.id, b.id);
      expect(values(comic).read(ReaderPreferences.readerSideMargin), 9);
    },
  );

  test(
    'outside-preset edits stay scoped; resets detach only current target',
    () async {
      final preset = await global.createFromCurrent('A');
      await global.apply(preset.id, global.scope);
      await comic.apply(preset.id, comic.scope);
      final initial = jsonEncode(global.list.single.values);
      for (final entry in <String, Object>{
        'readerBrightness': 75,
        'preloadImageCount': 8,
        'readerThumbnailState': 'collapsed',
        'eInkRefreshEnabled': true,
        'autoScrollSpeed': 120,
      }.entries) {
        await edit(comic, entry.key, entry.value);
        expect(comic.selectedId, preset.id);
        expect(jsonEncode(global.list.single.values), initial);
        expect(
          (appdata.settings['comicSpecificSettings']
              as Map)['book@a'][entry.key],
          entry.value,
        );
      }
      await comic.reset();
      expect(comic.selectedId, isNull);
      expect(global.selectedId, preset.id);
      expect(jsonEncode(global.list.single.values), initial);
    },
  );

  test(
    'legacy matching and mismatching references migrate without overwriting actual values',
    () async {
      appdata.settings['readerModePresets'] = [
        {
          'id': 'partial',
          'name': 'Partial',
          'values': {'readerSideMargin': 12},
        },
      ];
      appdata.settings['readerSideMargin'] = 12;
      appdata.settings.setDeviceReaderSetting('enabled', true);
      appdata.settings.setDeviceReaderSetting('readerSideMargin', 23);
      appdata.settings['readerPresetSelections'] = {
        global.selectionKey: 'partial',
        device.selectionKey: 'partial',
        comic.selectionKey: 'missing',
        '[]': 'partial',
      };
      expect(global.selectedId, 'partial');
      expect(device.selectedId, isNull);
      await appdata.updateSettings((_) {});
      expect(appdata.settings['readerPresetSelections'], {
        global.selectionKey: 'partial',
      });
      expect(values(device).read(ReaderPreferences.readerSideMargin), 23);
      await edit(global, 'readerSideMargin', 16);
      // The persisted materialized copy is deliberately stale after shared edit.
      expect((appdata.toJson()['settings'] as Map)['readerSideMargin'], 12);
      await reload();
      expect(global.selectedId, 'partial');
      expect(values(global).read(ReaderPreferences.readerSideMargin), 16);
      await appdata.updateSettings((_) {});
      await reload();
      expect(global.selectedId, 'partial');
      expect(values(device).read(ReaderPreferences.readerSideMargin), 23);
    },
  );

  test(
    'automatic global/device modes and manual comic override use latest shared fields',
    () async {
      final a = await global.createFromCurrent('A');
      await global.apply(a.id, global.scope);
      await device.apply(a.id, device.scope);
      await edit(global, 'autoReaderMode', true);
      await edit(device, 'pagedReaderMode', 'galleryTopToBottom');
      await edit(global, 'longStripReaderMode', 'waterfallTopToBottom');
      appdata.settings.setComicLayout(
        'book',
        'a',
        const ComicLayoutDetection(ComicLayout.paged, 6),
      );
      expect(
        appdata.settings.readerSettings('book', 'a').readerMode,
        'galleryTopToBottom',
      );
      await comic.apply(a.id, comic.scope);
      await edit(comic, 'readerMode', 'continuousRightToLeft');
      expect(
        appdata.settings.readerSettings('book', 'a').readerMode,
        'continuousRightToLeft',
      );
      expect(global.list.single.values['autoReaderMode'], true);
      await reload();
      expect(comic.selectedId, a.id);
      expect(
        appdata.settings.readerSettings('book', 'a').readerMode,
        'continuousRightToLeft',
      );
    },
  );

  test(
    'switching to a partial preset inherits latest outgoing values',
    () async {
      final a = await global.createFromCurrent('A');
      appdata.settings['readerModePresets'] = [
        a.toJson(),
        {
          'id': 'partial',
          'name': 'Partial',
          'values': {'readerMode': 'galleryTopToBottom'},
        },
      ];
      await global.apply(a.id, global.scope);
      await edit(global, 'readerSideMargin', 18);
      await global.apply('partial', global.scope);
      expect(global.selectedId, 'partial');
      expect(values(global).read(ReaderPreferences.readerSideMargin), 18);
      expect(global.list.last.values.containsKey('readerSideMargin'), false);
      await reload();
      expect(values(global).read(ReaderPreferences.readerSideMargin), 18);
    },
  );

  test(
    'delete preserves another device effect without adopting its identity',
    () async {
      final a = await global.createFromCurrent('A');
      await device.apply(a.id, device.scope);
      await edit(device, 'readerSideMargin', 22);
      appdata.settings['deviceId'] = '';
      await global.delete(a.id);
      expect(appdata.settings['deviceId'], '');
      expect(
        (appdata.settings['deviceSpecificSettings']
            as Map)['binding-device']['readerSideMargin'],
        22,
      );
      appdata.settings['deviceId'] = 'binding-device';
      expect(device.selectedId, isNull);
      expect(values(device).read(ReaderPreferences.readerSideMargin), 22);
    },
  );

  test(
    'first device multi-field edit and malformed identity safely create a target',
    () async {
      appdata.settings['deviceId'] = 7;
      await appdata.updateSettings((draft) {
        values(
          device,
          draft,
        ).write(ReaderPreferences.readerScreenPicNumberForPortrait, 2);
        values(
          device,
          draft,
        ).write(ReaderPreferences.readerScreenPicNumberForLandscape, 2);
      });
      expect(appdata.settings['deviceId'], isA<String>());
      expect(
        values(device).read(ReaderPreferences.readerScreenPicNumberForPortrait),
        2,
      );
      expect(
        values(
          device,
        ).read(ReaderPreferences.readerScreenPicNumberForLandscape),
        2,
      );
      final a = await global.createFromCurrent('A');
      appdata.settings['deviceId'] = 7;
      await device.apply(a.id, device.scope);
      expect(device.selectedId, a.id);
    },
  );

  for (final change in ['preset', 'device', 'directory']) {
    test('queued bound edit cancels changed $change ownership', () async {
      final a = await global.createFromCurrent('A');
      final b = await global.createFromCurrent('B');
      final target = change == 'device' ? device : global;
      await target.apply(a.id, target.scope);
      final entered = Completer<void>(), release = Completer<void>();
      final holding = appdata.runPersistenceMaintenance((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final editing = edit(target, 'readerSideMargin', 25);
      if (change == 'device') {
        appdata.settings['deviceId'] = 'new-device';
      } else if (change == 'directory') {
        final destination = Directory('${root.path}/other-data')..createSync();
        App.dataPath = destination.path;
      } else {
        appdata.settings['readerPresetSelections'] = {
          target.selectionKey: b.id,
        };
        appdata.settings['readerPresetBindings'] = {target.selectionKey: b.id};
      }
      final checking = expectLater(editing, throwsStateError);
      release.complete();
      await holding;
      await checking;
      expect(global.list.first.values['readerSideMargin'], 0);
      expect(global.list.last.values['readerSideMargin'], 0);
      if (change == 'directory') {
        expect(Directory(App.dataPath).listSync(), isEmpty);
      }
      App.dataPath = root.path;
    });
  }

  test(
    'queued field edits merge latest values and rename without replacing preset',
    () async {
      final a = await global.createFromCurrent('A');
      await global.apply(a.id, global.scope);
      await Future.wait([
        edit(global, 'readerSideMargin', 13),
        edit(global, 'enablePageAnimation', false),
        global.rename(a.id, 'Renamed'),
      ]);
      expect(global.list.single.values['readerSideMargin'], 13);
      expect(global.list.single.values['enablePageAnimation'], false);
      expect(global.list.single.name, 'Renamed');
      final entered = Completer<void>(), release = Completer<void>();
      final holding = appdata.runPersistenceMaintenance((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final queued = edit(global, 'readerSideMargin', 29);
      // Simulate a subsequent target takeover before writer admission.
      appdata.settings['readerPresetSelections'] = {};
      final checking = expectLater(queued, throwsStateError);
      release.complete();
      await holding;
      await checking;
      expect(global.list.single.values['readerSideMargin'], 13);
    },
  );
}
