import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/components/file_save_task.dart';
import 'favorite_models.dart';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/flyout.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/components/sidebar_resize_handle.dart';
import 'package:venera_next/components/window_selection_task.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_actions.dart';
import 'package:venera_next/features/favorites/favorite_filters.dart';
import 'package:venera_next/features/favorites/favorites_display.dart';
import 'package:venera_next/features/favorites/favorites_constants.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/comic_reorder_page.dart';
import 'package:venera_next/features/favorites/folder_rename_dialog.dart';
import 'package:venera_next/features/favorites/favorite_confirmation_dialog.dart';
import 'package:venera_next/features/favorites/favorite_transfer_dialog.dart';
import 'package:venera_next/features/favorites/favorite_metadata_dialog.dart';
import 'package:venera_next/features/local_comics/local_comics.dart';
import 'package:venera_next/features/reader/reader.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/selection_operation.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_locale.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/navigation_admission.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/consts.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/opencc.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

/// If the number of comics in a folder exceeds this limit, it will be
/// fetched asynchronously.
const _asyncDataFetchLimit = 500;

class LocalFavoritesPage extends StatefulWidget {
  const LocalFavoritesPage({
    required this.folder,
    required this.showFolders,
    required this.onFolderSelected,
    required this.updateFolderList,
    this.importFolder = importNetworkFolder,
    super.key,
  });

  final String folder;
  final VoidCallback showFolders;
  final void Function(bool isNetwork, String? folder) onFolderSelected;
  final VoidCallback updateFolderList;
  final Future<void> Function(
    BuildContext context,
    String source,
    int pages,
    String folder,
    String remoteFolder,
  )
  importFolder;

  @override
  State<LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<LocalFavoritesPage> {
  late List<FavoriteItem> comics;

  String? networkSource;
  String? networkFolder;

  Map<Comic, bool> selectedComics = {};

  String keyword = "";
  bool searchHasUpper = false;

  bool searchMode = false;

  bool multiSelectMode = false;

  int? lastSelectedIndex;

  bool get isAllFolder => widget.folder == localAllFolderLabel;

  LocalFavoritesManager get manager => _store.manager;

  late final FavoriteStoreBinding _store;

  late final LocalFavoritesManager _observedManager;
  late final int _observedGeneration;
  late final String _observedDataPath;
  WindowSelectionTask? _queryOwner;
  final _metadataTasks = <WindowSelectionTask>{};

  bool get _canReadObservedFolder =>
      mounted &&
      _queryOwner?.active == true &&
      _store.isCurrent &&
      _observedManager.connectionGeneration == _observedGeneration &&
      App.dataPath == _observedDataPath;

  bool isLoading = false;
  int _queryGeneration = 0;
  int _filterRequest = 0;
  ModalRoute<dynamic>? _updateFlyoutRoute;
  Object? _loadError;

  late String readFilterSelect;

  late Set<String> authorFilters;

  late Set<String> tagFilters;

  late String sortMode;

  late double _filterPanelWidth;

  late bool _filterPanelOpen;

  bool _resizingFilterPanel = false;

  static const _kFilterPanelBreakpoint = 900.0;
  static const _kFilterPanelMinWidth = 260.0;
  static const _kFilterPanelMaxWidth = 460.0;

  static Set<String> _readFilterValues(Object? value) =>
      value is List ? value.whereType<String>().toSet() : <String>{};

  String _storedSortMode() {
    final modes = appdata.implicitData['local_favorites_sort_modes'];
    final stored = modes is Map ? modes[widget.folder] : null;
    return stored is String && favoriteSortModes.contains(stored)
        ? stored
        : favoriteSortModes.first;
  }

  var searchResults = <FavoriteItem>[];

  void updateSearchResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = comics;
      } else {
        searchResults = [];
        for (var comic in comics) {
          if (matchKeyword(keyword, comic) ||
              matchKeywordT(keyword, comic) ||
              matchKeywordS(keyword, comic)) {
            searchResults.add(comic);
          }
        }
      }
    });
  }

  void updateComics() {
    if (!_canReadObservedFolder) return;
    final manager = _observedManager;
    final generation = ++_queryGeneration;
    final folder = widget.folder;
    _loadError = null;
    isLoading = false;
    try {
      final count = isAllFolder
          ? manager.totalComics
          : manager.folderComics(folder);
      if (!isAllFolder && !manager.existsFolder(folder)) {
        comics = [];
      } else if (count < _asyncDataFetchLimit) {
        comics = isAllFolder
            ? manager.getAllComics()
            : manager.getFolderComics(folder);
      } else {
        isLoading = true;
        final reading = isAllFolder
            ? manager.getAllComicsAsync()
            : manager.getFolderComicsAsync(folder);
        unawaited(
          reading.then<void>(
            (value) {
              if (!_canReadObservedFolder ||
                  generation != _queryGeneration ||
                  widget.folder != folder) {
                return;
              }
              setState(() {
                isLoading = false;
                comics = value;
              });
            },
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites query', error, stack);
              if (!_canReadObservedFolder ||
                  generation != _queryGeneration ||
                  widget.folder != folder) {
                return;
              }
              setState(() {
                isLoading = false;
                _loadError = error;
              });
            },
          ),
        );
      }
    } catch (error, stack) {
      Log.error('Favorites query', error, stack);
      _loadError = error;
    }
    setState(() {});
  }

  List<FavoriteItem> filterComics(List<FavoriteItem> curComics) {
    return curComics.where((comic) {
      if (authorFilters.isNotEmpty &&
          !favoriteAuthorValues(comic).any(authorFilters.contains)) {
        return false;
      }
      if (tagFilters.isNotEmpty && !_matchesTagFilters(comic)) {
        return false;
      }
      var history = HistoryScope.read(
        context,
      ).find(comic.id, ComicType(comic.sourceKey.hashCode));
      if (readFilterSelect == "UnCompleted") {
        return history == null || history.page != history.maxPage;
      } else if (readFilterSelect == "Completed") {
        return history != null && history.page == history.maxPage;
      }
      return true;
    }).toList();
  }

  bool _matchesTagFilters(FavoriteItem comic) {
    for (final tag in comic.tags) {
      if (tagFilters.contains(favoriteTagValue(tag)) ||
          tagFilters.contains(favoriteTagLabel(tag))) {
        return true;
      }
    }
    return false;
  }

  List<String> _collectFilterValues(Iterable<String> values) {
    final result = values.toSet().toList();
    result.sort();
    return result;
  }

  void _persistFilters() {
    final readFilter = readFilterSelect;
    final authors = authorFilters.toList();
    final tags = tagFilters.toList();
    unawaited(
      appdata
          .updateImplicit((draft) {
            draft['local_favorites_read_filter'] = readFilter;
            draft['local_favorites_author_filter'] = authors;
            draft['local_favorites_tag_filter'] = tags;
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites filter', error, stack);
            },
          ),
    );
  }

  void _persistSortMode() {
    final folder = widget.folder;
    final mode = sortMode;
    final stored = appdata.implicitData['local_favorites_sort_modes'];
    final modes = <String, Object?>{
      if (stored is Map)
        for (final entry in stored.entries) '${entry.key}': entry.value,
      folder: mode,
    };
    unawaited(
      appdata
          .updateImplicit((draft) {
            draft['local_favorites_sort_modes'] = modes;
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites sort mode', error, stack);
            },
          ),
    );
  }

  void _setReadFilter(String value) {
    setState(() => readFilterSelect = value);
    _persistFilters();
    updateComics();
  }

  void _setSortMode(String value) {
    setState(() => sortMode = value);
    _persistSortMode();
  }

  void _toggleAuthorFilter(String value) {
    setState(() {
      if (!authorFilters.remove(value)) authorFilters.add(value);
    });
    _persistFilters();
  }

  void _toggleTagFilter(String value) {
    setState(() {
      if (!tagFilters.remove(value)) tagFilters.add(value);
    });
    _persistFilters();
  }

  void _toggleFilterPanel() {
    setState(() => _filterPanelOpen = !_filterPanelOpen);
    _persistFilterPanel();
  }

  void _resizeFilterPanel(double delta) {
    setState(() {
      _resizingFilterPanel = true;
      if (!_filterPanelOpen) {
        if (delta >= 0) return;
        _filterPanelOpen = true;
        _filterPanelWidth = _kFilterPanelMinWidth;
        return;
      }
      final next = _filterPanelWidth - delta;
      if (next < _kFilterPanelMinWidth) {
        _filterPanelOpen = false;
        _filterPanelWidth = _kFilterPanelMinWidth;
        return;
      }
      _filterPanelWidth = next.clamp(
        _kFilterPanelMinWidth,
        _kFilterPanelMaxWidth,
      );
    });
  }

  void _finishFilterPanelResize() {
    if (_resizingFilterPanel) {
      setState(() => _resizingFilterPanel = false);
    }
    _persistFilterPanel();
  }

  void _persistFilterPanel() {
    final width = _filterPanelWidth;
    final open = _filterPanelOpen;
    unawaited(
      appdata
          .updateSettings((draft) {
            final store = GlobalPreferenceStore(draft);
            store.write(LayoutPreferences.favoritesFilterPanelWidth, width);
            store.write(LayoutPreferences.favoritesFilterPanelOpen, open);
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites filter panel', error, stack);
            },
          ),
    );
  }

  List<String> _availableAuthors() => _collectFilterValues([
    for (final comic in comics) ...favoriteAuthorValues(comic),
  ]);

  List<String> _availableTags() => _collectFilterValues([
    for (final comic in comics)
      for (final tag in comic.tags) favoriteTagLabel(tag),
  ]);

  Widget _buildFilterPanel() {
    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Filter".tl,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleFilterPanel,
                  tooltip: "Close".tl,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _FavoriteFilterEditor(
                readFilter: readFilterSelect,
                sortMode: sortMode,
                authors: authorFilters,
                tags: tagFilters,
                authorOptions: _availableAuthors(),
                tagOptions: _availableTags(),
                editable: true,
                onReadFilter: _setReadFilter,
                onSortMode: _setSortMode,
                onAuthorToggle: _toggleAuthorFilter,
                onTagToggle: _toggleTagFilter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyWithFilterPanel(Widget body) {
    if (context.width <= _kFilterPanelBreakpoint) return body;
    final open = _filterPanelOpen;
    return Stack(
      children: [
        Positioned.fill(right: open ? _filterPanelWidth : 0, child: body),
        if (open)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _filterPanelWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: context.colorScheme.outlineVariant,
                    width: 0.6,
                  ),
                ),
              ),
              child: _buildFilterPanel(),
            ),
          ),
        Positioned(
          right: open ? _filterPanelWidth - SidebarResizeHandle.width / 2 : 0,
          top: 0,
          bottom: 0,
          width: SidebarResizeHandle.width,
          child: SidebarResizeHandle(
            mirror: true,
            expanded: open,
            onToggle: _toggleFilterPanel,
            onDrag: _resizeFilterPanel,
            onDragEnd: _finishFilterPanelResize,
          ),
        ),
      ],
    );
  }

  void _showFilterSheet() {
    final folder = widget.folder;
    final request = ++_filterRequest;
    bool isCurrent() =>
        mounted && widget.folder == folder && request == _filterRequest;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _FavoriteFilterEditor(
                readFilter: readFilterSelect,
                sortMode: sortMode,
                authors: authorFilters,
                tags: tagFilters,
                authorOptions: _availableAuthors(),
                tagOptions: _availableTags(),
                editable: true,
                onReadFilter: (value) {
                  if (!isCurrent()) return;
                  _setReadFilter(value);
                },
                onSortMode: (value) {
                  if (!isCurrent()) return;
                  _setSortMode(value);
                },
                onAuthorToggle: (value) {
                  if (!isCurrent()) return;
                  _toggleAuthorFilter(value);
                },
                onTagToggle: (value) {
                  if (!isCurrent()) return;
                  _toggleTagFilter(value);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  bool matchKeyword(String keyword, FavoriteItem comic) {
    var list = keyword.split(" ");
    for (var k in list) {
      if (k.isEmpty) continue;
      if (checkKeyWordMatch(k, comic.title, false)) {
        continue;
      } else if (comic.subtitle != null &&
          checkKeyWordMatch(k, comic.subtitle!, false)) {
        continue;
      } else if (comic.tags.any((tag) {
        if (checkKeyWordMatch(k, tag, true)) {
          return true;
        } else if (tag.contains(':') &&
            checkKeyWordMatch(k, tag.split(':')[1], true)) {
          return true;
        } else if (appLocale.languageCode != 'en' &&
            checkKeyWordMatch(k, tag.translateTagsToCN, true)) {
          return true;
        }
        return false;
      })) {
        continue;
      } else if (checkKeyWordMatch(k, comic.author, true)) {
        continue;
      }
      return false;
    }
    return true;
  }

  bool checkKeyWordMatch(String keyword, String compare, bool needEqual) {
    String temp = compare;
    // 没有大写的话, 就转成小写比较, 避免搜索需要注意大小写
    if (!searchHasUpper) {
      temp = temp.toLowerCase();
    }
    if (needEqual) {
      return keyword == temp;
    }
    return temp.contains(keyword);
  }

  // Convert keyword to traditional Chinese to match comics
  bool matchKeywordT(String keyword, FavoriteItem comic) {
    if (!OpenCC.hasChineseSimplified(keyword)) {
      return false;
    }
    keyword = OpenCC.simplifiedToTraditional(keyword);
    return matchKeyword(keyword, comic);
  }

  // Convert keyword to simplified Chinese to match comics
  bool matchKeywordS(String keyword, FavoriteItem comic) {
    if (!OpenCC.hasChineseTraditional(keyword)) {
      return false;
    }
    keyword = OpenCC.traditionalToSimplified(keyword);
    return matchKeyword(keyword, comic);
  }

  @override
  void initState() {
    super.initState();
    _store = FavoritesScope.capture(context);
    _observedManager = _store.manager;
    _observedGeneration = _observedManager.connectionGeneration;
    _observedDataPath = App.dataPath;
    readFilterSelect =
        appdata.implicitData["local_favorites_read_filter"] ??
        readFilterList[0];
    authorFilters = _readFilterValues(
      appdata.implicitData['local_favorites_author_filter'],
    );
    tagFilters = _readFilterValues(
      appdata.implicitData['local_favorites_tag_filter'],
    );
    sortMode = _storedSortMode();
    final layout = GlobalPreferenceStore(appdata.settings);
    _filterPanelWidth = layout
        .read(LayoutPreferences.favoritesFilterPanelWidth)
        .toDouble();
    _filterPanelOpen = layout.read(LayoutPreferences.favoritesFilterPanelOpen);
    if (!isAllFolder) {
      var (a, b) = _observedManager.findLinked(widget.folder);
      networkSource = a;
      networkFolder = b;
    } else {
      networkSource = null;
      networkFolder = null;
    }
    comics = [];
    _observedManager.addListener(updateComics);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queryOwner != null) return;
    _queryOwner = WindowSelectionTask(context);
    updateComics();
  }

  void _retireUpdateFlyout() {
    final route = _updateFlyoutRoute;
    _updateFlyoutRoute = null;
    scheduleMicrotask(() {
      final navigator = route?.navigator;
      if (navigator?.mounted == true && route!.isActive) {
        navigator!.removeRoute(route);
      }
    });
  }

  @override
  void didUpdateWidget(LocalFavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder != widget.folder) {
      _cancelMetadataUpdates();
      _filterRequest++;
      sortMode = _storedSortMode();
      final linked = isAllFolder || !_canReadObservedFolder
          ? (null, null)
          : _observedManager.findLinked(widget.folder);
      networkSource = linked.$1;
      networkFolder = linked.$2;
      updateComics();
    }
    if (oldWidget.folder != widget.folder ||
        oldWidget.importFolder != widget.importFolder) {
      _retireUpdateFlyout();
    }
  }

  @override
  void dispose() {
    _cancelMetadataUpdates();
    _retireUpdateFlyout();
    _observedManager.removeListener(updateComics);
    scrollController.dispose();
    super.dispose();
  }

  void selectAll() {
    setState(() {
      if (searchMode) {
        selectedComics = searchResults.asMap().map((k, v) => MapEntry(v, true));
      } else {
        selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
      }
    });
  }

  void invertSelection() {
    setState(() {
      if (searchMode) {
        for (var c in searchResults) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      } else {
        for (var c in comics) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      }
    });
  }

  bool downloadComic(FavoriteItem c) {
    final library = LocalManager();
    var source = c.type.comicSource;
    if (source != null) {
      bool isDownloaded = library.isDownloaded(c.id, (c).type);
      if (isDownloaded) {
        return false;
      }
      library.addTask(
        ImagesDownloadTask(
          storage: library,
          source: source,
          comicId: c.id,
          comicTitle: c.title,
        ),
      );
      return true;
    }
    return false;
  }

  void downloadSelected() {
    int count = 0;
    for (var c in selectedComics.keys) {
      if (downloadComic(c as FavoriteItem)) {
        count++;
      }
    }
    if (count > 0) {
      context.showMessage(
        message: "Added @c comics to download queue.".tlParams({"c": count}),
      );
    }
  }

  var scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final target = widget;
    final selection = selectedComics.keys.cast<FavoriteItem>().toList();
    final selectedItems = selection.map((comic) => comic.detached()).toList();
    bool isCurrentSelection() =>
        _canReadObservedFolder &&
        widget.folder == target.folder &&
        multiSelectMode &&
        listEquals(selectedComics.keys.toList(), selection);
    var title = widget.folder;
    if (title == localAllFolderLabel) {
      title = "All".tl;
    }

    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        if (!searchMode && !multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Folders".tl,
              child: context.width <= favoritesTwoPanelChangeWidth
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      color: context.colorScheme.primary,
                      onPressed: widget.showFolders,
                    )
                  : const SizedBox(),
            ),
            title: GestureDetector(
              onTap: context.width < favoritesTwoPanelChangeWidth
                  ? widget.showFolders
                  : null,
              child: Text(title),
            ),
            actions: [
              if (networkSource != null && !isAllFolder)
                Tooltip(
                  message: "Sync".tl,
                  child: Flyout(
                    flyoutBuilder: (context) {
                      final source = networkSource;
                      final remoteFolder = networkFolder;
                      if (source == null || remoteFolder == null) {
                        return const SizedBox.shrink();
                      }
                      final folder = widget.folder;
                      final importFolder = widget.importFolder;
                      final generation = _observedManager.connectionGeneration;
                      final route = ModalRoute.of(context);
                      if (!identical(_updateFlyoutRoute, route)) {
                        _updateFlyoutRoute = route;
                        route?.completed.then((_) {
                          if (identical(_updateFlyoutRoute, route)) {
                            _updateFlyoutRoute = null;
                          }
                        });
                      }
                      bool isCurrent() =>
                          _canReadObservedFolder &&
                          widget.folder == folder &&
                          widget.importFolder == importFolder &&
                          _observedManager.connectionGeneration == generation &&
                          _observedManager.findLinked(folder) ==
                              (source, remoteFolder) &&
                          NavigationAdmission.allows(this.context);
                      return _FavoriteFolderSyncPanel(
                        networkSource: source,
                        networkFolder: remoteFolder,
                        onUpdate: (pages) async {
                          if (!isCurrent()) return;
                          await importFolder(
                            this.context,
                            source,
                            pages,
                            folder,
                            remoteFolder,
                          );
                          if (isCurrent()) updateComics();
                        },
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        return IconButton(
                          icon: const Icon(Icons.sync),
                          onPressed: () {
                            if (_updateFlyoutRoute == null &&
                                NavigationAdmission.allows(context)) {
                              Flyout.of(context).show();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              const FavoriteDisplayButton(),
              Tooltip(
                message: "Filter".tl,
                child: IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  color:
                      readFilterSelect != readFilterList[0] ||
                          authorFilters.isNotEmpty ||
                          tagFilters.isNotEmpty ||
                          !isManualFavoriteSort(sortMode)
                      ? context.colorScheme.primaryContainer
                      : null,
                  onPressed: () {
                    if (context.width > _kFilterPanelBreakpoint) {
                      _toggleFilterPanel();
                      return;
                    }
                    if (App.isMobile) {
                      _showFilterSheet();
                      return;
                    }
                    final folder = widget.folder;
                    final request = ++_filterRequest;
                    final availableAuthors = _collectFilterValues([
                      for (final comic in comics)
                        ...favoriteAuthorValues(comic),
                    ]);
                    final availableTags = _collectFilterValues([
                      for (final comic in comics)
                        for (final tag in comic.tags) favoriteTagLabel(tag),
                    ]);
                    showDialog(
                      context: context,
                      builder: (context) {
                        return _LocalFavoritesFilterDialog(
                          folder: folder,
                          initReadFilterSelect: readFilterSelect,
                          initSortMode: sortMode,
                          initAuthors: authorFilters,
                          initTags: tagFilters,
                          availableAuthors: availableAuthors,
                          availableTags: availableTags,
                          updateConfig:
                              (readFilter, nextSortMode, authors, tags) {
                                if (!mounted ||
                                    widget.folder != folder ||
                                    request != _filterRequest) {
                                  return;
                                }
                                setState(() {
                                  readFilterSelect = readFilter;
                                  sortMode = nextSortMode;
                                  authorFilters = authors;
                                  tagFilters = tags;
                                });
                                updateComics();
                              },
                        );
                      },
                    );
                  },
                ),
              ),
              Tooltip(
                message: "Search".tl,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      keyword = "";
                      searchMode = true;
                      updateSearchResult();
                    });
                  },
                ),
              ),
              if (!isAllFolder)
                MenuButton(
                  entries: [
                    MenuEntry(
                      icon: Icons.edit_outlined,
                      text: "Rename".tl,
                      onClick: () {
                        renameFavoriteFolder(
                          context,
                          manager: _observedManager,
                          folder: target.folder,
                          isCurrent: () =>
                              _canReadObservedFolder &&
                              widget.folder == target.folder,
                          onRenamed: (name) {
                            target.updateFolderList();
                            if (_canReadObservedFolder &&
                                _queryOwner?.canPresent == true &&
                                widget.folder == target.folder) {
                              target.onFolderSelected(false, name);
                            }
                          },
                        );
                      },
                    ),
                    if (isManualFavoriteSort(sortMode))
                      MenuEntry(
                        icon: Icons.reorder,
                        text: "Reorder".tl,
                        onClick: () {
                          if (_queryOwner?.canPresent != true) return;
                          reorderFavoriteComics(
                            context,
                            manager: _observedManager,
                            folder: target.folder,
                            isCurrent: () =>
                                _canReadObservedFolder &&
                                widget.folder == target.folder,
                          );
                        },
                      ),
                    MenuEntry(
                      icon: Icons.upload_file,
                      text: "Export".tl,
                      onClick: () {
                        if (!_canReadObservedFolder ||
                            _queryOwner?.canPresent != true ||
                            widget.folder != target.folder) {
                          return;
                        }
                        final json = _observedManager.folderToJson(
                          target.folder,
                        );
                        saveFileForWindow(
                          context,
                          data: utf8.encode(json),
                          filename: "${target.folder}.json",
                        );
                      },
                    ),
                    MenuEntry(
                      icon: Icons.update,
                      text: "Update Comics Info".tl,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !_canReadObservedFolder ||
                            widget.folder != target.folder) {
                          return;
                        }
                        _refreshMetadata(context, target.folder);
                      },
                    ),
                    MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Folder".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        if (_queryOwner?.canPresent != true) return;
                        confirmFavoriteMutation(
                          context: context,
                          manager: _observedManager,
                          folder: target.folder,
                          title: "Delete".tl,
                          content: "Delete folder '@f' ?".tlParams({
                            "f": target.folder,
                          }),
                          btnColor: context.colorScheme.error,
                          isCurrent: () =>
                              _canReadObservedFolder &&
                              widget.folder == target.folder,
                          mutate: () =>
                              _observedManager.deleteFolder(target.folder),
                          onCommitted: () {
                            target.updateFolderList();
                            if (_canReadObservedFolder &&
                                _queryOwner?.canPresent == true &&
                                widget.folder == target.folder) {
                              target.onFolderSelected(false, null);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
            ],
          )
        else if (multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    multiSelectMode = false;
                    selectedComics.clear();
                  });
                },
              ),
            ),
            title: Text(
              "Selected @c comics".tlParams({"c": selectedComics.length}),
            ),
            actions: [
              MenuButton(
                entries: [
                  if (!isAllFolder)
                    MenuEntry(
                      icon: Icons.drive_file_move,
                      text: "Move to folder".tl,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !isCurrentSelection()) {
                          return;
                        }
                        showFavoriteTransferDialog(
                          context: context,
                          manager: _observedManager,
                          source: target.folder,
                          comics: selectedItems,
                          move: true,
                          isCurrent: isCurrentSelection,
                          onCommitted: _cancel,
                        );
                      },
                    ),
                  if (!isAllFolder)
                    MenuEntry(
                      icon: Icons.copy,
                      text: "Copy to folder".tl,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !isCurrentSelection()) {
                          return;
                        }
                        showFavoriteTransferDialog(
                          context: context,
                          manager: _observedManager,
                          source: target.folder,
                          comics: selectedItems,
                          move: false,
                          isCurrent: isCurrentSelection,
                          onCommitted: _cancel,
                        );
                      },
                    ),
                  MenuEntry(
                    icon: Icons.select_all,
                    text: "Select All".tl,
                    onClick: selectAll,
                  ),
                  MenuEntry(
                    icon: Icons.deselect,
                    text: "Deselect".tl,
                    onClick: _cancel,
                  ),
                  MenuEntry(
                    icon: Icons.flip,
                    text: "Invert Selection".tl,
                    onClick: invertSelection,
                  ),
                  if (!isAllFolder)
                    MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Comic".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !isCurrentSelection()) {
                          return;
                        }
                        confirmFavoriteMutation(
                          context: context,
                          manager: _observedManager,
                          folder: target.folder,
                          title: "Delete".tl,
                          content: "Delete @c comics?".tlParams({
                            "c": selectedItems.length,
                          }),
                          btnColor: context.colorScheme.error,
                          isCurrent: isCurrentSelection,
                          mutate: () => _observedManager.batchDeleteComics(
                            target.folder,
                            selectedItems,
                          ),
                          onCommitted: _cancel,
                        );
                      },
                    ),
                  MenuEntry(
                    icon: Icons.download,
                    text: "Download".tl,
                    onClick: downloadSelected,
                  ),
                  if (selectedComics.length == 1)
                    MenuEntry(
                      icon: Icons.copy,
                      text: "Copy Title".tl,
                      onClick: () {
                        Clipboard.setData(
                          ClipboardData(text: selectedComics.keys.first.title),
                        );
                        context.showMessage(message: "Copied".tl);
                      },
                    ),
                  if (selectedComics.length == 1)
                    MenuEntry(
                      icon: Icons.chrome_reader_mode_outlined,
                      text: "Read".tl,
                      onClick: () {
                        final c = selectedComics.keys.first as FavoriteItem;
                        appNavigation.rootContext.to(
                          () => ReaderWithLoading(
                            id: c.id,
                            sourceKey: c.sourceKey,
                          ),
                        );
                      },
                    ),
                  if (selectedComics.length == 1)
                    MenuEntry(
                      icon: Icons.arrow_forward_ios,
                      text: "Jump to Detail".tl,
                      onClick: () {
                        final c = selectedComics.keys.first as FavoriteItem;
                        appNavigation.mainNavigatorKey?.currentContext?.to(
                          () => ComicPage(id: c.id, sourceKey: c.sourceKey),
                        );
                      },
                    ),
                ],
              ),
            ],
          )
        else if (searchMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    setState(() {
                      searchMode = false;
                    });
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: UnderlineInputBorder(),
              ),
              onChanged: (v) {
                keyword = v;
                searchHasUpper = keyword.contains(RegExp(r'[A-Z]'));
                updateSearchResult();
              },
            ).paddingBottom(8).paddingRight(8),
          ),
        if (_loadError != null)
          SliverToBoxAdapter(
            child: Column(
              children: [
                Text(_loadError.toString()),
                TextButton(onPressed: updateComics, child: Text('Retry'.tl)),
              ],
            ),
          )
        else if (isLoading)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: const Center(child: CircularProgressIndicator()),
            ),
          )
        else
          SliverGridComics(
            comics: sortFavoriteItems(
              filterComics(searchMode ? searchResults : comics),
              sortMode,
            ),
            selections: selectedComics,
            useFavoriteDisplaySettings: true,
            menuBuilder: (c) {
              final authors = favoriteAuthorValues(c);
              return [
                if (authors.isNotEmpty)
                  MenuEntry(
                    icon: Icons.person_search,
                    text: "Filter by author".tl,
                    onClick: () {
                      setState(() {
                        authorFilters = authors.toSet();
                      });
                      _persistFilters();
                    },
                  ),
                if (!isAllFolder)
                  MenuEntry(
                    icon: Icons.delete,
                    text: "Delete".tl,
                    onClick: () async {
                      if (!_canReadObservedFolder ||
                          _queryOwner?.canPresent != true ||
                          widget.folder != target.folder) {
                        return;
                      }
                      final item = (c as FavoriteItem).detached();
                      final owner = WindowSelectionTask(context);
                      try {
                        await owner.run<void>((operation) async {
                          operation.checkActive();
                          await AppDataOperations.instance.access(() async {
                            // An accepted deletion may outlive its page, but
                            // cannot enter a replacement database after queuing.
                            if (!_store.isCurrent ||
                                _observedManager.connectionGeneration !=
                                    _observedGeneration ||
                                App.dataPath != _observedDataPath ||
                                !_observedManager.existsFolder(target.folder)) {
                              throw const SelectionCancelled();
                            }
                            await _observedManager.deleteComicWithId(
                              target.folder,
                              item.id,
                              item.type,
                            );
                          });
                        }, reportFailureOnClose: true);
                      } on SelectionCancelled {
                        // The original caller or database retired before admission.
                      } catch (error, stack) {
                        Log.error('Delete favorite', error, stack);
                        if (context.mounted &&
                            owner.canPresent &&
                            _canReadObservedFolder &&
                            widget.folder == target.folder) {
                          context.showMessage(message: error.toString());
                        }
                      }
                    },
                  ),
                MenuEntry(
                  icon: Icons.check,
                  text: "Select".tl,
                  onClick: () {
                    setState(() {
                      if (!multiSelectMode) {
                        multiSelectMode = true;
                      }
                      if (selectedComics.containsKey(c as FavoriteItem)) {
                        selectedComics.remove(c);
                        _checkExitSelectMode();
                      } else {
                        selectedComics[c] = true;
                      }
                      lastSelectedIndex = comics.indexOf(c);
                    });
                  },
                ),
                MenuEntry(
                  icon: Icons.download,
                  text: "Download".tl,
                  onClick: () {
                    downloadComic(c as FavoriteItem);
                    context.showMessage(message: "Download started".tl);
                  },
                ),
                if (GlobalPreferenceStore(
                      appdata.settings,
                    ).read(FavoritePreferences.onClickFavorite) ==
                    "viewDetail")
                  MenuEntry(
                    icon: Icons.menu_book_outlined,
                    text: "Read".tl,
                    onClick: () {
                      appNavigation.mainNavigatorKey?.currentContext?.to(
                        () =>
                            ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
                      );
                    },
                  ),
              ];
            },
            onTap: (c, heroID) {
              if (multiSelectMode) {
                setState(() {
                  if (selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics.remove(c);
                    _checkExitSelectMode();
                  } else {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = comics.indexOf(c);
                });
              } else if (GlobalPreferenceStore(
                    appdata.settings,
                  ).read(FavoritePreferences.onClickFavorite) ==
                  "viewDetail") {
                appNavigation.mainNavigatorKey?.currentContext?.to(
                  () => ComicPage(
                    id: c.id,
                    sourceKey: c.sourceKey,
                    cover: c.cover,
                    title: c.title,
                    heroID: heroID,
                  ),
                );
              } else {
                appNavigation.mainNavigatorKey?.currentContext?.to(
                  () => ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
                );
              }
            },
            onLongPressed: (c, heroID) {
              setState(() {
                if (!multiSelectMode) {
                  multiSelectMode = true;
                  if (!selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = comics.indexOf(c);
                } else {
                  if (lastSelectedIndex != null) {
                    int start = lastSelectedIndex!;
                    int end = comics.indexOf(c as FavoriteItem);
                    if (start > end) {
                      int temp = start;
                      start = end;
                      end = temp;
                    }

                    for (int i = start; i <= end; i++) {
                      if (i == lastSelectedIndex) continue;

                      var comic = comics[i];
                      if (selectedComics.containsKey(comic)) {
                        selectedComics.remove(comic);
                      } else {
                        selectedComics[comic] = true;
                      }
                    }
                  }
                  lastSelectedIndex = comics.indexOf(c as FavoriteItem);
                }
                _checkExitSelectMode();
              });
            },
          ),
      ],
    );
    body = AppScrollBar(
      topPadding: 48,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedComics.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            updateComics();
          });
        }
      },
      child: _buildBodyWithFilterPanel(body),
    );
  }

  void _cancelMetadataUpdates() {
    for (final task in _metadataTasks.toList()) {
      task.cancel();
    }
  }

  void _refreshMetadata(BuildContext context, String folder) {
    final owner = WindowSelectionTask(context);
    _metadataTasks.add(owner);
    final result = showFavoriteMetadataDialog(
      context: context,
      owner: owner,
      manager: _observedManager,
      folder: folder,
      isCurrent: () => _canReadObservedFolder && widget.folder == folder,
    );
    unawaited(
      result.then<void>(
        (_) {
          _metadataTasks.remove(owner);
        },
        onError: (Object error, StackTrace stack) {
          // Presentation reports its original error and host; consume this page's
          // completion without transferring that failure to another page.
          _metadataTasks.remove(owner);
        },
      ),
    );
  }

  void _checkExitSelectMode() {
    if (selectedComics.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  void _cancel() {
    setState(() {
      selectedComics.clear();
      multiSelectMode = false;
    });
  }
}

class _FavoriteFolderSyncPanel extends StatefulWidget {
  const _FavoriteFolderSyncPanel({
    required this.networkSource,
    required this.networkFolder,
    required this.onUpdate,
  });

  final Future<void> Function(int pages) onUpdate;
  final String networkFolder;
  final String networkSource;

  @override
  State<_FavoriteFolderSyncPanel> createState() =>
      _FavoriteFolderSyncPanelState();
}

class _FavoriteFolderSyncPanelState
    extends SettingsSaveState<_FavoriteFolderSyncPanel> {
  int updatePageNum = 9999999;
  bool startingUpdate = false;
  late final Future<void> Function(int) _update;

  Future<void> _submit() async {
    if (startingUpdate || !acceptsSettingsChanges) return;
    final pages = updatePageNum;
    final update = _update;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() => startingUpdate = true);
    try {
      await waitForSettingsSave();
      if (!mounted ||
          !acceptsSettingsChanges ||
          route?.isCurrent != true ||
          !NavigationAdmission.allows(context)) {
        return;
      }
      if (!await navigator.maybePop() || route?.isCurrent == true) return;
      await update(pages);
    } catch (error, stack) {
      Log.error('Favorite update settings', error, stack);
      if (mounted) context.showMessage(message: error.toString());
    } finally {
      if (mounted) setState(() => startingUpdate = false);
    }
  }

  String get _allPageText => 'All'.tl;

  static const pageCounts = [1, 2, 3, 5, 10, 20, 50, 100, 200, 9999999];

  @override
  void initState() {
    _update = widget.onUpdate;
    final stored = appdata.implicitData['local_favorites_update_page_num'];
    updatePageNum = stored is int && stored > 0 ? stored : 9999999;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var source = ComicSource.find(widget.networkSource);
    final sourceName = source?.name ?? widget.networkSource;
    var text = "The folder is Linked to @source".tlParams({
      "source": sourceName,
    });
    if (widget.networkFolder.isNotEmpty) {
      text += "\n${"Source Folder".tl}: ${widget.networkFolder}";
    }

    final target = (widget.networkSource, widget.networkFolder);
    return protectSettings(
      FlyoutContent(
        title: 'Sync'.tl,
        actions: [
          FilledButton(
            onPressed: startingUpdate ? null : _submit,
            child: Text('Update'.tl),
          ),
        ],
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("Update the page number by the latest collection".tl),
                Select(
                  current: updatePageNum.toString() == '9999999'
                      ? _allPageText
                      : updatePageNum.toString(),
                  values: [
                    for (final value in pageCounts)
                      value == 9999999 ? _allPageText : '$value',
                  ],
                  minWidth: 48,
                  onTap: (index) {
                    if (!mounted ||
                        !acceptsSettingsChanges ||
                        startingUpdate ||
                        target !=
                            (widget.networkSource, widget.networkFolder) ||
                        index < 0 ||
                        index >= pageCounts.length) {
                      return;
                    }
                    final value = pageCounts[index];
                    setState(() {
                      updatePageNum = value;
                    });
                    saveSetting(
                      'local_favorites_update_page_num',
                      () => appdata.updateImplicit((draft) {
                        draft['local_favorites_update_page_num'] = value;
                      }),
                    );
                  },
                ),
              ],
            ),
            settingsSaveStatus,
          ],
        ),
      ),
    );
  }
}

class _LocalFavoritesFilterDialog extends StatefulWidget {
  const _LocalFavoritesFilterDialog({
    required this.folder,
    required this.initReadFilterSelect,
    required this.initSortMode,
    required this.initAuthors,
    required this.initTags,
    required this.availableAuthors,
    required this.availableTags,
    required this.updateConfig,
  });

  final String folder;
  final String initReadFilterSelect;
  final String initSortMode;
  final Set<String> initAuthors;
  final Set<String> initTags;
  final List<String> availableAuthors;
  final List<String> availableTags;
  final void Function(
    String readFilter,
    String sortMode,
    Set<String> authors,
    Set<String> tags,
  )
  updateConfig;

  @override
  State<_LocalFavoritesFilterDialog> createState() =>
      _LocalFavoritesFilterDialogState();
}

const readFilterList = ['All', 'UnCompleted', 'Completed'];

const favoriteSortModeLabels = {
  'manual': 'Manual',
  'timeNewest': 'Added (newest)',
  'timeOldest': 'Added (oldest)',
  'authorAsc': 'Author (A-Z)',
  'authorDesc': 'Author (Z-A)',
};

class _LocalFavoritesFilterDialogState
    extends SettingsSaveState<_LocalFavoritesFilterDialog> {
  List<String> optionTypes = ['Filter'];
  late var readFilter = widget.initReadFilterSelect;
  late var sortMode = widget.initSortMode;
  late final authors = <String>{...widget.initAuthors};
  late final tags = <String>{...widget.initTags};

  bool get _editable =>
      acceptsSettingsChanges && !savingSettings && !hasSettingsSaveError;

  List<String> _options(List<String> available, Set<String> selected) {
    final values = <String>{...available, ...selected}.toList();
    values.sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final authorOptions = _options(widget.availableAuthors, authors);
    final tagOptions = _options(widget.availableTags, tags);
    Widget tabBar = Material(
      borderRadius: BorderRadius.circular(8),
      child: AppTabBar(
        key: PageStorageKey(optionTypes),
        tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
      ),
    ).paddingTop(context.padding.top);
    return protectSettings(
      ContentDialog(
        content: DefaultTabController(
          length: optionTypes.length,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tabBar,
              TabViewBody(
                children: [
                  _FavoriteFilterEditor(
                    readFilter: readFilter,
                    sortMode: sortMode,
                    authors: authors,
                    tags: tags,
                    authorOptions: authorOptions,
                    tagOptions: tagOptions,
                    editable: _editable,
                    onReadFilter: (value) => setState(() => readFilter = value),
                    onSortMode: (value) => setState(() => sortMode = value),
                    onAuthorToggle: (value) => setState(() {
                      if (!authors.remove(value)) authors.add(value);
                    }),
                    onTagToggle: (value) => setState(() {
                      if (!tags.remove(value)) tags.add(value);
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          settingsSaveStatus,
          TextButton(
            onPressed: savingSettings || hasSettingsSaveError
                ? null
                : () {
                    setState(() {
                      readFilter = readFilterList[0];
                      authors.clear();
                      tags.clear();
                    });
                  },
            child: Text("Clear".tl),
          ),
          FilledButton(
            onPressed: savingSettings || hasSettingsSaveError
                ? null
                : () {
                    final value = readFilter;
                    final selectedSortMode = sortMode;
                    final selectedAuthors = Set<String>.of(authors);
                    final selectedTags = Set<String>.of(tags);
                    final storedModes =
                        appdata.implicitData['local_favorites_sort_modes'];
                    final sortModes = <String, Object?>{
                      if (storedModes is Map)
                        for (final entry in storedModes.entries)
                          '${entry.key}': entry.value,
                      widget.folder: selectedSortMode,
                    };
                    saveSetting(
                      'local_favorites_filter',
                      () => appdata.updateImplicit((draft) {
                        draft['local_favorites_read_filter'] = value;
                        draft['local_favorites_author_filter'] = selectedAuthors
                            .toList();
                        draft['local_favorites_tag_filter'] = selectedTags
                            .toList();
                        draft['local_favorites_sort_modes'] = sortModes;
                      }),
                      onSaved: () {
                        widget.updateConfig(
                          value,
                          selectedSortMode,
                          selectedAuthors,
                          selectedTags,
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) leaveSettings();
                        });
                      },
                    );
                  },
            child: Text("Confirm".tl),
          ),
        ],
      ),
    );
  }
}

/// Shared presentation for the filter dialog, the right side panel and the
/// mobile bottom sheet. Hosts own persistence; this widget only edits values.
class _FavoriteFilterEditor extends StatelessWidget {
  const _FavoriteFilterEditor({
    required this.readFilter,
    required this.sortMode,
    required this.authors,
    required this.tags,
    required this.authorOptions,
    required this.tagOptions,
    required this.editable,
    required this.onReadFilter,
    required this.onSortMode,
    required this.onAuthorToggle,
    required this.onTagToggle,
  });

  final String readFilter;
  final String sortMode;
  final Set<String> authors;
  final Set<String> tags;
  final List<String> authorOptions;
  final List<String> tagOptions;
  final bool editable;
  final ValueChanged<String> onReadFilter;
  final ValueChanged<String> onSortMode;
  final ValueChanged<String> onAuthorToggle;
  final ValueChanged<String> onTagToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 4),
          child: _FilterSectionTitle('Sort'),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final mode in favoriteSortModes)
              ChoiceChip(
                label: Text((favoriteSortModeLabels[mode] ?? 'Manual').tl),
                selected: sortMode == mode,
                onSelected: editable
                    ? (selected) {
                        if (selected) onSortMode(mode);
                      }
                    : null,
              ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Filter reading status".tl),
          trailing: Select(
            current: readFilter.tl,
            values: readFilterList.map((e) => e.tl).toList(),
            minWidth: 64,
            onTap: (index) {
              if (!editable || index < 0 || index >= readFilterList.length) {
                return;
              }
              onReadFilter(readFilterList[index]);
            },
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterChipsSection(
                  title: "Author",
                  options: authorOptions,
                  selected: authors,
                  editable: editable,
                  onToggle: onAuthorToggle,
                ),
                _FilterChipsSection(
                  title: "Tag",
                  options: tagOptions,
                  selected: tags,
                  editable: editable,
                  onToggle: onTagToggle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title.tl);
  }
}

class _FilterChipsSection extends StatelessWidget {
  const _FilterChipsSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.editable,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final bool editable;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: _FilterSectionTitle(title),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: editable ? (_) => onToggle(option) : null,
              ),
          ],
        ),
      ],
    );
  }
}
