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
  VoidCallback? _favoritesSearch;
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

  void setFavoritesSearch(VoidCallback? search) {
    if (search == _favoritesSearch) return;
    _favoritesSearch = search;
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

  void toggleLeftSidebar() => _toggleLeft?.call();

  void toggleRightSidebar() => _toggleRight?.call();

  /// Cmd+, opens reader settings while reading, otherwise general settings.
  void openSettingsAction() =>
      (_readerActions?.openSettings ?? _openSettings)?.call();

  /// Cmd+F: chapter list in the reader, local search in favorites, global
  /// search elsewhere.
  void openSearchAction() =>
      (_readerActions?.openChapters ?? _favoritesSearch ?? _openSearch)?.call();

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
