import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/search/search_page.dart';
import 'package:venera_next/features/search/search_result_page.dart';
import 'package:venera_next/features/search/aggregated_search_page.dart';
import 'package:venera_next/features/search/search_selection.dart';
import 'package:venera_next/features/search/search_profile.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import '../../support/creator_search_source.dart';
import '../../foundation/reader_preset_recovery_test.dart' show WriteHooks;

void main() {
  late Directory root;
  late Map<String, dynamic> previous;
  late List<CreatorSearchSource> sources;
  setUp(() {
    root = Directory.systemTemp.createTempSync('target-memory-');
    App.dataPath = App.cachePath = root.path;
    App.isInitialized = false;
    previous = Map.from(appdata.toJson()['settings'] as Map);
    appdata.settings['searchSelection'] = null;
    appdata.settings['language'] = 'en-US';
    appdata.settings['searchProfiles'] = [];
    appdata.settings['defaultSearchProfile'] = null;
    appdata.settings['autoAddLanguageFilter'] = 'none';
    appdata.settings['comicListDisplayMode'] = 'paging';
    appdata.settings['searchSources'] = ['a', 'b'];
    appdata.settings['defaultSearchTarget'] = 'a';
    sources = [
      CreatorSearchSource('a', displayName: 'Platform A'),
      CreatorSearchSource('b', displayName: 'Platform B'),
    ];
    configureComicSourceRegistry(
      all: () => sources,
      find: (key) => sources.where((e) => e.key == key).firstOrNull,
      fromIntKey: (_) => null,
      isEmpty: () => sources.isEmpty,
    );
  });
  tearDown(() {
    previous.forEach((k, v) => appdata.settings[k] = v);
    appdata.settings['searchSelection'] = previous['searchSelection'];
    configureComicSourceRegistry(
      all: () => [],
      find: (_) => null,
      fromIntKey: (_) => null,
      isEmpty: () => true,
    );
    App.dataPath = Directory.systemTemp.path;
    root.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchPage()));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
  }

  void profile(String id, String name, {String option = 'other'}) {
    appdata.settings['searchProfiles'] = [
      SearchProfile(
        id: id,
        name: name,
        sources: [
          SearchProfileSource(sourceKey: 'b', enabled: true, options: [option]),
        ],
      ).toJson(),
    ];
  }

  Future<void> selectProfile(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButton<String?>));
    await settle(tester);
    await tester.tap(find.text(name).last);
    await settle(tester);
  }

  for (final width in [375.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('$width $brightness keyboard selection has no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        profile('p', 'Plan B');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const SearchPage(),
          ),
        );
        await settle(tester);
        // Reach and activate the production checkbox using keyboard focus.
        final checkbox = find.byType(Checkbox);
        Focus.of(tester.element(checkbox)).requestFocus();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await settle(tester);
        await tester.tap(checkbox);
        await settle(tester);
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        tester.widget<Checkbox>(checkbox).focusNode!.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await settle(tester);
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await settle(tester);
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        await selectProfile(tester, 'Plan B');
        await tester.enterText(find.byType(TextField).first, 'Keyboard query');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  }

  testWidgets(
    'registry removal falls back and source rename retains temporary options',
    (tester) async {
      appdata.settings['searchSelection'] = const SearchSelection(
        aggregated: false,
        sourceKey: 'b',
        profileId: null,
      ).toJson();
      await open(tester);
      await tester.tap(find.text('Other'));
      await settle(tester);
      sources[1] = CreatorSearchSource('b', displayName: 'Renamed source');
      appdata.settings.notifyListeners();
      await settle(tester);
      expect(find.text('Renamed source'), findsOneWidget);
      expect(
        tester
            .widget<SearchOptionWidget>(find.byType(SearchOptionWidget))
            .value,
        'other',
      );
      sources.removeLast();
      appdata.settings.notifyListeners();
      await settle(tester);
      expect(
        find.text('Last search source unavailable; using Platform A'),
        findsOneWidget,
      );
      await tester.tap(find.text('Platform A'));
      await settle(tester);
      expect(
        find.textContaining('Last search source unavailable'),
        findsNothing,
      );
      expect((appdata.settings['searchSelection'] as Map)['sourceKey'], 'a');
      await close(tester);
    },
  );

  testWidgets(
    'explicit ordinary result parameters and unchanged return never overwrite memory',
    (tester) async {
      const selection = SearchSelection(
        aggregated: true,
        sourceKey: 'b',
        profileId: 'p',
      );
      profile('p', 'Plan B');
      appdata.settings['searchSelection'] = selection.toJson();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchResultPage(
              text: 'Explicit creator',
              sourceKey: 'a',
              options: ['other'],
            ),
          ),
        ),
      );
      await settle(tester);
      expect(sources.first.requests.single.$1, 'Explicit creator');
      expect(sources.first.requests.single.$3, ['other']);
      expect(sources.last.requests, isEmpty);
      expect(appdata.settings['searchSelection'], selection.toJson());
      await close(tester);
      await open(tester);
      await close(tester);
      expect(appdata.settings['searchSelection'], selection.toJson());
    },
  );

  testWidgets(
    'disk reload restores durable selection without temporary query/options',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Platform B'));
      await settle(tester);
      await close(tester);
      appdata.settings['searchSelection'] = null;
      await tester.runAsync(() => appdata.loadDataForTesting(root.path));
      await open(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      await submit(tester, 'Disk restored');
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'b',
      );
      expect(sources.last.requests, hasLength(1));
      await close(tester);
    },
  );

  testWidgets(
    'aggregate profile survives reopen and routes exact profile/options once',
    (tester) async {
      profile('p', 'Plan B');
      await open(tester);
      await selectProfile(tester, 'Plan B');
      await close(tester);
      await open(tester);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(
        tester
            .widget<DropdownButton<String?>>(
              find.byType(DropdownButton<String?>),
            )
            .value,
        'p',
      );
      await submit(tester, 'Plan query');
      expect(
        tester
            .widget<AggregatedSearchPage>(find.byType(AggregatedSearchPage))
            .profileId,
        'p',
      );
      expect(sources.first.requests, isEmpty);
      expect(sources.last.requests, hasLength(1));
      expect(sources.last.requests.single.$3, ['other']);
      await close(tester);
    },
  );

  testWidgets(
    'explicit null beats changed default and mode switches retain last source',
    (tester) async {
      profile('p', 'Default plan');
      appdata.settings['defaultSearchProfile'] = 'p';
      await open(tester);
      await tester.tap(find.text('Platform B'));
      await settle(tester);
      await selectProfile(tester, 'Global settings');
      await tester.tap(find.byType(Checkbox));
      await settle(tester);
      await close(tester);
      appdata.settings['defaultSearchTarget'] = '_aggregated_';
      await open(tester);
      expect(
        tester
            .widget<DropdownButton<String?>>(
              find.byType(DropdownButton<String?>),
            )
            .value,
        isNull,
      );
      await tester.tap(find.byType(Checkbox));
      await settle(tester);
      await submit(tester, 'Single');
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'b',
      );
      expect(appdata.settings['defaultSearchTarget'], '_aggregated_');
      expect(appdata.settings['defaultSearchProfile'], 'p');
      await close(tester);
    },
  );

  testWidgets(
    'live same-name key fallback restore and empty sources never request',
    (tester) async {
      sources = [
        CreatorSearchSource('a', displayName: 'Same'),
        CreatorSearchSource('b', displayName: 'Same'),
      ];
      appdata.settings['searchSelection'] = const SearchSelection(
        aggregated: false,
        sourceKey: 'b',
        profileId: null,
      ).toJson();
      await open(tester);
      appdata.settings['searchSources'] = ['a'];
      await settle(tester);
      expect(
        find.text('Last search source unavailable; using Same'),
        findsOneWidget,
      );
      expect((appdata.settings['searchSelection'] as Map)['sourceKey'], 'b');
      appdata.settings['searchSources'] = [];
      await settle(tester);
      expect(find.textContaining('No Search Sources'), findsOneWidget);
      expect(sources.expand((e) => e.requests), isEmpty);
      expect(tester.takeException(), isNull);
      appdata.settings['searchSources'] = ['a', 'b'];
      await settle(tester);
      expect(
        find.textContaining('Last search source unavailable'),
        findsNothing,
      );
      await submit(tester, 'Restored');
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'b',
      );
      expect(sources.first.requests, isEmpty);
      expect(sources.last.requests, hasLength(1));
      await close(tester);
    },
  );

  testWidgets(
    'live profile deletion rename update restore uses same ID and latest contents',
    (tester) async {
      profile('p', 'Original');
      appdata.settings['searchSelection'] = const SearchSelection(
        aggregated: true,
        sourceKey: 'b',
        profileId: 'p',
      ).toJson();
      await open(tester);
      appdata.settings['searchProfiles'] = [];
      await settle(tester);
      expect(
        find.text('Last search profile unavailable; using global settings'),
        findsOneWidget,
      );
      profile('other', 'Different default');
      appdata.settings['defaultSearchProfile'] = 'other';
      await settle(tester);
      expect(
        tester
            .widget<DropdownButton<String?>>(
              find.byType(DropdownButton<String?>),
            )
            .value,
        isNull,
      );
      profile('p', 'Renamed', option: 'normal');
      await settle(tester);
      expect(find.text('Renamed'), findsOneWidget);
      expect(
        find.textContaining('Last search profile unavailable'),
        findsNothing,
      );
      await submit(tester, 'Latest');
      expect(
        tester
            .widget<AggregatedSearchPage>(find.byType(AggregatedSearchPage))
            .profileId,
        'p',
      );
      expect(sources.last.requests.single.$3, ['normal']);
      await close(tester);
    },
  );

  for (final raw in [
    null,
    7,
    {'version': 2},
    {'version': 1, 'mode': 'single', 'sourceKey': 3, 'profileId': null},
  ]) {
    testWidgets(
      'legacy malformed $raw uses defaults without initialization write',
      (tester) async {
        appdata.settings['searchSelection'] = raw;
        appdata.settings['defaultSearchTarget'] = '_aggregated_';
        profile('p', 'Default');
        appdata.settings['defaultSearchProfile'] = 'p';
        await open(tester);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
        expect(
          tester
              .widget<DropdownButton<String?>>(
                find.byType(DropdownButton<String?>),
              )
              .value,
          'p',
        );
        expect(File('${root.path}/appdata.json').existsSync(), isFalse);
        expect(appdata.settings['searchSelection'], raw);
        await close(tester);
      },
    );
  }

  testWidgets(
    'real appdata IO failure blocks choices until recovery without replay',
    (tester) async {
      await open(tester);
      final blocker = Directory('${root.path}/appdata.json')..createSync();
      await tester.tap(find.text('Platform B'));
      await settle(tester);
      expect(find.text('Save failed; recovery incomplete'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(appdata.settings['searchSelection'], isNull);
      blocker.deleteSync();
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Save failed; recovery incomplete'), findsNothing);
      final disk = jsonDecode(
        File('${root.path}/appdata.json').readAsStringSync(),
      );
      expect(disk['settings']['searchSelection'], isNull);
      expect(disk['settings']['defaultSearchTarget'], 'a');
      await submit(tester, 'Recovered');
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'a',
      );
      await close(tester);
    },
  );

  testWidgets(
    'rapid controls disable during admitted save and do not start stale query',
    (tester) async {
      await open(tester);
      final release = Completer<void>();
      final exclusive = AppDataOperations.instance.run(() => release.future);
      await tester.tap(find.text('Platform B'));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(sources.expand((e) => e.requests), isEmpty);
      release.complete();
      await settle(tester);
      await exclusive;
      await submit(tester, 'Last accepted');
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'b',
      );
      expect(sources.last.requests, hasLength(1));
      await close(tester);
    },
  );

  test(
    'queued selection cannot write replacement directory or unrelated fields',
    () async {
      final replacement = Directory.systemTemp.createTempSync('target-new-');
      final release = Completer<void>();
      final exclusive = AppDataOperations.instance.run(() => release.future);
      final saving = const SearchSelection(
        aggregated: false,
        sourceKey: 'b',
        profileId: null,
      ).save(root.path);
      final expectation = expectLater(saving, throwsStateError);
      App.dataPath = replacement.path;
      release.complete();
      await exclusive;
      await expectation;
      expect(replacement.listSync(), isEmpty);
      expect(appdata.settings['defaultSearchTarget'], 'a');
      App.dataPath = root.path;
      replacement.deleteSync();
    },
  );

  testWidgets(
    'old page queued save cannot mutate reopened page in replacement directory',
    (tester) async {
      final replacement = Directory.systemTemp.createTempSync(
        'target-new-page-',
      );
      await open(tester);
      final release = Completer<void>();
      final exclusive = AppDataOperations.instance.run(() => release.future);
      await tester.tap(find.text('Platform B'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      App.dataPath = replacement.path;
      await tester.pumpWidget(const MaterialApp(home: SearchPage()));
      release.complete();
      await settle(tester);
      await exclusive;
      expect(replacement.listSync(), isEmpty);
      expect(appdata.settings['searchSelection'], isNull);
      await submit(tester, 'New directory');
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'a',
      );
      expect(sources.last.requests, isEmpty);
      await close(tester);
      App.dataPath = root.path;
      replacement.deleteSync(recursive: true);
    },
  );

  testWidgets(
    'reopening during pending save waits for durable completion then uses B',
    (tester) async {
      await open(tester);
      final release = Completer<void>();
      final exclusive = AppDataOperations.instance.run(() => release.future);
      await tester.tap(find.text('Platform B'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: SearchPage()));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      release.complete();
      await settle(tester);
      await exclusive;
      await submit(tester, 'Reopened during write');
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'b',
      );
      expect(sources.last.requests, hasLength(1));
      await close(tester);
    },
  );

  for (final name in ['appdata.json', 'syncdata.json']) {
    test(
      'real one-shot $name error durably compensates only selection',
      () async {
        appdata.settings['disableSyncFields'] = 'proxy';
        const old = SearchSelection(
          aggregated: false,
          sourceKey: 'a',
          profileId: null,
        );
        await old.save(root.path);
        final entered = Completer<void>();
        final release = Completer<void>();
        var writes = 0;
        final obstacle = Directory('${root.path}/$name.tmp')..createSync();
        final hook = WriteHooks((path, _) async {
          if (path == '${root.path}/$name.tmp' && writes++ == 0) {
            entered.complete();
          } else if (path.endsWith('.tmp') && writes <= 1) {
            await release.future;
          }
        });
        final saving = IOOverrides.runWithIOOverrides(
          () => const SearchSelection(
            aggregated: true,
            sourceKey: 'b',
            profileId: null,
          ).save(root.path),
          hook,
        );
        final checking = expectLater(
          saving,
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
        // Concurrent unrelated settings are owned by their own writers.
        appdata.settings['language'] = 'zh-TW';
        obstacle.deleteSync();
        release.complete();
        await checking;
        for (final file in ['appdata.json', 'syncdata.json']) {
          final disk = jsonDecode(
            File('${root.path}/$file').readAsStringSync(),
          );
          expect(disk['settings']['searchSelection'], old.toJson());
          expect(disk['settings']['language'], 'zh-TW');
          expect(disk['settings']['defaultSearchTarget'], 'a');
        }
        expect(
          appdata.settingsRecovery(root.path, SearchSelection.recoveryKey),
          isNull,
        );
      },
    );
  }

  testWidgets(
    'syncdata failure is visible and recovery restores both required files',
    (tester) async {
      appdata.settings['disableSyncFields'] = 'proxy';
      await open(tester);
      final obstacle = Directory('${root.path}/syncdata.json.tmp')
        ..createSync();
      await tester.tap(find.text('Platform B'));
      await settle(tester);
      expect(find.text('Save failed; recovery incomplete'), findsOneWidget);
      expect(appdata.settings['searchSelection'], isNull);
      appdata.settings['searchSources'] = [];
      await settle(tester);
      expect(find.textContaining('No Search Sources'), findsOneWidget);
      expect(find.text('Save failed; recovery incomplete'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      obstacle.deleteSync();
      await tester.tap(find.text('Retry'));
      await settle(tester);
      for (final file in ['appdata.json', 'syncdata.json']) {
        final disk = jsonDecode(File('${root.path}/$file').readAsStringSync());
        expect(disk['settings']['searchSelection'], isNull);
      }
      await close(tester);
    },
  );

  testWidgets(
    'temporary options reset on reopen while history uses remembered source once',
    (tester) async {
      final oldHistory = List<String>.of(appdata.searchHistory);
      addTearDown(() => appdata.searchHistory = oldHistory);
      appdata.searchHistory = ['History query'];
      await open(tester);
      await tester.tap(find.text('Platform B'));
      await settle(tester);
      await tester.tap(find.text('Other'));
      await settle(tester);
      await close(tester);
      await open(tester);
      expect(
        tester
            .widget<SearchOptionWidget>(find.byType(SearchOptionWidget))
            .value,
        'normal',
      );
      await tester.ensureVisible(find.text('History query'));
      await tester.tap(find.text('History query'));
      await settle(tester);
      expect(
        tester
            .widget<SearchResultPage>(find.byType(SearchResultPage))
            .sourceKey,
        'b',
      );
      expect(sources.last.requests, hasLength(1));
      expect(sources.last.requests.single.$1, 'History query');
      expect(sources.last.requests.single.$3, ['normal']);
      await close(tester);
    },
  );

  testWidgets('single B survives real controls close reopen and routes once', (
    tester,
  ) async {
    Future<void> open() async {
      await tester.pumpWidget(const MaterialApp(home: SearchPage()));
      await settle(tester);
    }

    await open();
    await tester.tap(find.text('Platform B'));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await open();
    await tester.enterText(find.byType(TextField).first, 'Remember B');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    final page = tester.widget<SearchResultPage>(find.byType(SearchResultPage));
    expect(page.sourceKey, 'b');
    expect(page.options, ['normal']);
    expect(sources.first.requests, isEmpty);
    expect(sources.last.requests, hasLength(1));
    expect(sources.last.requests.single.$1, 'Remember B');
    expect(sources.last.requests.single.$2, 1);
    expect(sources.last.requests.single.$3, ['normal']);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
