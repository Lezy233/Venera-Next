import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/components/layout.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'author_shelf_model.dart';
import 'creator_platform_names_view.dart';
import 'favorite_models.dart';
import 'favorite_order.dart';
import 'favorites_scope.dart';

class _ShelfDrag {
  const _ShelfDrag(
    this.owner,
    this.folder,
    this.author,
    this.comic,
    this.visible,
  );
  final _AuthorShelfState owner;
  final String folder;
  final AuthorShelfAuthor author;
  final FavoriteIdentity comic;
  final Set<FavoriteIdentity> visible;
}

/// This adapter keeps the existing page's action/selection/menu ownership.
/// Only concrete folders explicitly selecting shelves enter the new layout.
class FavoriteFolderComics extends StatelessWidget {
  const FavoriteFolderComics({
    super.key,
    required this.comics,
    required this.members,
    required this.folder,
    required this.shelves,
    required this.aliases,
    required this.isCurrent,
    this.selections,
    this.menuBuilder,
    this.onTap,
    this.onLongPressed,
    this.useFavoriteDisplaySettings = true,
  });
  final List<FavoriteItem> comics;
  final List<FavoriteItem> members;
  final String folder;
  final bool shelves;
  final Map<String, String> aliases;
  final bool Function() isCurrent;
  final Map<Comic, bool>? selections;
  final List<MenuEntry> Function(Comic)? menuBuilder;
  final void Function(Comic, int)? onTap;
  final void Function(Comic, int)? onLongPressed;
  final bool useFavoriteDisplaySettings;

  @override
  Widget build(BuildContext context) {
    if (!shelves) {
      return SliverGridComics(
        comics: comics,
        selections: selections,
        menuBuilder: menuBuilder,
        onTap: onTap,
        onLongPressed: onLongPressed,
        useFavoriteDisplaySettings: useFavoriteDisplaySettings,
      );
    }
    final groups = authorShelves(
      members,
      aliases: aliases,
      orders: isCurrent()
          ? FavoritesScope.read(context).authorShelfOrders(folder)
          : const {},
      visible: comics
          .where((item) => isBlocked(item) == null)
          .map(favoriteIdentity)
          .toSet(),
    );
    return SliverList.list(
      children: [
        for (final group in groups)
          _AuthorShelf(
            key: ValueKey((folder, group.author)),
            folder: folder,
            group: group,
            isCurrent: isCurrent,
            selections: selections,
            menuBuilder: menuBuilder,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _AuthorShelf extends StatefulWidget {
  const _AuthorShelf({
    super.key,
    required this.folder,
    required this.group,
    required this.isCurrent,
    this.selections,
    this.menuBuilder,
    this.onTap,
  });
  final String folder;
  final AuthorShelfGroup group;
  final bool Function() isCurrent;
  final Map<Comic, bool>? selections;
  final List<MenuEntry> Function(Comic)? menuBuilder;
  final void Function(Comic, int)? onTap;
  @override
  State<_AuthorShelf> createState() => _AuthorShelfState();
}

class _AuthorShelfState extends State<_AuthorShelf> {
  final horizontal = ScrollController();
  static int _nextHero = -1;
  final heroes = <FavoriteIdentity, int>{};
  AuthorShelfState state = AuthorShelfState.normal;
  late final FavoriteStoreBinding binding;
  late final int generation;
  late final String dataPath;
  late final String? token;
  AuthorShelfState? pending;
  AuthorShelfState? retry;
  bool failed = false;
  final dragFocus = FocusNode();
  FocusNode? previousFocus;
  int? pointer;
  bool dragging = false;
  bool moving = false;
  String? moveError;
  Future<void> Function()? retryMove;
  bool get current =>
      mounted &&
      binding.isCurrent &&
      widget.isCurrent() &&
      binding.manager.connectionGeneration == generation &&
      App.dataPath == dataPath &&
      binding.manager.orderScopeToken(
            FavoriteOrderScope.folder(widget.folder),
          ) ==
          token;

  @override
  void initState() {
    super.initState();
    binding = FavoritesScope.capture(context);
    generation = binding.manager.connectionGeneration;
    dataPath = App.dataPath;
    token = binding.manager.orderScopeToken(
      FavoriteOrderScope.folder(widget.folder),
    );
    state = binding.manager.shelfState(widget.folder, widget.group.author);
    binding.manager.addListener(_reload);
    addComicWidgetStateListener(_reload);
    appdata.settings.addListener(_reload);
  }

  void _reload() {
    _cancelDrag();
    if (current) {
      setState(
        () => state = binding.manager.shelfState(
          widget.folder,
          widget.group.author,
        ),
      );
    }
  }

  void _cancelDrag() {
    if (dragging && pointer != null) {
      GestureBinding.instance.cancelPointer(pointer!);
    }
  }

  @override
  void dispose() {
    _cancelDrag();
    dragFocus.dispose();
    horizontal.dispose();
    binding.manager.removeListener(_reload);
    removeComicWidgetStateListener(_reload);
    appdata.settings.removeListener(_reload);
    super.dispose();
  }

  Future<void> _move(
    _ShelfDrag data,
    FavoriteIdentity target,
    bool before,
  ) async {
    if (!current || moving || token == null || data.owner != this) return;
    setState(() {
      moving = true;
      moveError = null;
    });
    retryMove = () => _move(data, target, before);
    try {
      await binding.manager.moveAuthorShelfFavorite(
        folder: widget.folder,
        author: widget.group.author,
        comic: data.comic,
        neighbor: target,
        before: before,
        visible: data.visible,
        token: token!,
        generation: generation,
        dataPath: dataPath,
        isCurrent: () => current,
      );
      if (current) retryMove = null;
    } catch (_) {
      if (current) {
        setState(
          () => moveError = 'Could not save favorite order. Try again.'.tl,
        );
      }
    } finally {
      if (current) setState(() => moving = false);
    }
  }

  Future<void> _change(AuthorShelfState next) async {
    if (!current || pending != null || token == null) return;
    setState(() {
      pending = next;
      failed = false;
      retry = next;
    });
    try {
      await binding.manager.setShelfState(
        folder: widget.folder,
        author: widget.group.author,
        state: next,
        token: token!,
        generation: generation,
        dataPath: dataPath,
        isCurrent: () => current,
      );
      if (current) {
        setState(() {
          state = next;
          retry = null;
        });
      }
    } catch (_) {
      if (current) setState(() => failed = true);
    } finally {
      if (current) setState(() => pending = null);
    }
  }

  void _scroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        state != AuthorShelfState.collapsed ||
        !HardwareKeyboard.instance.isShiftPressed ||
        !horizontal.hasClients) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted || !horizontal.hasClients) return;
      final delta = event.scrollDelta.dy != 0
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;
      horizontal.jumpTo(
        (horizontal.offset + delta).clamp(
          horizontal.position.minScrollExtent,
          horizontal.position.maxScrollExtent,
        ),
      );
      event.respond(allowPlatformDefault: false);
    });
  }

  Widget _tile(FavoriteItem item) {
    final id = favoriteIdentity(item);
    final hero = heroes.putIfAbsent(id, () => _nextHero--);
    final selected =
        widget.selections?.entries.any(
          (entry) =>
              entry.key is FavoriteItem &&
              favoriteIdentity(entry.key as FavoriteItem) == id &&
              entry.value,
        ) ??
        false;
    final index = widget.group.items.indexOf(item);
    final data = _ShelfDrag(
      this,
      widget.folder,
      widget.group.author,
      id,
      widget.group.items.map(favoriteIdentity).toSet(),
    );
    final tile = _ShelfTileSurface(
      key: ValueKey((widget.folder, widget.group.author, id)),
      selected: selected,
      enabled: !dragging && !moving,
      child: ComicTile(
        hoverColor: Colors.transparent,
        comic: item,
        heroID: hero,
        displayMode: comicFavoriteDisplayState().isGallery
            ? ComicTileDisplayMode.gallery
            : ComicTileDisplayMode.detailed,
        enableLongPressed: false,
        menuOptions: widget.menuBuilder?.call(item),
        onTap: () {
          if (current && !dragging && !moving) widget.onTap?.call(item, hero);
        },
      ),
    );
    return DragTarget<_ShelfDrag>(
      onWillAcceptWithDetails: (details) {
        final source = details.data;
        final accepted =
            current &&
            !moving &&
            source.owner == this &&
            source.folder == widget.folder &&
            source.author == widget.group.author &&
            source.comic != id;
        if (!accepted && source.owner != this && source.owner.current) {
          source.owner.setState(
            () =>
                source.owner.moveError = 'Move within the same author shelf'.tl,
          );
        }
        return accepted;
      },
      onAcceptWithDetails: (details) => _move(
        details.data,
        id,
        widget.group.items.indexWhere(
              (item) => favoriteIdentity(item) == details.data.comic,
            ) >
            index,
      ),
      builder: (context, candidates, rejected) => Listener(
        onPointerDown: (event) {
          if (event.buttons == kPrimaryButton) pointer = event.pointer;
        },
        child: LongPressDraggable<_ShelfDrag>(
          data: data,
          maxSimultaneousDrags: moving || !current ? 0 : 1,
          allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
          hapticFeedbackOnStart: false,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: () {
            previousFocus = FocusManager.instance.primaryFocus;
            dragFocus.requestFocus();
            setState(() {
              dragging = true;
              moveError = null;
            });
          },
          onDragEnd: (_) {
            if (!mounted) return;
            setState(() {
              dragging = false;
              pointer = null;
            });
            dragFocus.unfocus(
              disposition: UnfocusDisposition.previouslyFocusedChild,
            );
            if (previousFocus?.context?.mounted == true) {
              previousFocus!.requestFocus();
            }
          },
          feedback: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(item.name),
            ),
          ),
          childWhenDragging: Opacity(opacity: AppOpacity.disabled, child: tile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: candidates.isEmpty
                      ? null
                      : Border.all(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
                child: tile,
              ),
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: PopupMenuButton<(FavoriteIdentity, bool)>(
                  tooltip: 'Reorder within author'.tl,
                  enabled: !moving && current,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (target) => _move(data, target.$1, target.$2),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: index > 0
                          ? (
                              favoriteIdentity(widget.group.items[index - 1]),
                              true,
                            )
                          : null,
                      enabled: index > 0,
                      child: Text('Move up'.tl),
                    ),
                    PopupMenuItem(
                      value: index < widget.group.items.length - 1
                          ? (
                              favoriteIdentity(widget.group.items[index + 1]),
                              false,
                            )
                          : null,
                      enabled: index < widget.group.items.length - 1,
                      child: Text('Move down'.tl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.group.author ?? 'Unnamed author'.tl;
    return Focus(
      focusNode: dragFocus,
      onKeyEvent: (_, event) {
        if (dragging &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelDrag();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: AppSizes.hairline),
          Row(
            key: ValueKey((
              'author-shelf-header',
              widget.folder,
              widget.group.author,
            )),
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  key: ValueKey((
                    'author-shelf-name',
                    widget.folder,
                    widget.group.author,
                  )),
                  onPressed:
                      state == AuthorShelfState.collapsed || pending != null
                      ? null
                      : () => _change(
                          state == AuthorShelfState.expanded
                              ? AuthorShelfState.normal
                              : AuthorShelfState.expanded,
                        ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text('${widget.group.items.length}'),
              ),
              IconButton(
                tooltip:
                    (state == AuthorShelfState.normal
                            ? 'Collapse author shelf'
                            : 'Show author grid')
                        .tl,
                key: ValueKey((
                  'author-shelf-arrow',
                  widget.folder,
                  widget.group.author,
                )),
                onPressed: pending != null
                    ? null
                    : () => _change(
                        state == AuthorShelfState.normal
                            ? AuthorShelfState.collapsed
                            : AuthorShelfState.normal,
                      ),
                icon: Icon(
                  state == AuthorShelfState.collapsed
                      ? Icons.chevron_right
                      : Icons.expand_more,
                ),
              ),
            ],
          ),
          if (failed)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Could not save author shelf. Try again.'.tl,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: retry == null ? null : () => _change(retry!),
                  child: Text('Retry'.tl),
                ),
              ],
            ),
          if (moveError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    moveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                if (retryMove != null)
                  TextButton(
                    onPressed: moving ? null : retryMove,
                    child: Text('Retry'.tl),
                  ),
              ],
            ),
          _ShelfSizeTransition(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final display = comicFavoriteDisplayState();
                final delegate = SliverGridDelegateWithComics(
                  galleryColumns: display.isGallery
                      ? display.galleryColumns
                      : null,
                  forceDetailed: !display.isGallery,
                );
                final layout =
                    delegate.getLayout(
                          SliverConstraints(
                            axisDirection: AxisDirection.down,
                            growthDirection: GrowthDirection.forward,
                            userScrollDirection: ScrollDirection.idle,
                            scrollOffset: 0,
                            precedingScrollExtent: 0,
                            overlap: 0,
                            remainingPaintExtent: double.infinity,
                            crossAxisExtent: constraints.maxWidth,
                            crossAxisDirection: AxisDirection.right,
                            viewportMainAxisExtent: double.infinity,
                            remainingCacheExtent: double.infinity,
                            cacheOrigin: 0,
                          ),
                        )
                        as SliverGridRegularTileLayout;
                final height = layout.childMainAxisExtent;
                final width = layout.childCrossAxisExtent;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state == AuthorShelfState.collapsed)
                      SizedBox(
                        height: height,
                        child: SingleChildScrollView(
                          key: ValueKey((
                            'author-shelf-scroll',
                            widget.folder,
                            widget.group.author,
                          )),
                          controller: horizontal,
                          scrollDirection: Axis.horizontal,
                          child: Listener(
                            onPointerSignal: _scroll,
                            child: Row(
                              children: [
                                for (final item in widget.group.items)
                                  SizedBox(
                                    width: width,
                                    height: height,
                                    child: _tile(item),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        key: ValueKey((
                          'author-shelf-grid',
                          widget.folder,
                          widget.group.author,
                        )),
                        children: [
                          for (final item in widget.group.items)
                            SizedBox(
                              width: width,
                              height: height,
                              child: _tile(item),
                            ),
                        ],
                      ),
                    if (state == AuthorShelfState.expanded)
                      CreatorPlatformNamesView(
                        creators: {widget.group.author ?? ''},
                        isCurrent: widget.isCurrent,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A local ink host keeps ComicTile's focus/press effects above its base color.
/// Hover belongs to this UI instance and has the shelf's motion preference.
class _ShelfTileSurface extends StatefulWidget {
  const _ShelfTileSurface({
    super.key,
    required this.selected,
    required this.enabled,
    required this.child,
  });
  final bool selected;
  final bool enabled;
  final Widget child;
  @override
  State<_ShelfTileSurface> createState() => _ShelfTileSurfaceState();
}

class _ShelfTileSurfaceState extends State<_ShelfTileSurface> {
  bool hovered = false;
  void _hover(bool value) {
    final next = value && widget.enabled;
    if (next != hovered) {
      setState(() => hovered = next);
    }
  }

  @override
  void didUpdateWidget(covariant _ShelfTileSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = widget.selected
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surface;
    return MouseRegion(
      opaque: false,
      onEnter: (_) => _hover(true),
      onHover: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: Material(
        color: hovered
            ? Color.alphaBlend(
                theme.colorScheme.onSurface.withValues(alpha: AppOpacity.hover),
                base,
              )
            : base,
        animateColor: true,
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.fast,
        // Only the built-in hover paint is replaced; original focus, press,
        // menus and all gesture recognizers remain on the production ComicTile.
        child: widget.child,
      ),
    );
  }
}

/// Bypass the size animation when disabled rather than starting a zero-duration
/// animation from layout, which synchronously re-dirties RenderAnimatedSize.
class _ShelfSizeTransition extends StatelessWidget {
  const _ShelfSizeTransition({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: AppMotion.normal,
          alignment: Alignment.topCenter,
          child: child,
        );
}
