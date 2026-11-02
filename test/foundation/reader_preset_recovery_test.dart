import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';

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
      await comic.apply(next.id, ReaderPreferenceScope.comic);
      expect(comic.selectedId, next.id);
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
