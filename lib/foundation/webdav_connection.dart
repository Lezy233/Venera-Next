/// Shared WebDAV connection storage.
///
/// One credential set is stored under [storageKey] and consumed by data sync,
/// CBZ archive backup and the WebDAV comic library. Per-purpose settings (sync
/// schedule, exclude list, backup path, library path, auto-update interval)
/// keep their existing keys.
const webDavConnectionKey = 'webdav.connection';
const webDavConnectionPendingConfirmationKey =
    'webdav.connection.pendingConfirmation';

/// Legacy keys that used to store their own credential triple.
const webDavLegacyConnectionKeys = [
  'webdav',
  'backupWebdav',
  'webdavComicLibrary',
];

/// Purpose switches. Missing values mean enabled so existing installs keep
/// working after the upgrade.
abstract final class WebDavPurposes {
  static const dataSync = 'webdav.purpose.dataSync';
  static const backup = 'webdav.purpose.backup';
  static const library = 'webdav.purpose.library';

  static const all = [dataSync, backup, library];

  static bool isEnabled(Object? Function(String) read, String key) =>
      read(key) != false;
}

/// Immutable WebDAV credential triple shared by all three purposes.
class WebDavConnection {
  const WebDavConnection({this.url = '', this.user = '', this.password = ''});

  static const empty = WebDavConnection();

  final String url;
  final String user;
  final String password;

  bool get isEmpty =>
      url.trim().isEmpty && user.trim().isEmpty && password.trim().isEmpty;

  bool get isConfigured => url.trim().isNotEmpty;

  Map<String, Object?> toJson() => {'url': url, 'user': user, 'pass': password};

  /// Returns null when the stored value is not a connection record.
  static WebDavConnection? tryParse(Object? value) {
    if (value is! Map) return null;
    if (value.isEmpty) return empty;
    final url = value['url'];
    final user = value['user'];
    final pass = value['pass'];
    if (url is! String || user is! String || pass is! String) return null;
    return WebDavConnection(url: url, user: user, password: pass);
  }

  /// Parses the legacy `[url, user, pass]` representation. An empty list is an
  /// explicit "not configured" marker, so it maps to [empty].
  static WebDavConnection? fromLegacy(Object? value) {
    if (value is! List) return null;
    if (value.isEmpty) return empty;
    if (value.length != 3 || value.whereType<String>().length != 3) return null;
    return WebDavConnection(
      url: value[0] as String,
      user: value[1] as String,
      password: value[2] as String,
    );
  }

  /// Canonical shared connection. When the shared record is empty the legacy
  /// data-sync key is used, which keeps old snapshots readable before the
  /// startup migration has run.
  static WebDavConnection read(Object? Function(String) read) {
    final shared = tryParse(read(webDavConnectionKey));
    if (shared != null && !shared.isEmpty) return shared;
    final legacy = fromLegacy(read('webdav'));
    if (legacy != null && !legacy.isEmpty) return legacy;
    return shared ?? legacy ?? empty;
  }

  /// Shared connection with a purpose-specific legacy fallback. Used while the
  /// old forms remain reachable for one release cycle.
  static WebDavConnection readWithLegacy(
    Object? Function(String) read,
    Object? legacyValue,
  ) {
    final shared = tryParse(read(webDavConnectionKey));
    if (shared != null && !shared.isEmpty) return shared;
    final legacy = fromLegacy(legacyValue);
    if (legacy != null && !legacy.isEmpty) return legacy;
    return shared ?? legacy ?? empty;
  }

  static String signature(WebDavConnection connection) => [
    connection.url.trim(),
    connection.user.trim(),
    connection.password.trim(),
  ].join('\u0000');
}

/// Inspects the three legacy credential keys and produces the values the
/// startup migration should write. Legacy keys are never removed.
class WebDavConnectionMigration {
  const WebDavConnectionMigration._(
    this.connection,
    this.pendingConfirmation,
    this.changes,
  );

  final WebDavConnection connection;
  final bool pendingConfirmation;
  final Map<String, Object?> changes;

  bool get changed => changes.isNotEmpty;

  static WebDavConnectionMigration inspect(Object? Function(String) read) {
    final storedShared = WebDavConnection.tryParse(read(webDavConnectionKey));
    final currentPending = read(webDavConnectionPendingConfirmationKey) == true;
    if (storedShared != null && !storedShared.isEmpty) {
      // An existing shared record is authoritative; only the upgrade writes
      // the pending marker for legacy discrepancies.
      return WebDavConnectionMigration._(
        storedShared,
        currentPending,
        const {},
      );
    }

    final legacy = <String, WebDavConnection>{};
    for (final key in webDavLegacyConnectionKeys) {
      final parsed = WebDavConnection.fromLegacy(read(key));
      if (parsed != null && !parsed.isEmpty) legacy[key] = parsed;
    }

    final chosen =
        legacy['webdav'] ??
        (legacy.isNotEmpty
            ? legacy.values.first
            : storedShared ?? WebDavConnection.empty);
    final distinct = legacy.values.map(WebDavConnection.signature).toSet();
    final pending = currentPending || distinct.length > 1;

    final changes = <String, Object?>{};
    final desired = chosen.toJson();
    if (!_sameMap(read(webDavConnectionKey), desired)) {
      changes[webDavConnectionKey] = desired;
    }
    if (pending && !currentPending) {
      changes[webDavConnectionPendingConfirmationKey] = true;
    }
    return WebDavConnectionMigration._(chosen, pending, changes);
  }

  static bool _sameMap(Object? stored, Map<String, Object?> desired) {
    final parsed = WebDavConnection.tryParse(stored);
    if (parsed == null) return false;
    return WebDavConnection.signature(parsed) ==
        WebDavConnection.signature(
          WebDavConnection(
            url: desired['url']! as String,
            user: desired['user']! as String,
            password: desired['pass']! as String,
          ),
        );
  }
}
