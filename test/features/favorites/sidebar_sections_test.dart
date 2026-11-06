import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_constants.dart';
import 'package:venera_next/features/favorites/local_favorite_series_page.dart';
import 'package:venera_next/features/favorites/network_favorites_page.dart';
import 'package:venera_next/features/favorites/sidebar_sections.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/foundation/translations.dart';
import '../../support/comic_source_fixture.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/components/window_frame.dart';
import 'package:venera_next/features/favorites/favorites_page.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/local_favorites_page.dart';
import 'package:venera_next/features/favorites/side_bar.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:window_manager/window_manager.dart';

Future<void> _flush(WidgetTester tester, Future<void> operation) async {
  var done = false;
  Object? error;
  operation.then(
    (_) => done = true,
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done, isTrue);
  expect(error, isNull);
  await tester.pump();
}

Future<Directory> _prepare(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final root = Directory.systemTemp.createTempSync('favorites-view-');
  final previousPath = App.dataPath;
  final previousSettings = Map<String, dynamic>.from(
    appdata.toJson()['settings'] as Map,
  );
  final previousImplicit = Map<String, dynamic>.from(appdata.implicitData);
  App.dataPath = root.path;
  App.cachePath = root.path;
  appdata.settings['language'] = 'en-US';
  appdata.settings['disableSyncFields'] = '';
  appdata.settings['favoritesFilterPanelOpen'] = false;
  appdata.settings['blockedWords'] = <String>[];
  appdata.settings['autoAddLanguageFilter'] = 'none';
  appdata.implicitData = {
    'local_favorites_read_filter': 'All',
    'unrelated': 42,
  };
  _favoritesOwner = null;
  _historyOwner = null;
  final manager = _favoritesForView();
  final history = _historyForView();
  await tester.runAsync(() async {
    await manager.init();
    await history.init();
    await manager.createFolder('A');
    await manager.createFolder('B');
    await manager.createSeries('A');
    await manager.createSeries('Second series');
    await manager.linkFolderToNetwork('A', 'test-source', 'remote-A');
  });
  registerShowMessageHandler((_, _) {});
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (_) async => false,
  );
  addTearDown(() async {
    await _flush(tester, appdata.writeImplicitData());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      await appdata.writeImplicitData();
      await manager.closeAndWait();
      history.close();
    });
    _favoritesOwner = null;
    _historyOwner = null;
    previousSettings.forEach((key, value) => appdata.settings[key] = value);
    appdata.implicitData = previousImplicit;
    App.dataPath = previousPath;
    root.deleteSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      null,
    );
  });
  return root;
}

Map _saved(Directory root) =>
    jsonDecode(File('${root.path}/implicitData.json').readAsStringSync())
        as Map;

Widget _host(
  Widget child, {
  Future<void> Function()? onExit,
  ThemeData? theme,
  double scale = 1,
}) => _libraryView(
  MaterialApp(
    navigatorKey: appNavigation.rootNavigatorKey,
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: onExit == null ? child! : WindowFrame(child!, onExit: onExit),
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  App.dataPath = Directory.systemTemp.path;
  for (final stored in [
    null,
    false,
    'bad',
    <String, dynamic>{},
    {'local': false, 'series': 'false', 'network': false},
  ]) {
    test('defaults and independently damaged values: $stored', () {
      final state = FavoriteSidebarSections(stored);
      expect(
        state.expanded(FavoriteSidebarSection.local),
        stored is Map && stored['local'] == false ? false : true,
      );
      expect(state.expanded(FavoriteSidebarSection.series), true);
      expect(
        state.expanded(FavoriteSidebarSection.network),
        stored is Map && stored['network'] == false ? false : true,
      );
      state.dispose();
    });
  }
  testWidgets('title coordinate hides only local children without selecting', (
    tester,
  ) async {
    await _prepare(tester);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(const FavoritesPage()));
    expect(find.text('A'), findsNWidgets(2));
    await tester.tapAt(tester.getCenter(find.text('Local')));
    await tester.pump();
    expect(find.text('A'), findsOneWidget); // same-name series remains
    expect(find.text('B'), findsNothing);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    expect(find.byType(LocalFavoritesPage), findsNothing);
    await _flush(
      tester,
      tester
          .state<SettingsSaveState>(find.byType(FavoritesPage))
          .waitForSettingsSave(),
    );
  });

  testWidgets(
    'mixed rapid toggles merge unknown fields and reload actual disk',
    (tester) async {
      final root = await _prepare(tester);
      appdata.implicitData[FavoriteSidebarSections.storageKey] = {
        'local': false,
        'series': 'false',
        'network': true,
        'future': 9,
      };
      await tester.pumpWidget(_host(const FavoritesPage()));
      expect(find.text('B'), findsNothing);
      expect(find.text('Second series'), findsOneWidget);
      final release = Completer<void>();
      final barrier = AppDataOperations.instance.run(() => release.future);
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      for (final title in ['Series', 'Network', 'Local', 'Local', 'Series']) {
        await tester.tapAt(tester.getCenter(find.text(title)));
        await tester.pump();
      }
      final owner = tester.state<SettingsSaveState>(find.byType(FavoritesPage));
      expect(owner.savingSettings, isTrue);
      release.complete();
      await _flush(tester, Future.wait([barrier, owner.waitForSettingsSave()]));
      expect(_saved(root)[FavoriteSidebarSections.storageKey], {
        'local': false,
        'series': true,
        'network': false,
        'future': 9,
      });
      expect(_saved(root)['unrelated'], 42);
      await tester.pumpWidget(const SizedBox());
      appdata.implicitData = {};
      await tester.runAsync(() => appdata.doInit());
      await tester.pumpWidget(_host(const FavoritesPage()));
      expect(find.text('B'), findsNothing);
      expect(find.text('Second series'), findsOneWidget);
      expect(
        tester
            .widget<FavoritesFolderSidebar>(find.byType(FavoritesFolderSidebar))
            .sections!
            .value,
        {'local': false, 'series': true, 'network': false},
      );
    },
  );

  testWidgets(
    'failed disk save keeps old file and retries latest intent visibly',
    (tester) async {
      final root = await _prepare(tester);
      await tester.runAsync(() => appdata.writeImplicitData());
      final oldFile = File('${root.path}/implicitData.json').readAsStringSync();
      final blocked = Directory('${root.path}/implicitData.json.tmp')
        ..createSync();
      await tester.pumpWidget(_host(const FavoritesPage()));
      await tester.tapAt(tester.getCenter(find.text('Local')));
      final owner = tester.state<SettingsSaveState>(find.byType(FavoritesPage));
      await _flush(tester, owner.waitForSettingsSave().catchError((_) {}));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(
        File('${root.path}/implicitData.json').readAsStringSync(),
        oldFile,
      );
      await tester.tapAt(tester.getCenter(find.text('Series')));
      await _flush(tester, owner.waitForSettingsSave().catchError((_) {}));
      blocked.deleteSync();
      await tester.tapAt(tester.getCenter(find.text('Retry')));
      await _flush(tester, owner.waitForSettingsSave());
      expect(find.text('Retry'), findsNothing);
      expect(_saved(root)[FavoriteSidebarSections.storageKey], {
        'local': false,
        'series': false,
        'network': true,
      });
    },
  );

  testWidgets('accepted save survives page disposal and window exit waits', (
    tester,
  ) async {
    final root = await _prepare(tester);
    var showing = true;
    var exits = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (_, change) {
            update = change;
            return showing ? const FavoritesPage() : const SizedBox();
          },
        ),
        onExit: () async => exits++,
      ),
    );
    final owner = tester.state<SettingsSaveState>(find.byType(FavoritesPage));
    final release = Completer<void>();
    final barrier = AppDataOperations.instance.run(() => release.future);
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    await tester.tapAt(tester.getCenter(find.text('Local')));
    update(() => showing = false);
    await tester.pump();
    (tester.state(find.byType(WindowFrame)) as WindowListener).onWindowClose();
    await tester.pump();
    expect(exits, 0);
    release.complete();
    await _flush(tester, Future.wait([barrier, owner.waitForSettingsSave()]));
    for (var i = 0; i < 20 && exits == 0; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(exits, 1);
    expect(_saved(root)[FavoriteSidebarSections.storageKey]['local'], false);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Tab Enter Space and directional keys toggle once with expanded semantics',
    (tester) async {
      await _prepare(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(const FavoritesPage()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('B'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('B'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('B'), findsNothing);
      final node = tester.getSemantics(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Local',
        ),
      );
      expect(
        node.getSemanticsData().flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      expect(node.getSemanticsData().flagsCollection.isButton, true);
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'real local content instance two selections filter and scroll survive collapse',
    (tester) async {
      await _prepare(tester);
      appdata.implicitData['favoriteFolder'] = {
        'name': 'A',
        'isNetwork': false,
      };
      appdata.implicitData['local_favorites_read_filter'] = 'UnCompleted';
      await tester.runAsync(() async {
        for (var i = 0; i < 18; i++) {
          await _favoritesForView().addComic(
            'A',
            FavoriteItem(
              id: 'f11-$i',
              name: 'Comic $i',
              author: '',
              coverPath: '',
              type: ComicType.local,
              tags: const [],
            ),
          );
        }
        await _favoritesForView().debugWaitForHashedIdsRefresh();
      });
      await tester.pumpWidget(_host(const FavoritesPage()));
      await tester.pumpAndSettle();
      final content = find.byType(LocalFavoritesPage);
      final state = tester.state(content);
      final firstTwo = tester
          .widget<SliverGridComics>(find.byType(SliverGridComics))
          .comics
          .take(2)
          .toList();
      final expectedSelection = firstTwo.map((c) => c.id).toSet();
      await tester.longPressAt(
        tester.getCenter(find.text(firstTwo.first.title).first),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.text(firstTwo.last.title).first),
      );
      await tester.pumpAndSettle();
      Set<String> selection() => tester
          .widget<SliverGridComics>(find.byType(SliverGridComics))
          .selections!
          .keys
          .map((e) => e.id)
          .toSet();
      expect(selection(), expectedSelection);
      final scrollable = find
          .descendant(of: content, matching: find.byType(Scrollable))
          .first;
      final scroll = tester.state<ScrollableState>(scrollable).position;
      scroll.jumpTo(120);
      await tester.pump();
      final offset = scroll.pixels;
      final filter = appdata.implicitData['local_favorites_read_filter'];
      await tester.tapAt(tester.getCenter(find.text('Local')));
      await tester.pump();
      expect(identical(state, tester.state(content)), true);
      expect(selection(), expectedSelection);
      expect(scroll.pixels, offset);
      expect(appdata.implicitData['local_favorites_read_filter'], filter);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Local, A' &&
              w.properties.selected == true,
        ),
        findsOneWidget,
      );
      await tester.tapAt(
        tester.getCenter(find.byIcon(Icons.chevron_right).first),
      );
      await tester.pump();
      expect(selection(), expectedSelection);
      // Restore content focus before Escape, as a user clicking the selection toolbar would.
      await tester.tapAt(tester.getCenter(find.text('Selected 2 comics')));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
      await tester.pumpAndSettle();
      expect(selection(), isEmpty);
      expect(identical(state, tester.state(content)), true);
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
    },
  );

  testWidgets(
    'same named series wins identity and retains its real content state',
    (tester) async {
      await _prepare(tester);
      final series = _favoritesForView().series.first;
      appdata.implicitData['favoriteFolder'] = {
        'name': 'A',
        'isNetwork': false,
      };
      appdata.implicitData['favoriteSeries'] = series.id;
      await tester.pumpWidget(_host(const FavoritesPage()));
      await tester.pumpAndSettle();
      final content = find.byType(LocalFavoriteSeriesPage);
      final state = tester.state(content);
      for (final title in ['Local', 'Series', 'Network']) {
        await tester.tapAt(tester.getCenter(find.text(title)));
        await tester.pump();
      }
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Series, A' &&
              w.properties.selected == true,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Local, A',
        ),
        findsNothing,
      );
      expect(identical(state, tester.state(content)), true);
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
    },
  );

  testWidgets(
    'narrow chooser shares state and independent menu does not close or select',
    (tester) async {
      await _prepare(tester);
      await tester.pumpWidget(_host(const FavoritesPage()));
      await tester.tapAt(tester.getCenter(find.text('Local')));
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
      tester.view.physicalSize = const Size(390, 800);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final chooser = find.byWidgetPredicate(
        (w) => w is FavoritesFolderSidebar && w.withAppbar,
      );
      expect(chooser, findsOneWidget);
      expect(
        find.descendant(of: chooser, matching: find.text('B')),
        findsNothing,
      );
      final local = find.descendant(of: chooser, matching: find.text('Local'));
      final menus = find.descendant(
        of: chooser,
        matching: find.byType(MenuButton),
      );
      await tester.tapAt(tester.getCenter(menus.first));
      await tester.pumpAndSettle();
      expect(find.text('Create Folder'), findsOneWidget);
      expect(chooser, findsOneWidget);
      expect(find.byType(LocalFavoritesPage), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(local));
      await tester.pump();
      expect(
        find.descendant(of: chooser, matching: find.text('B')),
        findsOneWidget,
      );
      expect(chooser, findsOneWidget);
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
      await tester.tap(
        find.descendant(of: chooser, matching: find.byType(CloseButton)),
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    },
  );

  testWidgets(
    'network current identity and request count survive all group toggles',
    (tester) async {
      await _prepare(tester);
      final sources = [
        _NetworkSource('remote-one'),
        _NetworkSource('remote-two'),
      ];
      configureComicSourceRegistry(
        all: () => sources,
        find: (key) => sources.where((s) => s.key == key).firstOrNull,
        fromIntKey: (_) => null,
        isEmpty: () => false,
      );
      configureFavoriteDataResolver(
        (key) => sources.where((s) => s.key == key).firstOrNull?.favoriteData,
      );
      addTearDown(() {
        configureFavoriteDataResolver(null);
        configureComicSourceRegistry(
          all: () => [],
          find: (_) => null,
          fromIntKey: (_) => null,
          isEmpty: () => true,
        );
      });
      appdata.settings['favorites'] = sources.map((s) => s.key).toList();
      appdata.implicitData['favoriteFolder'] = {
        'name': 'remote-two',
        'isNetwork': true,
      };
      await tester.pumpWidget(_host(const FavoritesPage()));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
      final network = find.byType(NetworkFavoritePage);
      final content = find.descendant(
        of: network,
        matching: find.byType(ComicList),
      );
      final state = tester.state(content);
      expect(sources[1].requests, 1);
      for (final title in ['Local', 'Series', 'Network']) {
        await tester.tapAt(tester.getCenter(find.text(title)));
        await tester.pump();
      }
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Network, A' &&
              w.properties.selected == true,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Series, A',
        ),
        findsNothing,
      );
      expect(identical(state, tester.state(content)), true);
      expect(sources.map((s) => s.requests), [0, 1]);
      await tester.tapAt(
        tester.getCenter(find.byIcon(Icons.chevron_right).last),
      );
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
      await tester.pumpAndSettle();
      expect(sources.map((s) => s.requests), [0, 1]);
      expect(identical(state, tester.state(content)), true);
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
    },
  );

  testWidgets(
    'focused child returns to its own header and disappears from traversal',
    (tester) async {
      await _prepare(tester);
      final sections = FavoriteSidebarSections(null);
      addTearDown(sections.dispose);
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 256,
            child: FavoritesFolderSidebar(
              selectedFolder: null,
              isNetworkSelected: false,
              sections: sections,
              onFolderSelected: (_, _) => selected++,
            ),
          ),
        ),
      );
      // Header, local management button, then the real All child.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      final before = FocusManager.instance.primaryFocus;
      expect(
        before?.context?.findAncestorWidgetOfExactType<ClickInkWell>(),
        isNotNull,
      );
      sections.setExpanded(FavoriteSidebarSection.local, false);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(before));
      expect(find.text('All'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('B'), findsOneWidget); // focus moved to Local header
      expect(selected, 0);
    },
  );

  testWidgets(
    'empty groups keep headers and management actions with zero selection callbacks',
    (tester) async {
      await _prepare(tester);
      await tester.runAsync(() async {
        for (final series in _favoritesForView().series.toList()) {
          await _favoritesForView().deleteSeries(series.id);
        }
      });
      var selected = 0;
      await tester.pumpWidget(
        _host(
          FavoritesFolderSidebar(
            selectedFolder: null,
            isNetworkSelected: false,
            onFolderSelected: (_, _) => selected++,
            onSeriesSelected: (_) => selected++,
            onSelected: () => selected++,
          ),
        ),
      );
      for (final name in ['Local', 'Series', 'Network']) {
        await tester.tapAt(tester.getCenter(find.text(name)));
        await tester.pump();
      }
      expect(find.byType(MenuButton), findsNWidgets(2));
      await tester.tapAt(tester.getCenter(find.byType(MenuButton).last));
      await tester.pumpAndSettle();
      expect(find.text('Create series'), findsOneWidget);
      expect(selected, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byIcon(Icons.settings)));
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    },
  );

  testWidgets(
    'All is an explicit current identity and null never impersonates it',
    (tester) async {
      await _prepare(tester);
      await tester.pumpWidget(_host(const FavoritesPage()));
      await tester.tapAt(tester.getCenter(find.text('All')));
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
      final content = tester.state(find.byType(LocalFavoritesPage));
      expect(
        tester
            .widget<LocalFavoritesPage>(find.byType(LocalFavoritesPage))
            .folder,
        localAllFolderLabel,
      );
      await tester.tapAt(tester.getCenter(find.text('Local')));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Local, All' &&
              w.properties.selected == true,
        ),
        findsOneWidget,
      );
      expect(
        identical(content, tester.state(find.byType(LocalFavoritesPage))),
        true,
      );
      await _flush(
        tester,
        tester
            .state<SettingsSaveState>(find.byType(FavoritesPage))
            .waitForSettingsSave(),
      );
      await tester.pumpWidget(const SizedBox());
      appdata.implicitData.remove('favoriteFolder');
      await tester.pumpWidget(_host(const FavoritesPage()));
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Local, All',
        ),
        findsNothing,
      );
      expect(find.byType(LocalFavoritesPage), findsNothing);
    },
  );

  testWidgets(
    'narrow failure shows Retry and closing chooser retains accepted saving',
    (tester) async {
      final root = await _prepare(tester);
      tester.view.physicalSize = const Size(390, 800);
      await tester.pumpWidget(_host(const FavoritesPage()));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final chooser = find.byWidgetPredicate(
        (w) => w is FavoritesFolderSidebar && w.withAppbar,
      );
      final blocked = Directory('${root.path}/implicitData.json.tmp')
        ..createSync();
      await tester.tapAt(
        tester.getCenter(
          find.descendant(of: chooser, matching: find.text('Local')),
        ),
      );
      final owner = tester.state<SettingsSaveState>(find.byType(FavoritesPage));
      await _flush(tester, owner.waitForSettingsSave().catchError((_) {}));
      expect(find.text('Retry').hitTestable(), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      blocked.deleteSync();
      final release = Completer<void>();
      final barrier = AppDataOperations.instance.run(() => release.future);
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      await tester.tap(find.text('Retry').hitTestable());
      await tester.pump();
      expect(owner.savingSettings, true);
      final route = ModalRoute.of(tester.element(chooser))!;
      await tester.tap(
        find.descendant(of: chooser, matching: find.byType(CloseButton)),
      );
      await tester.pump();
      await tester.pump(route.reverseTransitionDuration);
      expect(route.isActive, false);
      expect(chooser.hitTestable(), findsNothing);
      // SDK _InterpolationSimulation.isDone uses time > duration. At the exact
      // endpoint the slide is invisible but the reverse status retains overlays.
      await tester.pump(const Duration(microseconds: 1));
      await tester.pump();
      expect(chooser, findsNothing);
      expect(owner.savingSettings, true);
      release.complete();
      await _flush(tester, Future.wait([barrier, owner.waitForSettingsSave()]));
      expect(_saved(root)[FavoriteSidebarSections.storageKey]['local'], false);
      expect(find.text('Retry'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final language in ['zh-CN', 'zh-TW']) {
      for (final width in [160.0, 256.0]) {
        testWidgets(
          'UI $width dark=$dark $language text 1.6 current All and long series',
          (tester) async {
            await _prepare(tester);
            await tester.runAsync(AppTranslation.init);
            appdata.settings['language'] = language;
            final manager = _favoritesForView();
            final series = manager.series.first;
            final longName = '很长的当前系列名称用于最窄侧栏大字完整提示验证';
            await tester.runAsync(
              () => manager.renameSeries(series.id, longName),
            );
            final sections = FavoriteSidebarSections({
              'local': false,
              'series': false,
              'network': false,
            });
            await tester.pumpWidget(
              _host(
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: FavoritesFolderSidebar(
                      selectedFolder: 'All',
                      selectedSeries: series.id,
                      isNetworkSelected: false,
                      sections: sections,
                      onFolderSelected: (_, _) {},
                    ),
                  ),
                ),
                theme: dark ? ThemeData.dark() : ThemeData.light(),
                scale: 1.6,
              ),
            );
            expect(tester.takeException(), isNull);
            expect(find.text(longName), findsOneWidget);
            expect(
              find.byWidgetPredicate(
                (w) => w is Tooltip && w.message?.contains(longName) == true,
              ),
              findsOneWidget,
            );
            await tester.tapAt(tester.getCenter(find.byType(MenuButton).last));
            await tester.pumpAndSettle();
            expect(find.text('Create series'.tl), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            sections.dispose();
            appdata.settings['language'] = 'en-US';
          },
        );
      }
    }
  }
}

class _NetworkSource extends ComicSourceFixture {
  _NetworkSource(String key) : super(key: key);
  int requests = 0;
  @override
  FavoriteData get favoriteData => _data;
  late final FavoriteData _data = FavoriteData(
    key: key,
    title: 'A',
    multiFolder: false,
    loadNext: null,
    loadComic: (page, [folder]) async {
      requests++;
      return const Res(<Comic>[], subData: 1);
    },
  );
}

LocalFavoritesManager? _favoritesOwner;
LocalFavoritesManager _favoritesForView() =>
    _favoritesOwner ??= LocalFavoritesManager.independent();
HistoryManager? _historyOwner;
HistoryManager _historyForView() => _historyOwner ??= HistoryManager.create();
Widget _libraryView(Widget child) {
  return FavoritesScope(
    manager: _favoritesForView(),
    child: HistoryScope(manager: _historyForView(), child: child),
  );
}
