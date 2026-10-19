import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:venera_next/foundation/image_provider/reader_image.dart';

/// One display page and the chapter images it contains.
class ReaderThumbnailPage {
  const ReaderThumbnailPage(this.page, this.images, this.firstImageNumber);

  final int page;
  final List<String> images;
  final int firstImageNumber;
}

/// Request for the thumbnail sidebar; owns target checks so the panel never
/// jumps a reader that has since been replaced.
class ReaderThumbnailRequest {
  ReaderThumbnailRequest({
    required this.pages,
    required this.currentPage,
    required this.isCurrent,
    required this.select,
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
  });

  final List<ReaderThumbnailPage> pages;
  final int Function() currentPage;
  final bool Function() isCurrent;
  final bool Function(int) select;
  final String? sourceKey;
  final String comicId;
  final String chapterId;

  bool get isEmpty => pages.isEmpty;
}

class ReaderThumbnailsView extends StatefulWidget {
  const ReaderThumbnailsView({
    super.key,
    required this.request,
    required this.vertical,
    required this.reverse,
    required this.size,
    required this.onSelect,
  });

  final ReaderThumbnailRequest request;
  final bool vertical;
  final bool reverse;

  /// Width of a vertical strip, height of a horizontal strip.
  final double size;
  final void Function(int page) onSelect;

  @override
  State<ReaderThumbnailsView> createState() => _ReaderThumbnailsViewState();
}

class _ReaderThumbnailsViewState extends State<ReaderThumbnailsView> {
  final _itemScrollController = ItemScrollController();
  late int _lastPage = widget.request.currentPage();

  @override
  void initState() {
    super.initState();
    _centerCurrentPage();
  }

  @override
  void didUpdateWidget(ReaderThumbnailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = widget.request.currentPage();
    if (page != _lastPage) {
      _lastPage = page;
      _centerCurrentPage();
    }
  }

  /// Keeps the thumbnail of the current page centred after page turns. Wheel
  /// scrolling stays under the user's control until the next page change.
  void _centerCurrentPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      final index = (widget.request.currentPage() - 1).clamp(
        0,
        widget.request.pages.length - 1,
      );
      _itemScrollController.scrollTo(
        index: index,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = widget.request.pages;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: ScrollablePositionedList.builder(
        initialScrollIndex: math.max(0, widget.request.currentPage() - 1),
        itemScrollController: _itemScrollController,
        itemCount: pages.length,
        scrollControllerCallback: (_) {},
        scrollDirection: widget.vertical ? Axis.vertical : Axis.horizontal,
        reverse: widget.reverse,
        itemBuilder: (context, index) {
          final page = pages[index];
          final current = page.page == widget.request.currentPage();
          return _ThumbnailTile(
            request: widget.request,
            page: page,
            current: current,
            vertical: widget.vertical,
            size: widget.size,
            onTap: () => widget.onSelect(page.page),
          );
        },
      ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.request,
    required this.page,
    required this.current,
    required this.vertical,
    required this.size,
    required this.onTap,
  });

  final ReaderThumbnailRequest request;
  final ReaderThumbnailPage page;
  final bool current;
  final bool vertical;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = page.images;
    Widget thumb(int index) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: _ThumbnailImage(
        imageKey: images[index],
        request: request,
        imageNumber: page.firstImageNumber + index,
        vertical: vertical,
      ),
    );
    final imageArea = images.isEmpty
        ? const SizedBox()
        : vertical
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < images.length; i++) Expanded(child: thumb(i)),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < images.length; i++)
                SizedBox(height: size - 24, child: thumb(i)),
            ],
          );

    final tile = Material(
      color: current
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: vertical
                  ? SizedBox(width: size - 16, child: imageArea)
                  : SizedBox(height: size - 16, child: imageArea),
            ),
            Positioned(
              left: 6,
              top: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    '${page.page}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: tile,
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.imageKey,
    required this.request,
    required this.imageNumber,
    required this.vertical,
  });

  final String imageKey;
  final ReaderThumbnailRequest request;
  final int imageNumber;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: ReaderImageProvider(
        imageKey,
        request.sourceKey,
        request.comicId,
        request.chapterId,
        imageNumber,
        enableResize: true,
      ),
      fit: vertical ? BoxFit.fitWidth : BoxFit.fitHeight,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
