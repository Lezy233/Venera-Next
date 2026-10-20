import 'package:venera_next/design_system/breakpoints.dart';

/// If window width is less than this value, it is considered as compact.
///
/// Deprecated: use [Breakpoints.compactMaxWidth] or the helpers on
/// [Breakpoints] instead. Kept as a forwarding alias for older call sites.
@Deprecated('Use Breakpoints.of(context) / Breakpoints.compactMaxWidth')
const changePoint = Breakpoints.compactMaxWidth;

/// If window width is at least this value, it is considered as expanded.
///
/// Deprecated: use [Breakpoints.expandedMinWidth] or the helpers on
/// [Breakpoints] instead. Kept as a forwarding alias for older call sites.
@Deprecated('Use Breakpoints.of(context) / Breakpoints.expandedMinWidth')
const changePoint2 = Breakpoints.expandedMinWidth;

/// Default user agent for http requests.
const webUA =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36";

/// Pages for all comics is started from this value.
const firstPage = 1;

/// Chapters for all comics is started from this value.
const firstChapter = 1;
