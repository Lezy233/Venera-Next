import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppdataImportCheckpoint before;
  late ReaderPreset old, next;
  const store = ReaderPresetStore();
  Map disk(String name) =>
      jsonDecode(File('${root.path}/$name').readAsStringSync()) as Map;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('b3-recovery-');
    App.dataPath = App.cachePath = root.path;
    before = appdata.captureImportCheckpoint();
    appdata.settings['readerPresetSelections'] = {};
    appdata.settings['readerModePresets'] = [];
    appdata.settings['disableSyncFields'] = 'proxy';
    appdata.settings['deviceId'] = 'b3';
    appdata.settings['deviceSpecificSettings'] = {};
    appdata.settings['comicSpecificSettings'] = {};
    appdata.settings['readerSideMargin'] = 0;
    old = await store.createFromCurrent('Old');
    appdata.settings['readerSideMargin'] = 16;
    next = await store.createFromCurrent('New');
    await store.apply(old.id, ReaderPreferenceScope.global);
  });
  tearDown(() async {
    await appdata.restoreImportCheckpoint(before, persist: false);
    root.deleteSync(recursive: true);
  });

  Future<void> editMargin(num value) => appdata.updateSettings(
    (draft) => ReaderPreferenceStore(
      settings: draft,
      scope: ReaderPreferenceScope.global,
    ).write(ReaderPreferences.readerSideMargin, value),
  );

  const shared = ReaderPresetStore(
    scope: ReaderPreferenceScope.comic,
    comicId: 'shared',
    sourceKey: 'source',
  );

  for (final name in ['appdata.json', 'syncdata.json']) {
    test(
      'B3 shared partial field real $name failure restores absence and both files',
      () async {
        appdata.settings['readerModePresets'] = [
          {
            'id': 'partial',
            'name': 'Partial',
            'values': {'readerMode': 'galleryRightToLeft'},
          },
        ];
        await store.apply('partial', store.scope);
        await shared.apply('partial', shared.scope);
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
        final editing = IOOverrides.runWithIOOverrides(
          () => editMargin(25),
          hook,
        );
        final checking = expectLater(
          editing,
          throwsA(
            isA<SettingsRecoveryFailure>().having(
              (e) => e.incomplete,
              'compensation completed',
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
        expect(store.selectedId, 'partial');
        expect(shared.selectedId, 'partial');
        expect(store.list.single.values.containsKey('readerSideMargin'), false);
        expect(
          appdata.settings.readerSettings('shared', 'source').readerSideMargin,
          0,
        );
        for (final file in ['appdata.json', 'syncdata.json']) {
          final settings = disk(file)['settings'];
          expect(
            (settings['readerModePresets'] as List).single['values']
                .containsKey('readerSideMargin'),
            false,
          );
          expect(
            settings['readerPresetSelections'][store.selectionKey],
            'partial',
          );
        }
        await appdata.loadDataForTesting(root.path);
        expect(store.selectedId, 'partial');
        expect(store.list.single.values.containsKey('readerSideMargin'), false);
      },
    );
  }

  test(
    'B3 shared field compensation retains concurrent rename, other fields, other preset and takeover',
    () async {
      await shared.apply(old.id, shared.scope);
      var calls = 0;
      final hook = WriteHooks((path, _) async {
        if (path.endsWith('syncdata.json.tmp') && calls++ == 0) {
          // Synchronous competing publishers model changes while native IO is
          // suspended. The field-level rollback must never replace the library.
          appdata.settings['readerModePresets'] = [
            for (final p in store.list)
              {
                ...p.toJson(),
                'name': p.id == old.id ? 'Concurrent rename' : p.name,
                'values': {
                  ...p.values,
                  if (p.id == old.id) 'readerSideMargin': 23,
                  if (p.id == old.id) 'enablePageAnimation': false,
                  if (p.id == next.id) 'readerSideMargin': 7,
                },
              },
          ];
          appdata.settings['language'] = 'zh_TW';
          throw const FileSystemException('one-shot');
        }
      });
      await expectLater(
        IOOverrides.runWithIOOverrides(() => editMargin(16), hook),
        throwsA(
          isA<SettingsRecoveryFailure>().having(
            (e) => e.incomplete,
            'recovered',
            false,
          ),
        ),
      );
      expect(store.selectedId, old.id);
      expect(shared.selectedId, old.id);
      final current = store.list.firstWhere((p) => p.id == old.id);
      expect(current.name, 'Concurrent rename');
      expect(current.values['readerSideMargin'], 23);
      expect(current.values['enablePageAnimation'], false);
      expect(
        store.list
            .firstWhere((p) => p.id == next.id)
            .values['readerSideMargin'],
        7,
      );
      expect(
        appdata.settings.readerSettings('shared', 'source').readerSideMargin,
        23,
      );
      await appdata.loadDataForTesting(root.path);
      expect(
        appdata.settings.readerSettings('shared', 'source').readerSideMargin,
        23,
      );
    },
  );

  test(
    'B3 shared recovery pauses dependent targets and retries without replay',
    () async {
      await shared.apply(old.id, shared.scope);
      final obstacle = Directory('${root.path}/syncdata.json.tmp')
        ..createSync();
      await expectLater(
        editMargin(17),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      expect(store.selectedId, isNull);
      expect(shared.selectedId, isNull);
      expect(shared.recovery, isNotNull);
      expect(
        appdata.settings.readerSettings('shared', 'source').readerSideMargin,
        0,
      );
      await expectLater(
        shared.clearSelection(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(
        shared.reset(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(
        store.delete(old.id),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(
        shared.apply(next.id, shared.scope),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(
        shared.retryRecovery(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      obstacle.deleteSync();
      const independent = ReaderPresetStore(
        scope: ReaderPreferenceScope.comic,
        comicId: 'independent',
        sourceKey: 'source',
      );
      await independent.apply(next.id, independent.scope);
      expect(independent.selectedId, next.id);
      await shared.retryRecovery();
      expect(store.recovery, isNull);
      expect(shared.recovery, isNull);
      expect(store.selectedId, old.id);
      expect(shared.selectedId, old.id);
      expect(store.list.first.values['readerSideMargin'], 0);
      await appdata.loadDataForTesting(root.path);
      expect(
        appdata.settings.readerSettings('shared', 'source').readerSideMargin,
        0,
      );
      await editMargin(17);
      expect(
        appdata.settings.readerSettings('shared', 'source').readerSideMargin,
        17,
      );
    },
  );

  for (final action in ['None', 'delete', 'update']) {
    test(
      'B3 shared $action failure restores bindings and latest effect',
      () async {
        await shared.apply(old.id, shared.scope);
        await editMargin(11);
        final obstacle = Directory('${root.path}/appdata.json.tmp')
          ..createSync();
        final operation = switch (action) {
          'None' => shared.clearSelection(),
          'delete' => store.delete(old.id),
          _ => store.updateFromCurrent(old.id),
        };
        await expectLater(operation, throwsA(isA<SettingsRecoveryFailure>()));
        expect(appdata.settings.readerPresetId(store.selectionKey), old.id);
        expect(appdata.settings.readerPresetId(shared.selectionKey), old.id);
        expect(store.list.first.values['readerSideMargin'], 11);
        expect(
          appdata.settings.readerSettings('shared', 'source').readerSideMargin,
          11,
        );
        obstacle.deleteSync();
        await (action == 'None' ? shared : store).retryRecovery();
        await appdata.loadDataForTesting(root.path);
        expect(store.selectedId, old.id);
        expect(shared.selectedId, old.id);
        expect(
          appdata.settings.readerSettings('shared', 'source').readerSideMargin,
          11,
        );
      },
    );
  }

  for (final blockedName in ['appdata.json', 'syncdata.json']) {
    test(
      'B3 real one-shot $blockedName failure compensates both files',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        var writes = 0;
        final blocked = Directory('${root.path}/$blockedName.tmp')
          ..createSync();
        final hook = WriteHooks((path, _) async {
          if (path == '${root.path}/$blockedName.tmp' && writes++ == 0) {
            // Let the real native write fail; hold its peer until the obstacle
            // has been removed so the compensation has a deterministic chance.
            entered.complete();
          } else if (path.endsWith('.tmp') && writes <= 1) {
            await release.future;
          }
        });
        final applying = IOOverrides.runWithIOOverrides(
          () => store.apply(next.id, ReaderPreferenceScope.global),
          hook,
        );
        final checking = expectLater(
          applying,
          throwsA(
            isA<SettingsRecoveryFailure>().having(
              (e) => e.incomplete,
              'recovered',
              false,
            ),
          ),
        );
        await entered.future;
        // Native failure is observed through a peer barrier, not a timer guess.
        while (!hook.failed) {
          await Future<void>.delayed(Duration.zero);
        }
        blocked.deleteSync();
        release.complete();
        await checking;
        expect(store.recovery, isNull);
        expect(store.selectedId, old.id);
        for (final name in ['appdata.json', 'syncdata.json']) {
          expect(disk(name)['settings']['readerSideMargin'], 0);
          expect(
            disk(
              name,
            )['settings']['readerPresetSelections'][store.selectionKey],
            old.id,
          );
        }
        expect(disk('syncdata.json')['settings'].containsKey('proxy'), false);
        await appdata.loadDataForTesting(root.path);
        expect(store.selectedId, old.id);
      },
    );
  }

  test(
    'B3 repeated real failure pauses only target; retry restores without applying',
    () async {
      final blocked = Directory('${root.path}/syncdata.json.tmp')..createSync();
      await expectLater(
        store.apply(next.id, ReaderPreferenceScope.global),
        throwsA(
          isA<SettingsRecoveryFailure>().having(
            (e) => e.incomplete,
            'incomplete',
            true,
          ),
        ),
      );
      expect(appdata.settings['readerSideMargin'], 0);
      expect(store.recovery!.initialError, isA<FileSystemException>());
      expect(store.recovery!.recoveryError, isA<FileSystemException>());
      expect(store.selectedId, isNull);
      await expectLater(
        store.clearSelection(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      await expectLater(store.reset(), throwsA(isA<SettingsRecoveryFailure>()));
      await expectLater(
        store.retryRecovery(),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      blocked.deleteSync();
      const comic = ReaderPresetStore(
        scope: ReaderPreferenceScope.comic,
        comicId: '1',
        sourceKey: 's',
      );
      await expectLater(
        comic.apply(next.id, ReaderPreferenceScope.comic),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      final independent = await store.createFromCurrent('Independent');
      await comic.apply(independent.id, ReaderPreferenceScope.comic);
      expect(comic.selectedId, independent.id);
      expect(store.selectedId, isNull);
      await store.retryRecovery();
      expect(store.recovery, isNull);
      expect(store.selectedId, old.id);
      expect(appdata.settings['readerSideMargin'], 0);
      await store.apply(next.id, ReaderPreferenceScope.global);
      expect(store.selectedId, next.id);
    },
  );

  test(
    'B3 compensation preserves unrelated edits, same-field takeover, current projection',
    () async {
      // Exercise independent materialized ownership; shared-preset field
      // takeover is covered separately by the binding recovery matrix.
      await store.clearSelection();
      var calls = 0;
      final hook = WriteHooks((path, _) async {
        if (path.endsWith('syncdata.json.tmp') && calls++ == 0) {
          appdata.settings['readerSideMargin'] = 23;
          appdata.settings['language'] = 'zh_TW';
          appdata.settings['disableSyncFields'] = 'language';
          appdata.settings.setReaderSetting(
            'other',
            'source',
            'readerSideMargin',
            31,
          );
          throw const FileSystemException('one-shot');
        }
      });
      await expectLater(
        IOOverrides.runWithIOOverrides(
          () => store.apply(next.id, ReaderPreferenceScope.global),
          hook,
        ),
        throwsA(
          isA<SettingsRecoveryFailure>().having(
            (e) => e.incomplete,
            'recovered',
            false,
          ),
        ),
      );
      expect(appdata.settings['readerSideMargin'], 23);
      expect(appdata.settings['language'], 'zh_TW');
      expect(
        appdata.settings.getReaderSetting(
          'other',
          'source',
          'readerSideMargin',
        ),
        23,
      ); // disabled layer
      expect(
        (appdata.settings['comicSpecificSettings']
            as Map)['other@source']['readerSideMargin'],
        31,
      );
      expect(disk('appdata.json')['settings']['readerSideMargin'], 23);
      expect(disk('syncdata.json')['settings'].containsKey('language'), false);
      expect(disk('syncdata.json')['settings'].containsKey('proxy'), true);
    },
  );

  test(
    'B3 absence and original device identity are restored after first failed device apply',
    () async {
      appdata.settings['deviceId'] = '';
      const device = ReaderPresetStore(scope: ReaderPreferenceScope.device);
      final blocked = Directory('${root.path}/appdata.json.tmp')..createSync();
      await expectLater(
        device.apply(next.id, ReaderPreferenceScope.device),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      expect(appdata.settings['deviceId'], '');
      expect(appdata.settings['deviceSpecificSettings'], isEmpty);
      expect(device.recovery, isNotNull);
      blocked.deleteSync();
      await device.retryRecovery();
      expect(device.recovery, isNull);
      expect(appdata.settings['deviceId'], '');
    },
  );

  for (final operation in ['None', 'reset']) {
    test(
      'B3 failed $operation restores previous reference and parameters',
      () async {
        final blocked = Directory('${root.path}/appdata.json.tmp')
          ..createSync();
        await expectLater(
          operation == 'None' ? store.clearSelection() : store.reset(),
          throwsA(isA<SettingsRecoveryFailure>()),
        );
        expect(
          appdata.settings['readerPresetSelections'][store.selectionKey],
          old.id,
        );
        expect(appdata.settings['readerSideMargin'], 0);
        blocked.deleteSync();
        await store.retryRecovery();
        expect(store.selectedId, old.id);
      },
    );
  }

  test('B3 fault exit boundary loads actual primary without replay', () async {
    final blocked = Directory('${root.path}/syncdata.json.tmp')..createSync();
    await expectLater(
      store.apply(next.id, ReaderPreferenceScope.global),
      throwsA(isA<SettingsRecoveryFailure>()),
    );
    final primary = disk('appdata.json');
    // Possible disk state after force-exit during failed compensation.
    primary['settings']['readerSideMargin'] = 16;
    primary['settings']['readerPresetSelections'][store.selectionKey] = next.id;
    final fresh = Directory('${root.path}/fresh-process')..createSync();
    File('${fresh.path}/appdata.json').writeAsStringSync(jsonEncode(primary));
    App.dataPath = fresh.path;
    await appdata.loadDataForTesting(fresh.path);
    expect(store.recovery, isNull);
    expect(store.selectedId, next.id);
    expect(appdata.settings['readerSideMargin'], 16);
    blocked.deleteSync();
    App.dataPath = root.path;
  });

  test(
    'B3 directory switch during failure never compensates into new directory',
    () async {
      final other = Directory('${root.path}/other')..createSync();
      final original = App.dataPath;
      final owner = store.capture();
      final hook = WriteHooks((path, _) async {
        if (path.endsWith('syncdata.json.tmp')) {
          App.dataPath = other.path;
          throw const FileSystemException('directory switched');
        }
      });
      await expectLater(
        IOOverrides.runWithIOOverrides(
          () => owner.apply(next.id, ReaderPreferenceScope.global),
          hook,
        ),
        throwsA(isA<SettingsRecoveryFailure>()),
      );
      expect(other.listSync(), isEmpty);
      await expectLater(owner.retryRecovery(), throwsStateError);
      expect(other.listSync(), isEmpty);
      App.dataPath = original;
      await store.retryRecovery();
      expect(store.selectedId, old.id);
      expect(appdata.settings['readerSideMargin'], 0);
    },
  );
}

/// Real File IO with an optional boundary hook. Exposes native failure arrival
/// to remove a one-shot obstacle without racing the compensation write.
final class WriteHooks extends IOOverrides {
  WriteHooks(this.beforeWrite);
  final Future<void> Function(String, String) beforeWrite;
  bool failed = false;
  @override
  File createFile(String path) => HookedFile(super.createFile(path), this);
}

class HookedFile implements File {
  HookedFile(this.raw, this.hooks);
  final File raw;
  final WriteHooks hooks;
  @override
  String get path => raw.path;
  @override
  Directory get parent => raw.parent;
  @override
  Future<bool> exists() => raw.exists();
  @override
  Future<File> copy(String path) => raw.copy(path);
  @override
  Future<File> rename(String path) => raw.rename(path);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      raw.delete(recursive: recursive);
  @override
  Future<File> writeAsString(
    String content, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    await hooks.beforeWrite(path, content);
    try {
      return await raw.writeAsString(
        content,
        mode: mode,
        encoding: encoding,
        flush: flush,
      );
    } catch (_) {
      hooks.failed = true;
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
