import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:venera_next/features/comic_widgets/comic_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/search/search_page.dart';
import 'package:venera_next/features/search/search_profile.dart';
import 'package:venera_next/features/search/search_profiles.dart';
import 'package:venera_next/features/search/aggregated_search_page.dart';
import 'package:venera_next/features/search/search_result_page.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import '../../support/creator_search_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, dynamic> previous;
  late List<CreatorSearchSource> sources;
  final manager = SearchProfileManager.instance;
  late GlobalKey<NavigatorState> navigator;
  setUp(() {
    root = Directory.systemTemp.createTempSync('profile-flow-');
    App.dataPath = root.path;
    App.cachePath = root.path;
    App.isInitialized = false;
    previous = Map.from(appdata.toJson()['settings'] as Map);
    appdata.settings['language'] = 'en-US';
    appdata.settings['searchProfiles'] = [];
    appdata.settings['defaultSearchProfile'] = null;
    appdata.settings['autoAddLanguageFilter'] = 'none';
    appdata.settings['comicListDisplayMode'] = 'paging';
    appdata.settings['searchSources'] = ['a', 'b'];
    appdata.settings['defaultSearchTarget'] = '_aggregated_';
    sources = [
      CreatorSearchSource('a', displayName: 'Platform A'),
      CreatorSearchSource('b', displayName: 'Platform B'),
    ];
    configureComicSourceRegistry(
      all: () => sources,
      find: (key) => sources.where((e) => e.key == key).firstOrNull,
      fromIntKey: (_) => null,
      isEmpty: () => false,
    );
    navigator = GlobalKey<NavigatorState>();
  });
  tearDown(() {
    previous.forEach((k, v) => appdata.settings[k] = v);
    App.dataPath = Directory.systemTemp.path;
    configureComicSourceRegistry(
      all: () => [],
      find: (_) => null,
      fromIntKey: (_) => null,
      isEmpty: () => true,
    );
    root.deleteSync(recursive: true);
  });
  Future<void> frames(WidgetTester tester) async {
    await tester.pumpAndSettle();
    var done = false;
    Object? error;
    appdata.writeImplicitData().then(
      (_) => done = true,
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    for (var i = 0; i < 200 && !done; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(done, isTrue);
    expect(error, isNull);
    await tester.pumpAndSettle();
  }

  Future<T> drain<T>(WidgetTester tester, Future<T> work) async {
    var done = false;
    Object? failure;
    T? result;
    work.then(
      (value) {
        result = value;
        done = true;
      },
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    for (var i = 0; i < 200 && !done; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(done, isTrue);
    expect(failure, isNull);
    return result as T;
  }

  Future<void> host(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(body: page),
      ),
    );
    await frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
    });
  }

  test(
    'schema fallback supports select/dropdown/multi-select and ignores unknown/disabled sources',
    () {
      final profile = SearchProfile(
        id: 'p',
        name: 'P',
        sources: const [
          SearchProfileSource(sourceKey: 'missing', enabled: true, options: []),
          SearchProfileSource(
            sourceKey: 'b',
            enabled: false,
            options: ['other'],
          ),
          SearchProfileSource(
            sourceKey: 'a',
            enabled: true,
            options: ['removed'],
          ),
        ],
      );
      expect(manager.resolve(profile).map((e) => e.source.key), ['a']);
      expect(manager.resolve(profile).single.options, ['normal']);
      final schema = SearchPageData(
        [
          SearchOptions(
            LinkedHashMap.of({'a': 'A', 'b': 'B'}),
            'Multi',
            'multi-select',
            '["a"]',
          ),
        ],
        null,
        null,
      );
      expect(resolveSearchProfileOptions(schema, ['["b"]']), ['["b"]']);
      expect(resolveSearchProfileOptions(schema, ['["removed"]']), ['["a"]']);
      expect(resolveSearchProfileOptions(schema, ['bad json']), ['["a"]']);
    },
  );
  testWidgets(
    'reachable profile create/validation retry/source enable/order/options update/default/rename/delete',
    (tester) async {
      await host(tester, const SearchProfilesSettings());
      await tester.tap(find.byTooltip('Create search profile'));
      await frames(tester);
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(find.text('Search profile name is empty'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Plan');
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(find.byType(SearchProfileEditor), findsOneWidget);
      // Toggle B off, then on, change its schema option and move it before A.
      await tester.tap(find.widgetWithText(SwitchListTile, 'Platform B'));
      await frames(tester);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Platform B'));
      await frames(tester);
      await tester.tap(find.text('Other').last);
      await frames(tester);
      await tester.tap(find.byTooltip('Move up').last);
      await frames(tester);
      await tester.tap(find.text('Save'));
      await frames(tester);
      final saved = manager.all.single;
      expect(saved.sources.map((e) => e.sourceKey), ['b', 'a']);
      expect(saved.sources.first.options, ['other']);
      expect(saved.sources.first.enabled, isTrue);
      await tester.tap(find.byTooltip('Default search profile'));
      await frames(tester);
      expect(manager.defaultId, saved.id);
      await tester.tap(find.text('Plan'));
      await frames(tester);
      expect(
        tester
            .widgetList<SearchOptionWidget>(find.byType(SearchOptionWidget))
            .map((e) => e.value),
        ['other', 'normal'],
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Platform A'));
      await frames(tester);
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(manager.all.single.sources.last.enabled, isFalse);
      await tester.tap(find.byTooltip('Manage search profile'));
      await frames(tester);
      await tester.tap(find.text('Rename'));
      await frames(tester);
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(find.text('Renamed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Manage search profile'));
      await frames(tester);
      await tester.tap(find.text('Delete'));
      await frames(tester);
      expect(manager.all, isEmpty);
      expect(manager.defaultId, isNull);
    },
  );
  testWidgets(
    'create IO failure is localized and retryable without duplicate profile; cancel is safe',
    (tester) async {
      await host(tester, const SearchProfilesSettings());
      final blocked = Directory('${root.path}/appdata.json')..createSync();
      await tester.tap(find.byTooltip('Create search profile'));
      await frames(tester);
      await tester.enterText(find.byType(TextField), 'Retry plan');
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(find.text('Could not save search profile'), findsOneWidget);
      expect(find.byType(SearchProfileEditor), findsNothing);
      expect(manager.all, hasLength(1));
      final id = manager.all.single.id;
      blocked.deleteSync();
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(find.byType(SearchProfileEditor), findsOneWidget);
      expect(manager.all.single.id, id);
      navigator.currentState!.pop();
      await frames(tester);
      await tester.tap(find.byTooltip('Create search profile'));
      await frames(tester);
      await tester.tap(find.text('Cancel'));
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'aggregate title and cover open exact source detail once, not full results',
    (tester) async {
      final opened = <(String, String)>[];
      configureComicWidgets(
        comicPageBuilder:
            ({required id, required sourceKey, cover, title, heroID}) {
              opened.add((id, sourceKey));
              return const Scaffold(
                body: Text('Controlled detail destination'),
              );
            },
      );
      addTearDown(configureComicWidgets);
      await host(tester, const AggregatedSearchPage(keyword: 'Book'));
      for (final source in sources) {
        final name = 'Controlled result 1 · ${source.displayName}';
        final tile = find.ancestor(
          of: find.text(name),
          matching: find.byType(SimpleComicTile),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text(name), matching: find.byType(RichText)),
        );
        final glyph = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: name.length),
            )
            .first;
        final titlePoint = paragraph.localToGlobal(glyph.toRect().center);
        final coverPoint = tester.getTopLeft(tile) + const Offset(40, 60);
        for (final point in [titlePoint, coverPoint]) {
          final before = opened.length;
          await tester.tapAt(point);
          await frames(tester);
          expect(opened.length, before + 1);
          expect(opened.last, ('result-1', source.key));
          expect(find.byType(SearchResultPage), findsNothing);
          expect(find.text('Controlled detail destination'), findsOneWidget);
          navigator.currentState!.pop();
          await frames(tester);
        }
      }
      expect(opened, [
        ('result-1', 'a'),
        ('result-1', 'a'),
        ('result-1', 'b'),
        ('result-1', 'b'),
      ]);
    },
  );
  testWidgets(
    'profile aggregate/full results/Next retain snapshot after profile changes',
    (tester) async {
      final profile = await drain(
        tester,
        manager.create('Snapshot', const [
          SearchProfileSource(
            sourceKey: 'b',
            enabled: true,
            options: ['other'],
          ),
        ]),
      );
      await host(
        tester,
        AggregatedSearchPage(keyword: 'Book', profileId: profile.id),
      );
      expect(sources.last.requests.single.$3, ['other']);
      expect(sources.first.requests, isEmpty);
      await drain(
        tester,
        manager.update(profile.id, const [
          SearchProfileSource(
            sourceKey: 'a',
            enabled: true,
            options: ['normal'],
          ),
        ]),
      );
      await tester.tap(find.text('Platform B'));
      await frames(tester);
      expect(
        tester.widget<SearchResultPage>(find.byType(SearchResultPage)).options,
        ['other'],
      );
      await tester.tap(find.text('Next').first);
      await frames(tester);
      expect(sources.last.requests.last.$1, 'Book');
      expect(sources.last.requests.last.$2, 2);
      expect(sources.last.requests.last.$3, ['other']);
      expect(sources.first.requests, isEmpty);
    },
  );
  testWidgets(
    'real search entry default profile can explicitly switch to legacy global settings',
    (tester) async {
      final profile = await drain(
        tester,
        manager.create('Only B', const [
          SearchProfileSource(
            sourceKey: 'b',
            enabled: true,
            options: ['other'],
          ),
        ]),
      );
      await drain(tester, manager.setDefault(profile.id));
      await host(tester, const SearchPage());
      await tester.tap(find.byType(DropdownButton<String?>));
      await frames(tester);
      await tester.tap(find.text('Global settings').last);
      await frames(tester);
      await tester.enterText(find.byType(TextField).first, 'Global book');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await frames(tester);
      expect(find.byType(AggregatedSearchPage), findsOneWidget);
      expect(sources.first.requests.single.$3, ['normal']);
      expect(sources.last.requests.single.$3, ['normal']);
      expect(tester.takeException(), isNull);
    },
  );
}
