import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/app_shell/global_shortcuts.dart';
import 'package:venera_next/app_shell/desktop_menus.dart';
import 'package:venera_next/features/settings/keyboard_shortcuts.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_registry.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_store.dart';

Future<void> chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool alt = false,
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<T> flush<T>(WidgetTester tester, Future<T> future) async {
  bool done = false;
  T? result;
  Object? error;
  future.then(
    (value) {
      result = value;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done, true);
  expect(error, isNull);
  return result as T;
}

void main() {
  setUpAll(() => App.dataPath = Directory.systemTemp.path);
  late Directory root;
  late Map<String, dynamic> previous;
  late String path;
  setUp(() {
    root = Directory.systemTemp.createTempSync('shortcuts-test-');
    path = App.dataPath;
    previous =
        jsonDecode(jsonEncode(appdata.toJson()['settings']))
            as Map<String, dynamic>;
    App.dataPath = root.path;
    appdata.settings['shortcutOverrides'] = <String, String>{};
    appdata.settings['language'] = 'en-US';
    appdata.settings['disableSyncFields'] = '';
  });
  tearDown(() {
    previous.forEach((k, v) => appdata.settings[k] = v);
    appdata.settings['shortcutOverrides'] = previous['shortcutOverrides'];
    App.dataPath = path;
    root.deleteSync(recursive: true);
    shortcutCaptureOwner.value = null;
  });

  testWidgets(
    'four legacy global actions and four navigation defaults preserve dispatch',
    (tester) async {
      final chrome = DesktopChromeController();
      final body = FocusNode();
      var settings = 0, left = 0, right = 0;
      final tabs = <int>[];
      chrome.bindGlobalActions(
        openSettings: () => settings++,
        openSearch: () {},
        navigate: tabs.add,
        back: () {},
      );
      chrome.setLeftSidebar(
        available: true,
        expanded: true,
        toggle: () => left++,
      );
      chrome.setRightSidebar(
        available: true,
        expanded: true,
        toggle: () => right++,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalShortcuts(
            chrome: chrome,
            child: Focus(
              focusNode: body,
              autofocus: true,
              child: Scaffold(
                body: TextField(focusNode: chrome.searchFocusNode),
              ),
            ),
          ),
        ),
      );
      await chord(tester, LogicalKeyboardKey.comma);
      expect(settings, 1);
      await chord(tester, LogicalKeyboardKey.keyF);
      expect(chrome.searchFocusNode.hasFocus, true);
      body.requestFocus();
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.keyB);
      await chord(tester, LogicalKeyboardKey.keyB, alt: true);
      expect([left, right], [1, 1]);
      for (final key in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ]) {
        await chord(tester, key);
      }
      expect(tabs, [0, 1, 2, 3]);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      for (final key in [
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.comma,
        LogicalKeyboardKey.digit1,
      ]) {
        await chord(tester, key);
      }
      expect([left, right, settings], [1, 1, 1]);
      expect(tabs, [0, 1, 2, 3]);
      await tester.pumpWidget(const SizedBox());
      body.dispose();
      chrome.dispose();
    },
  );

  testWidgets(
    'override save reload clear and resets round trip without changing other settings',
    (tester) async {
      const store = ShortcutStore();
      await flush(
        tester,
        store.assign(
          'app.openSettings',
          const SingleActivator(
            LogicalKeyboardKey.keyP,
            control: true,
            shift: true,
          ),
        ),
      );
      final file = File('${root.path}/appdata.json');
      final saved = jsonDecode(file.readAsStringSync()) as Map;
      expect(
        saved['settings']['shortcutOverrides']['app.openSettings'],
        'ctrl+shift+p',
      );
      appdata.settings['shortcutOverrides'] = <String, String>{};
      await flush(tester, appdata.loadDataForTesting(root.path));
      expect(
        ShortcutCodec.encode(store.effective['app.openSettings']!.single),
        'ctrl+shift+p',
      );
      expect(
        await flush(
          tester,
          store.assign(
            'app.openSettings',
            const SingleActivator(LogicalKeyboardKey.keyB, control: true),
          ),
        ),
        isNotNull,
      );
      expect(
        ShortcutCodec.encode(store.effective['app.openSettings']!.single),
        'ctrl+shift+p',
      );
      expect(
        await flush(
          tester,
          store.assign(
            'reader.moveLeft',
            const SingleActivator(
              LogicalKeyboardKey.keyP,
              control: true,
              shift: true,
            ),
          ),
        ),
        isNull,
      );
      await flush(tester, store.assign('app.openSettings', null));
      expect(store.effective['app.openSettings'], isEmpty);
      await flush(tester, store.reset('app.openSettings'));
      expect(
        ShortcutCodec.encode(store.effective['app.openSettings']!.single),
        'ctrl+,',
      );
      await flush(tester, store.reset());
      expect(appdata.settings['shortcutOverrides'], isEmpty);
      expect(appdata.settings['language'], 'en-US');
    },
  );

  testWidgets(
    'settings capture consumes chord, rejects conflict, Esc cancels, clear and reset work',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chrome = DesktopChromeController();
      var opened = 0;
      chrome.bindGlobalActions(
        openSettings: () => opened++,
        openSearch: () {},
        navigate: (_) {},
        back: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalShortcuts(
            chrome: chrome,
            child: const KeyboardShortcutsSettings(),
          ),
        ),
      );
      final row = find.byKey(const ValueKey('app.openSettings'));
      await tester.tap(row);
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.keyB);
      await flush(tester, appdata.updateSettings((_) {}));
      expect(
        find.text('Already used by “Toggle left sidebar”'),
        findsOneWidget,
      );
      expect(opened, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Press a new shortcut…'), findsNothing);
      await tester.tap(row);
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.keyP, shift: true);
      await flush(tester, appdata.updateSettings((_) {}));
      expect(find.text('Ctrl+Shift+P'), findsOneWidget);
      expect(opened, 0);
      await chord(tester, LogicalKeyboardKey.keyP, shift: true);
      expect(opened, 1);
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Clear shortcut')),
      );
      await flush(tester, appdata.updateSettings((_) {}));
      expect(
        find.descendant(of: row, matching: find.text('No shortcut')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Reset shortcut')),
      );
      await flush(tester, appdata.updateSettings((_) {}));
      expect(
        find.descendant(of: row, matching: find.text('Ctrl+,')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pump();
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(find.text('Press a new shortcut…'), findsNothing);
      expect(shortcutCaptureOwner.value, isNull);
      await tester.tap(row);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      chrome.dispose();
    },
  );

  testWidgets(
    'macOS accelerators use effective registry values and respect capture and input',
    (tester) async {
      final chrome = DesktopChromeController();
      var opened = 0;
      chrome.bindGlobalActions(
        openSettings: () => opened++,
        openSearch: () {},
        navigate: (_) {},
        back: () {},
      );
      PlatformMenuItem item(String title) => DesktopApplicationMenuBar.menus(
        chrome,
        macOS: true,
      ).expand((m) => m.menus).firstWhere((i) => i.label == title);
      expect((item('Settings…').shortcut as SingleActivator).meta, true);
      appdata.settings['shortcutOverrides'] = {
        'app.openSettings': 'meta+shift+p',
        'app.openSearch': '',
      };
      expect(
        ShortcutCodec.encode(item('Settings…').shortcut as SingleActivator),
        'meta+shift+p',
      );
      expect(item('Search…').shortcut, isNull);
      var fullscreen = 0;
      chrome.setReaderActions(
        DesktopReaderActions(
          openSettings: () {},
          openChapters: () {},
          toggleThumbnails: () {},
          toggleFullscreen: () => fullscreen++,
        ),
      );
      expect(
        (item('Full Screen').shortcut as SingleActivator).trigger,
        LogicalKeyboardKey.f12,
      );
      item('Full Screen').onSelected!();
      expect(fullscreen, 1);
      shortcutCaptureOwner.value = Object();
      expect(item('Settings…').shortcut, isNull);
      shortcutCaptureOwner.value = null;
      chrome.setReaderActions(null);
      final beforeTyping = item('Settings…');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
      );
      await tester.pump();
      expect(item('Settings…').shortcut, isNull);
      beforeTyping.onSelected!();
      expect(
        opened,
        0,
        reason: 'A stale native accelerator must not bypass the text guard',
      );
      item('Settings…').onSelected!();
      expect(
        opened,
        1,
        reason: 'An ordinary menu click remains available while typing',
      );
      await tester.pumpWidget(const SizedBox());
      chrome.dispose();
    },
  );
}
