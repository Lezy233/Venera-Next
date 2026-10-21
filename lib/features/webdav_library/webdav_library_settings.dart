import 'package:venera_next/foundation/webdav_connection.dart';

import 'webdav_library_config.dart';

/// Typed view of the legacy settings keys. Reading never repairs stored data.
class WebDavLibrarySettings {
  const WebDavLibrarySettings({
    required this.connection,
    required this.autoSync,
    required this.intervalMinutes,
    this.enabled = true,
  });

  final WebDavLibraryConfig connection;
  final bool autoSync;
  final int intervalMinutes;
  final bool enabled;

  factory WebDavLibrarySettings.read(Object? Function(String) readValue) {
    final connection = WebDavConnection.readWithLegacy(
      readValue,
      readValue('webdavComicLibrary'),
    );
    final path = readValue('webdavComicLibraryPath');
    final interval = readValue('webdavComicLibrarySyncIntervalMinutes');
    final rounded = interval is num && interval.isFinite ? interval.round() : 0;
    final enabled = WebDavPurposes.isEnabled(readValue, WebDavPurposes.library);
    return WebDavLibrarySettings(
      connection: WebDavLibraryConfig(
        url: connection.url,
        user: connection.user,
        pass: connection.password,
        remotePath: path is String ? path : '/venera_comics/',
      ),
      // Preserve the scheduler's opt-in rule for missing/malformed values.
      autoSync: enabled && readValue('webdavComicLibraryAutoSync') == true,
      intervalMinutes: rounded > 0 ? rounded : 360,
      enabled: enabled,
    );
  }

  Map<String, Object?> toSettings() => {
    webDavConnectionKey: WebDavConnection(
      url: connection.url,
      user: connection.user,
      password: connection.pass,
    ).toJson(),
    'webdavComicLibrary':
        !connection.isValid &&
            connection.user.isEmpty &&
            connection.pass.isEmpty
        ? <String>[]
        : [connection.url, connection.user, connection.pass],
    'webdavComicLibraryPath': connection.remotePath,
    'webdavComicLibraryAutoSync': autoSync,
    'webdavComicLibrarySyncIntervalMinutes': intervalMinutes,
  };
}

/// The composition owner persists a captured configuration and reconciles its
/// runtime effects with the actual published state, including partial failure.
class WebDavLibrarySettingsStore {
  WebDavLibrarySettingsStore({
    required Object? Function(String) readValue,
    required Future<void> Function(WebDavLibrarySettings) persist,
  }) : _readValue = readValue,
       _persist = persist;

  final Object? Function(String) _readValue;
  final Future<void> Function(WebDavLibrarySettings) _persist;

  WebDavLibrarySettings read() => WebDavLibrarySettings.read(_readValue);

  Future<void> save(WebDavLibrarySettings configuration) =>
      _persist(configuration);
}
