import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_layout.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  App.dataPath = App.cachePath = Directory.systemTemp.path;
  late Directory root;
  late Map previous;
  late String oldPath;
  const global = ReaderPresetStore();
  const comic = ReaderPresetStore(
    scope: ReaderPreferenceScope.comic,
    comicId: 'book',
    sourceKey: 'local',
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('reader-presets-');
    oldPath = App.dataPath;
    previous = jsonDecode(jsonEncode(appdata.toJson()['settings'])) as Map;
    App.dataPath = root.path;
    appdata.settings.resetGlobalReaderSettings();
    appdata.settings['deviceId'] = 'preset-test';
    appdata.settings['deviceSpecificSettings'] = <String, dynamic>{};
    appdata.settings['comicSpecificSettings'] = <String, dynamic>{};
    appdata.settings['comicLayoutDetections'] = <String, dynamic>{};
    appdata.settings['readerModePresets'] = <dynamic>[];
    appdata.settings['disableSyncFields'] = '';
  });
  tearDown(() {
    previous.forEach((key, value) => appdata.settings[key] = value);
    App.dataPath = oldPath;
    root.deleteSync(recursive: true);
  });

  test(
    'CRUD preserves order, identity and JSON across reload; delete keeps applied values',
    () async {
      appdata.settings['readerSideMargin'] = 12;
      final first = await global.createFromCurrent('  Manga  ');
      final second = await global.createFromCurrent('Strip');
      expect(first.name, 'Manga');
      await global.rename(first.id, 'Renamed');
      expect(global.list.map((p) => p.id), [first.id, second.id]);
      appdata.settings['readerSideMargin'] = 25;
      await global.updateFromCurrent(first.id);
      expect(global.list.first.values['readerSideMargin'], 25);
      appdata.settings['readerSideMargin'] = 0;
      await global.apply(first.id, ReaderPreferenceScope.global);
      await global.delete(first.id);
      expect(appdata.settings['readerSideMargin'], 25);
      expect(global.list.single.id, second.id);
      final json =
          jsonDecode(File('${root.path}/appdata.json').readAsStringSync())
              as Map;
      expect(json['settings']['readerModePresets'], isList);
      appdata.settings['readerModePresets'] = [];
      appdata.settings['readerModePresets'] =
          json['settings']['readerModePresets'];
      expect(global.list.single.id, second.id);
      expect(
        () => global.list.single.values['readerMode'] = 'invalid',
        throwsUnsupportedError,
      );
    },
  );

  test(
    'names are trimmed, nonempty, at most 30 Unicode characters, unique ignoring case',
    () async {
      final first = await global.createFromCurrent('Manga');
      final duplicate = isA<ReaderPresetNameError>().having(
        (e) => e.messageKey,
        'key',
        'This preset name is already used',
      );
      await expectLater(
        global.createFromCurrent('  manga '),
        throwsA(duplicate),
      );
      await expectLater(
        global.rename(first.id, ' \n '),
        throwsA(isA<ReaderPresetNameError>()),
      );
      await expectLater(
        global.createFromCurrent('a' * 31),
        throwsA(isA<ReaderPresetNameError>()),
      );
      await global.createFromCurrent('😀' * 30);
      await global.rename(first.id, ' MANGA ');
      expect(global.list.first.name, 'MANGA');
      final other = await global.createFromCurrent('Other');
      await expectLater(global.rename(other.id, 'manga'), throwsA(duplicate));
      expect(global.list.last.name, 'Other');
    },
  );

  test('serialized concurrent creates cannot admit a duplicate name', () async {
    final outcomes = await Future.wait([
      for (final name in ['Same', 'same'])
        global
            .createFromCurrent(name)
            .then<Object>((p) => p, onError: (Object e) => e),
    ]);
    expect(outcomes.whereType<ReaderPreset>(), hasLength(1));
    expect(outcomes.whereType<ReaderPresetNameError>(), hasLength(1));
    expect(global.list, hasLength(1));
  });

  test(
    'snapshot contains exactly the 19 contract keys and resolved comic auto mode',
    () async {
      const keys = {
        'readerMode',
        'autoReaderMode',
        'pagedReaderMode',
        'longStripReaderMode',
        'readerScreenPicNumberForPortrait',
        'readerScreenPicNumberForLandscape',
        'showSingleImageOnFirstPage',
        'limitImageWidth',
        'readerSideMargin',
        'splitDualPage',
        'splitDualPageInvert',
        'enablePageAnimation',
        'enableTapToTurnPages',
        'reverseTapToTurnPages',
        'enableDoubleTapToZoom',
        'longPressAction',
        'longPressZoomPosition',
        'quickCollectImage',
        'enableTurnPageByVolumeKey',
      };
      appdata.settings['autoReaderMode'] = true;
      appdata.settings['readerMode'] = 'galleryLeftToRight';
      appdata.settings['longStripReaderMode'] = 'continuousTopToBottom';
      appdata.settings.setComicLayout(
        'book',
        'local',
        const ComicLayoutDetection(ComicLayout.longStrip, 6),
      );
      final preset = await comic.createFromCurrent('Resolved');
      expect(readerPresetPreferences, hasLength(19));
      expect(preset.values.keys.toSet(), keys);
      expect(preset.values['readerMode'], 'continuousTopToBottom');
      expect(preset.values['autoReaderMode'], false);
      expect(appdata.settings['autoReaderMode'], true);
      appdata.settings.setComicReaderModeOverride(
        'book',
        'local',
        'galleryRightToLeft',
      );
      await comic.updateFromCurrent(preset.id);
      expect(comic.list.single.values['readerMode'], 'galleryRightToLeft');
    },
  );

  for (final scope in [
    ReaderPreferenceScope.global,
    ReaderPreferenceScope.device,
    ReaderPreferenceScope.comic,
  ]) {
    test(
      'apply writes $scope, activates explicit layer and leaves excluded settings untouched',
      () async {
        appdata.settings['readerMode'] = 'galleryRightToLeft';
        appdata.settings['readerSideMargin'] = 18;
        final preset = await global.createFromCurrent('Preset');
        appdata.settings['readerMode'] = 'waterfallTopToBottom';
        appdata.settings['readerSideMargin'] = 0;
        appdata.settings['readerBrightness'] = 70;
        appdata.settings['readerThumbnailState'] = 'collapsed';
        appdata.settings['autoReaderMode'] = true;
        final changed = await comic.apply(preset.id, scope);
        final scoped = ReaderPreferenceStore(
          settings: appdata.settings,
          scope: scope,
          comicId: 'book',
          sourceKey: 'local',
        );
        expect(changed.toSet(), preset.values.keys.toSet());
        expect(scoped.read(ReaderPreferences.readerSideMargin), 18);
        expect(scoped.read(ReaderPreferences.readerMode), 'galleryRightToLeft');
        expect(scoped.read(ReaderPreferences.readerBrightness), 70);
        expect(
          scoped.read(ReaderPreferences.readerThumbnailState),
          'collapsed',
        );
        if (scope == ReaderPreferenceScope.comic) {
          expect(
            appdata.settings.comicReaderModeOverride('book', 'local'),
            'galleryRightToLeft',
          );
          expect(
            appdata.settings.isComicSpecificSettingsEnabled('book', 'local'),
            true,
          );
        }
        if (scope == ReaderPreferenceScope.device) {
          expect(appdata.settings.isDeviceSpecificSettingsEnabled(), true);
        }
        if (scope != ReaderPreferenceScope.global) {
          expect(appdata.settings['readerSideMargin'], 0);
          expect(appdata.settings['readerMode'], 'waterfallTopToBottom');
        }
      },
    );
  }

  test(
    'partial values do not fill missing fields or apply foreign keys',
    () async {
      appdata.settings['readerModePresets'] = [
        {
          'id': 'partial',
          'name': 'Partial',
          'values': {'readerSideMargin': 9, 'readerBrightness': 1},
        },
      ];
      await comic.apply('partial', ReaderPreferenceScope.comic);
      expect(appdata.settings.comicReaderModeOverride('book', 'local'), isNull);
      expect(
        appdata.settings.getReaderSetting('book', 'local', 'readerSideMargin'),
        9,
      );
      expect(
        appdata.settings.getReaderSetting('book', 'local', 'readerBrightness'),
        50,
      );
      expect(
        await comic.apply('missing', ReaderPreferenceScope.comic),
        isEmpty,
      );
    },
  );

  test(
    'device snapshot reads enabled layer and inherited fallback, not comic values',
    () async {
      appdata.settings['readerSideMargin'] = 3;
      appdata.settings.setDeviceReaderSetting('readerSideMargin', 11);
      appdata.settings.setDeviceReaderSetting(
        'readerMode',
        'galleryTopToBottom',
      );
      appdata.settings.setEnabledDeviceSpecificSettings(true);
      appdata.settings.setReaderSetting(
        'book',
        'local',
        'readerSideMargin',
        29,
      );
      appdata.settings.setEnabledComicSpecificSettings('book', 'local', true);
      const device = ReaderPresetStore(scope: ReaderPreferenceScope.device);
      final preset = await device.createFromCurrent('Device');
      expect(preset.values['readerSideMargin'], 11);
      expect(preset.values['readerMode'], 'galleryTopToBottom');
      expect(preset.values['enableTapToTurnPages'], true);
      expect(
        (await global.createFromCurrent('Global')).values['readerSideMargin'],
        3,
      );
    },
  );
}
