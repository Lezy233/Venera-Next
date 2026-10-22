import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_registry.dart';
import 'desktop_chrome.dart';

class GlobalShortcutTarget implements ShortcutTarget {
  GlobalShortcutTarget(this.chrome);
  final DesktopChromeController chrome;
  @override
  void invokeShortcut(ShortcutCommand command, KeyEvent event) {
    switch (command) {
      case ShortcutCommand.openSettings:
        chrome.openSettingsAction();
      case ShortcutCommand.openSearch:
        chrome.openSearchAction();
      case ShortcutCommand.toggleLeftSidebar:
        chrome.toggleLeftSidebar();
      case ShortcutCommand.toggleRightSidebar:
        chrome.toggleRightSidebar();
      case ShortcutCommand.goHome:
        chrome.navigateTo(0);
      case ShortcutCommand.goFavorites:
        chrome.navigateTo(1);
      case ShortcutCommand.goExplore:
        chrome.navigateTo(2);
      case ShortcutCommand.goCategories:
        chrome.navigateTo(3);
      default:
        break;
    }
  }
}

/// Resolve from current settings on every event: updates need no rebinding and
/// do not touch the chrome's frame-safe action registration lifecycle.
class _GlobalShortcutManager extends ShortcutManager {
  _GlobalShortcutManager(this.chrome);
  DesktopChromeController chrome;
  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (shortcutCaptureOwner.value != null ||
        shortcutTextInputFocused() ||
        event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final action = AppShortcutRegistry.match(
      ShortcutContext.global,
      event,
      appdata.settings['shortcutOverrides'],
      macOS: App.isMacOS,
    );
    if (action == null) return KeyEventResult.ignored;
    action.runner(GlobalShortcutTarget(chrome), event);
    return KeyEventResult.handled;
  }
}

class GlobalShortcuts extends StatefulWidget {
  const GlobalShortcuts({super.key, required this.chrome, required this.child});
  final DesktopChromeController chrome;
  final Widget child;
  @override
  State<GlobalShortcuts> createState() => _GlobalShortcutsState();
}

class _GlobalShortcutsState extends State<GlobalShortcuts> {
  late final _manager = _GlobalShortcutManager(widget.chrome);
  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _manager.chrome = widget.chrome;
    return Shortcuts.manager(manager: _manager, child: widget.child);
  }
}
