import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/app_shell/desktop_top_bar.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/translations.dart';

/// Native macOS menu bar. Windows/Linux use the inline title-bar menu instead.
class DesktopApplicationMenuBar extends StatelessWidget {
  const DesktopApplicationMenuBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!App.isMacOS) return child;
    final chrome = DesktopChromeScope.maybeOf(context);
    if (chrome == null) return child;
    return ListenableBuilder(
      listenable: chrome,
      builder: (context, _) =>
          PlatformMenuBar(menus: _menus(chrome), child: child),
    );
  }

  List<PlatformMenu> _menus(DesktopChromeController chrome) {
    final reader = chrome.readerActions;
    return [
      PlatformMenu(
        label: 'VeneraNext',
        menus: [
          PlatformMenuItem(
            label: 'About VeneraNext'.tl,
            onSelected: showDesktopAbout,
          ),
          PlatformMenuItem(
            label: 'Settings…'.tl,
            onSelected: chrome.openSettingsAction,
          ),
          PlatformMenuItem(
            label: 'Quit VeneraNext'.tl,
            onSelected: () => windowManager.close(),
          ),
        ],
      ),
      PlatformMenu(
        label: 'File'.tl,
        menus: [
          PlatformMenuItem(
            label: 'Search…'.tl,
            onSelected: chrome.openSearchAction,
          ),
          PlatformMenuItem(
            label: 'Close Window'.tl,
            onSelected: () => windowManager.close(),
          ),
        ],
      ),
      PlatformMenu(
        label: 'View'.tl,
        menus: [
          PlatformMenuItem(
            label: 'Left sidebar'.tl,
            onSelected: chrome.favoritesActive && chrome.leftAvailable
                ? chrome.toggleLeftSidebar
                : null,
          ),
          PlatformMenuItem(
            label: 'Right sidebar'.tl,
            onSelected: chrome.favoritesActive && chrome.rightAvailable
                ? chrome.toggleRightSidebar
                : null,
          ),
          PlatformMenuItem(
            label: 'Full Screen'.tl,
            onSelected: toggleDesktopFullScreen,
          ),
        ],
      ),
      PlatformMenu(
        label: 'Navigate'.tl,
        menus: [
          for (var index = 0; index < 4; index++)
            PlatformMenuItem(
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
          PlatformMenuItem(label: 'Back'.tl, onSelected: chrome.goBack),
        ],
      ),
      if (reader != null)
        PlatformMenu(
          label: 'Reader'.tl,
          menus: [
            PlatformMenuItem(
              label: 'Reading Settings'.tl,
              onSelected: reader.openSettings,
            ),
            PlatformMenuItem(
              label: 'Chapter List'.tl,
              onSelected: reader.openChapters,
            ),
            PlatformMenuItem(
              label: 'Thumbnails'.tl,
              onSelected: reader.toggleThumbnails,
            ),
          ],
        ),
      PlatformMenu(
        label: 'Help'.tl,
        menus: [
          PlatformMenuItem(
            label: 'About VeneraNext'.tl,
            onSelected: showDesktopAbout,
          ),
          PlatformMenuItem(
            label: 'GitHub Repository'.tl,
            onSelected: () =>
                launchUrlString('https://github.com/Lezy233/Venera-Next'),
          ),
        ],
      ),
    ];
  }
}
