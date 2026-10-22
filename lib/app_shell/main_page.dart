import 'package:flutter/material.dart';
import 'package:venera_next/features/discovery/discovery.dart';
import 'package:venera_next/features/favorites/favorites.dart';
import 'package:venera_next/features/search/search.dart';
import 'package:venera_next/features/settings/settings.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/translations.dart';

import '../components/navigation_bar.dart';
import 'desktop_chrome.dart';
import 'package:venera_next/routing/app_navigation.dart';
import '../foundation/context.dart';
import 'home_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  /// Tab order in [_pages] / [NaviPane.paneItems]. Favorites owns the shell
  /// sidebar controls, so the shell needs to know when it is current.
  static const _favoritesTabIndex = 1;

  late final NaviObserver _observer;

  GlobalKey<NavigatorState>? _navigatorKey;

  final _naviKey = GlobalKey<NaviPaneState>();

  DesktopChromeController? _chrome;

  bool _chromeContextSyncScheduled = false;
  bool _chromeBindingScheduled = false;
  DesktopChromeController? _boundChrome;

  late final VoidCallback _openSettings = _showSettings;
  late final VoidCallback _openSearch = _showSearch;
  late final ValueChanged<int> _navigate = _navigateTo;
  late final VoidCallback _back = _goBack;

  void _showSettings() =>
      to(() => const SettingsPage(), preventDuplicate: true);
  void _showSearch() => to(() => const SearchPage(), preventDuplicate: true);
  void _navigateTo(int index) => _naviKey.currentState?.updatePage(index);
  void _goBack() {
    final navigator = _navigatorKey?.currentState;
    if (navigator != null && navigator.canPop()) navigator.maybePop();
  }

  void to(Widget Function() widget, {bool preventDuplicate = false}) async {
    if (preventDuplicate) {
      var page = widget();
      if ("/${page.runtimeType}" == _observer.routes.last.toString()) return;
    }
    _navigatorKey!.currentContext!.to(widget);
  }

  @override
  void initState() {
    _observer = NaviObserver();
    _observer.addListener(_scheduleChromeContextSync);
    _navigatorKey = GlobalKey();
    appNavigation.mainNavigatorKey = _navigatorKey;
    index = int.parse(
      GlobalPreferenceStore(
        appdata.settings,
      ).read(DiscoveryPreferences.initialPage),
    );
    super.initState();
  }

  final _pages = [
    const HomePage(),
    const FavoritesPage(key: PageStorageKey('favorites')),
    const ExplorePage(key: PageStorageKey('explore')),
    const CategoriesPage(key: PageStorageKey('categories')),
  ];

  var index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chrome = DesktopChromeScope.maybeRead(context);
    _scheduleChromeBinding();
    _scheduleChromeContextSync();
  }

  void _scheduleChromeBinding() {
    if (_chromeBindingScheduled || identical(_boundChrome, _chrome)) return;
    _chromeBindingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chromeBindingScheduled = false;
      if (mounted) _bindChrome();
    });
  }

  void _bindChrome() {
    final chrome = _chrome;
    if (chrome == null || identical(_boundChrome, chrome)) return;
    _boundChrome = chrome;
    chrome.bindGlobalActions(
      openSettings: _openSettings,
      openSearch: _openSearch,
      navigate: _navigate,
      back: _back,
    );
  }

  /// Favorites shell controls belong to the favorites tab only while its root
  /// route is on top. The page itself stays mounted underneath pushed routes
  /// (details, settings, search), so its lifecycle cannot own this state.
  void _syncChromeContext() {
    final chrome = _chrome;
    final navi = _naviKey.currentState;
    if (chrome == null || navi == null) return;
    chrome.setFavoritesActive(navi.isTabRoot(_favoritesTabIndex));
  }

  void _scheduleChromeContextSync() {
    if (_chromeContextSyncScheduled) return;
    _chromeContextSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chromeContextSyncScheduled = false;
      if (mounted) _syncChromeContext();
    });
  }

  @override
  void dispose() {
    _observer.removeListener(_scheduleChromeContextSync);
    _chrome?.setFavoritesActive(false);
    _chrome?.clearGlobalActions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleChromeBinding();
    _scheduleChromeContextSync();
    return NaviPane(
      key: _naviKey,
      initialPage: index,
      observer: _observer,
      navigatorKey: _navigatorKey!,
      paneItems: [
        PaneItemEntry(
          label: 'Home'.tl,
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
        ),
        PaneItemEntry(
          label: 'Favorites'.tl,
          icon: Icons.local_activity_outlined,
          activeIcon: Icons.local_activity,
        ),
        PaneItemEntry(
          label: 'Explore'.tl,
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore,
        ),
        PaneItemEntry(
          label: 'Categories'.tl,
          icon: Icons.category_outlined,
          activeIcon: Icons.category,
        ),
      ],
      onPageChanged: (i) {
        setState(() {
          index = i;
        });
        _scheduleChromeContextSync();
      },
      paneActions: [
        PaneActionEntry(
          icon: Icons.settings,
          label: "Settings".tl,
          onTap: () {
            to(() => const SettingsPage(), preventDuplicate: true);
          },
        ),
      ],
      pageBuilder: (index) {
        return _pages[index];
      },
    );
  }
}
