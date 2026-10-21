import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/settings/remote_storage.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/foundation/webdav_connection.dart';

Future<void> _flush(WidgetTester tester, Future<void> operation) async {
  var done = false;
  Object? failure;
  operation.then<void>(
    (_) => done = true,
    onError: (Object error) {
      failure = error;
      done = true;
    },
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done, isTrue);
  expect(failure, isNull);
}

Directory _prepare(List<String> messages) {
  final root = Directory.systemTemp.createTempSync('remote-storage-');
  App.dataPath = root.path;
  final previous = jsonDecode(jsonEncode(appdata.toJson()['settings'])) as Map;
  appdata.settings['language'] = 'en-US';
  appdata.settings[webDavConnectionKey] = null;
  appdata.settings[webDavConnectionPendingConfirmationKey] = false;
  for (final key in WebDavPurposes.all) {
    appdata.settings[key] = true;
  }
  appdata.settings['webdav'] = <String>[];
  appdata.settings['backupWebdav'] = <String>[];
  appdata.settings['webdavComicLibrary'] = <String>[];
  registerShowMessageHandler((_, message) => messages.add(message));
  addTearDown(() {
    registerShowMessageHandler((_, _) {});
    previous.forEach((key, value) => appdata.settings[key] = value);
    root.deleteSync(recursive: true);
  });
  return root;
}

Widget _host() => MaterialApp(
  home: Scaffold(
    body: RemoteStorageSettings(testConnection: (_) async => const Res(true)),
  ),
);

void main() {
  testWidgets('unconfigured purpose routes the user to the connection form', (
    tester,
  ) async {
    final messages = <String>[];
    _prepare(messages);
    await tester.pumpWidget(_host());

    expect(find.text('Not configured'), findsWidgets);
    await tester.tap(find.text('Comic Archive Backup'));
    await tester.pump();

    expect(messages, contains('Configure the shared WebDAV connection first.'));
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saving one connection makes all three purposes configured', (
    tester,
  ) async {
    final messages = <String>[];
    final root = _prepare(messages);
    await tester.pumpWidget(_host());

    await tester.enterText(find.byType(TextField).at(0), 'https://dav.example');
    await tester.enterText(find.byType(TextField).at(1), 'user');
    await tester.enterText(find.byType(TextField).at(2), 'pass');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await _flush(tester, appdata.saveData(false));

    final saved =
        jsonDecode(
              File('${root.path}/appdata.json').readAsStringSync(),
            )['settings']
            as Map;
    expect(saved[webDavConnectionKey], {
      'url': 'https://dav.example',
      'user': 'user',
      'pass': 'pass',
    });
    expect(saved['webdav'], ['https://dav.example', 'user', 'pass']);
    expect(saved[webDavConnectionPendingConfirmationKey], isFalse);
    expect(find.text('Not configured'), findsNothing);
    expect(messages, contains('Saved'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('purpose switch and migration confirmation persist', (
    tester,
  ) async {
    final messages = <String>[];
    _prepare(messages);
    appdata.settings[webDavConnectionKey] = {
      'url': 'https://dav.example',
      'user': '',
      'pass': '',
    };
    appdata.settings[webDavConnectionPendingConfirmationKey] = true;
    await tester.pumpWidget(_host());

    expect(
      find.text(
        'Previous WebDAV connections differed. The data sync connection is now used by every purpose.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await _flush(tester, appdata.saveData(false));
    expect(appdata.settings[webDavConnectionPendingConfirmationKey], isFalse);

    final row = find.ancestor(
      of: find.text('Data Sync'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pump();
    await _flush(tester, appdata.saveData(false));
    expect(appdata.settings[WebDavPurposes.dataSync], isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
