import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/app_shell/main_page.dart';
import 'package:venera_next/components/navigation_bar.dart';
import 'package:venera_next/foundation/appdata.dart';

class _Chrome extends DesktopChromeController {
  final phases = <SchedulerPhase>[];
  final callbacks = <List<Object>>[];

  @override
  void bindGlobalActions({
    required VoidCallback openSettings,
    required VoidCallback openSearch,
    required void Function(int) navigate,
    required VoidCallback back,
  }) {
    phases.add(SchedulerBinding.instance.schedulerPhase);
    callbacks.add([openSettings, openSearch, navigate, back]);
    super.bindGlobalActions(
      openSettings: openSettings,
      openSearch: openSearch,
      navigate: navigate,
      back: back,
    );
  }
}

void main() {
  setUp(() {
    final settings = Map<String, dynamic>.from(
      appdata.toJson()['settings'] as Map,
    );
    appdata.settings['initialPage'] = '3';
    appdata.settings['language'] = 'en-US';
    addTearDown(
      () => settings.forEach((key, value) => appdata.settings[key] = value),
    );
  });

  testWidgets(
    'main page binds once after build and survives dependency rebuilds',
    (tester) async {
      final chrome = _Chrome();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        chrome.dispose();
      });
      final key = GlobalKey();
      Widget host(double scale) => MaterialApp(
        home: DesktopChromeScope(
          controller: chrome,
          child: Builder(
            builder: (_) {
              // Simulate repeated inherited dependency updates in the build
              // phase so the real StatefulElement invokes the lifecycle hook.
              final element = key.currentContext as StatefulElement?;
              element?.didChangeDependencies();
              element?.didChangeDependencies();
              return MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: MainPage(key: key),
              );
            },
          ),
        ),
      );
      await tester.pumpWidget(host(1));
      expect(tester.takeException(), isNull);
      expect(chrome.phases, [SchedulerPhase.postFrameCallbacks]);
      expect(chrome.canNavigate, isTrue);
      await tester.pump();
      expect(chrome.phases, hasLength(1));
      // Force the real State's dependency lifecycle, plus an inherited rebuild.
      await tester.pumpWidget(host(1.1));
      await tester.pump();
      expect(chrome.phases, hasLength(1));
      expect(tester.takeException(), isNull);
      chrome.navigateTo(2);
      await tester.pumpAndSettle();
      expect(tester.state<NaviPaneState>(find.byType(NaviPane)).currentPage, 2);
      expect(chrome.phases, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(chrome.canNavigate, isFalse);
    },
  );

  testWidgets(
    'replacement controller receives the same stable callbacks after build',
    (tester) async {
      final first = _Chrome(), second = _Chrome();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        first.dispose();
        second.dispose();
      });
      final key = GlobalKey();
      Widget host(_Chrome chrome) => MaterialApp(
        home: DesktopChromeScope(
          controller: chrome,
          child: Builder(
            builder: (_) {
              (key.currentContext as StatefulElement?)?.didChangeDependencies();
              return MainPage(key: key);
            },
          ),
        ),
      );
      await tester.pumpWidget(host(first));
      expect(tester.takeException(), isNull);
      final state = key.currentState;
      await tester.pumpWidget(host(second));
      await tester.pump();
      expect(key.currentState, same(state));
      expect(first.phases, [SchedulerPhase.postFrameCallbacks]);
      expect(second.phases, [SchedulerPhase.postFrameCallbacks]);
      for (var i = 0; i < 4; i++) {
        expect(second.callbacks.single[i], same(first.callbacks.single[i]));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
