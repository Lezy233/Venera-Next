import 'package:flutter/material.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/design_system/breakpoints.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';
import 'package:venera_next/features/settings/about.dart';
import 'package:venera_next/features/settings/appearance.dart';
import 'package:venera_next/features/settings/local_favorites.dart';
import 'package:venera_next/features/settings/network.dart';
import 'package:venera_next/features/settings/explore_settings.dart';
import 'package:venera_next/features/settings/app.dart';
import 'package:venera_next/features/settings/reader.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.initialPage = -1, super.key});

  final int initialPage;

  /// Opens an existing editor in the two-pane settings navigator, if present.
  /// Standalone settings and compact layouts keep their popup presentation.
  static bool openEditor(BuildContext context, Widget Function() builder) {
    if (Breakpoints.isCompact(context)) return false;
    final scope = context
        .getInheritedWidgetOfExactType<_SettingsEditingScope>();
    if (scope == null) return false;
    scope.open(context, builder);
    return true;
  }

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int currentPage = -1;

  ColorScheme get colors => Theme.of(context).colorScheme;

  bool get enableTwoViews => !Breakpoints.isCompact(context);

  final categories = <String>[
    "Explore",
    "Reading",
    "Appearance",
    "Local Favorites",
    "APP",
    "Network",
    "About",
  ];

  final icons = <IconData>[
    Icons.explore,
    Icons.book,
    Icons.color_lens,
    Icons.collections_bookmark_rounded,
    Icons.apps,
    Icons.public,
    Icons.info,
  ];

  @override
  void initState() {
    // Category indexes changed when statistics/debug left the main list; drop
    // any stale initial index rather than opening a removed page.
    currentPage =
        widget.initialPage >= -1 && widget.initialPage < categories.length
        ? widget.initialPage
        : -1;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(child: buildBody());
  }

  /// In desktop two-pane mode always land on a category instead of a blank pane.
  int get _effectivePage =>
      enableTwoViews && currentPage == -1 ? 0 : currentPage;

  Widget buildBody() {
    if (enableTwoViews) {
      return Row(
        children: [
          SizedBox(
            width: AppSizes.settingsSidebarWidth,
            height: double.infinity,
            child: buildLeft(_effectivePage),
          ),
          Container(
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.colorScheme.contentBorder,
                  width: AppSizes.hairline,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.normal,
              transitionBuilder: (child, animation) {
                return LayoutBuilder(
                  builder: (context, constrains) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        var width = constrains.maxWidth;
                        var value = animation.isForwardOrCompleted
                            ? 1 - animation.value
                            : 1;
                        var left = width * value;
                        return Stack(
                          children: [
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: left,
                              width: width,
                              child: child,
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: buildRight(_effectivePage),
            ),
          ),
        ],
      );
    } else {
      return buildLeft(_effectivePage);
    }
  }

  Widget buildLeft(int selectedPage) {
    return Material(
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          SizedBox(
            height: AppSizes.settingsHeaderHeight,
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: "Back".tl,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: context.pop,
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Text("Settings".tl, style: ts.s20),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(child: buildCategories(selectedPage)),
        ],
      ),
    );
  }

  Widget buildCategories(int selectedPage) {
    Widget buildItem(String name, int id) {
      final bool selected = id == selectedPage;

      Widget content = AnimatedContainer(
        key: ValueKey(id),
        duration: AppMotion.normal,
        width: double.infinity,
        height: AppSizes.settingsCategoryHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentContainer.toOpacity(AppOpacity.selectedContainer)
              : null,
          border: Border(
            left: BorderSide(
              color: selected ? colors.accent : Colors.transparent,
              width: AppSizes.settingsSelectedIndicatorWidth,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icons[id], size: AppSizes.navIconSize),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                name,
                style: ts.s16,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected && !enableTwoViews) const Icon(Icons.arrow_right),
          ],
        ),
      );

      return Padding(
        padding: enableTwoViews
            ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm)
            : EdgeInsets.zero,
        child: ClickInkWell(
          onTap: () {
            if (enableTwoViews) {
              setState(() => currentPage = id);
            } else {
              context.to(() => _SettingsDetailPage(pageIndex: id));
            }
          },
          child: content,
        ).paddingVertical(AppSpacing.xs),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      itemBuilder: (context, index) => buildItem(categories[index].tl, index),
    );
  }

  Widget buildRight(int page) {
    if (page == -1) {
      return const SizedBox();
    }
    return _SettingsEditingScope(
      key: ValueKey(page),
      open: (context, builder) => context.to(builder),
      child: Navigator(
        key: ValueKey(page),
        onGenerateRoute: (settings) {
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return _buildSettingsContent(page);
            },
            transitionDuration: Duration.zero,
          );
        },
      ),
    );
  }

  Widget _buildSettingsContent(int pageIndex) {
    return switch (pageIndex) {
      0 => const ExploreSettings(),
      1 => const ReaderSettings(),
      2 => const AppearanceSettings(),
      3 => const LocalFavoritesSettings(),
      4 => const AppSettings(),
      5 => const NetworkSettings(),
      6 => const AboutSettings(),
      _ => throw UnimplementedError(),
    };
  }
}

class _SettingsEditingScope extends InheritedWidget {
  const _SettingsEditingScope({
    super.key,
    required this.open,
    required super.child,
  });

  final void Function(BuildContext context, Widget Function() builder) open;

  @override
  bool updateShouldNotify(_SettingsEditingScope oldWidget) => false;
}

class _SettingsDetailPage extends StatelessWidget {
  const _SettingsDetailPage({required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Material(child: _buildPage());
  }

  Widget _buildPage() {
    return switch (pageIndex) {
      0 => const ExploreSettings(),
      1 => const ReaderSettings(),
      2 => const AppearanceSettings(),
      3 => const LocalFavoritesSettings(),
      4 => const AppSettings(),
      5 => const NetworkSettings(),
      6 => const AboutSettings(),
      _ => throw UnimplementedError(),
    };
  }
}
