import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_registry.dart';
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
      listenable: Listenable.merge([
        chrome,
        appdata.settings,
        FocusManager.instance,
        shortcutCaptureOwner,
      ]),
      builder: (context, _) =>
          PlatformMenuBar(menus: menus(chrome), child: child),
    );
  }

  static List<PlatformMenu> menus(
    DesktopChromeController chrome, {
    bool? macOS,
  }) {
    final effective = AppShortcutRegistry.resolve(
      appdata.settings['shortcutOverrides'],
      macOS: macOS ?? App.isMacOS,
    );
    SingleActivator? shortcut(String id) {
      // Native accelerators are dispatched before Flutter Focus handlers.
      // Suspend them while typing/capturing so they cannot bypass the guards.
      if (shortcutCaptureOwner.value != null ||
          (id.startsWith('app.') && shortcutTextInputFocused())) {
        return null;
      }
      return effective[id]?.firstOrNull;
    }

    VoidCallback menuAction(String id, VoidCallback invoke) {
      final accelerator = shortcut(id);
      return () {
        // A native key can arrive before the next menu rebuild after focus
        // changes. Recheck at dispatch; ordinary clicks on unbound items work.
        if (accelerator != null &&
            (shortcutCaptureOwner.value != null ||
                (id.startsWith('app.') && shortcutTextInputFocused()))) {
          return;
        }
        invoke();
      };
    }

    const navigationActions = [
      'app.goHome',
      'app.goFavorites',
      'app.goExplore',
      'app.goCategories',
    ];

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
            shortcut: shortcut('app.openSettings'),
            onSelected: menuAction(
              'app.openSettings',
              chrome.openSettingsAction,
            ),
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
            shortcut: shortcut('app.openSearch'),
            onSelected: menuAction('app.openSearch', chrome.openSearchAction),
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
            shortcut: shortcut('app.toggleLeftSidebar'),
            onSelected: chrome.favoritesActive && chrome.leftAvailable
                ? menuAction('app.toggleLeftSidebar', chrome.toggleLeftSidebar)
                : null,
          ),
          PlatformMenuItem(
            label: 'Right sidebar'.tl,
            shortcut: shortcut('app.toggleRightSidebar'),
            onSelected: chrome.favoritesActive && chrome.rightAvailable
                ? menuAction(
                    'app.toggleRightSidebar',
                    chrome.toggleRightSidebar,
                  )
                : null,
          ),
          PlatformMenuItem(
            label: 'Full Screen'.tl,
            shortcut: reader == null
                ? null
                : shortcut('reader.toggleFullscreen'),
            onSelected: reader == null
                ? toggleDesktopFullScreen
                : menuAction(
                    'reader.toggleFullscreen',
                    reader.toggleFullscreen ?? toggleDesktopFullScreen,
                  ),
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
              shortcut: shortcut(navigationActions[index]),
              onSelected: chrome.canNavigate
                  ? menuAction(
                      navigationActions[index],
                      () => chrome.navigateTo(index),
                    )
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
