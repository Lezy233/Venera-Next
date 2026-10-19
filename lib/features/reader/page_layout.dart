import 'dart:math' as math;

/// Mapping between one-based image numbers and display pages.
/// Image ranges use zero-based, end-exclusive indices for List.sublist.
class ReaderPageLayout {
  const ReaderPageLayout({
    required this.imagesPerPage,
    required this.singleImageOnFirstPage,
    this.spreadImages = const {},
  }) : assert(imagesPerPage > 0);

  final int imagesPerPage;
  final bool singleImageOnFirstPage;

  /// One-based image numbers that already contain two facing pages (a scan of
  /// a double-page spread). Such an image always occupies its own page and is
  /// never paired with a neighbour.
  final Set<int> spreadImages;

  /// Display-page ranges, zero-based and end-exclusive.
  List<(int, int)> _ranges(int imageCount) {
    if (imageCount <= 0) {
      return singleImageOnFirstPage ? const [(0, 0)] : const [];
    }
    final ranges = <(int, int)>[];
    var start = 0;
    if (singleImageOnFirstPage) {
      ranges.add((0, 1));
      start = 1;
    }
    while (start < imageCount) {
      if (spreadImages.contains(start + 1)) {
        ranges.add((start, start + 1));
        start += 1;
        continue;
      }
      var end = start + 1;
      while (end < imageCount && end - start < imagesPerPage) {
        // A spread must not be paired with the previous normal image.
        if (spreadImages.contains(end + 1)) break;
        end += 1;
      }
      ranges.add((start, end));
      start = end;
    }
    return ranges;
  }

  /// Null means images have not loaded; preserve the loading placeholder page.
  int pageCount(int? imageCount) =>
      imageCount == null ? 1 : _ranges(imageCount).length;

  int pageForImage(int imageNumber, {int? imageCount}) {
    if (imageCount != null) {
      final ranges = _ranges(imageCount);
      for (var index = 0; index < ranges.length; index++) {
        final (start, end) = ranges[index];
        if (imageNumber - 1 >= start && imageNumber - 1 < end) {
          return index + 1;
        }
      }
      return ranges.isEmpty ? 1 : ranges.length;
    }
    if (imagesPerPage == 1) return imageNumber;
    return singleImageOnFirstPage
        ? ((imageNumber - 1) / imagesPerPage).ceil() + 1
        : (imageNumber / imagesPerPage).ceil();
  }

  /// First image (one-based) of a display page. Arithmetic only; callers that
  /// can observe spread images should use [imageRange] instead.
  int firstImageOnPage(int page) {
    if (singleImageOnFirstPage && page != 1) {
      return (page - 2) * imagesPerPage + 2;
    }
    return (page - 1) * imagesPerPage + 1;
  }

  (int start, int end) imageRange(int page, int imageCount) {
    // A cover-only empty chapter retains its legacy placeholder page count,
    // but has no source image for rendering or prefetch to index.
    if (imageCount == 0) return (0, 0);
    final ranges = _ranges(imageCount);
    if (page < 1 || page > ranges.length) return (0, 0);
    return ranges[page - 1];
  }

  /// Finishing the last display page (or its comments page) marks the last image.
  int historyImage(int page, int imageCount) {
    if (page >= pageCount(imageCount)) return imageCount;
    final (start, _) = imageRange(page, imageCount);
    return start + 1;
  }

  /// Keep the first image visible across layouts, or preserve the trailing
  /// comments page. This does not change chapter IDs or waterfall segments.
  int remapPage(int page, ReaderPageLayout target, {required int? imageCount}) {
    final targetCount = target.pageCount(imageCount);
    if (page > pageCount(imageCount)) return targetCount + 1;
    final (start, _) = imageRange(page, imageCount ?? 0);
    return target
        .pageForImage(start + 1, imageCount: imageCount)
        .clamp(1, math.max(1, targetCount));
  }
}
