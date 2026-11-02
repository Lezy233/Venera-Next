import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/features/search/search_profile.dart';
import 'package:venera_next/features/search/search_profiles.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';

void main() {
  test(
    'search profile JSON round trip preserves order, enabled state and options',
    () {
      const profile = SearchProfile(
        id: 'p1',
        name: '  Works  ',
        sources: [
          SearchProfileSource(sourceKey: 'a', enabled: true, options: ['one']),
          SearchProfileSource(sourceKey: 'b', enabled: false, options: ['two']),
        ],
      );
      final decoded = SearchProfile.fromJson(profile.toJson());
      expect(decoded?.id, 'p1');
      expect(decoded?.sources.map((item) => item.sourceKey), ['a', 'b']);
      expect(decoded?.sources.last.enabled, isFalse);
      expect(decoded?.sources.first.options, ['one']);
    },
  );

  test('profile manager CRUD persists default and validates names', () async {
    final root = Directory.systemTemp.createTempSync('search-profile-manager-');
    final previousProfiles = appdata.settings['searchProfiles'];
    final previousDefault = appdata.settings['defaultSearchProfile'];
    App.dataPath = root.path;
    appdata.settings['searchProfiles'] = <dynamic>[];
    appdata.settings['defaultSearchProfile'] = null;
    addTearDown(() {
      appdata.settings['searchProfiles'] = previousProfiles;
      appdata.settings['defaultSearchProfile'] = previousDefault;
      App.dataPath = Directory.systemTemp.path;
      root.deleteSync(recursive: true);
    });
    final manager = SearchProfileManager.instance;
    final created = await manager.create('Saved', const [
      SearchProfileSource(sourceKey: 'source-a', enabled: true, options: ['x']),
    ]);
    expect(manager.byId(created.id)?.sources.single.options, ['x']);
    await manager.setDefault(created.id);
    expect(manager.defaultProfile?.id, created.id);
    await manager.rename(created.id, 'Renamed');
    expect(manager.defaultProfile?.name, 'Renamed');
    await manager.update(created.id, const [
      SearchProfileSource(
        sourceKey: 'source-a',
        enabled: false,
        options: ['y'],
      ),
    ]);
    expect(manager.byId(created.id)?.sources.single.enabled, isFalse);
    expect(() => manager.validateName(' Renamed '), throwsFormatException);
    await manager.remove(created.id);
    expect(manager.all, isEmpty);
    expect(manager.defaultId, isNull);
  });

  testWidgets('profile settings has no compact layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SearchProfilesSettings())),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
