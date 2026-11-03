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
import 'reader_preset_recovery_test.dart' show WriteHooks;

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
  late ReaderPreset a;
  Future<void> inherit() => appdata.updateSettings(
    (s) => s.setComicReaderModeOverride('book', 'a', null),
  );
  Future<void> fixed(String mode) => appdata.updateSettings(
    (s) => s.setComicReaderModeOverride('book', 'a', mode),
  );
  String actual([String source = 'a']) =>
      appdata.settings.readerSettings('book', source).readerMode;
  Map disk(String name) =>
      jsonDecode(File('${root.path}/$name').readAsStringSync()) as Map;
  ReaderPreset getA() => global.list.firstWhere((p) => p.id == a.id);
  setUp(() async {
    checkpoint = appdata.captureImportCheckpoint();
    root = Directory.systemTemp.createTempSync('b3-inherit-');
    App.dataPath = App.cachePath = root.path;
    appdata.settings.resetGlobalReaderSettings();
    appdata.settings['deviceId'] = 'inherit-device';
    appdata.settings['deviceSpecificSettings'] = {};
    appdata.settings['comicSpecificSettings'] = {};
    appdata.settings['comicLayoutDetections'] = {};
    appdata.settings['readerPresetSelections'] = {};
    appdata.settings['readerPresetBindings'] = {};
    appdata.settings['readerModePresets'] = [];
    appdata.settings['disableSyncFields'] = 'proxy';
    appdata.settings['readerMode'] = 'continuousTopToBottom';
    a = await global.createFromCurrent('A');
    appdata.settings['readerMode'] = 'waterfallTopToBottom';
    await comic.apply(a.id, comic.scope);
  });
  tearDown(() async {
    await appdata.restoreImportCheckpoint(checkpoint, persist: false);
    root.deleteSync(recursive: true);
  });

  test(
    'inherit follows current upper mode, enable switch and each comic auto layout',
    () async {
      await other.apply(a.id, other.scope);
      await inherit();
      expect([comic.selectedId, other.selectedId], [a.id, a.id]);
      expect(actual(), 'waterfallTopToBottom');
      await appdata.updateSettings((s) {
        s.setDeviceReaderSetting('enabled', true);
        s.setDeviceReaderSetting('readerMode', 'galleryTopToBottom');
      });
      expect(actual(), 'galleryTopToBottom');
      await appdata.updateSettings((s) {
        s.setDeviceReaderSetting('autoReaderMode', true);
        s.setDeviceReaderSetting('pagedReaderMode', 'galleryRightToLeft');
        s.setDeviceReaderSetting(
          'longStripReaderMode',
          'continuousTopToBottom',
        );
        s.setComicLayout(
          'book',
          'a',
          const ComicLayoutDetection(ComicLayout.paged, 6),
        );
        s.setComicLayout(
          'book',
          'b',
          const ComicLayoutDetection(ComicLayout.longStrip, 6),
        );
      });
      expect(actual(), 'galleryRightToLeft');
      expect(actual('b'), 'continuousTopToBottom');
      await appdata.updateSettings(
        (s) => s.setEnabledComicSpecificSettings('book', 'a', false),
      );
      expect(actual(), 'galleryRightToLeft');
      expect(comic.selectedId, a.id);
      await appdata.updateSettings(
        (s) => s.setEnabledDeviceSpecificSettings(false),
      );
      expect(actual(), 'waterfallTopToBottom');
      expect(getA().modeBehavior, 'inherit');
    },
  );

  test(
    'same ID at all three layers uses independent global base without recursion',
    () async {
      final base = {
        for (final key in [
          'readerMode',
          'autoReaderMode',
          'pagedReaderMode',
          'longStripReaderMode',
        ])
          key: (appdata.toJson()['settings'] as Map)[key],
      };
      await global.apply(a.id, global.scope);
      await device.apply(a.id, device.scope);
      await inherit();
      expect(global.selectedId, a.id);
      expect(device.selectedId, a.id);
      expect(comic.selectedId, a.id);
      expect(
        appdata.settings.globalReaderSettings.readerMode,
        'waterfallTopToBottom',
      );
      expect(actual(), 'waterfallTopToBottom');
      expect({
        for (final key in base.keys)
          key: (appdata.toJson()['settings'] as Map)[key],
      }, base);
      await appdata.updateSettings((s) {
        s['autoReaderMode'] = true;
        s['pagedReaderMode'] = 'galleryLeftToRight';
        s['longStripReaderMode'] = 'continuousRightToLeft';
        s.setComicLayout(
          'book',
          'a',
          const ComicLayoutDetection(ComicLayout.longStrip, 6),
        );
      });
      expect(actual(), 'continuousRightToLeft');
      await appdata.loadDataForTesting(root.path);
      expect(getA().modeBehavior, 'inherit');
      expect(actual(), 'continuousRightToLeft');
      await fixed('galleryTopToBottom');
      expect(getA().modeBehavior, 'fixed');
      expect(
        [
          appdata.settings.globalReaderSettings.readerMode,
          ReaderPreferenceStore(
            settings: appdata.settings,
            scope: device.scope,
          ).read(ReaderPreferences.readerMode),
          actual(),
        ],
        ['galleryTopToBottom', 'galleryTopToBottom', 'galleryTopToBottom'],
      );
      // Fixed reactivates the preset's dormant auto value, never a new snapshot.
      expect(getA().values['autoReaderMode'], false);
    },
  );

  test(
    'upper distinct fixed preset updates inherited comics dynamically',
    () async {
      final b = await global.createFromCurrent('B');
      await global.apply(b.id, global.scope);
      await inherit();
      await appdata.updateSettings(
        (s) => ReaderPreferenceStore(
          settings: s,
          scope: ReaderPreferenceScope.global,
        ).write(ReaderPreferences.readerMode, 'galleryTopToBottom'),
      );
      expect(actual(), 'galleryTopToBottom');
      expect(getA().modeBehavior, 'inherit');
      expect(global.selectedId, b.id);
      expect(comic.selectedId, a.id);
    },
  );

  test(
    'mode four edits return same ID to fixed; other fifteen and outside fields retain inherit',
    () async {
      for (final entry in <String, Object>{
        'readerMode': 'galleryLeftToRight',
        'autoReaderMode': true,
        'pagedReaderMode': 'galleryTopToBottom',
        'longStripReaderMode': 'continuousRightToLeft',
      }.entries) {
        await inherit();
        await appdata.updateSettings(
          (s) => ReaderPreferenceStore(
            settings: s,
            scope: comic.scope,
            comicId: 'book',
            sourceKey: 'a',
          ).writeRaw(entry.key, entry.value),
        );
        expect(getA().modeBehavior, 'fixed', reason: entry.key);
        expect(getA().values[entry.key], entry.value);
        expect(comic.selectedId, a.id);
      }
      await inherit();
      for (final p in readerPresetPreferences.where(
        (p) => ![
          'readerMode',
          'autoReaderMode',
          'pagedReaderMode',
          'longStripReaderMode',
        ].contains(p.key),
      )) {
        await appdata.updateSettings(
          (s) => ReaderPreferenceStore(
            settings: s,
            scope: comic.scope,
            comicId: 'book',
            sourceKey: 'a',
          ).writeRaw(p.key, getA().values[p.key]),
        );
        expect(getA().modeBehavior, 'inherit', reason: p.key);
      }
      await appdata.updateSettings(
        (s) => ReaderPreferenceStore(
          settings: s,
          scope: comic.scope,
          comicId: 'book',
          sourceKey: 'a',
        ).write(ReaderPreferences.readerBrightness, 75),
      );
      expect(getA().modeBehavior, 'inherit');
      expect(
        getA().values.keys.toSet(),
        readerPresetPreferences.map((p) => p.key).toSet(),
      );
    },
  );

  test(
    'pure inherit valid, bad behavior fixed, empty invalid; switching rename reload and snapshots',
    () async {
      appdata.settings['readerModePresets'] = [
        a.toJson(),
        {'id': 'pure', 'name': 'Pure', 'values': {}, 'modeBehavior': 'inherit'},
        {'id': 'empty', 'name': 'Empty', 'values': {}},
        {'id': 'bad', 'name': 'Bad', 'values': {}, 'modeBehavior': 'garbage'},
        {
          'id': 'bad-fixed',
          'name': 'Bad fixed',
          'values': {'readerMode': 'galleryLeftToRight'},
          'modeBehavior': 7,
        },
      ];
      expect(await other.apply('pure', other.scope), contains('readerMode'));
      expect(other.selectedId, 'pure');
      expect(actual('b'), 'waterfallTopToBottom');
      expect(await other.apply('empty', other.scope), isEmpty);
      expect(await other.apply('bad', other.scope), isEmpty);
      await other.apply('bad-fixed', other.scope);
      expect(
        global.list.firstWhere((p) => p.id == 'bad-fixed').modeBehavior,
        'fixed',
      );
      expect(actual('b'), 'galleryLeftToRight');
      await inherit();
      await global.rename(a.id, 'Renamed');
      expect(getA().name, 'Renamed');
      expect(getA().modeBehavior, 'inherit');
      await comic.apply('pure', comic.scope);
      await comic.apply(a.id, comic.scope);
      await appdata.loadDataForTesting(root.path);
      expect(comic.selectedId, a.id);
      expect(getA().modeBehavior, 'inherit');
      final snapshot = await comic.createFromCurrent('Snapshot');
      expect(snapshot.modeBehavior, 'fixed');
      expect(snapshot.values['readerMode'], actual());
      await comic.updateFromCurrent(a.id);
      expect(getA().modeBehavior, 'fixed');
      expect(getA().values['autoReaderMode'], false);
    },
  );

  for (final action in ['None', 'delete']) {
    test(
      '$action preserves dynamic inheritance for every target instead of mode snapshots',
      () async {
        await global.apply(a.id, global.scope);
        await device.apply(a.id, device.scope);
        await other.apply(a.id, other.scope);
        await inherit();
        if (action == 'None') {
          await global.clearSelection();
          await device.clearSelection();
          await comic.clearSelection();
          await other.clearSelection();
        } else {
          await global.delete(a.id);
        }
        expect([
          global.selectedId,
          device.selectedId,
          comic.selectedId,
          other.selectedId,
        ], everyElement(isNull));
        final records = appdata.settings['deviceSpecificSettings'] as Map;
        for (final key in [
          'readerMode',
          'autoReaderMode',
          'pagedReaderMode',
          'longStripReaderMode',
        ]) {
          expect((records['inherit-device'] as Map).containsKey(key), false);
        }
        expect(appdata.settings.comicReaderModeOverride('book', 'a'), isNull);
        await appdata.updateSettings(
          (s) => s['readerMode'] = 'galleryTopToBottom',
        );
        expect(actual(), 'galleryTopToBottom');
        expect(actual('b'), 'galleryTopToBottom');
        await appdata.loadDataForTesting(root.path);
        expect(actual(), 'galleryTopToBottom');
      },
    );
  }

  for (final name in ['appdata.json', 'syncdata.json']) {
    for (final direction in ['inherit', 'fixed']) {
      test(
        'real $name $direction failure compensates behavior presence in both files',
        () async {
          if (direction == 'fixed') {
            await inherit();
          } else {
            appdata.settings['readerModePresets'] = [
              for (final p in global.list)
                {...p.toJson()}..remove('modeBehavior'),
            ];
            await appdata.saveData(false);
          }
          final before =
              (appdata.settings['readerModePresets'] as List).single as Map;
          final hadBehavior = before.containsKey('modeBehavior'),
              behavior = before['modeBehavior'];
          final entered = Completer<void>(), release = Completer<void>();
          var writes = 0;
          final obstacle = Directory('${root.path}/$name.tmp')..createSync();
          final hook = WriteHooks((path, _) async {
            if (path == '${root.path}/$name.tmp' && writes++ == 0) {
              entered.complete();
            } else if (path.endsWith('.tmp') && writes <= 1) {
              await release.future;
            }
          });
          final operation = IOOverrides.runWithIOOverrides(
            () =>
                direction == 'fixed' ? fixed('galleryTopToBottom') : inherit(),
            hook,
          );
          final checking = expectLater(
            operation,
            throwsA(
              isA<SettingsRecoveryFailure>().having(
                (e) => e.incomplete,
                'compensated',
                false,
              ),
            ),
          );
          await entered.future;
          while (!hook.failed) {
            await Future<void>.delayed(Duration.zero);
          }
          obstacle.deleteSync();
          release.complete();
          await checking;
          for (final file in ['appdata.json', 'syncdata.json']) {
            final item =
                (disk(file)['settings']['readerModePresets'] as List).single
                    as Map;
            expect(item.containsKey('modeBehavior'), hadBehavior);
            expect(item['modeBehavior'], behavior);
          }
          await appdata.loadDataForTesting(root.path);
          expect(comic.selectedId, a.id);
          expect(
            actual(),
            direction == 'fixed'
                ? 'waterfallTopToBottom'
                : 'continuousTopToBottom',
          );
        },
      );
    }
  }

  test(
    'inherit repeated failure pauses shared object; retry only restores then explicit edit',
    () async {
      await other.apply(a.id, other.scope);
      final obstacle = Directory('${root.path}/syncdata.json.tmp')
        ..createSync();
      await expectLater(inherit(), throwsA(isA<SettingsRecoveryFailure>()));
      expect(comic.selectedId, isNull);
      expect(other.selectedId, isNull);
      expect(getA().modeBehavior, 'fixed');
      expect(actual(), 'continuousTopToBottom');
      await expectLater(
        other.clearSelection(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(
        fixed('galleryTopToBottom'),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(
        comic.retryRecovery(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      obstacle.deleteSync();
      await other.retryRecovery();
      expect(comic.selectedId, a.id);
      expect(getA().modeBehavior, 'fixed');
      await inherit();
      expect(getA().modeBehavior, 'inherit');
    },
  );

  for (final action in ['None', 'delete']) {
    test(
      'inherit $action failure restores behavior binding and physical ownership',
      () async {
        await global.apply(a.id, global.scope);
        await device.apply(a.id, device.scope);
        await inherit();
        final before = jsonEncode(appdata.settings['comicSpecificSettings']);
        final obstacle = Directory('${root.path}/appdata.json.tmp')
          ..createSync();
        await expectLater(
          action == 'None' ? comic.clearSelection() : global.delete(a.id),
          throwsA(isA<SettingsRecoveryFailure>()),
        );
        expect(getA().modeBehavior, 'inherit');
        expect(appdata.settings.readerPresetId(comic.selectionKey), a.id);
        expect(jsonEncode(appdata.settings['comicSpecificSettings']), before);
        expect(actual(), 'waterfallTopToBottom');
        obstacle.deleteSync();
        await (action == 'None' ? comic : global).retryRecovery();
        await appdata.loadDataForTesting(root.path);
        expect(comic.selectedId, a.id);
        expect(getA().modeBehavior, 'inherit');
        expect(actual(), 'waterfallTopToBottom');
      },
    );
  }

  test(
    'behavior compensation preserves concurrent rename fields and later behavior takeover',
    () async {
      var calls = 0;
      final hook = WriteHooks((path, _) async {
        if (path.endsWith('syncdata.json.tmp') && calls++ == 0) {
          appdata.settings['readerModePresets'] = [
            for (final p in global.list)
              {
                ...p.toJson(),
                'name': 'Renamed',
                'modeBehavior': 'fixed',
                'values': {...p.values, 'readerSideMargin': 23},
              },
          ];
          throw const FileSystemException('one-shot');
        }
      });
      await expectLater(
        IOOverrides.runWithIOOverrides(inherit, hook),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      expect(getA().name, 'Renamed');
      expect(getA().values['readerSideMargin'], 23);
      expect(getA().modeBehavior, 'fixed');
      expect(comic.selectedId, a.id);
    },
  );

  for (final change in ['id', 'source', 'directory']) {
    test(
      'queued inherit $change ownership cannot reach another target',
      () async {
        final b = await global.createFromCurrent('B');
        await other.apply(b.id, other.scope);
        final entered = Completer<void>(), release = Completer<void>();
        final holding = appdata.runPersistenceMaintenance((_) async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final operation = inherit();
        if (change == 'id') {
          appdata.settings['readerPresetSelections'] = {
            comic.selectionKey: b.id,
            other.selectionKey: b.id,
          };
          appdata.settings['readerPresetBindings'] = {
            comic.selectionKey: b.id,
            other.selectionKey: b.id,
          };
        } else if (change == 'directory') {
          final destination = Directory('${root.path}/other')..createSync();
          App.dataPath = destination.path;
        }
        final checking = change == 'source'
            ? operation
            : expectLater(operation, throwsStateError);
        release.complete();
        await holding;
        await checking;
        if (change == 'source') {
          expect(getA().modeBehavior, 'inherit');
        } else {
          expect(getA().modeBehavior, 'fixed');
        }
        expect(
          global.list.firstWhere((p) => p.id == b.id).modeBehavior,
          'fixed',
        );
        if (change == 'directory') {
          expect(Directory(App.dataPath).listSync(), isEmpty);
        }
        App.dataPath = root.path;
      },
    );
  }
}
