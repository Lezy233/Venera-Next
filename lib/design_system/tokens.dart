import 'package:flutter/material.dart';

/// Spacing scale on a 4px base. See `design-spec.md` §2.1.
///
/// Use these values for padding, margins and gaps. Fixed component sizes
/// (bar heights, rail widths) belong to [AppSizes].
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. See `design-spec.md` §2.2.
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double pill = 999;
}

/// Motion durations. See `design-spec.md` §2.3.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration emphasized = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration tooltipWait = Duration(milliseconds: 600);
}

/// Opacity values for interaction states. See `design-spec.md` §2.6.
abstract final class AppOpacity {
  static const double disabled = 0.38;
  static const double hover = 0.08;
  static const double pressed = 0.12;
  static const double selectedContainer = 0.36;
}

/// Shadow recipes. Flat is the default; only genuinely floating surfaces get
/// a shadow. See `design-spec.md` §2.4.
abstract final class AppShadows {
  static List<BoxShadow> floating(ColorScheme scheme, {bool focused = true}) =>
      [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: focused ? 0.24 : 0.12),
          blurRadius: AppSpacing.lg,
          offset: const Offset(0, AppSpacing.xs),
        ),
      ];
}

/// Font sizes matching the existing `ts.s10` … `ts.s20` scale.
/// See `design-spec.md` §2.5.
abstract final class AppFontSize {
  static const double caption = 10;
  static const double bodySmall = 12;
  static const double body = 14;
  static const double bodyLarge = 16;
  static const double title = 18;
  static const double titleLarge = 20;
}

/// Fixed shell and layout component sizes. See `design-spec.md` §2.7.
abstract final class AppSizes {
  static const double titleBarHeight = 36;
  static const double hairline = 1;
  static const double windowControlWidth = 46;
  static const double windowControlIconSize = 10;
  static const double windowButtonsWidth = windowControlWidth * 3;
  static const double shellIconSize = 18;
  static const double shellSearchIconSize = 16;
  static const double macTrafficLightsWidth = 68;
  static const double shellControlSize = 30;
  static const double navTopBarHeight = 48;
  static const double navBottomBarHeight = 58;
  static const double navSideRailWidth = 48;
  static const double navItemSize = 48;
  static const double navBottomIndicatorWidth = 64;
  static const double navBottomIndicatorHeight = 28;
  static const double navBottomIndicatorMinWidth = 32;
  static const double navIconSize = 24;
  static const double commandCenterWidth = 320;
  static const double commandCenterHeight = 26;
  static const double settingsSidebarWidth = 280;
  static const double settingsCategoryHeight = 46;
  static const double settingsHeaderHeight = 56;
  static const double settingsSelectedIndicatorWidth = 2;
  static const double authIconSize = 36;
}

/// Semantic color roles layered on top of [ColorScheme].
///
/// The scheme remains the single source of color; these aliases name the
/// shell/content/accent intent so shell widgets do not pick raw shades.
extension AppColorRoles on ColorScheme {
  Color get shellSurface => surface;

  Color get shellSurfaceHover => surfaceContainerHigh;

  Color get shellBorder => outlineVariant;

  Color get shellForeground => onSurface;

  Color get shellForegroundMuted => onSurfaceVariant;

  Color get disabledForeground =>
      onSurface.withValues(alpha: AppOpacity.disabled);

  Color get contentSurface => surface;

  Color get contentSurfaceRaised => surfaceContainerLow;

  Color get contentBorder => outlineVariant;

  Color get accent => primary;

  Color get accentContainer => primaryContainer;

  Color get onAccentContainer => onPrimaryContainer;

  Color get danger => error;

  Color get onDanger => onError;
}
