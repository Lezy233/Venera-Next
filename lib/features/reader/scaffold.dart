import 'dart:async';
import 'package:venera_next/components/settings_save_state.dart';

import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/features/reader/status_info.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/features/reader/progress_bar.dart';
import 'package:venera_next/features/reader/bottom_actions.dart';
import 'package:venera_next/features/reader/top_bar.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/features/reader/sidebar_binding.dart';
import 'package:venera_next/features/reader/thumbnails.dart';
import 'package:venera_next/features/history/history_api.dart'
    show ImageFavoriteResult;
import 'package:venera_next/features/reader/image_favorite_controller.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/auto_reading.dart';
import 'package:venera_next/features/reader/chapter_comments.dart';
import 'package:venera_next/features/reader/comments_controller.dart';
import 'package:venera_next/features/reader/chapter_navigation.dart';
import 'package:venera_next/features/reader/chapter_navigation_button.dart';
import 'package:venera_next/features/reader/chapters.dart';
import 'package:venera_next/features/reader/chapter_menu.dart';
import 'package:venera_next/features/reader/eink_refresh.dart';
import 'package:venera_next/features/reader/eink_refresh_controller.dart';
import 'package:venera_next/features/reader/gesture_port.dart';
import 'package:venera_next/features/reader/image_favorite_swipe.dart';
import 'package:venera_next/features/reader/platform_effects_controller.dart';
import 'shell_data.dart';
import 'progress_navigation.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/features/reader/image_export.dart';
import 'package:venera_next/features/reader/image_export_binding.dart';
import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/features/reader/settings_effects.dart';
import 'package:venera_next/features/reader/settings_panel.dart';
import 'package:venera_next/features/reader/image_selection.dart';
import 'package:venera_next/features/reader/image_picker.dart';
import 'package:venera_next/components/sidebar_resize_handle.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/routing/settings.dart';

class ReaderScaffold extends StatefulWidget {
  const ReaderScaffold({
    super.key,
    required this.data,
    required this.progress,
    required this.onExit,
    required this.onFullscreen,
    required this.onToggleAutomaticReading,
    required this.acquireSidebarPause,
    required this.readImagePickContext,
    required this.imageWork,
    required this.orientation,
    required this.onRotate,
    required this.onSystemUiChanged,
    required this.createChapterMenu,
    this.createThumbnails,
    required this.favoriteChanges,
    required this.createFavoriteQuery,
    required this.createImageFavorite,
    required this.createImageExport,
    required this.createSettings,
    required this.createChapterComments,
    required this.chapterNavigation,
    required this.child,
  });

  final ReaderShellData data;
  final ReaderProgressRequest progress;
  final Future<void> Function() onExit;
  final VoidCallback? onFullscreen;
  final bool Function() onToggleAutomaticReading;
  final VoidCallback Function() acquireSidebarPause;
  final ReaderImagePickContext? Function() readImagePickContext;
  final ImageWork imageWork;
  final ReaderOrientation orientation;
  final VoidCallback? onRotate;
  final void Function(bool menuOpen) onSystemUiChanged;
  final ReaderChapterMenuRequest? Function() createChapterMenu;
  final ReaderThumbnailRequest? Function()? createThumbnails;
  final Listenable favoriteChanges;
  final ReaderImageFavoriteQuery? Function() createFavoriteQuery;
  final ReaderImageFavoriteRequest? Function() createImageFavorite;
  final ReaderImageExportRequest? Function() createImageExport;
  final ReaderSettingsRequest? Function() createSettings;
  final ReaderChapterCommentsRequest? Function() createChapterComments;
  final ReaderChapterNavigationAction? chapterNavigation;
  final Widget child;

  @override
  State<ReaderScaffold> createState() => ReaderScaffoldState();
}

class ReaderScaffoldState extends State<ReaderScaffold> {
  var _brightnessPreview = ReaderBrightnessPreview();

  late double _thumbnailWidth;
  late double _thumbnailHeight;
  DesktopChromeController? _chrome;
  DesktopReaderActions? _desktopReaderActions;
  bool? _thumbnailCollapsedOverride;
  final _chapterQuery = ValueNotifier<String>('');
  ReaderChapterMenuRequest? _chapterSearchRequest;
  ReaderSidebarHandle? _chapterSearchHandle;

  bool get _thumbnailCollapsed =>
      _thumbnailCollapsedOverride ??
      widget.data.preferences.readerThumbnailState == 'collapsed';

  bool _isOpen = false;

  bool _brightnessPanelOpen = false;

  final EInkRefreshController _eInkRefreshController = EInkRefreshController();

  static const kTopBarHeight = 56.0;

  bool get isOpen => _isOpen;

  ReaderGesturePort? _gesturePort;
  ReaderGesturePort? get gestureDetectorState => _gesturePort;
  void onGesturePortChanged(ReaderGesturePort port, bool attached) {
    if (!attached && !identical(_gesturePort, port)) return;
    _gesturePort = attached ? port : null;
    _imageFavoriteSwipe.attach(_gesturePort);
    if (attached && mounted) addDragListener();
  }

  late final _imageFavoriteSwipe = ImageFavoriteSwipeBinding(
    isVertical: () => widget.data.vertical,
    collect: addImageFavorite,
  );

  void addDragListener() {
    if (!mounted) return;
    _imageFavoriteSwipe.setEnabled(widget.data.swipeToCollect);
  }

  @override
  void initState() {
    super.initState();
    final layout = GlobalPreferenceStore(appdata.settings);
    _thumbnailWidth = layout
        .read(LayoutPreferences.readerThumbnailWidth)
        .toDouble();
    _thumbnailHeight = layout
        .read(LayoutPreferences.readerThumbnailHeight)
        .toDouble();
    _brightnessPreview.addListener(update);
    widget.favoriteChanges.addListener(_imageFavoritesChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chrome = _chrome = DesktopChromeScope.maybeRead(context);
    if (chrome == null) return;
    final actions = _desktopReaderActions ??= DesktopReaderActions(
      openSettings: openSetting,
      openChapters: openChapterDrawer,
      toggleThumbnails: _toggleThumbnail,
      filterChapters: _filterChapters,
      submitChapterSearch: _submitChapterSearch,
    );
    chrome.setReaderActions(actions);
  }

  @override
  void dispose() {
    final actions = _desktopReaderActions;
    if (actions != null && identical(_chrome?.readerActions, actions)) {
      _chrome?.setReaderActions(null);
    }
    _chapterQuery.dispose();
    _brightnessPreview.dispose();
    widget.favoriteChanges.removeListener(_imageFavoritesChanged);
    unawaited(_favorites.dispose());
    _sidebarBinding.dispose();
    _imageFavoriteSwipe.dispose();
    _gesturePort = null;
    unawaited(_exporter?.dispose());
    _imagePicker.dispose();
    _selectionOverlay.dispose();
    _eInkRefreshController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReaderScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.favoriteChanges, widget.favoriteChanges)) {
      oldWidget.favoriteChanges.removeListener(_imageFavoritesChanged);
      widget.favoriteChanges.addListener(_imageFavoritesChanged);
      _favorites.invalidate();
    }
    if (oldWidget.data.comicId != widget.data.comicId ||
        oldWidget.data.sourceKey != widget.data.sourceKey ||
        !identical(oldWidget.imageWork, widget.imageWork)) {
      _replaceBrightnessPreview();
    }
    if (oldWidget.data.swipeToCollect != widget.data.swipeToCollect) {
      addDragListener();
    }
    if (!identical(oldWidget.imageWork, widget.imageWork)) {
      unawaited(_favorites.dispose());
      _favorites = _createFavorites();
      unawaited(_exporter?.dispose());
      _exporter = null;
    }
  }

  void _replaceBrightnessPreview() {
    _sidebarBinding.close();
    _brightnessPreview.dispose();
    _brightnessPreview = ReaderBrightnessPreview()..addListener(update);
  }

  void _applySystemUiMode() {
    widget.onSystemUiChanged(_isOpen);
  }

  void openOrClose() {
    setState(() {
      _isOpen = !_isOpen;
      if (!_isOpen) {
        _brightnessPanelOpen = false;
      }
    });
    _applySystemUiMode();
  }

  void update() {
    if (mounted) setState(() {});
  }

  void requestEInkRefresh() {
    if (!mounted || !widget.data.gallery) {
      return;
    }

    final settings = widget.data.preferences;
    if (!settings.eInkRefreshEnabled) {
      _eInkRefreshController.reset();
      return;
    }
    _eInkRefreshController.onPageChanged(
      interval: settings.eInkRefreshInterval,
      durationMilliseconds: settings.eInkRefreshDuration,
      style: EInkRefreshStyle.fromKey(settings.eInkRefreshStyle),
    );
  }

  void resetEInkRefreshCounter() {
    _eInkRefreshController.reset();
  }

  void _persistThumbnailSettings() {
    final width = _thumbnailWidth;
    final height = _thumbnailHeight;
    unawaited(
      appdata
          .updateSettings((draft) {
            final store = GlobalPreferenceStore(draft);
            store.write(LayoutPreferences.readerThumbnailWidth, width);
            store.write(LayoutPreferences.readerThumbnailHeight, height);
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Reader thumbnail settings', error, stack);
            },
          ),
    );
  }

  void _persistThumbnailState(bool collapsed) {
    unawaited(
      appdata
          .updateSettings((draft) {
            ReaderPreferenceStore(
              settings: draft,
              scope: ReaderPreferenceScope.active,
              comicId: widget.data.comicId,
              sourceKey: widget.data.sourceKey,
            ).write(
              ReaderPreferences.readerThumbnailState,
              collapsed ? 'collapsed' : 'expanded',
            );
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Reader thumbnail state', error, stack);
            },
          ),
    );
  }

  void _toggleThumbnail() {
    final next = !_thumbnailCollapsed;
    setState(() => _thumbnailCollapsedOverride = next);
    _persistThumbnailState(next);
  }

  void _resizeThumbnails({required bool vertical, required double delta}) {
    final wasCollapsed = _thumbnailCollapsed;
    var becameCollapsed = wasCollapsed;
    setState(() {
      if (vertical) {
        if (!wasCollapsed || delta > 0) {
          _thumbnailCollapsedOverride = false;
          final next = (_thumbnailWidth + delta).clamp(120.0, 480.0);
          if (next <= 130 && wasCollapsed) {
            _thumbnailCollapsedOverride = true;
            becameCollapsed = true;
          } else {
            _thumbnailWidth = next;
          }
        }
      } else {
        if (!wasCollapsed || delta > 0) {
          _thumbnailCollapsedOverride = false;
          final next = (_thumbnailHeight + delta).clamp(100.0, 320.0);
          if (next <= 110 && wasCollapsed) {
            _thumbnailCollapsedOverride = true;
            becameCollapsed = true;
          } else {
            _thumbnailHeight = next;
          }
        }
      }
    });
    if (becameCollapsed != wasCollapsed) {
      _persistThumbnailState(becameCollapsed);
    }
  }

  void _finishThumbnailResize() => _persistThumbnailSettings();

  Widget _buildBody() {
    final content = AbsorbPointer(
      absorbing: widget.data.animating,
      child: widget.child,
    );
    // Thumbnail strips target wide (desktop) layouts; narrow readers keep the
    // full page area and no overlay.
    if (context.width < 900 || widget.data.onCommentsPage) return content;
    final request = widget.createThumbnails?.call();
    if (request == null || request.isEmpty) return content;
    final settings = widget.data.preferences;
    final position = settings.readerThumbnailPosition;
    final vertical = position != 'bottom';
    final floating = settings.readerThumbnailMode == 'floating';
    final readingReversed =
        settings.readerMode == 'galleryRightToLeft' ||
        settings.readerMode == 'continuousRightToLeft';
    // Bottom strips follow the reading order; top-to-bottom reading can choose
    // its own horizontal direction.
    final reverse =
        !vertical &&
        (widget.data.vertical
            ? settings.readerThumbnailScrollDirection == 'rightToLeft'
            : readingReversed);
    final size = vertical ? _thumbnailWidth : _thumbnailHeight;
    final collapsed = _thumbnailCollapsed;

    void select(int page) {
      if (!request.isCurrent()) return;
      request.select(page);
    }

    Widget handle({required bool expanded}) {
      if (vertical) {
        return SidebarResizeHandle(
          expanded: expanded,
          mirror: position == 'right',
          onToggle: _toggleThumbnail,
          onDrag: (delta) => _resizeThumbnails(
            vertical: true,
            delta: position == 'right' ? -delta : delta,
          ),
          onDragEnd: _finishThumbnailResize,
        );
      }
      return _BottomResizeHandle(
        expanded: expanded,
        onToggle: _toggleThumbnail,
        onDrag: (delta) => _resizeThumbnails(vertical: false, delta: delta),
        onDragEnd: _finishThumbnailResize,
      );
    }

    if (collapsed) {
      return Stack(
        children: [
          Positioned.fill(child: content),
          if (vertical)
            Positioned(
              left: position == 'left' ? 0 : null,
              right: position == 'right' ? 0 : null,
              top: 0,
              bottom: 0,
              child: handle(expanded: false),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 14,
              child: handle(expanded: false),
            ),
        ],
      );
    }

    final panel = ReaderThumbnailsView(
      request: request,
      vertical: vertical,
      reverse: reverse,
      size: size,
      onSelect: select,
    );

    if (floating) {
      return Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            left: vertical ? (position == 'left' ? 0 : null) : 0,
            right: vertical ? (position == 'right' ? 0 : null) : 0,
            top: vertical ? 0 : null,
            bottom: 0,
            width: vertical ? size : null,
            height: vertical ? null : size,
            child: panel,
          ),
          if (vertical)
            Positioned(
              left: position == 'left' ? size - 7 : null,
              right: position == 'right' ? size - 7 : null,
              top: 0,
              bottom: 0,
              child: handle(expanded: true),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: size - 7,
              height: 14,
              child: handle(expanded: true),
            ),
        ],
      );
    }

    final Widget fixed;
    if (position == 'left') {
      fixed = Row(
        children: [
          SizedBox(width: size, child: panel),
          Expanded(child: content),
        ],
      );
    } else if (position == 'right') {
      fixed = Row(
        children: [
          Expanded(child: content),
          SizedBox(width: size, child: panel),
        ],
      );
    } else {
      fixed = Column(
        children: [
          Expanded(child: content),
          SizedBox(height: size, child: panel),
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: fixed),
        if (vertical)
          Positioned(
            left: position == 'left' ? size - 7 : null,
            right: position == 'right' ? size - 7 : null,
            top: 0,
            bottom: 0,
            child: handle(expanded: true),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: size - 7,
            height: 14,
            child: handle(expanded: true),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnChapterCommentsPage = widget.data.onCommentsPage;
    final brightnessPanelVisible = _isOpen && _brightnessPanelOpen;
    final menuDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final scaler = MediaQuery.textScalerOf(context);
    final titleScale = [12.0, 16.0, 18.0]
        .map((size) => scaler.scale(size) / size)
        .fold(1.0, (largest, scale) => scale > largest ? scale : largest);
    final topBarHeight = kTopBarHeight * titleScale;
    return Stack(
      children: [
        Positioned.fill(child: _buildBody()),
        if (!isOnChapterCommentsPage)
          Positioned.fill(
            child: ReaderBrightnessOverlay(
              enabled:
                  _brightnessPreview.enabled ??
                  widget.data.preferences.readerBrightnessEnabled,
              brightness:
                  _brightnessPreview.brightness ??
                  widget.data.preferences.readerBrightness,
            ),
          ),
        if (!isOnChapterCommentsPage) _buildInformation(),
        ReaderChapterNavigationButton(action: widget.chapterNavigation),
        AnimatedPositioned(
          duration: menuDuration,
          top: _isOpen ? 0 : -(topBarHeight + context.padding.top),
          left: 0,
          right: 0,
          // Insets change immediately when the native/custom frame changes.
          // Keep content height in sync; animate only its entrance position.
          child: SizedBox(
            height: topBarHeight + context.padding.top,
            child: _menuRegion(visible: _isOpen, child: buildTop()),
          ),
        ),
        AnimatedPositioned(
          duration: menuDuration,
          bottom: _isOpen
              ? 0
              : -(ReaderBottomBar.height +
                    MediaQuery.of(context).padding.bottom),
          left: 0,
          right: 0,
          child: _menuRegion(visible: _isOpen, child: buildBottom()),
        ),
        AnimatedPositioned(
          duration: menuDuration,
          curve: Curves.easeOut,
          right: 16 + context.padding.right,
          bottom: brightnessPanelVisible
              ? ReaderBottomBar.height + context.padding.bottom + 12
              : -context.height,
          child: _menuRegion(
            visible: brightnessPanelVisible,
            child: buildBrightnessPanel(),
          ),
        ),
        Positioned.fill(
          child: EInkRefreshOverlay(controller: _eInkRefreshController),
        ),
      ],
    );
  }

  Widget _menuRegion({required bool visible, required Widget child}) =>
      ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      );

  Widget buildTop() => ReaderTopBar(
    title: widget.data.title,
    chapterTitle: widget.data.chapterTitle,
    onBack: () => unawaited(widget.onExit()),
    actions: [
      if (shouldShowChapterComments())
        Tooltip(
          message: "Chapter Comments".tl,
          child: IconButton(
            icon: const Icon(Icons.comment),
            onPressed: openChapterComments,
          ),
        ),
      Tooltip(
        message: "Settings".tl,
        child: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: openSetting,
        ),
      ),
    ],
  );

  late var _favorites = _createFavorites();

  ReaderImageFavoriteController
  _createFavorites() => ReaderImageFavoriteController(
    work: widget.imageWork,
    onChanged: () {
      if (mounted) update();
    },
    cancelSelection: _selectionOverlay.cancel,
    onUnsupported: () => showToast(
      message: 'Local comic collection is not supported at present'.tl,
      context: context,
    ),
    onResult: (result) => showToast(
      message: switch (result) {
        ImageFavoriteResult.protectedCover =>
          'The cover cannot be uncollected here'.tl,
        ImageFavoriteResult.chapterOrderChanged =>
          'The chapter order of the comic may have changed, temporarily not supported for collection'
              .tl,
        ImageFavoriteResult.collected => 'Successfully collected'.tl,
        ImageFavoriteResult.uncollected => 'Uncollected the image'.tl,
      },
      context: context,
      seconds: 1,
    ),
    onError: (error, stack) {
      Log.error('Image Favorite', error, stack);
      showToast(message: error.toString(), context: context, seconds: 1);
    },
  );

  void _imageFavoritesChanged() => _favorites.invalidate();

  void addImageFavorite() =>
      unawaited(_favorites.collect(widget.createImageFavorite(), _pickImage));

  Future<int?> _pickImage() async {
    final selection = await _imagePicker.pick();
    return selection != null &&
            selection.isCurrent(widget.readImagePickContext())
        ? selection.index
        : null;
  }

  Widget buildBottom() {
    _favorites.bind(widget.createFavoriteQuery());
    return _buildBottom();
  }

  Widget _buildBottom() {
    // Use maxPage for display (excluding chapter comments page)
    final progress = widget.progress;
    final toggleAutomaticReading = widget.onToggleAutomaticReading;
    final work = widget.imageWork;
    final displayPage = progress.page.clamp(1, progress.maxPage);
    var text = "E${progress.chapter} : P$displayPage";
    if (!widget.data.hasChapters) {
      text = "P$displayPage";
    }
    String edgeLabel(int direction) {
      final target = progress.chapter + direction;
      if (target >= 1 && target <= progress.maxChapter) {
        return direction < 0 ? 'Previous chapter'.tl : 'Next chapter'.tl;
      }
      return 'Page @page'.tlParams({
        'page': direction < 0 ? '1' : '${progress.maxPage}',
      });
    }

    final buttons = buildReaderBottomActions(
      context,
      imageFavoriteStatus: _favorites.status,
      imageCollecting: _favorites.collecting,
      onCollect: _favorites.canCollect ? addImageFavorite : null,
      onRetryImageStatus: _favorites.retry,
      onFullscreen: widget.onFullscreen,
      orientation: widget.orientation,
      onRotate: widget.onRotate,
      brightnessEnabled:
          _brightnessPreview.enabled ??
          widget.data.preferences.readerBrightnessEnabled,
      onBrightness: () =>
          setState(() => _brightnessPanelOpen = !_brightnessPanelOpen),
      automaticReading: ReaderAutomaticReadingAction(
        tooltip: switch (widget.data.automaticReading) {
          AutoReadingStatus.waiting =>
            'Automatic reading is waiting for content'.tl,
          AutoReadingStatus.paused => 'Automatic reading is paused'.tl,
          _ => 'Start or stop automatic reading'.tl,
        },
        active: widget.data.automaticReadingActive,
        playing: widget.data.automaticReadingActive,
        onPressed: () {
          if (!mounted || !identical(widget.imageWork, work)) return;
          final active = toggleAutomaticReading();
          if (mounted && active && isOpen) openOrClose();
          update();
        },
      ),
      onChapters: widget.data.hasChapters ? openChapterDrawer : null,
      onSave: saveCurrentImage,
      onShare: share,
    );

    return ReaderBottomBar(
      label: text,
      actions: buttons,
      page: progress.page,
      maxPage: progress.maxPage,
      reversed: progress.reversed,
      isOpen: isOpen,
      progressIdentity: progress.identity,
      onPageChanged: progress.selectPage,
      onPrevious: progress.previous,
      onNext: progress.next,
      previousTooltip: edgeLabel(progress.reversed ? 1 : -1),
      nextTooltip: edgeLabel(progress.reversed ? -1 : 1),
    );
  }

  Widget buildBrightnessPanel() => SettingsSaveScope(
    work: widget.imageWork,
    child: ReaderBrightnessSetting(
      comicId: widget.data.comicId,
      sourceKey: widget.data.sourceKey,
      preview: _brightnessPreview,
      panel: true,
      onChanged: _onSettingChanged,
    ),
  );

  Widget _buildInformation() {
    final preferences = widget.data.preferences;
    final showPage = preferences.showPageNumberInReader;
    final showStatus = preferences.enableClockAndBatteryInfoInReader;
    if (!showPage && !showStatus) return const SizedBox.shrink();
    final progress = widget.progress;
    final padding = context.padding;
    return Positioned(
      bottom: 13 + padding.bottom,
      left: 25 + padding.left,
      right: 25 + padding.right,
      child: IgnorePointer(
        child: OverflowBar(
          alignment: showPage
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.end,
          spacing: 12,
          overflowSpacing: 4,
          overflowAlignment: OverflowBarAlignment.end,
          children: [
            if (showPage)
              ReaderPageInfo(
                page: progress.page,
                maxPage: progress.maxPage,
                chapterTitle: widget.data.hasChapters
                    ? widget.data.chapterTitle ?? 'E${progress.chapter}'
                    : null,
              ),
            if (showStatus)
              const ReaderStatusInfo(
                key: ValueKey('reader-status-information'),
              ),
          ],
        ),
      ),
    );
  }

  void _filterChapters(String query) {
    if (!mounted) return;
    _chapterQuery.value = query;
    openChapterDrawer();
  }

  void _submitChapterSearch(String query) {
    final request = _chapterSearchRequest;
    final handle = _chapterSearchHandle;
    if (!mounted || request == null || handle?.isCurrent != true) return;
    final first = request.data
        .filteredGroups(query)
        .expand((group) => group.entries)
        .firstOrNull;
    if (first != null && request.select(first.index)) handle?.close();
  }

  void openChapterDrawer() {
    if (_chapterSearchHandle?.isCurrent == true) return;
    final request = widget.createChapterMenu();
    if (request == null) return;
    ReaderSidebarHandle? handle;
    handle = _sidebarBinding.show(
      context,
      ValueListenableBuilder<String>(
        valueListenable: _chapterQuery,
        builder: (context, query, _) => ReaderChaptersView(
          data: request.data,
          query: query,
          onSelect: (chapter) {
            if (handle?.isCurrent != true) return;
            request.select(chapter);
            handle?.close();
          },
          onClose: () => handle?.close(),
        ),
      ),
      // The command center lives above this route and keeps keyboard input.
      requestFocus: _chrome?.searchFocusNode.context != null ? false : null,
    );
    if (handle != null) {
      _chapterSearchHandle = handle;
      _chapterSearchRequest = request;
    }
  }

  ReaderImageExportBinding? _exporter;
  ReaderImageExportBinding get _imageExporter =>
      _exporter ??= ReaderImageExportBinding(
        context: context,
        work: widget.imageWork,
        cancelSelection: _selectionOverlay.cancel,
        createRequest: () => widget.createImageExport(),
        pick: _pickImage,
      );

  void saveCurrentImage() => unawaited(_imageExporter.export(sharing: false));
  void share() => unawaited(_imageExporter.export(sharing: true));

  void openSetting() {
    final request = widget.createSettings();
    if (request == null || !request.isCurrent()) return;
    final work = widget.imageWork;
    bool isCurrent() =>
        mounted && identical(widget.imageWork, work) && request.isCurrent();
    setState(() {
      _brightnessPanelOpen = false;
    });
    _openSideBar(
      ReaderSettingsPanel(
        request: request,
        work: work,
        isCurrent: isCurrent,
        onChanged: (key) {
          if (isCurrent()) {
            request.apply(key, applyShellEffect: _applyShellEffect);
          }
        },
        brightnessPreview: _brightnessPreview,
      ),
      width: 400,
    );
  }

  void _onSettingChanged(String key) {
    if (!mounted) return;
    widget.createSettings()?.apply(key, applyShellEffect: _applyShellEffect);
  }

  void _applyShellEffect(ReaderSettingEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case ReaderSettingEffect.rebindImageGesture:
        addDragListener();
      case ReaderSettingEffect.resetEInk:
        resetEInkRefreshCounter();
      case ReaderSettingEffect.updateSystemUi:
        _applySystemUiMode();
      case ReaderSettingEffect.rebuildShell:
        update();
      default:
        throw ArgumentError.value(effect, 'effect', 'Not a shell effect');
    }
  }

  late final _sidebarBinding = ReaderSidebarBinding(
    canOpen: () => mounted,
    acquireInteraction: () {
      final releasePause = widget.acquireSidebarPause();
      final gesture = gestureDetectorState;
      gesture?.ignoreNextTap();
      return () {
        try {
          releasePause();
        } finally {
          gesture?.clearIgnoreNextTap();
        }
      };
    },
    onError: (error, stack) {
      Log.error('Reader', 'Failed to open sidebar: $error', stack);
      if (mounted) context.showMessage(message: error.toString());
    },
  );

  void _openSideBar(Widget widget, {double width = 400}) =>
      _sidebarBinding.show(context, widget, width: width);

  bool shouldShowChapterComments() {
    return widget.createChapterComments() != null;
  }

  void openChapterComments() {
    final request = widget.createChapterComments();
    if (request == null || !request.isCurrent()) return;
    ReaderSidebarHandle? handle;
    handle = _sidebarBinding.show(
      context,
      ChapterCommentsPage(
        request: request,
        work: widget.imageWork,
        onRetired: () => handle?.close(),
      ),
      width: 500,
      isRequestCurrent: request.isCurrent,
    );
  }

  late final _imagePicker = ReaderImagePicker(
    current: () => mounted ? widget.readImagePickContext() : null,
    selectPosition: _showSelectImageOverlay,
  );

  final _selectionOverlay = ReaderImageSelectionOverlay();

  Future<Offset?> _showSelectImageOverlay() {
    if (_isOpen) openOrClose();
    return _selectionOverlay.show(context);
  }
}

class _BottomResizeHandle extends StatelessWidget {
  const _BottomResizeHandle({
    required this.expanded,
    required this.onToggle,
    required this.onDrag,
    required this.onDragEnd,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        onVerticalDragUpdate: (details) => onDrag(-details.delta.dy),
        onVerticalDragEnd: (_) => onDragEnd(),
        child: SizedBox(
          height: 14,
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
