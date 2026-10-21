import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/app_runtime/webdav_library.dart';
import 'package:venera_next/features/settings/setting_components.dart';
import 'package:venera_next/features/settings/webdav_connection_fields.dart';
import 'package:venera_next/features/settings/webdav_settings.dart';
import 'package:venera_next/features/sync/sync.dart';
import 'package:venera_next/features/webdav_library/webdav_library.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/webdav_connection.dart';
import 'package:venera_next/foundation/widget_utils.dart';

/// Single remote-storage entry: one shared WebDAV connection plus the three
/// purpose groups that consume it.
class RemoteStorageSettings extends StatefulWidget {
  const RemoteStorageSettings({super.key, this.testConnection});

  /// Injected by tests; defaults to the archive transport probe.
  final Future<Res<bool>> Function(BackupConfig)? testConnection;

  @override
  State<RemoteStorageSettings> createState() => _RemoteStorageSettingsState();
}

class _RemoteStorageSettingsState
    extends SettingsSaveState<RemoteStorageSettings> {
  late final WebDavConnectionControllers _controllers;
  final _scrollController = ScrollController();
  final _urlFocus = FocusNode();
  bool _testing = false;

  bool get _busy => savingSettings || _testing;

  WebDavConnection get _connection => WebDavConnection(
    url: _controllers.url.text,
    user: _controllers.user.text,
    password: _controllers.password.text,
  );

  bool get _configured => _connection.isConfigured;

  @override
  void initState() {
    super.initState();
    final connection = WebDavConnection.read((key) => appdata.settings[key]);
    _controllers = WebDavConnectionControllers(
      url: connection.url,
      user: connection.user,
      password: connection.password,
      remotePath: '/',
    );
    appdata.settings.addListener(_refresh);
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    _controllers.dispose();
    _scrollController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pendingMigration =
        appdata.settings[webDavConnectionPendingConfirmationKey] == true;
    return protectSettings(
      Material(
        child: SmoothCustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppbar(title: Text('Remote Storage'.tl)),
            settingsSaveStatus.toSliver(),
            if (pendingMigration) _migrationNotice().toSliver(),
            SettingPartTitle(
              title: 'Connection'.tl,
              icon: Icons.cloud_outlined,
            ),
            _connectionForm().toSliver(),
            SettingPartTitle(title: 'Purposes'.tl, icon: Icons.cloud_sync),
            _purposeGroup(
              title: 'Data Sync'.tl,
              description:
                  'Sync app settings and favorites data with your WebDAV server.'
                      .tl,
              icon: Icons.sync,
              enabledKey: WebDavPurposes.dataSync,
              onConfigure: () => showPopUpWidget(
                context,
                const DataSyncWebdavSetting(showConnection: false),
              ),
            ).toSliver(),
            _purposeGroup(
              title: 'Comic Archive Backup'.tl,
              description:
                  'Back up and restore local comic CBZ archives only. Reading and app data sync are not affected.'
                      .tl,
              icon: Icons.archive_outlined,
              enabledKey: WebDavPurposes.backup,
              onConfigure: () => showPopUpWidget(
                context,
                const BackupWebdavSetting(showConnection: false),
              ),
            ).toSliver(),
            _purposeGroup(
              title: 'WebDAV Comic Library'.tl,
              description:
                  'Read comics from the server directory structure. CBZ files remain available for archive backup.'
                      .tl,
              icon: Icons.menu_book_outlined,
              enabledKey: WebDavPurposes.library,
              onConfigure: () => showPopUpWidget(
                context,
                WebDavComicLibrarySetting(
                  WebDavLibraryScope.of(context),
                  showConnection: false,
                ),
              ),
            ).toSliver(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  Widget _migrationNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: context.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Previous WebDAV connections differed. The data sync connection is now used by every purpose.'
                          .tl,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _confirmMigration,
                  child: Text('Confirm'.tl),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectionForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _configured ? 'Configured'.tl : 'Not configured'.tl,
            style: TextStyle(
              color: _configured
                  ? context.colorScheme.primary
                  : context.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          WebDavConnectionFields(
            controllers: _controllers,
            enabled: !_busy,
            remotePathHint: '/',
            showRemotePath: false,
            urlFocusNode: _urlFocus,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _testOnly,
                  child: Text('Test Connection'.tl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text('Save'.tl),
                ),
              ),
            ],
          ),
          if (_configured)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _confirmClear,
                child: Text('Clear connection'.tl),
              ),
            ),
        ],
      ),
    );
  }

  Widget _purposeGroup({
    required String title,
    required String description,
    required IconData icon,
    required String enabledKey,
    required VoidCallback onConfigure,
  }) {
    final enabled = WebDavPurposes.isEnabled(
      (key) => appdata.settings[key],
      enabledKey,
    );
    final configured = _configured;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 2),
          Text(
            '${'Connection status'.tl}: ${configured ? 'Configured'.tl : 'Not configured'.tl}',
            style: TextStyle(
              color: configured
                  ? context.colorScheme.primary
                  : context.colorScheme.error,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: enabled,
            onChanged: _busy ? null : (value) => _setPurpose(enabledKey, value),
          ),
          const Icon(Icons.keyboard_arrow_right),
        ],
      ),
      onTap: () {
        if (!enabled) {
          context.showMessage(message: 'Enable this purpose first.'.tl);
          return;
        }
        if (!configured) {
          _guideToConnection();
          return;
        }
        onConfigure();
      },
    );
  }

  Future<void> _setPurpose(String key, bool value) async {
    final ok = await saveSetting(
      key,
      () => appdata.updateSettings((draft) {
        draft[key] = value;
      }, sync: false),
    );
    if (ok && key == WebDavPurposes.library && mounted) {
      // Apply the visibility switch without waiting for a restart.
      mountWebDavLibrary(webDavLibrary);
      setState(() {});
    }
  }

  Future<void> _confirmMigration() async {
    await appdata.updateSettings((draft) {
      draft[webDavConnectionPendingConfirmationKey] = false;
    }, sync: false);
  }

  void _guideToConnection() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    _urlFocus.requestFocus();
    context.showMessage(
      message: 'Configure the shared WebDAV connection first.'.tl,
    );
  }

  Future<Res<bool>> _probe() {
    final connection = _connection;
    final config = BackupConfig(
      url: connection.url,
      user: connection.user,
      pass: connection.password,
      remotePath: '/',
    );
    final probe =
        widget.testConnection ?? ComicBackupManager.instance.testConnection;
    return Future<Res<bool>>.sync(() => probe(config)).catchError(
      (Object error, StackTrace stack) => Res<bool>.fromException(error, stack),
    );
  }

  Future<void> _testOnly() async {
    if (_busy || _connection.isEmpty) return;
    setState(() => _testing = true);
    final result = await _probe();
    if (!mounted) return;
    setState(() => _testing = false);
    context.showMessage(
      message: result.error
          ? result.errorMessage!.tl
          : 'Connection successful'.tl,
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final connection = _connection;
    if (!connection.isEmpty) {
      setState(() => _testing = true);
      final result = await _probe();
      if (!mounted) return;
      setState(() => _testing = false);
      if (result.error) {
        context.showMessage(message: result.errorMessage!.tl);
        return;
      }
    }
    final ok = await saveSetting(
      'remote-storage.connection',
      () => appdata.updateSettings((draft) {
        draft[webDavConnectionKey] = connection.toJson();
        if (connection.isEmpty) {
          // Explicit disconnect: clear the legacy credential mirrors too so an
          // old fallback cannot resurrect the connection.
          draft['webdav'] = <String>[];
          draft['backupWebdav'] = <String>[];
          draft['webdavComicLibrary'] = <String>[];
        } else {
          draft['webdav'] = [
            connection.url.trim(),
            connection.user,
            connection.password,
          ];
        }
        draft[webDavConnectionPendingConfirmationKey] = false;
      }, sync: false),
    );
    if (!mounted) return;
    if (ok) context.showMessage(message: 'Saved'.tl);
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear connection'.tl),
        content: Text(
          'Remove the shared connection? Data sync, archive backup and the WebDAV library will stop working until it is configured again.'
              .tl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'.tl),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear'.tl),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _controllers.url.clear();
    _controllers.user.clear();
    _controllers.password.clear();
    await _save();
  }
}
