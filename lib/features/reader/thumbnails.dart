import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:venera_next/foundation/image_provider/reader_image.dart';
import 'package:venera_next/foundation/translations.dart';

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
    required this.onSelect,
    required this.onClose,
  });

  final ReaderThumbnailRequest request;
  final void Function(int page) onSelect;
  final VoidCallback onClose;

  @override
  State<ReaderThumbnailsView> createState() => _ReaderThumbnailsViewState();
}

class _ReaderThumbnailsViewState extends State<ReaderThumbnailsView> {
  static const _itemExtent = 132.0;

  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    final index = math.max(0, widget.request.currentPage() - 1);
    _controller = ScrollController(initialScrollOffset: index * _itemExtent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = widget.request.pages;
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Thumbnails'.tl,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close'.tl,
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _controller,
              itemExtent: _itemExtent,
              itemCount: pages.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final page = pages[index];
                final current = page.page == widget.request.currentPage();
                return _ThumbnailTile(
                  request: widget.request,
                  page: page,
                  current: current,
                  onTap: () => widget.onSelect(page.page),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.request,
    required this.page,
    required this.current,
    required this.onTap,
  });

  final ReaderThumbnailRequest request;
  final ReaderThumbnailPage page;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: current
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${page.page}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      for (var i = 0; i < page.images.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: _ThumbnailImage(
                              imageKey: page.images[i],
                              request: request,
                              imageNumber: page.firstImageNumber + i,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.imageKey,
    required this.request,
    required this.imageNumber,
  });

  final String imageKey;
  final ReaderThumbnailRequest request;
  final int imageNumber;

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
      fit: BoxFit.cover,
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
