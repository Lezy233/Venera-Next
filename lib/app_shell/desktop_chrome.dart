import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:venera_next/foundation/app.dart';

/// Reader actions exposed to the desktop menus and shortcuts.
class DesktopReaderActions {
  const DesktopReaderActions({
    required this.openSettings,
    required this.openChapters,
    required this.toggleThumbnails,
  });

  final VoidCallback openSettings;
  final VoidCallback openChapters;
  final VoidCallback toggleThumbnails;
}

/// Shell-level state shared by the custom title bar, menus and shortcuts.
/// Pages register their available sidebars/actions while they are mounted.
class DesktopChromeController extends ChangeNotifier {
  bool _favoritesActive = false;
  bool _leftAvailable = false;
  bool _leftExpanded = true;
  VoidCallback? _toggleLeft;
  bool _rightAvailable = false;
  bool _rightExpanded = false;
  VoidCallback? _toggleRight;
  ValueChanged<String>? _favoritesSearchQuery;
  DesktopReaderActions? _readerActions;

  VoidCallback? _openSettings;
  VoidCallback? _openSearch;
  void Function(int index)? _navigate;
  VoidCallback? _back;

  bool get favoritesActive => _favoritesActive;
  bool get leftAvailable => _leftAvailable;
  bool get leftExpanded => _leftExpanded;
  bool get rightAvailable => _rightAvailable;
  bool get rightExpanded => _rightExpanded;
  DesktopReaderActions? get readerActions => _readerActions;

  void setFavoritesActive(bool value) {
    if (value == _favoritesActive) return;
    _favoritesActive = value;
    notifyListeners();
  }

  void setLeftSidebar({
    required bool available,
    required bool expanded,
    VoidCallback? toggle,
  }) {
    if (available == _leftAvailable &&
        expanded == _leftExpanded &&
        toggle == _toggleLeft) {
      return;
    }
    _leftAvailable = available;
    _leftExpanded = expanded;
    _toggleLeft = toggle;
    notifyListeners();
  }

  void setRightSidebar({
    required bool available,
    required bool expanded,
    VoidCallback? toggle,
  }) {
    if (available == _rightAvailable &&
        expanded == _rightExpanded &&
        toggle == _toggleRight) {
      return;
    }
    _rightAvailable = available;
    _rightExpanded = expanded;
    _toggleRight = toggle;
    notifyListeners();
  }

  void setFavoritesSearchQuery(ValueChanged<String>? search) {
    if (search == _favoritesSearchQuery) return;
    _favoritesSearchQuery = search;
    notifyListeners();
  }

  void setReaderActions(DesktopReaderActions? actions) {
    if (identical(actions, _readerActions)) return;
    _readerActions = actions;
    notifyListeners();
  }

  void bindGlobalActions({
    required VoidCallback openSettings,
    required VoidCallback openSearch,
    required void Function(int index) navigate,
    required VoidCallback back,
  }) {
    final changed =
        openSettings != _openSettings ||
        openSearch != _openSearch ||
        navigate != _navigate ||
        back != _back;
    _openSettings = openSettings;
    _openSearch = openSearch;
    _navigate = navigate;
    _back = back;
    if (changed) notifyListeners();
  }

  void clearGlobalActions() {
    _openSettings = null;
    _openSearch = null;
    _navigate = null;
    _back = null;
    notifyListeners();
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void toggleLeftSidebar() => _toggleLeft?.call();

  void toggleRightSidebar() => _toggleRight?.call();

  /// Cmd+, opens reader settings while reading, otherwise general settings.
  void openSettingsAction() =>
      (_readerActions?.openSettings ?? _openSettings)?.call();

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode(debugLabel: 'desktop search');

  /// Cmd+F / clicking the search box: focus the top bar search field. In the
  /// reader the search target is the chapter list.
  void focusSearch() {
    final reader = _readerActions;
    if (reader != null) {
      reader.openChapters();
      return;
    }
    searchFocusNode.requestFocus();
    searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: searchController.text.length,
    );
  }

  void openSearchAction() => focusSearch();

  /// Live typing for pages that can filter as the user types (favorites).
  void updateSearchQuery(String value) => _favoritesSearchQuery?.call(value);

  /// Submitted text: filter favorites locally, otherwise open global search.
  void submitSearch(String value) {
    final favorites = _favoritesSearchQuery;
    if (favorites != null) {
      favorites(value);
      return;
    }
    _openSearch?.call();
  }

  void navigateTo(int index) => _navigate?.call(index);

  void goBack() => _back?.call();

  bool get canNavigate => _navigate != null;
}

class DesktopChromeScope extends InheritedNotifier<DesktopChromeController> {
  const DesktopChromeScope({
    super.key,
    required DesktopChromeController controller,
    required super.child,
  }) : super(notifier: controller);

  static DesktopChromeController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DesktopChromeScope>()?.notifier;

  static DesktopChromeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DesktopChromeScope>()
      ?.notifier;
}

/// Primary shortcut for the current desktop platform.
SingleActivator primaryShortcut(
  LogicalKeyboardKey key, {
  bool alt = false,
  bool shift = false,
}) => SingleActivator(
  key,
  meta: App.isMacOS,
  control: !App.isMacOS,
  alt: alt,
  shift: shift,
);

/// Global desktop shortcuts. Page-specific actions are resolved by the
/// controller (reader wins over favorites over the global fallback).
Map<ShortcutActivator, VoidCallback> desktopShortcuts(
  DesktopChromeController chrome,
) => {
  primaryShortcut(LogicalKeyboardKey.comma): chrome.openSettingsAction,
  primaryShortcut(LogicalKeyboardKey.keyF): chrome.openSearchAction,
  primaryShortcut(LogicalKeyboardKey.keyB): chrome.toggleLeftSidebar,
  primaryShortcut(LogicalKeyboardKey.keyB, alt: true):
      chrome.toggleRightSidebar,
};
