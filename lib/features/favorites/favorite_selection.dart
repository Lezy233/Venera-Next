import 'package:flutter/services.dart';

bool consumeFavoriteSelectionEscape(
  KeyEvent event, {
  required bool active,
  required void Function() onExit,
}) {
  if (!active ||
      event is! KeyDownEvent ||
      event.logicalKey != LogicalKeyboardKey.escape) {
    return false;
  }
  onExit();
  return true;
}
