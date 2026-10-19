import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'consts.dart';
import 'gesture.dart';

class Select extends StatelessWidget {
  const Select({
    super.key,
    required this.current,
    required this.values,
    this.onTap,
    this.minWidth,
  });

  final String? current;

  final List<String> values;

  final void Function(int index)? onTap;

  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textMinWidth = math.max(0.0, (minWidth ?? 96) - 34);
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClickInkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap == null
            ? null
            : () async {
                final renderBox = context.findRenderObject() as RenderBox;
                final offset = renderBox.localToGlobal(Offset.zero);
                final size = renderBox.size;
                final selected = await showMenu<String>(
                  context: context,
                  useRootNavigator: true,
                  elevation: 3,
                  color: colorScheme.surfaceContainerHigh,
                  constraints: const BoxConstraints(
                    minWidth: 120,
                    maxWidth: 280,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  position: RelativeRect.fromLTRB(
                    offset.dx,
                    offset.dy + size.height + 2,
                    offset.dx + size.width,
                    offset.dy,
                  ),
                  items: [
                    for (var index = 0; index < values.length; index++)
                      PopupMenuItem<String>(
                        value: values[index],
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              child: values[index] == current
                                  ? Icon(
                                      Icons.check,
                                      size: 14,
                                      color: colorScheme.onSurface,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                values[index],
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
                if (selected != null) {
                  final index = values.indexOf(selected);
                  if (index >= 0) onTap?.call(index);
                }
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: textMinWidth,
                  maxWidth: 180,
                ),
                child: Text(
                  current ?? ' ',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ).padding(const EdgeInsets.fromLTRB(10, 5, 4, 5)),
      ),
    );
  }
}

class FilterChipFixedWidth extends StatefulWidget {
  const FilterChipFixedWidth({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final Widget label;

  final bool selected;

  final void Function(bool) onSelected;

  @override
  State<FilterChipFixedWidth> createState() => _FilterChipFixedWidthState();
}

class _FilterChipFixedWidthState extends State<FilterChipFixedWidth> {
  bool get selected => widget.selected;

  double? labelWidth;

  double? labelHeight;

  var key = GlobalKey();

  @override
  void initState() {
    Future.microtask(measureSize);
    super.initState();
  }

  void measureSize() {
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    labelWidth = renderBox.size.width;
    labelHeight = renderBox.size.height;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      textStyle: Theme.of(context).textTheme.labelLarge,
      child: ClickInkWell(
        onTap: () => widget.onSelected(true),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: AnimatedContainer(
          duration: fastAnimationDuration,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: labelWidth == null ? firstBuild() : buildContent(),
        ),
      ),
    );
  }

  Widget firstBuild() {
    return Center(
      child: SizedBox(key: key, child: widget.label),
    );
  }

  Widget buildContent() {
    const iconSize = 18.0;
    const gap = 4.0;
    return SizedBox(
      width: iconSize + labelWidth! + gap,
      height: math.max(iconSize, labelHeight!),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: fastAnimationDuration,
            left: selected ? (iconSize + gap) : (iconSize + gap) / 2,
            child: widget.label,
          ),
          if (selected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: labelWidth! + gap,
              child: const AnimatedCheckIcon(size: iconSize).toCenter(),
            ),
        ],
      ),
    );
  }
}

class AnimatedCheckWidget extends AnimatedWidget {
  const AnimatedCheckWidget({
    super.key,
    required Animation<double> animation,
    this.size,
  }) : super(listenable: animation);

  final double? size;

  @override
  Widget build(BuildContext context) {
    var iconSize = size ?? IconTheme.of(context).size ?? 25;
    final animation = listenable as Animation<double>;
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: animation.value,
          child: ClipRRect(
            child: Icon(
              Icons.check,
              size: iconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedCheckIcon extends StatefulWidget {
  const AnimatedCheckIcon({this.size, super.key});

  final double? size;

  @override
  State<AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: fastAnimationDuration,
    );
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {});
      });
    controller.forward();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCheckWidget(animation: animation, size: widget.size);
  }
}

class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;

  final bool isSelected;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: fastAnimationDuration,
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.secondaryContainer
            : context.colorScheme.surface,
        border: isSelected
            ? Border.all(color: context.colorScheme.secondaryContainer)
            : Border.all(color: context.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ClickInkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}
