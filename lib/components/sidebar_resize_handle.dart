import 'dart:async';

import 'package:flutter/material.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

/// Hover-revealed handle for a collapsible, resizable sidebar.
///
/// Put it at the sidebar's trailing edge while the sidebar is expanded, or at
/// the viewport's leading edge while it is collapsed. Hovering reveals a pill;
/// tapping toggles the sidebar and dragging resizes it.
class SidebarResizeHandle extends StatefulWidget {
  const SidebarResizeHandle({
    super.key,
    required this.expanded,
    this.onToggle,
    required this.onDrag,
    required this.onDragEnd,
    this.enabled = true,
    this.mirror = false,
  });

  /// Width of the interactive strip. Parents position it so that it straddles
  /// the sidebar edge.
  static const double width = 14;

  /// Whether the sidebar is currently expanded.
  final bool expanded;

  /// Called when the handle is tapped. Null hides the toggle pill while
  /// keeping width-drag collapsing available.
  final VoidCallback? onToggle;

  /// Called with the horizontal drag delta while resizing.
  final ValueChanged<double> onDrag;

  /// Called when a resize drag ends or is cancelled.
  final VoidCallback onDragEnd;

  /// When false the handle stays hidden and ignores pointers.
  final bool enabled;

  /// Flips the chevrons for sidebars anchored to the trailing edge.
  final bool mirror;

  @override
  State<SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<SidebarResizeHandle> {
  static const _hoverDelay = Duration(milliseconds: 120);
  static const _fadeDuration = Duration(milliseconds: 120);

  Timer? _hideTimer;
  bool _hovering = false;
  bool _dragging = false;

  bool get _visible =>
      widget.enabled && widget.onToggle != null && (_hovering || _dragging);

  @override
  void didUpdateWidget(covariant SidebarResizeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _hovering = false;
      _dragging = false;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onEnter() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_hovering) {
      setState(() => _hovering = true);
    }
  }

  void _onExit() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hoverDelay, () {
      if (mounted && !_dragging && _hovering) {
        setState(() => _hovering = false);
      }
    });
  }

  void _dragStart(DragStartDetails details) {
    setState(() => _dragging = true);
  }

  void _dragEnd() {
    if (!mounted) {
      widget.onDragEnd();
      return;
    }
    setState(() => _dragging = false);
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = (widget.expanded ? 'Collapse sidebar' : 'Expand sidebar').tl;
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.resizeLeftRight
          : MouseCursor.defer,
      onEnter: widget.enabled ? (_) => _onEnter() : null,
      onExit: widget.enabled ? (_) => _onExit() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onToggle : null,
        onHorizontalDragStart: widget.enabled ? _dragStart : null,
        onHorizontalDragUpdate: widget.enabled
            ? (details) => widget.onDrag(details.delta.dx)
            : null,
        onHorizontalDragEnd: widget.enabled ? (_) => _dragEnd() : null,
        onHorizontalDragCancel: widget.enabled ? _dragEnd : null,
        child: SizedBox(
          width: SidebarResizeHandle.width,
          height: double.infinity,
          child: Center(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: _fadeDuration,
              child: IgnorePointer(
                child: Semantics(
                  button: true,
                  label: label,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.toOpacity(0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 12,
                      height: 48,
                      child: Icon(
                        widget.mirror
                            ? (widget.expanded
                                  ? Icons.chevron_right
                                  : Icons.chevron_left)
                            : (widget.expanded
                                  ? Icons.chevron_left
                                  : Icons.chevron_right),
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
