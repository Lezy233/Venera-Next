import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:venera_next/design_system/breakpoints.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/routing/app_navigation.dart';

import 'desktop_chrome.dart';

class DesktopLayoutControls extends StatelessWidget {
  const DesktopLayoutControls({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = DesktopChromeScope.maybeOf(context);
    if (chrome == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: chrome,
      builder: (context, _) {
        final favorites = chrome.favoritesActive;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SidebarToggleButton(
              tooltip: _sidebarTooltip(
                favorites: favorites,
                available: chrome.leftAvailable,
                toggle: 'Toggle left sidebar',
              ),
              enabled: favorites && chrome.leftAvailable,
              expanded: chrome.leftExpanded,
              onTap: chrome.toggleLeftSidebar,
              mirrored: false,
            ),
            _SidebarToggleButton(
              tooltip: _sidebarTooltip(
                favorites: favorites,
                available: chrome.rightAvailable,
                toggle: 'Toggle right sidebar',
              ),
              enabled: favorites && chrome.rightAvailable,
              expanded: chrome.rightExpanded,
              onTap: chrome.toggleRightSidebar,
              mirrored: true,
            ),
          ],
        );
      },
    );
  }

  String _sidebarTooltip({
    required bool favorites,
    required bool available,
    required String toggle,
  }) {
    if (!favorites) return 'Only available on Favorites'.tl;
    if (!available) return 'No sidebar on this page'.tl;
    return toggle.tl;
  }
}

class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({
    required this.tooltip,
    required this.enabled,
    required this.expanded,
    required this.onTap,
    required this.mirrored,
  });

  final String tooltip;
  final bool enabled;
  final bool expanded;
  final VoidCallback onTap;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !enabled
        ? scheme.disabledForeground
        : expanded
        ? scheme.accent
        : scheme.shellForegroundMuted;
    final icon = Image.asset(
      mirrored
          ? 'assets/vscode_layout_sidebar_right.png'
          : 'assets/vscode_layout_sidebar_left.png',
      width: AppSizes.shellIconSize,
      height: AppSizes.shellIconSize,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
    );
    return IconButton(
      tooltip: tooltip,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      constraints: const BoxConstraints.tightFor(
        width: AppSizes.shellControlSize,
        height: AppSizes.shellControlSize,
      ),
      iconSize: AppSizes.shellIconSize,
      onPressed: enabled ? onTap : null,
      icon: icon,
    );
  }
}

/// Command center shared by live page filters and global search submission.
class DesktopSearchBox extends StatelessWidget {
  const DesktopSearchBox({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = DesktopChromeScope.maybeOf(context);
    if (chrome == null || !Breakpoints.isExpanded(context)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final isReader = chrome.readerActions != null;
    final hint = isReader
        ? "Search chapters".tl
        : chrome.favoritesActive
        ? "Search favorites".tl
        : "Search".tl;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(
        color: scheme.shellBorder,
        width: AppSizes.hairline,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SizedBox(
        width: AppSizes.commandCenterWidth,
        height: AppSizes.commandCenterHeight,
        child: TextField(
          controller: chrome.searchController,
          focusNode: chrome.searchFocusNode,
          style: const TextStyle(fontSize: AppFontSize.bodySmall),
          textInputAction: TextInputAction.search,
          onTap: chrome.focusSearch,
          onChanged: chrome.updateSearchQuery,
          onSubmitted: chrome.submitSearch,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: scheme.shellSurfaceHover,
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: AppFontSize.bodySmall,
              color: scheme.shellForegroundMuted,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: AppSizes.shellSearchIconSize,
              color: scheme.shellForegroundMuted,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: AppSpacing.xl,
              minHeight: AppSpacing.xl,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.sm,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: scheme.accent,
                width: AppSizes.hairline,
              ),
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.bodySmall,
            color: enabled
                ? Theme.of(context).colorScheme.shellForeground
                : Theme.of(context).colorScheme.shellForegroundMuted,
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
