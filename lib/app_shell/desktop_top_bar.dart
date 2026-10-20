import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/routing/app_navigation.dart';

import 'desktop_chrome.dart';

const _kTopBarIconSize = 18.0;

class DesktopLayoutControls extends StatelessWidget {
  const DesktopLayoutControls({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = DesktopChromeScope.maybeOf(context);
    if (chrome == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: chrome,
      builder: (context, _) {
        if (!chrome.favoritesActive) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayoutMenuButton(chrome: chrome),
            if (chrome.leftAvailable)
              _SidebarToggleButton(
                tooltip: 'Toggle left sidebar'.tl,
                expanded: chrome.leftExpanded,
                onTap: chrome.toggleLeftSidebar,
                mirrored: false,
              ),
            if (chrome.rightAvailable)
              _SidebarToggleButton(
                tooltip: 'Toggle right sidebar'.tl,
                expanded: chrome.rightExpanded,
                onTap: chrome.toggleRightSidebar,
                mirrored: true,
              ),
          ],
        );
      },
    );
  }
}

class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({
    required this.tooltip,
    required this.expanded,
    required this.onTap,
    required this.mirrored,
  });

  final String tooltip;
  final bool expanded;
  final VoidCallback onTap;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final color = expanded
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = Icon(
      Icons.vertical_split,
      size: _kTopBarIconSize,
      color: color,
    );
    // The title bar sits above MaterialApp's Overlay, so Tooltip (and tooltips
    // on PopupMenuButton) cannot be used here.
    return Semantics(
      label: tooltip,
      button: true,
      child: IconButton(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        iconSize: _kTopBarIconSize,
        onPressed: onTap,
        icon: mirrored ? Transform.flip(flipX: true, child: icon) : icon,
      ),
    );
  }
}

class _LayoutMenuButton extends StatelessWidget {
  const _LayoutMenuButton({required this.chrome});

  final DesktopChromeController chrome;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '',
      padding: EdgeInsets.zero,
      iconSize: _kTopBarIconSize,
      icon: const Icon(Icons.dashboard_customize_outlined),
      constraints: const BoxConstraints(minWidth: 180),
      onSelected: (value) {
        if (value == 0) chrome.toggleLeftSidebar();
        if (value == 1) chrome.toggleRightSidebar();
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 0,
          enabled: chrome.leftAvailable,
          checked: chrome.leftExpanded,
          child: Text('Left sidebar'.tl),
        ),
        CheckedPopupMenuItem(
          value: 1,
          enabled: chrome.rightAvailable,
          checked: chrome.rightExpanded,
          child: Text('Right sidebar'.tl),
        ),
      ],
    );
  }
}

/// Inline application menu for Windows/Linux title bars.
class DesktopInlineMenuBar extends StatelessWidget {
  const DesktopInlineMenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = DesktopChromeScope.maybeOf(context);
    if (chrome == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: chrome,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InlineMenu(
              label: 'File'.tl,
              items: [
                _InlineItem(
                  label: 'Settings…'.tl,
                  onSelected: chrome.openSettingsAction,
                ),
                _InlineItem(
                  label: 'Search…'.tl,
                  onSelected: chrome.openSearchAction,
                ),
                _InlineItem(
                  label: 'Close Window'.tl,
                  onSelected: () => windowManager.close(),
                ),
              ],
            ),
            _InlineMenu(
              label: 'View'.tl,
              items: [
                _InlineItem(
                  label: 'Left sidebar'.tl,
                  checked: chrome.leftExpanded,
                  enabled: chrome.favoritesActive && chrome.leftAvailable,
                  onSelected: chrome.toggleLeftSidebar,
                ),
                _InlineItem(
                  label: 'Right sidebar'.tl,
                  checked: chrome.rightExpanded,
                  enabled: chrome.favoritesActive && chrome.rightAvailable,
                  onSelected: chrome.toggleRightSidebar,
                ),
                _InlineItem(
                  label: 'Full Screen'.tl,
                  onSelected: () => toggleDesktopFullScreen(),
                ),
              ],
            ),
            _InlineMenu(
              label: 'Navigate'.tl,
              items: [
                for (var index = 0; index < 4; index++)
                  _InlineItem(
                    label: const [
                      'Home',
                      'Favorites',
                      'Explore',
                      'Categories',
                    ][index].tl,
                    onSelected: chrome.canNavigate
                        ? () => chrome.navigateTo(index)
                        : null,
                  ),
                _InlineItem(label: 'Back'.tl, onSelected: chrome.goBack),
              ],
            ),
            _InlineMenu(
              label: 'Reader'.tl,
              items: [
                _InlineItem(
                  label: 'Reading Settings'.tl,
                  onSelected: chrome.readerActions?.openSettings,
                ),
                _InlineItem(
                  label: 'Chapter List'.tl,
                  onSelected: chrome.readerActions?.openChapters,
                ),
                _InlineItem(
                  label: 'Thumbnails'.tl,
                  onSelected: chrome.readerActions?.toggleThumbnails,
                ),
              ],
            ),
            _InlineMenu(
              label: 'Help'.tl,
              items: [
                _InlineItem(
                  label: 'About VeneraNext'.tl,
                  onSelected: () => showDesktopAbout(),
                ),
                _InlineItem(
                  label: 'GitHub Repository'.tl,
                  onSelected: () =>
                      launchUrlString('https://github.com/Lezy233/Venera-Next'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _InlineItem {
  const _InlineItem({
    required this.label,
    this.onSelected,
    this.checked = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onSelected;
  final bool checked;
  final bool enabled;
}

class _InlineMenu extends StatelessWidget {
  const _InlineMenu({required this.label, required this.items});

  final String label;
  final List<_InlineItem> items;

  @override
  Widget build(BuildContext context) {
    final enabled = items.any(
      (item) => item.enabled && item.onSelected != null,
    );
    return PopupMenuButton<int>(
      enabled: enabled,
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: (index) => items[index].onSelected?.call(),
      itemBuilder: (context) => [
        for (var index = 0; index < items.length; index++)
          CheckedPopupMenuItem(
            value: index,
            checked: items[index].checked,
            enabled: items[index].enabled && items[index].onSelected != null,
            child: Text(items[index].label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

Future<void> toggleDesktopFullScreen() async {
  final full = await windowManager.isFullScreen();
  await windowManager.setFullScreen(!full);
}

void showDesktopAbout() {
  showAboutDialog(
    context: appNavigation.rootContext,
    applicationName: 'VeneraNext',
    applicationVersion: App.version,
    applicationLegalese: '© 2026 Lezy233',
    applicationIcon: const Icon(Icons.menu_book, size: 40),
  );
}
