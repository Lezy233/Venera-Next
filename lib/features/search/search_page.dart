import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/flyout.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/loading.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_locale.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/global_state.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/routing/app_links.dart';
import 'package:venera_next/routing/settings.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'package:venera_next/features/comic_details/comic_details.dart';
import 'aggregated_search_page.dart';
import 'search_result_page.dart';
import 'search_shortcuts.dart';
import 'search_profile.dart';
import 'search_selection.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/design_system/tokens.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchBarController controller;

  late List<String> searchSources;

  String searchTarget = "";

  SearchPageData get currentSearchPageData =>
      ComicSource.find(searchTarget)!.searchPageData!;

  bool aggregatedSearch = false;
  String? profileId;
  late final String _dataPath;
  late SearchSelection _selection;
  late final SearchSelection _initialDefault;
  bool _saving = false;
  Object? _saveError;
  bool get _blocked =>
      _saving ||
      SearchSelection.isSaving(_dataPath) ||
      App.dataPath != _dataPath ||
      appdata.settingsRecovery(_dataPath, SearchSelection.recoveryKey) != null;
  bool get _sourceMissing =>
      _selection.sourceKey != null &&
      !searchSources.contains(_selection.sourceKey);
  bool get _profileMissing =>
      _selection.profileId != null &&
      SearchProfileManager.instance.byId(_selection.profileId!) == null;

  void _resolveSelection() {
    final oldTarget = searchTarget;
    findSearchSources();
    aggregatedSearch = _selection.aggregated;
    searchTarget = searchSources.contains(_selection.sourceKey)
        ? _selection.sourceKey!
        : searchSources.firstOrNull ?? '';
    profileId = _profileMissing ? null : _selection.profileId;
    if (searchTarget != oldTarget && searchTarget.isNotEmpty) {
      useDefaultOptions();
    }
  }

  Future<void> _choose(SearchSelection selection) async {
    if (_blocked) return;
    final restoreAggregateFocus = _aggregateFocus.hasFocus;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await selection.save(_dataPath);
      if (!mounted || App.dataPath != _dataPath) return;
      final resetOptions =
          !selection.aggregated &&
          (_selection.aggregated ||
              selection.sourceKey != _selection.sourceKey);
      _selection = selection;
      _resolveSelection();
      if (resetOptions && searchTarget.isNotEmpty) useDefaultOptions();
    } catch (error) {
      if (!mounted || App.dataPath != _dataPath) return;
      _saveError = error;
    } finally {
      if (mounted && App.dataPath == _dataPath) {
        setState(() {
          _saving = false;
          _resolveSelection();
        });
        if (restoreAggregateFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_blocked) _aggregateFocus.requestFocus();
          });
        }
      }
    }
  }

  Future<void> _retryRecovery() async {
    if (_saving || App.dataPath != _dataPath) return;
    setState(() => _saving = true);
    try {
      await appdata.retrySettingsRecovery(
        _dataPath,
        SearchSelection.recoveryKey,
      );
      if (mounted && App.dataPath == _dataPath) _saveError = null;
    } catch (error) {
      if (mounted && App.dataPath == _dataPath) _saveError = error;
    } finally {
      if (mounted && App.dataPath == _dataPath) {
        setState(() {
          _saving = false;
          _resolveSelection();
        });
      }
    }
  }

  var focusNode = FocusNode();
  final _aggregateFocus = FocusNode();

  var options = <String>[];

  void update() {
    if (mounted) setState(() {});
  }

  void search([String? text]) {
    if (_blocked || searchSources.isEmpty) return;
    _resolveSelection();
    if (searchSources.isEmpty) return;
    if (aggregatedSearch) {
      context
          .to(
            () => AggregatedSearchPage(
              keyword: text ?? controller.text,
              profileId: profileId,
            ),
          )
          .then((_) => update());
    } else {
      context
          .to(
            () => SearchResultPage(
              text: text ?? controller.text,
              sourceKey: searchTarget,
              options: options,
            ),
          )
          .then((_) => update());
    }
  }

  var suggestions = <Pair<String, TranslationType>>[];

  bool canHandleUrl(String text) {
    if (!text.isURL) return false;
    for (var source in ComicSource.all()) {
      if (source.linkHandler != null) {
        var uri = Uri.parse(text);
        if (source.linkHandler!.domains.contains(uri.host)) {
          return true;
        }
      }
    }
    return false;
  }

  void findSuggestions() {
    if (_blocked || searchSources.isEmpty) {
      this.suggestions.clear();
      update();
      return;
    }
    var text = controller.text.split(" ").last;
    var suggestions = this.suggestions;

    suggestions.clear();

    if (canHandleUrl(controller.text)) {
      suggestions.add(Pair("**URL**", TranslationType.other));
    } else {
      var text = controller.text;

      for (var comicSource in ComicSource.all()) {
        if (comicSource.idMatcher?.hasMatch(text) ?? false) {
          suggestions.add(
            Pair("**${comicSource.key}**", TranslationType.other),
          );
        }
      }
    }

    if (ComicSource.find(searchTarget)?.enableTagsSuggestions != true) {
      update();
      return;
    }

    bool check(String text, String key, String value) {
      if (text.removeAllBlank == "") {
        return false;
      }
      if (key.length >= text.length && key.substring(0, text.length) == text ||
          (key.contains(" ") &&
              key.split(" ").last.length >= text.length &&
              key.split(" ").last.substring(0, text.length) == text)) {
        return true;
      } else if (value.length >= text.length && value.contains(text)) {
        return true;
      }
      return false;
    }

    void find(Map<String, String> map, TranslationType type) {
      for (var element in map.entries) {
        if (suggestions.length > 100) {
          break;
        }
        if (check(text, element.key, element.value)) {
          suggestions.add(Pair(element.key, type));
        }
      }
    }

    find(TagsTranslation.femaleTags, TranslationType.female);
    find(TagsTranslation.maleTags, TranslationType.male);
    find(TagsTranslation.parodyTags, TranslationType.parody);
    find(TagsTranslation.characterTranslations, TranslationType.character);
    find(TagsTranslation.otherTags, TranslationType.other);
    find(TagsTranslation.mixedTags, TranslationType.mixed);
    find(TagsTranslation.languageTranslations, TranslationType.language);
    find(TagsTranslation.artistTags, TranslationType.artist);
    find(TagsTranslation.groupTags, TranslationType.group);
    find(TagsTranslation.cosplayerTags, TranslationType.cosplayer);
    update();
  }

  @override
  void initState() {
    _dataPath = App.dataPath;
    findSearchSources();
    var defaultSearchTarget = GlobalPreferenceStore(
      appdata.settings,
    ).read(DiscoveryPreferences.defaultSearchTarget);
    if (defaultSearchTarget == "_aggregated_") {
      aggregatedSearch = true;
    } else if (defaultSearchTarget != null &&
        searchSources.contains(defaultSearchTarget)) {
      searchTarget = defaultSearchTarget;
    }
    profileId = SearchProfileManager.instance.defaultProfile?.id;
    _initialDefault = SearchSelection(
      aggregated: aggregatedSearch,
      sourceKey: searchTarget.isEmpty ? null : searchTarget,
      profileId: profileId,
    );
    _selection = SearchSelection.read(_dataPath) ?? _initialDefault;
    _resolveSelection();
    controller = SearchBarController(onSearch: search);
    appdata.settings.addListener(updateSearchSourcesIfNeeded);
    SearchProfileManager.instance.addListener(updateSearchSourcesIfNeeded);
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    _aggregateFocus.dispose();
    appdata.settings.removeListener(updateSearchSourcesIfNeeded);
    SearchProfileManager.instance.removeListener(updateSearchSourcesIfNeeded);
    super.dispose();
  }

  void findSearchSources() {
    var all = ComicSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    var settings =
        GlobalPreferenceStore(
          appdata.settings,
        ).read(DiscoveryPreferences.searchSources) ??
        const <String>[];
    var sources = <String>[];
    for (var source in settings) {
      if (all.contains(source)) {
        sources.add(source);
      }
    }
    searchSources = sources;
    if (!searchSources.contains(searchTarget)) {
      searchTarget = searchSources.firstOrNull ?? "";
    }
  }

  void updateSearchSourcesIfNeeded() {
    if (!mounted || App.dataPath != _dataPath) return;
    setState(() {
      if (!_saving) {
        _selection = SearchSelection.read(_dataPath) ?? _initialDefault;
      }
      _resolveSelection();
    });
  }

  void manageSearchSources() {
    showPopUpWidget(appNavigation.rootContext, setSearchSourcesWidget());
  }

  Widget buildEmpty() {
    var msg = "No Search Sources".tl;
    msg += '\n';
    VoidCallback onTap;
    if (ComicSource.isEmpty) {
      msg += "Please add some sources".tl;
      onTap = () {
        context.to(() => ComicSourcePage());
      };
    } else {
      msg += "Please check your settings".tl;
      onTap = manageSearchSources;
    }
    return Material(
      child: Column(
        children: [
          Expanded(
            child: NetworkError(
              message: msg,
              retry: onTap,
              withAppbar: true,
              buttonText: "Manage".tl,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: buildSelectionFeedback().toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (searchSources.isEmpty) {
      return buildEmpty();
    }
    return Scaffold(
      body: SmoothCustomScrollView(slivers: buildSlivers().toList()),
    );
  }

  Iterable<Widget> buildSlivers() sync* {
    yield SliverIgnorePointer(
      ignoring: _blocked,
      sliver: ExcludeFocus(
        excluding: _blocked,
        child: SliverSearchBar(
          controller: controller,
          onChanged: (s) {
            findSuggestions();
          },
          focusNode: focusNode,
        ),
      ),
    );
    if (suggestions.isNotEmpty) {
      yield buildSuggestions(context);
    } else {
      yield buildSearchTarget();
      yield SliverAnimatedPaintExtent(
        duration: const Duration(milliseconds: 200),
        child: buildSearchOptions(),
      );
      yield const SearchShortcutsSliver();
      yield SliverIgnorePointer(
        ignoring: _blocked,
        sliver: ExcludeFocus(
          excluding: _blocked,
          child: _SearchHistory(search),
        ),
      );
    }
  }

  Widget buildSearchTarget() {
    var sources = searchSources.map((e) => ComicSource.find(e)!).toList();
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: Text("Search in".tl),
              trailing: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: manageSearchSources,
              ),
            ),
            AbsorbPointer(
              absorbing: _blocked || aggregatedSearch,
              child: ExcludeFocus(
                excluding: _blocked || aggregatedSearch,
                child: Opacity(
                  opacity: _blocked || aggregatedSearch
                      ? AppOpacity.disabled
                      : 1,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sources.map((e) {
                      return OptionChip(
                        text: e.name,
                        isSelected: searchTarget == e.key || aggregatedSearch,
                        onTap: () {
                          if (_blocked || aggregatedSearch) return;
                          _choose(
                            SearchSelection(
                              aggregated: false,
                              sourceKey: e.key,
                              profileId: profileId,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Aggregated Search".tl),
              leading: Checkbox(
                focusNode: _aggregateFocus,
                value: aggregatedSearch,
                onChanged: _blocked
                    ? null
                    : (value) => _choose(
                        SearchSelection(
                          aggregated: value ?? false,
                          sourceKey: searchTarget.isEmpty ? null : searchTarget,
                          profileId: profileId,
                        ),
                      ),
              ),
            ),
            if (SearchProfileManager.instance.all.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmarks_outlined),
                title: Text('Search profile'.tl),
                trailing: SizedBox(
                  width: 160,
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value:
                        SearchProfileManager.instance.byId(profileId ?? '') ==
                            null
                        ? null
                        : profileId,
                    hint: Text('Global settings'.tl),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Global settings'.tl),
                      ),
                      for (final profile in SearchProfileManager.instance.all)
                        DropdownMenuItem<String?>(
                          value: profile.id,
                          child: Text(
                            profile.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _blocked
                        ? null
                        : (value) => _choose(
                            SearchSelection(
                              aggregated: value != null || aggregatedSearch,
                              sourceKey: searchTarget.isEmpty
                                  ? null
                                  : searchTarget,
                              profileId: value,
                            ),
                          ),
                  ),
                ),
              ),
            ...buildSelectionFeedback(),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> buildSelectionFeedback() sync* {
    if (_sourceMissing) {
      yield Text(
        searchTarget.isEmpty
            ? 'Last search source unavailable; no search sources'.tl
            : 'Last search source unavailable; using @name'.tlParams({
                'name': ComicSource.find(searchTarget)?.name ?? searchTarget,
              }),
      );
    }
    if (_profileMissing) {
      yield Text('Last search profile unavailable; using global settings'.tl);
    }
    if (_saving) yield Text('Saving search selection'.tl);
    if (_saveError != null ||
        appdata.settingsRecovery(_dataPath, SearchSelection.recoveryKey) !=
            null) {
      yield Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not save search selection; previous selection restored'.tl,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          if (appdata.settingsRecovery(
                _dataPath,
                SearchSelection.recoveryKey,
              ) !=
              null)
            Text('Save failed; recovery incomplete'.tl),
          TextButton(
            onPressed: _saving ? null : _retryRecovery,
            child: Text('Retry'.tl),
          ),
        ],
      );
    }
  }

  void useDefaultOptions() {
    final searchOptions = currentSearchPageData.searchOptions ?? [];
    options = searchOptions.map((e) => e.defaultValue).toList();
  }

  Widget buildSearchOptions() {
    if (aggregatedSearch) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    var children = <Widget>[];

    final searchOptions = currentSearchPageData.searchOptions ?? [];
    if (searchOptions.length != options.length) {
      useDefaultOptions();
    }
    if (searchOptions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }
    for (int i = 0; i < searchOptions.length; i++) {
      final option = searchOptions[i];
      children.add(
        SearchOptionWidget(
          option: option,
          value: options[i],
          onChanged: (value) {
            options[i] = value;
            update();
          },
          sourceKey: searchTarget,
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget buildSuggestions(BuildContext context) {
    bool check(String text, String key, String value) {
      if (text.removeAllBlank == "") {
        return false;
      }
      if (key.length >= text.length && key.substring(0, text.length) == text ||
          (key.contains(" ") &&
              key.split(" ").last.length >= text.length &&
              key.split(" ").last.substring(0, text.length) == text)) {
        return true;
      } else if (value.length >= text.length && value.contains(text)) {
        return true;
      }
      return false;
    }

    void onSelected(String text, TranslationType? type) {
      var words = controller.text.split(" ");
      if (words.length >= 2 &&
          check(
            "${words[words.length - 2]} ${words[words.length - 1]}",
            text,
            text.translateTagsToCN,
          )) {
        controller.text = controller.text.replaceLast(
          "${words[words.length - 2]} ${words[words.length - 1]}",
          "",
        );
      } else {
        controller.text = controller.text.replaceLast(
          words[words.length - 1],
          "",
        );
      }
      final source = ComicSource.find(searchTarget);
      String insert;
      if (source?.onTagSuggestionSelected != null) {
        insert = source!.onTagSuggestionSelected!(type?.name ?? '', text);
      } else {
        var t = text;
        if (t.contains(' ')) t = "'$t'";
        insert = type != null ? "${type.name}:$t" : t;
      }
      controller.text += "$insert ";
      suggestions.clear();
      update();
      focusNode.requestFocus();
    }

    bool showMethod = MediaQuery.of(context).size.width < 600;
    bool showTranslation = appLocale.languageCode == "zh";
    Widget buildItem(Pair<String, TranslationType> value) {
      if (value.left == "**URL**") {
        return ListTile(
          leading: const Icon(Icons.link),
          title: Text("Open link".tl),
          subtitle: Text(
            controller.text,
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
          trailing: const Icon(Icons.arrow_right),
          onTap: () {
            setState(() {
              suggestions.clear();
            });
            handleAppLink(Uri.parse(controller.text));
          },
        );
      }

      if (RegExp(r"^\*\*.*\*\*$").hasMatch(value.left)) {
        var key = value.left.substring(2, value.left.length - 2);
        var comicSource = ComicSource.find(key);
        if (comicSource == null) {
          return const SizedBox();
        }
        return ListTile(
          leading: const Icon(Icons.link),
          title: Text("${"Open comic".tl}: ${comicSource.name}"),
          subtitle: Text(
            controller.text,
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
          trailing: const Icon(Icons.arrow_right),
          onTap: () {
            context.to(() => ComicPage(sourceKey: key, id: controller.text));
          },
        );
      }

      var subTitle = TagsTranslation.translationTagWithNamespace(
        value.left,
        value.right.name,
      );
      return ListTile(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: Text(value.left)),
            if (!showMethod) const SizedBox(width: 12),
            if (!showMethod && showTranslation)
              Text(
                subTitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
        subtitle: (showMethod && showTranslation) ? Text(subTitle) : null,
        trailing: Text(value.right.name, style: const TextStyle(fontSize: 13)),
        onTap: () => onSelected(value.left, value.right),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text("Suggestions".tl),
            trailing: Tooltip(
              message: "Clear".tl,
              child: IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  suggestions.clear();
                  update();
                },
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return buildItem(suggestions[index]);
          }, childCount: suggestions.length),
        ),
      ],
    );
  }
}

class SearchOptionWidget extends StatelessWidget {
  const SearchOptionWidget({
    super.key,
    required this.option,
    required this.value,
    required this.onChanged,
    required this.sourceKey,
  });

  final SearchOptions option;

  final String value;

  final void Function(String) onChanged;

  final String sourceKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(option.label.ts(sourceKey)),
        ),
        if (option.type == 'select')
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: option.options.entries.map((e) {
              return OptionChip(
                text: e.value.ts(sourceKey),
                isSelected: value == e.key,
                onTap: () {
                  onChanged(e.key);
                },
              );
            }).toList(),
          ),
        if (option.type == 'multi-select')
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: option.options.entries.map((e) {
              return OptionChip(
                text: e.value.ts(sourceKey),
                isSelected: (jsonDecode(value) as List).contains(e.key),
                onTap: () {
                  var list = jsonDecode(value) as List;
                  if (list.contains(e.key)) {
                    list.remove(e.key);
                  } else {
                    list.add(e.key);
                  }
                  onChanged(jsonEncode(list));
                },
              );
            }).toList(),
          ),
        if (option.type == 'dropdown')
          Select(
            current: option.options[value],
            values: option.options.values.toList(),
            onTap: (index) {
              onChanged(option.options.keys.elementAt(index));
            },
            minWidth: 96,
          ),
      ],
    );
  }
}

class _SearchHistory extends StatefulWidget {
  const _SearchHistory(this.search);

  final void Function(String) search;

  @override
  State<_SearchHistory> createState() => _SearchHistoryState();
}

class _SearchHistoryState extends State<_SearchHistory> {
  bool _saving = false;

  Future<bool> _editHistory(Future<void> Function() edit) async {
    if (_saving || !mounted) return false;
    setState(() => _saving = true);
    try {
      await edit();
      return true;
    } catch (error, stack) {
      Log.error('Search history', error, stack);
      if (mounted) context.showMessage(message: error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return const SizedBox(height: 16);
        }
        if (index == 1) {
          return ListTile(
            leading: const Icon(Icons.history),
            contentPadding: EdgeInsets.zero,
            title: Text("Search History".tl),
            trailing: Flyout(
              flyoutBuilder: (context) {
                var saving = false;
                return StatefulBuilder(
                  builder: (context, update) => FlyoutContent(
                    title: "Clear Search History".tl,
                    actions: [
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final route = ModalRoute.of(context);
                                update(() => saving = true);
                                final saved = await _editHistory(
                                  appdata.clearSearchHistory,
                                );
                                if (saved &&
                                    context.mounted &&
                                    route?.isCurrent != false) {
                                  context.pop();
                                }
                                if (context.mounted) {
                                  update(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text("Clear".tl),
                      ),
                    ],
                  ),
                );
              },
              child: Builder(
                builder: (context) {
                  return Tooltip(
                    message: "Clear".tl,
                    child: IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: () {
                        context.findAncestorStateOfType<FlyoutState>()!.show();
                      },
                    ),
                  );
                },
              ),
            ),
          );
        }
        return buildItem(index - 2);
      }, childCount: 2 + appdata.searchHistory.length),
    ).sliverPaddingHorizontal(16);
  }

  Widget buildItem(int index) {
    final keyword = appdata.searchHistory[index];
    void showMenu(
      BuildContext context,
      MenuRouteController menus,
      Offset offset,
    ) {
      menus.show(context, offset, [
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy'.tl,
          onClick: () {
            Clipboard.setData(ClipboardData(text: keyword));
          },
        ),
        MenuEntry(
          icon: Icons.delete,
          text: 'Delete'.tl,
          onClick: () async {
            await _editHistory(() => appdata.removeSearchHistory(keyword));
          },
        ),
      ]);
    }

    return ContextMenuRegion(
      identity: keyword,
      builder: (context, menus) {
        return ClickInkWell(
          onTap: () {
            widget.search(keyword);
          },
          onLongPress: () {
            var renderBox = context.findRenderObject() as RenderBox;
            var offset = renderBox.localToGlobal(Offset.zero);
            showMenu(
              context,
              menus,
              Offset(
                offset.dx + renderBox.size.width / 2 - 121,
                offset.dy + renderBox.size.height - 8,
              ),
            );
          },
          onSecondaryTapUp: (details) {
            showMenu(context, menus, details.globalPosition);
          },
          child: Container(
            decoration: BoxDecoration(
              // color: context.colorScheme.surfaceContainer,
              border: Border(
                left: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(keyword, style: ts.s14),
          ),
        ).paddingBottom(8).paddingHorizontal(4);
      },
    );
  }
}
