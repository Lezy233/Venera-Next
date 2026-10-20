import 'package:flutter/widgets.dart';

/// Hosts a widget that needs an [Overlay] ancestor but itself sits above the
/// app's Navigator/Overlay (for example the custom window title bar).
///
/// The overlay covers the whole window so text selection toolbars can render
/// outside the hosted widget's bounds; areas not covered by [child] do not
/// consume pointer events.
class OverlayHost extends StatefulWidget {
  const OverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<OverlayHost> {
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(
      // Only the hosted strip consumes hit tests; the rest of the window
      // keeps receiving pointers through the transparent overlay area.
      builder: (_) =>
          Positioned(top: 0, left: 0, right: 0, child: widget.child),
    );
  }

  @override
  void didUpdateWidget(OverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}
