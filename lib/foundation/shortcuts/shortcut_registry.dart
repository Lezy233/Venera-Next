import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// F1 may add page contexts and scope overrides by (context, stack). Keep the
/// current flat actionId -> combo storage behind this resolver for migration.
enum ShortcutContext { global, reader }

/// Capture suspends application accelerators, including native macOS menus.
/// Ownership prevents a detached editor from clearing another editor's capture.
final shortcutCaptureOwner = ValueNotifier<Object?>(null);

enum ShortcutCommand {
  openSettings,
  openSearch,
  toggleLeftSidebar,
  toggleRightSidebar,
  goHome,
  goFavorites,
  goExplore,
  goCategories,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  toggleFullscreen,
  nextPage,
  prevPage,
}

/// The active route supplies a target at dispatch time; the table owns no State.
abstract interface class ShortcutTarget {
  void invokeShortcut(ShortcutCommand command, KeyEvent event);
}

class ShortcutRunner {
  const ShortcutRunner(this.command);
  final ShortcutCommand command;
  void call(ShortcutTarget target, KeyEvent event) =>
      target.invokeShortcut(command, event);
}

class ShortcutAction {
  const ShortcutAction(
    this.id,
    this.titleKey,
    this.context,
    this.defaultBindings,
    this.runner, {
    this.macOSBindings,
  });
  final String id;
  final String titleKey;
  final ShortcutContext context;
  final List<SingleActivator> defaultBindings;
  final ShortcutRunner runner;
  final List<SingleActivator>? macOSBindings;

  List<SingleActivator> bindingsForPlatform({required bool macOS}) {
    if (macOS && macOSBindings != null) return macOSBindings!;
    return defaultBindings
        .map(
          (binding) => macOS && context == ShortcutContext.global
              ? SingleActivator(
                  binding.trigger,
                  meta: binding.control,
                  alt: binding.alt,
                  shift: binding.shift,
                )
              : binding,
        )
        .toList();
  }
}

const shortcutActions = <ShortcutAction>[
  ShortcutAction('app.openSettings', 'Open settings', ShortcutContext.global, [
    SingleActivator(LogicalKeyboardKey.comma, control: true),
  ], ShortcutRunner(ShortcutCommand.openSettings)),
  ShortcutAction('app.openSearch', 'Focus search', ShortcutContext.global, [
    SingleActivator(LogicalKeyboardKey.keyF, control: true),
  ], ShortcutRunner(ShortcutCommand.openSearch)),
  ShortcutAction(
    'app.toggleLeftSidebar',
    'Toggle left sidebar',
    ShortcutContext.global,
    [SingleActivator(LogicalKeyboardKey.keyB, control: true)],
    ShortcutRunner(ShortcutCommand.toggleLeftSidebar),
  ),
  ShortcutAction(
    'app.toggleRightSidebar',
    'Toggle right sidebar',
    ShortcutContext.global,
    [SingleActivator(LogicalKeyboardKey.keyB, control: true, shift: true)],
    ShortcutRunner(ShortcutCommand.toggleRightSidebar),
    macOSBindings: [
      SingleActivator(LogicalKeyboardKey.keyB, meta: true, alt: true),
    ],
  ),
  ShortcutAction('app.goHome', 'Go to Home', ShortcutContext.global, [
    SingleActivator(LogicalKeyboardKey.digit1, control: true),
  ], ShortcutRunner(ShortcutCommand.goHome)),
  ShortcutAction('app.goFavorites', 'Go to Favorites', ShortcutContext.global, [
    SingleActivator(LogicalKeyboardKey.digit2, control: true),
  ], ShortcutRunner(ShortcutCommand.goFavorites)),
  ShortcutAction('app.goExplore', 'Go to Explore', ShortcutContext.global, [
    SingleActivator(LogicalKeyboardKey.digit3, control: true),
  ], ShortcutRunner(ShortcutCommand.goExplore)),
  ShortcutAction(
    'app.goCategories',
    'Go to Categories',
    ShortcutContext.global,
    [SingleActivator(LogicalKeyboardKey.digit4, control: true)],
    ShortcutRunner(ShortcutCommand.goCategories),
  ),
  ShortcutAction('reader.moveLeft', 'Move left', ShortcutContext.reader, [
    SingleActivator(LogicalKeyboardKey.arrowLeft),
  ], ShortcutRunner(ShortcutCommand.moveLeft)),
  ShortcutAction('reader.moveRight', 'Move right', ShortcutContext.reader, [
    SingleActivator(LogicalKeyboardKey.arrowRight),
  ], ShortcutRunner(ShortcutCommand.moveRight)),
  ShortcutAction('reader.moveUp', 'Move up', ShortcutContext.reader, [
    SingleActivator(LogicalKeyboardKey.arrowUp),
  ], ShortcutRunner(ShortcutCommand.moveUp)),
  ShortcutAction('reader.moveDown', 'Move down', ShortcutContext.reader, [
    SingleActivator(LogicalKeyboardKey.arrowDown),
  ], ShortcutRunner(ShortcutCommand.moveDown)),
  ShortcutAction(
    'reader.toggleFullscreen',
    'Toggle fullscreen',
    ShortcutContext.reader,
    [SingleActivator(LogicalKeyboardKey.f12)],
    ShortcutRunner(ShortcutCommand.toggleFullscreen),
  ),
  ShortcutAction('reader.nextPage', 'Next page', ShortcutContext.reader, [
    SingleActivator(LogicalKeyboardKey.space),
    SingleActivator(LogicalKeyboardKey.pageDown),
  ], ShortcutRunner(ShortcutCommand.nextPage)),
  ShortcutAction('reader.prevPage', 'Previous page', ShortcutContext.reader, [
    SingleActivator(LogicalKeyboardKey.pageUp),
  ], ShortcutRunner(ShortcutCommand.prevPage)),
];

abstract final class ShortcutCodec {
  static bool isModifier(LogicalKeyboardKey key) => const [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.scrollLock,
  ].contains(key);

  static String _keyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'space';
    final label = key.keyLabel.toLowerCase().replaceAll(' ', '');
    // '+' is the encoding separator. The stable key id handles unnamed keys.
    return label.isEmpty || label.contains('+')
        ? 'key-${key.keyId.toRadixString(16)}'
        : label;
  }

  static final _keys = <String, LogicalKeyboardKey>{
    for (final key in LogicalKeyboardKey.knownLogicalKeys) _keyName(key): key,
  };
  static String encode(SingleActivator binding) => [
    if (binding.control) 'ctrl',
    if (binding.alt) 'alt',
    if (binding.meta) 'meta',
    if (binding.shift) 'shift',
    _keyName(binding.trigger),
  ].join('+');

  static SingleActivator? decode(String value) {
    final parts = value.toLowerCase().split('+');
    final key = _keys[parts.last];
    if (key == null || isModifier(key) || key == LogicalKeyboardKey.escape) {
      return null;
    }
    final modifiers = parts.take(parts.length - 1).toList();
    if (modifiers.toSet().length != modifiers.length ||
        modifiers.any(
          (s) => !const {'ctrl', 'alt', 'meta', 'shift'}.contains(s),
        )) {
      return null;
    }
    return SingleActivator(
      key,
      control: modifiers.contains('ctrl'),
      alt: modifiers.contains('alt'),
      meta: modifiers.contains('meta'),
      shift: modifiers.contains('shift'),
    );
  }

  static SingleActivator capture(KeyEvent event, [HardwareKeyboard? keyboard]) {
    final keys = keyboard ?? HardwareKeyboard.instance;
    return SingleActivator(
      event.logicalKey,
      control: keys.isControlPressed,
      alt: keys.isAltPressed,
      meta: keys.isMetaPressed,
      shift: keys.isShiftPressed,
    );
  }

  static String format(SingleActivator binding, {required bool macOS}) {
    final key = binding.trigger == LogicalKeyboardKey.space
        ? 'Space'
        : binding.trigger.keyLabel;
    return macOS
        ? '${binding.control ? '⌃' : ''}${binding.alt ? '⌥' : ''}${binding.shift ? '⇧' : ''}${binding.meta ? '⌘' : ''}$key'
        : [
            if (binding.control) 'Ctrl',
            if (binding.alt) 'Alt',
            if (binding.meta) 'Meta',
            if (binding.shift) 'Shift',
            key.length == 1 ? key.toUpperCase() : key,
          ].join('+');
  }
}

abstract final class AppShortcutRegistry {
  static ShortcutAction action(String id) =>
      shortcutActions.firstWhere((a) => a.id == id);

  /// Normalize legacy single strings, including '' (explicitly unbound).
  /// Return owned lists so serialized edits never mutate live settings.
  static Map<String, List<String>> overrides(Object? value) => value is Map
      ? {
          for (final entry in value.entries)
            if (entry.key is String &&
                (entry.value is String || entry.value is List))
              entry.key as String: entry.value is String
                  ? (entry.value == '' ? <String>[] : [entry.value as String])
                  : (entry.value as List).whereType<String>().toList(),
        }
      : {};

  static Map<String, List<SingleActivator>> resolve(
    Object? value, {
    required bool macOS,
  }) {
    final saved = overrides(value);
    final claimed = <ShortcutContext, Set<String>>{};
    final result = <String, List<SingleActivator>>{};
    for (final action in shortcutActions) {
      final custom = saved[action.id];
      var bindings = action.bindingsForPlatform(macOS: macOS);
      if (custom != null) {
        // Each stored chord is decoded and deduplicated independently.
        final unique = <String, SingleActivator>{};
        for (final code in custom) {
          final binding = ShortcutCodec.decode(code);
          if (binding != null) unique[ShortcutCodec.encode(binding)] = binding;
        }
        bindings = unique.values.toList();
      }
      final domain = claimed.putIfAbsent(action.context, () => {});
      if (bindings.any((b) => domain.contains(ShortcutCodec.encode(b)))) {
        bindings = [];
      }
      domain.addAll(bindings.map(ShortcutCodec.encode));
      result[action.id] = List.unmodifiable(bindings);
    }
    return result;
  }

  static ShortcutAction? conflict(
    String id,
    SingleActivator binding,
    Object? value, {
    required bool macOS,
  }) {
    final edited = action(id), encoded = ShortcutCodec.encode(binding);
    final effective = resolve(value, macOS: macOS);
    for (final other in shortcutActions) {
      if (other.id != id &&
          other.context == edited.context &&
          effective[other.id]!.any((b) => ShortcutCodec.encode(b) == encoded)) {
        return other;
      }
    }
    return null;
  }

  static ShortcutAction? match(
    ShortcutContext context,
    KeyEvent event,
    Object? value, {
    required bool macOS,
    HardwareKeyboard? keyboard,
  }) {
    final effective = resolve(value, macOS: macOS);
    // Up events still belong to the held action (fullscreen fires on release).
    final probe = event is KeyUpEvent
        ? KeyDownEvent(
            physicalKey: event.physicalKey,
            logicalKey: event.logicalKey,
            timeStamp: event.timeStamp,
          )
        : event;
    for (final action in shortcutActions) {
      if (action.context == context &&
          effective[action.id]!.any(
            (b) => b.accepts(probe, keyboard ?? HardwareKeyboard.instance),
          )) {
        return action;
      }
    }
    return null;
  }
}

bool shortcutTextInputFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      (context.widget is EditableText ||
          context.findAncestorWidgetOfExactType<EditableText>() != null);
}

KeyEvent shortcutDirectionEvent(KeyEvent event, LogicalKeyboardKey direction) {
  if (event.logicalKey == direction) return event;
  if (event is KeyUpEvent) {
    return KeyUpEvent(
      physicalKey: event.physicalKey,
      logicalKey: direction,
      timeStamp: event.timeStamp,
      synthesized: event.synthesized,
    );
  }
  if (event is KeyRepeatEvent) {
    return KeyRepeatEvent(
      physicalKey: event.physicalKey,
      logicalKey: direction,
      timeStamp: event.timeStamp,
    );
  }
  return KeyDownEvent(
    physicalKey: event.physicalKey,
    logicalKey: direction,
    timeStamp: event.timeStamp,
    synthesized: event.synthesized,
  );
}
