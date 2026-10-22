import 'package:flutter/services.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_registry.dart';

/// Retain the action accepted on key-down, so key-up still stops a gallery
/// timer after modifiers, settings or effective bindings change while held.
class ReaderShortcutSession {
  final _held = <PhysicalKeyboardKey, ShortcutAction>{};
  void clear() => _held.clear();

  bool dispatch(
    KeyEvent event, {
    required Object? overrides,
    required bool macOS,
    required bool primaryFocus,
    required bool textInput,
    required ShortcutTarget target,
  }) {
    final held = _held[event.physicalKey];
    final action =
        held ??
        AppShortcutRegistry.match(
          ShortcutContext.reader,
          event,
          overrides,
          macOS: macOS,
        );
    if (event is KeyUpEvent) _held.remove(event.physicalKey);
    if (action == null) return false;
    // F12 historically runs on key-up before the viewport focus guard. Keep
    // that exception; all view commands retain primary-focus ownership.
    if (action.runner.command != ShortcutCommand.toggleFullscreen &&
        (!primaryFocus || textInput)) {
      return false;
    }
    if (event is KeyDownEvent) _held[event.physicalKey] = action;
    action.runner(target, event);
    return true;
  }
}
