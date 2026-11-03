import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';

import 'reader_preset_recovery_test.dart' show WriteHooks;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppdataImportCheckpoint checkpoint;
  const store = ReaderPresetStore();
  const device = ReaderPresetStore(scope: ReaderPreferenceScope.device);
  const comic = ReaderPresetStore(
    scope: ReaderPreferenceScope.comic,
    comicId: 'book',
    sourceKey: 'local',
  );
  List<String> ids() => store.list.map((p) => p.id).toList();
  Map disk(String name) =>
      jsonDecode(File('${root.path}/$name').readAsStringSync()) as Map;
  Map<String, dynamic> cloneSettings() =>
      jsonDecode(jsonEncode(appdata.toJson()['settings']))
          as Map<String, dynamic>;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('f9-store-');
    App.dataPath = App.cachePath = root.path;
    checkpoint = appdata.captureImportCheckpoint();
    appdata.settings['deviceId'] = 'f9';
    appdata.settings['deviceSpecificSettings'] = {};
    appdata.settings['comicSpecificSettings'] = {};
    appdata.settings['readerPresetSelections'] = {};
    appdata.settings['readerPresetBindings'] = {};
    appdata.settings['readerModePresets'] = [
      for (final id in ['A', 'B', 'C'])
        {
          'id': id,
          'name': id,
          'values': {
            for (final p in readerPresetPreferences) p.key: p.normalize(null),
          },
          'modeBehavior': id == 'B' ? 'inherit' : 'fixed',
          'legacyMetadata': id,
        },
    ];
    appdata.settings['disableSyncFields'] = 'proxy';
    await store.apply('B', store.scope);
    await device.apply('B', device.scope);
    await comic.apply('B', comic.scope);
  });
  tearDown(() async {
    // A failing assertion must not leak recovery ownership into later tests.
    if (store.orderRecovery != null) {
      for (final name in ['appdata.json', 'syncdata.json']) {
        final obstacle = Directory('${root.path}/$name.tmp');
        if (obstacle.existsSync()) obstacle.deleteSync(recursive: true);
      }
      await store.retryOrderRecovery();
    }
    await appdata.restoreImportCheckpoint(checkpoint, persist: false);
    root.deleteSync(recursive: true);
  });

  for (final behavior in ['fixed', 'inherit']) {
    test(
      'move preserves complete raw objects, 19 keys and three bindings: $behavior',
      () async {
        if (behavior == 'fixed') {
          await appdata.updateSettings(
            (s) => ReaderPreferenceStore(
              settings: s,
              scope: ReaderPreferenceScope.global,
            ).write(ReaderPreferences.readerMode, 'waterfallTopToBottom'),
          );
        }
        final before = cloneSettings();
        final actual = {
          for (final p in readerPresetPreferences)
            p.key: appdata.settings.readerSettings('book', 'local').read(p),
        };
        expect(await store.move('C', 'A', before: true), true);
        expect(ids(), ['C', 'A', 'B']);
        expect(await store.move('C', 'B', before: false), true);
        expect(ids(), ['A', 'B', 'C']);
        final after = cloneSettings();
        final library = after.remove('readerModePresets') as List;
        expect(after, Map.of(before)..remove('readerModePresets'));
        expect(library, before['readerModePresets']);
        expect({
          for (final p in readerPresetPreferences)
            p.key: appdata.settings.readerSettings('book', 'local').read(p),
        }, actual);
        for (final target in [store, device, comic]) {
          expect(target.selectedId, 'B');
        }
        await appdata.loadDataForTesting(root.path);
        expect(const ReaderPresetStore().list.map((p) => p.id), [
          'A',
          'B',
          'C',
        ]);
        expect(comic.selectedId, 'B');
      },
    );
  }

  test(
    'None remains None; move reloads in new instance; CRUD keeps unrelated order',
    () async {
      await comic.clearSelection();
      await store.move('C', 'A', before: true);
      await store.rename('B', 'Renamed');
      await store.updateFromCurrent('B');
      final created = await store.createFromCurrent('New');
      expect(ids(), ['C', 'A', 'B', created.id]);
      await store.delete('A');
      expect(ids(), ['C', 'B', created.id]);
      await appdata.loadDataForTesting(root.path);
      expect(const ReaderPresetStore().list.map((p) => p.id), [
        'C',
        'B',
        created.id,
      ]);
      expect(comic.selectedId, isNull);
    },
  );

  test('no-op, empty, single and invalid targets never write', () async {
    var writes = 0;
    final hook = WriteHooks((_, _) async {
      writes++;
    });
    await IOOverrides.runWithIOOverrides(() async {
      expect(await store.move('A', 'B', before: true), false);
      expect(await store.move('C', 'B', before: false), false);
      expect(await store.move('B', 'B', before: true), false);
      await expectLater(
        store.move('missing', 'A', before: true),
        throwsStateError,
      );
      await expectLater(
        store.move('A', 'missing', before: true),
        throwsStateError,
      );
      appdata.settings['readerModePresets'] = [store.list.first.toJson()];
      expect(await store.move('A', 'A', before: false), false);
      appdata.settings['readerModePresets'] = [];
      await expectLater(store.move('A', 'B', before: true), throwsStateError);
    }, hook);
    expect(writes, 0);
  });

  test(
    'queued move reads latest CRUD and shared fields without stale overwrite',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final barrier = appdata.runPersistenceMaintenance((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final create = store.createFromCurrent('New');
      final rename = store.rename('B', 'Renamed');
      final edit = appdata.updateSettings(
        (s) => ReaderPreferenceStore(
          settings: s,
          scope: ReaderPreferenceScope.global,
        ).write(ReaderPreferences.readerSideMargin, 21),
      );
      final delete = store.delete('A');
      final move = store.move('C', 'B', before: true);
      release.complete();
      await barrier;
      final created = await create;
      await Future.wait([rename, edit, delete, move]);
      expect(ids(), ['C', 'B', created.id]);
      expect(store.list[1].name, 'Renamed');
      expect(store.list[1].values['readerSideMargin'], 21);
      expect(comic.selectedId, 'B');
    },
  );

  for (final deleted in ['A', 'C']) {
    test(
      'queued deletion of $deleted invalidates move without resurrection',
      () async {
        final deletion = store.delete(deleted);
        final move = store.move('C', 'A', before: true);
        final check = expectLater(move, throwsStateError);
        await deletion;
        await check;
        expect(ids(), isNot(contains(deleted)));
      },
    );
  }

  for (final filename in ['appdata.json', 'syncdata.json']) {
    test(
      'real $filename failure compensates order preserving concurrent CRUD and unrelated fields',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        var calls = 0;
        final obstacle = Directory('${root.path}/$filename.tmp')..createSync();
        final hook = WriteHooks((path, _) async {
          if (path == '${root.path}/$filename.tmp' && calls++ == 0) {
            appdata.settings['readerModePresets'] = [
              for (final p in store.list)
                if (p.id != 'A')
                  {
                    ...p.toJson(),
                    if (p.id == 'B') 'name': 'Concurrent',
                    'values': {
                      ...p.values,
                      if (p.id == 'B') 'readerSideMargin': 22,
                    },
                  },
              {
                'id': 'D',
                'name': 'New',
                'values': {'readerSideMargin': 7},
              },
            ];
            appdata.settings['language'] = 'zh_TW';
            entered.complete();
          } else if (path.endsWith('.tmp') && calls <= 1) {
            await release.future;
          }
        });
        final moving = IOOverrides.runWithIOOverrides(
          () => store.move('C', 'B', before: true),
          hook,
        );
        final check = expectLater(
          moving,
          throwsA(
            isA<SettingsRecoveryFailure>().having(
              (e) => e.incomplete,
              'recovered',
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
        await check;
        expect(ids(), ['B', 'C', 'D']);
        expect(store.list.first.name, 'Concurrent');
        expect(store.list.first.values['readerSideMargin'], 22);
        expect(appdata.settings['language'], 'zh_TW');
        expect(comic.selectedId, 'B');
        for (final file in ['appdata.json', 'syncdata.json']) {
          expect(
            (disk(file)['settings']['readerModePresets'] as List).map(
              (p) => p['id'],
            ),
            ['B', 'C', 'D'],
          );
          expect(disk(file)['settings']['language'], 'zh_TW');
        }
        await appdata.loadDataForTesting(root.path);
        expect(ids(), ['B', 'C', 'D']);
      },
    );
  }

  test(
    'incomplete compensation blocks reordering across stores; retry saves current valid state without replay',
    () async {
      final obstacle = Directory('${root.path}/syncdata.json.tmp')
        ..createSync();
      await expectLater(
        store.move('C', 'A', before: true),
        throwsA(
          isA<SettingsRecoveryFailure>().having(
            (e) => e.incomplete,
            'incomplete',
            true,
          ),
        ),
      );
      expect(ids(), ['A', 'B', 'C']);
      expect(const ReaderPresetStore().orderRecovery, isNotNull);
      expect(comic.selectedId, 'B');
      await expectLater(
        comic.move('B', 'A', before: true),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(
        store.retryOrderRecovery(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      // Non-order ownership may still make legitimate changes while paused.
      appdata.settings['language'] = 'zh_TW';
      appdata.settings['readerModePresets'] = [
        for (final p in store.list)
          {...p.toJson(), if (p.id == 'A') 'name': 'Updated'},
      ];
      obstacle.deleteSync();
      await store.retryOrderRecovery();
      expect(store.orderRecovery, isNull);
      expect(ids(), ['A', 'B', 'C']);
      expect(store.list.first.name, 'Updated');
      for (final file in ['appdata.json', 'syncdata.json']) {
        expect(disk(file)['settings']['language'], 'zh_TW');
        expect(
          (disk(file)['settings']['readerModePresets'] as List).first['id'],
          'A',
        );
      }
    },
  );

  test('later order takeover survives failed order compensation', () async {
    var once = false;
    final hook = WriteHooks((path, _) async {
      if (path.endsWith('syncdata.json.tmp') && !once) {
        once = true;
        final byId = {for (final p in store.list) p.id: p.toJson()};
        appdata.settings['readerModePresets'] = [
          byId['B'],
          byId['C'],
          byId['A'],
        ];
        throw const FileSystemException('one-shot');
      }
    });
    await expectLater(
      IOOverrides.runWithIOOverrides(
        () => store.move('C', 'A', before: true),
        hook,
      ),
      throwsA(isA<SettingsRecoveryFailure>()),
    );
    expect(ids(), ['B', 'C', 'A']);
  });

  test(
    'directory switch while queued rejects original owner without writing new library',
    () async {
      final owner = store.capture();
      final other = Directory('${root.path}/other')..createSync();
      final entered = Completer<void>(), release = Completer<void>();
      final barrier = appdata.runPersistenceMaintenance((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final move = owner.move('C', 'A', before: true);
      final check = expectLater(move, throwsStateError);
      App.dataPath = other.path;
      release.complete();
      await barrier;
      await check;
      expect(other.listSync(), isEmpty);
      expect(ids(), ['A', 'B', 'C']);
      App.dataPath = root.path;
    },
  );

  test(
    'directory switch during failed IO defers owned order rollback to original directory',
    () async {
      final owner = store.capture();
      final other = Directory('${root.path}/other')..createSync();
      final hook = WriteHooks((path, _) async {
        if (path.endsWith('syncdata.json.tmp')) {
          App.dataPath = other.path;
          throw const FileSystemException('directory switched');
        }
      });
      await expectLater(
        IOOverrides.runWithIOOverrides(
          () => owner.move('C', 'A', before: true),
          hook,
        ),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      expect(other.listSync(), isEmpty);
      await expectLater(owner.retryOrderRecovery(), throwsStateError);
      expect(other.listSync(), isEmpty);
      App.dataPath = root.path;
      await store.retryOrderRecovery();
      expect(ids(), ['A', 'B', 'C']);
      expect(comic.selectedId, 'B');
    },
  );
}
