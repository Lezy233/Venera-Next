import 'package:venera_next/foundation/application_preferences.dart';

import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/features/settings/setting_components.dart';
import 'package:venera_next/features/settings/app_controls.dart';
import 'keyboard_shortcuts.dart';
import 'package:venera_next/features/settings/local_storage_settings.dart';
import 'package:venera_next/features/settings/remote_storage.dart';
import 'package:venera_next/features/settings/settings_task_presenter.dart';
import 'package:venera_next/features/sync/sync.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/cache_manager.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/file_interaction.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/webdav_connection.dart';
import 'package:venera_next/foundation/widget_utils.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  final _tasks = SettingsTaskPresenter();

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_refresh);
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final connection = WebDavConnection.read((key) => appdata.settings[key]);
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("App".tl)),
        SettingPartTitle(title: "Data".tl, icon: Icons.storage),
        const LocalStorageSettings().toSliver(),
        ListTile(
          title: Text("Cache Size".tl),
          subtitle: Text(bytesToReadableString(CacheManager().currentSize)),
        ).toSliver(),
        CallbackSetting(
          title: "Clear Cache".tl,
          actionTitle: "Clear".tl,
          callback: () async {
            await _tasks.run(
              context,
              task: (_) async {
                await CacheManager().clear();
                return null;
              },
              errorMessage: "Error".tl,
              successMessage: "Cache cleared".tl,
              onSuccess: () => setState(() {}),
            );
          },
        ).toSliver(),
        const CacheLimitSetting().toSliver(),
        const HistoryRetentionSetting().toSliver(),
        CallbackSetting(
          title: "Export App Data".tl,
          callback: () async {
            await _tasks.run(
              context,
              task: (operation) async {
                await operation.useTemporaryFile(
                  cacheDirectory: Directory(App.cachePath),
                  filename: 'data.venera',
                  prepare: (file) async {
                    await exportAppData(sync: false, destination: file);
                  },
                  consume: (file) => saveFile(
                    operation: operation,
                    filename: 'data.venera',
                    file: file,
                    checkStop: operation.checkActive,
                  ),
                );
                return null;
              },
              errorMessage: "Error".tl,
            );
          },
          actionTitle: 'Export'.tl,
        ).toSliver(),
        CallbackSetting(
          title: "Import App Data".tl,
          callback: () async {
            await _tasks.run(
              context,
              task: (operation) async {
                final file = await operation.pickFile(
                  () => selectFile(
                    ext: ['venera', 'picadata'],
                    checkStop: operation.checkActive,
                  ),
                );
                if (file == null) return null;
                return operation.useFileCopy(
                  file,
                  cacheDirectory: Directory(App.cachePath),
                  consume: (cacheFile) async {
                    try {
                      if (file.name.endsWith('picadata')) {
                        await importPicaData(cacheFile);
                      } else {
                        await importAppData(cacheFile);
                      }
                    } finally {
                      appNavigation.forceRebuild();
                    }
                    return null;
                  },
                );
              },
              errorMessage: "Failed to import data".tl,
            );
          },
          actionTitle: 'Import'.tl,
        ).toSliver(),
        CallbackSetting(
          title: "Remote Storage".tl,
          subtitle:
              "${"One WebDAV connection shared by data sync, CBZ archive backup and the WebDAV comic library.".tl} "
              "${"Connection status".tl}: ${connection.isConfigured ? "Configured".tl : "Not configured".tl}",
          callback: () => context.to(() => const RemoteStorageSettings()),
          actionTitle: 'Configure'.tl,
        ).toSliver(),
        SettingPartTitle(title: "Behavior".tl, icon: Icons.tune),
        SelectSetting.preference(
          title: "Initial Page".tl,
          preference: DiscoveryPreferences.initialPage,
          optionTranslation: {
            '0': "Home Page".tl,
            '1': "Favorites Page".tl,
            '2': "Explore Page".tl,
            '3': "Categories Page".tl,
          },
        ).toSliver(),
        CallbackSetting(
          title: 'Keyboard shortcuts'.tl,
          actionTitle: 'Open'.tl,
          callback: () => context.to(() => const KeyboardShortcutsSettings()),
        ).toSliver(),
        SwitchSetting.preference(
          title: "Reverse default chapter order".tl,
          preference: AppPreferences.reverseChapterOrder,
        ).toSliver(),
        SettingPartTitle(title: "User".tl, icon: Icons.person_outline),
        SelectSetting.preference(
          title: "Language".tl,
          preference: AppPreferences.language,
          optionTranslation: const {
            "system": "System",
            "zh-CN": "简体中文",
            "zh-TW": "繁體中文",
            "en-US": "English",
          },
          onChanged: () {
            appNavigation.forceRebuild();
          },
        ).toSliver(),
        if (!App.isLinux) const AuthorizationRequiredSetting().toSliver(),
      ],
    );
  }
}
