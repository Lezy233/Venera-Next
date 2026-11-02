import "package:flutter/material.dart";
import 'package:shimmer_animation/shimmer_animation.dart';
import "package:venera_next/components/appbar.dart";
import "package:venera_next/components/gesture.dart";
import "package:venera_next/components/scroll.dart";
import "package:venera_next/features/comic_widgets/comic_widgets.dart";
import "package:venera_next/foundation/context.dart";
import "package:venera_next/features/comic_source/comic_source.dart";
import "package:venera_next/foundation/translations.dart";
import "package:venera_next/foundation/widget_utils.dart";

import "search_result_page.dart";
import 'search_profile.dart';

class AggregatedSearchPage extends StatefulWidget {
  const AggregatedSearchPage({
    super.key,
    required this.keyword,
    this.profileId,
  });

  final String keyword;
  final String? profileId;

  @override
  State<AggregatedSearchPage> createState() => _AggregatedSearchPageState();
}

class _AggregatedSearchPageState extends State<AggregatedSearchPage> {
  late final List<ResolvedSearchProfileSource> sources;

  late final SearchBarController controller;

  var _keyword = "";

  @override
  void initState() {
    // null explicitly means legacy global settings. The search entry resolves
    // the default once when initialized; a user's Global choice stays global.
    final selected = widget.profileId == null
        ? null
        : SearchProfileManager.instance.byId(widget.profileId!);
    if (selected != null) {
      sources = SearchProfileManager.instance.resolve(selected);
    } else {
      sources = [
        for (final item in searchProfileSourcesFromGlobals())
          if (ComicSource.find(item.sourceKey) case final source?)
            ResolvedSearchProfileSource(source: source, options: item.options),
      ];
    }
    _keyword = widget.keyword;
    controller = SearchBarController(
      currentText: widget.keyword,
      onSearch: (text) {
        setState(() {
          _keyword = text;
        });
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverSearchBar(controller: controller),
        SliverList(
          key: ValueKey(_keyword),
          delegate: SliverChildBuilderDelegate((context, index) {
            final source = sources[index];
            return _SliverSearchResult(
              key: ValueKey(source.source.key),
              source: source.source,
              options: source.options,
              keyword: _keyword,
            );
          }, childCount: sources.length),
        ),
      ],
    );
  }
}

class _SliverSearchResult extends StatefulWidget {
  const _SliverSearchResult({
    required this.source,
    required this.options,
    required this.keyword,
    super.key,
  });

  final ComicSource source;
  final List<String> options;

  final String keyword;

  @override
  State<_SliverSearchResult> createState() => _SliverSearchResultState();
}

class _SliverSearchResultState extends State<_SliverSearchResult>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;

  static const _kComicHeight = 162.0;

  double get _comicWidth => _kComicHeight * 0.7;

  static const _kLeftPadding = 16.0;

  List<Comic>? comics;

  String? error;

  void load() async {
    try {
      final data = widget.source.searchPageData!;
      final res = data.loadPage != null
          ? await data.loadPage!(widget.keyword, 1, widget.options)
          : await data.loadNext!(widget.keyword, null, widget.options);
      if (!mounted) return;
      setState(() {
        if (res.error) {
          error = res.errorMessage ?? 'Unknown error'.tl;
        } else {
          comics = res.data;
        }
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Unknown error'.tl;
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Widget buildPlaceHolder() {
    return Container(
      height: _kComicHeight,
      width: _comicWidth,
      margin: const EdgeInsets.only(left: _kLeftPadding),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget buildComic(Comic c) {
    return SimpleComicTile(
      comic: c,
      withTitle: true,
    ).paddingLeft(_kLeftPadding).paddingBottom(2);
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && error!.startsWith("CloudflareException")) {
      error = "Cloudflare verification required".tl;
    }
    super.build(context);
    return ClickInkWell(
      onTap: () {
        context.to(
          () => SearchResultPage(
            text: widget.keyword,
            sourceKey: widget.source.key,
            options: widget.options,
          ),
        );
      },
      child: Column(
        children: [
          ListTile(
            mouseCursor: SystemMouseCursors.click,
            title: Text(widget.source.name),
          ),
          if (isLoading)
            SizedBox(
              height: _kComicHeight,
              width: double.infinity,
              child: Shimmer(
                child: LayoutBuilder(
                  builder: (context, constrains) {
                    var itemWidth = _comicWidth + _kLeftPadding;
                    var items = (constrains.maxWidth / itemWidth).ceil();
                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Row(
                            children: List.generate(
                              items,
                              (index) => buildPlaceHolder(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          else if (error != null || comics == null || comics!.isEmpty)
            SizedBox(
              height: _kComicHeight,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error ?? "No search results found".tl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ).paddingHorizontal(16),
            )
          else
            SizedBox(
              height: _kComicHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [for (var c in comics!) buildComic(c)],
              ),
            ),
        ],
      ).paddingBottom(16),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
