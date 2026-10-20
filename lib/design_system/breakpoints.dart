import 'package:flutter/widgets.dart';

/// Material 3 window size classes used across the app.
/// See `design-spec.md` §3.
enum WindowSizeClass {
  /// `width < 720`: single column, mobile navigation.
  compact,

  /// `720 <= width < 1200`: side rail, two-pane settings.
  medium,

  /// `width >= 1200`: side rail, two-pane settings, command center.
  expanded,
}

extension WindowSizeClassX on WindowSizeClass {
  bool get isCompact => this == WindowSizeClass.compact;

  bool get isMedium => this == WindowSizeClass.medium;

  bool get isExpanded => this == WindowSizeClass.expanded;
}

/// The single source of responsive breakpoints.
///
/// Never compare against raw numbers in UI code; use [of] or the
/// [isCompact] / [isMedium] / [isExpanded] helpers instead.
abstract final class Breakpoints {
  /// Upper bound (exclusive) of the compact class.
  static const double compactMaxWidth = 720;

  /// Lower bound (inclusive) of the expanded class.
  static const double expandedMinWidth = 1200;

  static WindowSizeClass classify(double width) {
    if (width < compactMaxWidth) return WindowSizeClass.compact;
    if (width < expandedMinWidth) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  static WindowSizeClass of(BuildContext context) =>
      classify(MediaQuery.sizeOf(context).width);

  static bool isCompact(BuildContext context) =>
      of(context) == WindowSizeClass.compact;

  static bool isMedium(BuildContext context) =>
      of(context) == WindowSizeClass.medium;

  static bool isExpanded(BuildContext context) =>
      of(context) == WindowSizeClass.expanded;
}
