import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_registry.dart';
import 'package:venera_next/features/reader/keyboard_shortcuts.dart';

class _Target implements ShortcutTarget {
  final events = <(ShortcutCommand, KeyEvent)>[];
  @override
  void invokeShortcut(ShortcutCommand command, KeyEvent event) =>
      events.add((command, event));
}

void main() {
  test(
    'defaults cover all actions and adapt only default global modifiers',
    () {
      for (final mac in [false, true]) {
        final bindings = AppShortcutRegistry.resolve(null, macOS: mac);
        expect(bindings, hasLength(15));
        expect(
          shortcutActions.where((a) => a.context == ShortcutContext.global),
          hasLength(8),
        );
        expect(bindings['app.openSettings']!.single.control, !mac);
        expect(bindings['app.openSettings']!.single.meta, mac);
        expect(bindings['app.toggleRightSidebar']!.map(ShortcutCodec.encode), [
          mac ? 'alt+meta+b' : 'ctrl+shift+b',
        ]);
        expect(
          AppShortcutRegistry.resolve({
            'app.toggleRightSidebar': ['ctrl+alt+b'],
          }, macOS: mac)['app.toggleRightSidebar']!.map(ShortcutCodec.encode),
          ['ctrl+alt+b'],
        );
        expect(bindings['reader.nextPage']!.map(ShortcutCodec.encode), [
          'space',
          'pagedown',
        ]);
        expect(bindings['reader.prevPage']!.map(ShortcutCodec.encode), [
          'pageup',
        ]);
        expect(
          bindings['reader.toggleFullscreen']!.single.trigger,
          LogicalKeyboardKey.f12,
        );
        expect(
          bindings.values
              .expand((b) => b)
              .any((b) => b.trigger == LogicalKeyboardKey.escape),
          false,
        );
        final changed = AppShortcutRegistry.resolve({
          'app.openSettings': 'ctrl+shift+p',
        }, macOS: mac);
        expect(
          ShortcutCodec.encode(changed['app.openSettings']!.single),
          'ctrl+shift+p',
        );
        expect(
          AppShortcutRegistry.resolve({
            'app.openSettings': '',
          }, macOS: mac)['app.openSettings'],
          isEmpty,
        );
      }
    },
  );

  test(
    'codec round trips modifiers and trigger keys without display coupling',
    () {
      for (final key in [
        LogicalKeyboardKey.comma,
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.f12,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.add,
        LogicalKeyboardKey.digit1,
      ]) {
        for (var flags = 0; flags < 16; flags++) {
          final binding = SingleActivator(
            key,
            control: flags & 1 != 0,
            alt: flags & 2 != 0,
            meta: flags & 4 != 0,
            shift: flags & 8 != 0,
          );
          final code = ShortcutCodec.encode(binding);
          expect(ShortcutCodec.encode(ShortcutCodec.decode(code)!), code);
        }
      }
      expect(ShortcutCodec.decode('ctrl+ctrl+b'), isNull);
      expect(ShortcutCodec.decode('ctrl+unknown-key'), isNull);
      expect(ShortcutCodec.decode('escape'), isNull);
      expect(
        ShortcutCodec.format(
          const SingleActivator(
            LogicalKeyboardKey.keyB,
            control: true,
            alt: true,
          ),
          macOS: false,
        ),
        'Ctrl+Alt+B',
      );
      expect(
        ShortcutCodec.format(
          const SingleActivator(
            LogicalKeyboardKey.keyP,
            meta: true,
            shift: true,
          ),
          macOS: true,
        ),
        '⇧⌘P',
      );
    },
  );

  test(
    'same-context conflicts reject, cross-context and own defaults do not',
    () {
      const b = SingleActivator(LogicalKeyboardKey.keyB, control: true);
      expect(
        AppShortcutRegistry.conflict(
          'app.openSettings',
          b,
          {},
          macOS: false,
        )?.id,
        'app.toggleLeftSidebar',
      );
      expect(
        AppShortcutRegistry.conflict('reader.moveLeft', b, {}, macOS: false),
        isNull,
      );
      expect(
        AppShortcutRegistry.conflict(
          'reader.nextPage',
          const SingleActivator(LogicalKeyboardKey.space),
          {},
          macOS: false,
        ),
        isNull,
      );
      final loaded = AppShortcutRegistry.resolve({
        'app.openSettings': 'ctrl+b',
      }, macOS: false);
      expect(loaded['app.openSettings'], hasLength(1));
      expect(loaded['app.toggleLeftSidebar'], isEmpty);
      expect(
        AppShortcutRegistry.resolve({
          'reader.moveLeft': 'space',
        }, macOS: false)['reader.nextPage'],
        isEmpty,
      );
    },
  );

  test(
    'list overrides preserve order, empty semantics and legacy compatibility',
    () {
      final raw = {
        'app.openSettings': ['ctrl+p', 'ctrl+shift+p', 'ctrl+p'],
        'app.openSearch': <String>[],
        'reader.moveLeft': 'j',
        'reader.moveRight': '',
      };
      final effective = AppShortcutRegistry.resolve(raw, macOS: false);
      expect(effective['app.openSettings']!.map(ShortcutCodec.encode), [
        'ctrl+p',
        'ctrl+shift+p',
      ]);
      expect(effective['app.openSearch'], isEmpty);
      expect(effective['reader.moveLeft']!.map(ShortcutCodec.encode), ['j']);
      expect(effective['reader.moveRight'], isEmpty);
      expect(effective['reader.nextPage']!.map(ShortcutCodec.encode), [
        'space',
        'pagedown',
      ]);
      final migrated = AppShortcutRegistry.overrides(raw);
      expect(migrated['reader.moveLeft'], ['j']);
      expect(migrated['reader.moveRight'], isEmpty);
      expect(
        AppShortcutRegistry.conflict(
          'app.openSearch',
          ShortcutCodec.decode('ctrl+shift+p')!,
          raw,
          macOS: false,
        )?.id,
        'app.openSettings',
      );
      expect(
        AppShortcutRegistry.conflict(
          'reader.moveUp',
          ShortcutCodec.decode('ctrl+shift+p')!,
          raw,
          macOS: false,
        ),
        isNull,
      );
      // Loading retains deterministic action-order conflict handling from D4.
      expect(
        AppShortcutRegistry.resolve({
          'reader.moveLeft': ['space', 'j'],
        }, macOS: false)['reader.nextPage'],
        isEmpty,
      );
    },
  );

  testWidgets(
    'reader owns matching chords and retains accepted action until key-up',
    (tester) async {
      final target = _Target(), session = ReaderShortcutSession();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final down = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyJ,
        logicalKey: LogicalKeyboardKey.keyJ,
        timeStamp: Duration.zero,
      );
      bool dispatch(KeyEvent event, Object? saved) => session.dispatch(
        event,
        overrides: saved,
        macOS: false,
        primaryFocus: true,
        textInput: false,
        target: target,
      );
      expect(dispatch(down, {'reader.moveLeft': 'ctrl+j'}), true);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      final repeat = KeyRepeatEvent(
        physicalKey: down.physicalKey,
        logicalKey: down.logicalKey,
        timeStamp: Duration.zero,
      );
      final up = KeyUpEvent(
        physicalKey: down.physicalKey,
        logicalKey: down.logicalKey,
        timeStamp: Duration.zero,
      );
      expect(dispatch(repeat, {'reader.moveLeft': ''}), true);
      expect(dispatch(up, {'reader.moveLeft': ''}), true);
      expect(
        target.events.map((e) => e.$1),
        everyElement(ShortcutCommand.moveLeft),
      );
      expect(target.events.map((e) => e.$2.runtimeType), [
        KeyDownEvent,
        KeyRepeatEvent,
        KeyUpEvent,
      ]);
      final canonical = shortcutDirectionEvent(
        repeat,
        LogicalKeyboardKey.arrowLeft,
      );
      expect(canonical, isA<KeyRepeatEvent>());
      expect(canonical.logicalKey, LogicalKeyboardKey.arrowLeft);
      expect(
        session.dispatch(
          down,
          overrides: {'reader.moveLeft': 'j'},
          macOS: false,
          primaryFocus: false,
          textInput: false,
          target: target,
        ),
        false,
      );
    },
  );
}
